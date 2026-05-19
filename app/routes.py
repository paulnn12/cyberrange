import io
import os
import re
import subprocess
import zipfile
from datetime import datetime
from flask import Blueprint, render_template, request, jsonify, send_file
from .backends import query_anthropic, query_ollama

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
            response_text = query_anthropic(user_prompt)

        elif backend == "ollama":
            ip    = data.get("ip", "").strip()
            port  = data.get("port", "11434").strip()
            model = data.get("model", "").strip()
            if not ip or not model:
                return jsonify({"error": "IP and model are required for Ollama"}), 400
            response_text = query_ollama(user_prompt, ip, port, model)

        else:
            return jsonify({"error": "Unknown backend"}), 400

        filename, exec_output, new_dirs = _save_and_run(response_text)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({
        "response":    response_text,
        "saved_as":    filename,
        "exec_output": exec_output,
        "new_dirs":    new_dirs,
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
