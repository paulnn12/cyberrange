import json
import os
from pathlib import Path
import anthropic
import requests

FEASIBILITY_SYSTEM_PROMPT = (Path(__file__).parent / "prompts" / "feasibility_prompt.md").read_text(encoding="utf-8")


def check_feasibility(prompt: str, backend: str, **backend_kwargs) -> dict:
    feasibility_prompt = f"Evaluate this lab request for Docker feasibility:\n\n{prompt}"

    try:
        if backend == "anthropic":
            api_key = os.environ.get("ANTHROPIC_API_KEY")
            if not api_key:
                raise ValueError("ANTHROPIC_API_KEY is not set")
            client = anthropic.Anthropic(api_key=api_key)
            message = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=400,
                system=FEASIBILITY_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": feasibility_prompt}],
            )
            raw = message.content[0].text

        elif backend == "ollama":
            ip    = backend_kwargs.get("ip", "")
            port  = backend_kwargs.get("port", "11434")
            model = backend_kwargs.get("model", "")
            url   = f"http://{ip}:{port}/api/chat"
            response = requests.post(
                url,
                json={
                    "model": model,
                    "stream": False,
                    "messages": [
                        {"role": "system", "content": FEASIBILITY_SYSTEM_PROMPT},
                        {"role": "user",   "content": feasibility_prompt},
                    ],
                    "options": {"num_predict": 400, "temperature": 0.0},
                },
                timeout=60,
            )
            response.raise_for_status()
            raw = response.json()["message"]["content"]

        else:
            return {"feasible": True}

        return json.loads(raw)

    except (json.JSONDecodeError, KeyError):
        return {"feasible": True}
    except Exception:
        return {"feasible": True}
