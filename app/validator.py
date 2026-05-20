import json
import logging
import os
from pathlib import Path
import subprocess
import time

import requests

logger = logging.getLogger(__name__)

MAX_RETRIES = 3
COMPOSE_TIMEOUT = 300
HEALTH_WAIT = 30

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "output")

_FIX_SYSTEM = (Path(__file__).parent / "prompts" / "fix_prompt.md").read_text(encoding="utf-8")


def _get_subdirs(directory: str) -> set:
    try:
        return {e.name for e in os.scandir(directory) if e.is_dir()}
    except FileNotFoundError:
        return set()


def _compose_down(lab_dir: str) -> None:
    try:
        subprocess.run(
            ["docker", "compose", "down", "-v"],
            cwd=lab_dir,
            timeout=60,
            capture_output=True,
        )
    except Exception:
        pass


def _collect_error_context(lab_subdir: str) -> tuple[bool, str]:
    """Return (all_healthy, diagnostic_context) for the LLM fixer."""
    context = []

    # 1. Service state
    ps = subprocess.run(
        ["docker", "compose", "ps", "--format", "json"],
        cwd=lab_subdir, capture_output=True, text=True, timeout=30,
    )
    context.append(f"=== SERVICE STATUS ===\n{ps.stdout}")

    # 2. Determine health from ps output
    unhealthy = []
    services_raw = ps.stdout.strip()
    parsed_services = []
    if services_raw:
        for line in services_raw.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                svc = json.loads(line)
                parsed_services.append(svc)
            except json.JSONDecodeError:
                continue
            state  = (svc.get("State")  or svc.get("status") or "").lower()
            health = (svc.get("Health") or "").lower()
            name   = svc.get("Name") or svc.get("name") or "unknown"
            if health in ("unhealthy", "starting"):
                unhealthy.append(f"{name} (health={health})")
            elif state not in ("running", "healthy"):
                unhealthy.append(f"{name} (state={state})")

    # 3. Logs (last 80 lines, all services)
    logs = subprocess.run(
        ["docker", "compose", "logs", "--tail=80", "--no-color"],
        cwd=lab_subdir, capture_output=True, text=True, timeout=30,
    )
    context.append(f"=== LOGS ===\n{logs.stdout}\n{logs.stderr}")

    # 4. Basic HTTP probe on every exposed port
    for svc in parsed_services:
        for pub in svc.get("Publishers", []):
            host_port = pub.get("PublishedPort")
            if host_port:
                try:
                    r = requests.get(
                        f"http://localhost:{host_port}",
                        timeout=5, allow_redirects=True,
                    )
                    context.append(f"=== HTTP {host_port} → {r.status_code} ===")
                except Exception as e:
                    context.append(f"=== HTTP {host_port} → FAILED: {e} ===")

    all_healthy = len(unhealthy) == 0
    return all_healthy, "\n\n".join(context)


def _fix_script(original_script: str, error_output: str, backend: str, **kwargs) -> str:
    user_msg = f"ORIGINAL SCRIPT:\n{original_script}\n\nERROR OUTPUT:\n{error_output}"

    if backend == "anthropic":
        import os as _os
        import anthropic
        api_key = _os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY is not set")
        client = anthropic.Anthropic(api_key=api_key)
        msg = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=16000,
            system=_FIX_SYSTEM,
            messages=[{"role": "user", "content": user_msg}],
        )
        return msg.content[0].text

    elif backend == "ollama":
        ip = kwargs.get("ip", "")
        port = kwargs.get("port", "11434")
        model = kwargs.get("model", "")
        url = f"http://{ip}:{port}/api/chat"
        response = requests.post(
            url,
            json={
                "model": model,
                "stream": False,
                "messages": [
                    {"role": "system", "content": _FIX_SYSTEM},
                    {"role": "user", "content": user_msg},
                ],
                "options": {"num_ctx": 32768, "num_predict": 16000, "temperature": 0.2},
            },
            timeout=300,
        )
        response.raise_for_status()
        return response.json()["message"]["content"]

    raise ValueError(f"Unknown backend: {backend}")


def run_validation_loop(script_path: str, lab_dir: str, backend: str, **backend_kwargs) -> dict:
    # Check Docker is available
    try:
        subprocess.run(
            ["docker", "info"],
            capture_output=True,
            timeout=10,
            check=True,
        )
    except Exception as e:
        logger.warning("Docker not available, skipping validation: %s", e)
        return {"success": None, "attempts": 0, "message": "Docker not available"}

    last_error = ""
    current_lab_dir = lab_dir

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            # Step 1: run the (possibly rewritten) script
            dirs_before = _get_subdirs(OUTPUT_DIR)
            subprocess.run(
                ["bash", script_path],
                cwd=OUTPUT_DIR,
                timeout=60,
                check=True,
                capture_output=True,
            )
            dirs_after = _get_subdirs(OUTPUT_DIR)
            new_dirs = sorted(dirs_after - dirs_before)

            # Step 2: find the lab subdirectory
            if new_dirs:
                current_lab_dir = os.path.join(OUTPUT_DIR, new_dirs[-1])
            elif not os.path.isdir(current_lab_dir):
                last_error = "Script ran but created no subdirectory"
                logger.warning("Attempt %d: %s", attempt, last_error)
                continue

            # Step 3: docker compose up --build -d
            up_result = subprocess.run(
                ["docker", "compose", "up", "--build", "-d"],
                cwd=current_lab_dir,
                timeout=COMPOSE_TIMEOUT,
                capture_output=True,
                text=True,
            )
            if up_result.returncode != 0:
                last_error = up_result.stdout + up_result.stderr
            else:
                # Step 4: wait, then collect status
                time.sleep(HEALTH_WAIT)
                all_healthy, error_context = _collect_error_context(current_lab_dir)

                if all_healthy:
                    return {
                        "success": True,
                        "attempts": attempt,
                        "lab_dir": current_lab_dir,
                        "logs": error_context,
                    }
                last_error = error_context

            # Step 6: ask LLM to fix the script
            if attempt < MAX_RETRIES:
                logger.info("Attempt %d failed, asking LLM to fix script.", attempt)
                with open(script_path, "r") as f:
                    original = f.read()
                fixed = _fix_script(original, last_error, backend, **backend_kwargs)
                with open(script_path, "w") as f:
                    f.write(fixed)

        except subprocess.TimeoutExpired as e:
            last_error = f"Timeout: {e}"
            logger.warning("Attempt %d timed out: %s", attempt, e)
        except Exception as e:
            last_error = str(e)
            logger.warning("Attempt %d error: %s", attempt, e)
        finally:
            # Step 7: tear down before retry
            if os.path.isdir(current_lab_dir):
                _compose_down(current_lab_dir)

    return {"success": False, "attempts": MAX_RETRIES, "last_error": last_error}
