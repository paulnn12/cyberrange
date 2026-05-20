import io
import os
import re
import subprocess
import threading
import uuid
import zipfile
from datetime import datetime
from flask import Blueprint, render_template, request, jsonify, send_file
from .backends import query_anthropic, query_ollama, generate_readme
from .feasibility import check_feasibility
from .validator import run_validation_loop, MAX_RETRIES

JOBS = {}  # job_id -> {"status": str, "step": str, "result": dict|None}

bp = Blueprint("main", __name__)

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "output")


def _strip_markdown_fences(text: str) -> str:
    """Remove ```bash ... ``` or ``` ... ``` wrappers that LLMs sometimes add."""
    match = re.search(r"```(?:bash|sh)?\n(.*?)```", text, re.DOTALL)
    return match.group(1).strip() if match else text.strip()


def _get_subdirs(directory: str) -> set[str]:
    """Return the set of direct subdirectory names inside directory."""
    try:
        return {
            entry.name
            for entry in os.scandir(directory)
            if entry.is_dir()
        }
    except FileNotFoundError:
        return set()


def _save_and_run(text: str) -> tuple[str, str, list[str]]:
    """Write the script to output/, run it, and return new directories created by it."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filename = datetime.now().strftime("%Y%m%d_%H%M%S") + ".sh"
    path = os.path.join(OUTPUT_DIR, filename)

    with open(path, "w") as f:
        f.write(_strip_markdown_fences(text))
    os.chmod(path, 0o755)

    dirs_before = _get_subdirs(OUTPUT_DIR)

    result = subprocess.run(
        ["bash", filename],
        cwd=OUTPUT_DIR,
        capture_output=True,
        text=True,
        timeout=60,
    )

    dirs_after  = _get_subdirs(OUTPUT_DIR)
    new_dirs    = sorted(dirs_after - dirs_before)

    return filename, result.stdout + result.stderr, new_dirs


@bp.route("/")
def index():
    return render_template("index.html")


@bp.route("/prompt", methods=["POST"])
def handle_prompt():
    data = request.get_json()
    backend     = data.get("backend")
    user_prompt = data.get("prompt", "").strip()

    if not user_prompt:
        return jsonify({"error": "Empty prompt"}), 400

    try:
        if backend == "anthropic":
            feasibility = check_feasibility(user_prompt, backend)
            if not feasibility.get("feasible", True):
                return jsonify({
                    "error":      "not_feasible",
                    "reason":     feasibility.get("reason", ""),
                    "suggestion": feasibility.get("suggestion", ""),
                }), 422
            response_text = query_anthropic(user_prompt)

        elif backend == "ollama":
            ip    = data.get("ip", "").strip()
            port  = data.get("port", "11434").strip()
            model = data.get("model", "").strip()
            if not ip or not model:
                return jsonify({"error": "IP and model are required for Ollama"}), 400
            feasibility = check_feasibility(user_prompt, backend, ip=ip, port=port, model=model)
            if not feasibility.get("feasible", True):
                return jsonify({
                    "error":      "not_feasible",
                    "reason":     feasibility.get("reason", ""),
                    "suggestion": feasibility.get("suggestion", ""),
                }), 422
            response_text = query_ollama(user_prompt, ip, port, model)

        else:
            return jsonify({"error": "Unknown backend"}), 400

        filename, exec_output, new_dirs = _save_and_run(response_text)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # Build kwargs for the validation LLM call
    script_path = os.path.join(OUTPUT_DIR, filename)
    lab_dir = os.path.join(OUTPUT_DIR, new_dirs[0]) if new_dirs else OUTPUT_DIR
    backend_kwargs = {}
    if backend == "ollama":
        backend_kwargs = {
            "ip":    data.get("ip", "").strip(),
            "port":  data.get("port", "11434").strip(),
            "model": data.get("model", "").strip(),
        }

    try:
        val_result = run_validation_loop(script_path, lab_dir, backend, **backend_kwargs)
    except Exception as e:
        val_result = {"success": False, "attempts": 0, "last_error": str(e)}

    if val_result.get("success") is True:
        validation = {"success": True, "attempts": val_result["attempts"], "message": "Lab validated successfully."}
    elif val_result.get("success") is None:
        validation = {"success": None, "attempts": 0, "message": val_result.get("message", "Validation skipped.")}
    else:
        validation = {
            "success":  False,
            "attempts": val_result.get("attempts", MAX_RETRIES),
            "message":  "Lab could not be validated after 3 attempts.",
        }

    # --- README generation ---
    readme_content = ""
    readme_filename = ""
    try:
        with open(os.path.join(OUTPUT_DIR, filename), encoding="utf-8") as f:
            script_content = f.read()
        readme_content  = generate_readme(script_content, filename, backend, **backend_kwargs)
        readme_filename = filename.replace(".sh", "_README.md")
        with open(os.path.join(OUTPUT_DIR, readme_filename), "w", encoding="utf-8") as f:
            f.write(readme_content)
    except Exception as readme_err:
        readme_content  = f"README generation failed: {readme_err}"
        readme_filename = ""
    # --- end README generation ---

    return jsonify({
        "response":         response_text,
        "saved_as":         filename,
        "exec_output":      exec_output,
        "new_dirs":         new_dirs,
        "validation":       validation,
        "readme":           readme_content,
        "readme_filename":  readme_filename,
    })


def _run_job(job_id: str, payload: dict) -> None:
    job = JOBS[job_id]
    backend = payload["backend"]
    user_prompt = payload["prompt"]

    try:
        job["step"] = "generating"
        job["status"] = "running"

        if backend == "anthropic":
            feasibility = check_feasibility(user_prompt, backend)
            if not feasibility.get("feasible", True):
                job["status"] = "done"
                job["result"] = {
                    "error":      "not_feasible",
                    "reason":     feasibility.get("reason", ""),
                    "suggestion": feasibility.get("suggestion", ""),
                }
                return
            response_text = query_anthropic(user_prompt)
        elif backend == "ollama":
            ip    = payload.get("ip", "")
            port  = payload.get("port", "11434")
            model = payload.get("model", "")
            feasibility = check_feasibility(user_prompt, backend, ip=ip, port=port, model=model)
            if not feasibility.get("feasible", True):
                job["status"] = "done"
                job["result"] = {
                    "error":      "not_feasible",
                    "reason":     feasibility.get("reason", ""),
                    "suggestion": feasibility.get("suggestion", ""),
                }
                return
            response_text = query_ollama(user_prompt, ip, port, model)
        else:
            job["status"] = "error"
            job["result"] = {"error": "Unknown backend"}
            return

        filename, exec_output, new_dirs = _save_and_run(response_text)

        script_path = os.path.join(OUTPUT_DIR, filename)
        lab_dir = os.path.join(OUTPUT_DIR, new_dirs[0]) if new_dirs else OUTPUT_DIR
        backend_kwargs = {}
        if backend == "ollama":
            backend_kwargs = {"ip": payload.get("ip", ""), "port": payload.get("port", "11434"), "model": payload.get("model", "")}

        job["step"] = "validating"

        original_fix = run_validation_loop.__globals__.get("_fix_script")

        # Patch validator to update job step during retries
        import app.validator as _val
        _orig_fix = _val._fix_script

        def _patched_fix(script, error, bk, **kw):
            attempts_so_far = JOBS[job_id].get("_attempt", 1)
            JOBS[job_id]["step"] = f"fixing_attempt_{attempts_so_far + 1}"
            JOBS[job_id]["_attempt"] = attempts_so_far + 1
            return _orig_fix(script, error, bk, **kw)

        _val._fix_script = _patched_fix
        try:
            val_result = run_validation_loop(script_path, lab_dir, backend, **backend_kwargs)
        finally:
            _val._fix_script = _orig_fix

        if val_result.get("success") is True:
            validation = {"success": True, "attempts": val_result["attempts"], "message": "Lab validated successfully."}
        elif val_result.get("success") is None:
            validation = {"success": None, "attempts": 0, "message": val_result.get("message", "Validation skipped.")}
        else:
            validation = {"success": False, "attempts": val_result.get("attempts", MAX_RETRIES), "message": "Lab could not be validated after 3 attempts."}

        # --- README generation ---
        readme_content = ""
        readme_filename = ""
        try:
            with open(os.path.join(OUTPUT_DIR, filename), encoding="utf-8") as f:
                script_content = f.read()
            readme_content  = generate_readme(script_content, filename, backend, **backend_kwargs)
            readme_filename = filename.replace(".sh", "_README.md")
            with open(os.path.join(OUTPUT_DIR, readme_filename), "w", encoding="utf-8") as f:
                f.write(readme_content)
        except Exception as readme_err:
            readme_content  = f"README generation failed: {readme_err}"
            readme_filename = ""
        # --- end README generation ---

        job["status"] = "done"
        job["result"] = {
            "response":         response_text,
            "saved_as":         filename,
            "exec_output":      exec_output,
            "new_dirs":         new_dirs,
            "validation":       validation,
            "readme":           readme_content,
            "readme_filename":  readme_filename,
        }

    except Exception as e:
        job["status"] = "error"
        job["result"] = {"error": str(e)}


@bp.route("/prompt/async", methods=["POST"])
def handle_prompt_async():
    data = request.get_json()
    backend     = data.get("backend")
    user_prompt = data.get("prompt", "").strip()

    if not user_prompt:
        return jsonify({"error": "Empty prompt"}), 400

    job_id = str(uuid.uuid4())
    JOBS[job_id] = {"status": "pending", "step": None, "result": None, "_attempt": 1}

    t = threading.Thread(target=_run_job, args=(job_id, data), daemon=True)
    t.start()

    return jsonify({"job_id": job_id}), 202


@bp.route("/prompt/status/<job_id>")
def prompt_status(job_id: str):
    job = JOBS.get(job_id)
    if job is None:
        return jsonify({"error": "Unknown job"}), 404
    return jsonify({
        "status": job["status"],
        "step":   job.get("step"),
        "result": job["result"],
    })


@bp.route("/download-dir/<path:dirname>")
def download_dir(dirname: str):
    """Zip a subdirectory of output/ and send it as a file download."""
    # Prevent path traversal
    target = os.path.realpath(os.path.join(OUTPUT_DIR, dirname))
    if not target.startswith(os.path.realpath(OUTPUT_DIR) + os.sep):
        return jsonify({"error": "Invalid path"}), 400
    if not os.path.isdir(target):
        return jsonify({"error": "Directory not found"}), 404

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(target):
            for file in files:
                abs_path = os.path.join(root, file)
                arc_path = os.path.relpath(abs_path, OUTPUT_DIR)
                zf.write(abs_path, arc_path)
    buf.seek(0)

    return send_file(
        buf,
        mimetype="application/zip",
        as_attachment=True,
        download_name=f"{dirname}.zip",
    )


@bp.route("/download-readme/<path:filename>")
def download_readme(filename: str):
    """Send the professor README as a .md file download."""
    target = os.path.realpath(os.path.join(OUTPUT_DIR, filename))
    if not target.startswith(os.path.realpath(OUTPUT_DIR) + os.sep):
        return jsonify({"error": "Invalid path"}), 400
    if not os.path.isfile(target):
        return jsonify({"error": "File not found"}), 404
    return send_file(
        target,
        mimetype="text/markdown",
        as_attachment=True,
        download_name=filename,
    )
