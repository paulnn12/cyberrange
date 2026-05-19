import os
import re
import subprocess
from datetime import datetime
from flask import Blueprint, render_template, request, jsonify
from .backends import query_anthropic, query_ollama

bp = Blueprint("main", __name__)

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "output")


def _strip_markdown_fences(text: str) -> str:
    """Retire les blocs ```bash ... ``` ou ``` ... ``` qu'un LLM peut ajouter."""
    match = re.search(r"```(?:bash|sh)?\n(.*?)```", text, re.DOTALL)
    return match.group(1).strip() if match else text.strip()


def _save_and_run(text: str) -> tuple[str, str]:
    """Écrit le script dans output/ et l'exécute depuis ce répertoire."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filename = datetime.now().strftime("%Y%m%d_%H%M%S") + ".sh"
    path = os.path.join(OUTPUT_DIR, filename)

    with open(path, "w") as f:
        f.write(_strip_markdown_fences(text))
    os.chmod(path, 0o755)

    result = subprocess.run(
        ["bash", filename],
        cwd=OUTPUT_DIR,
        capture_output=True,
        text=True,
        timeout=60,
    )
    exec_output = result.stdout + result.stderr
    return filename, exec_output


@bp.route("/")
def index():
    return render_template("index.html")


@bp.route("/prompt", methods=["POST"])
def prompt():
    data = request.get_json()
    backend = data.get("backend")
    user_prompt = data.get("prompt", "").strip()

    if not user_prompt:
        return jsonify({"error": "prompt vide"}), 400

    try:
        if backend == "anthropic":
            response_text = query_anthropic(user_prompt)

        elif backend == "ollama":
            ip = data.get("ip", "").strip()
            port = data.get("port", "11434").strip()
            model = data.get("model", "").strip()
            if not ip or not model:
                return jsonify({"error": "IP et modèle requis pour ollama"}), 400
            response_text = query_ollama(user_prompt, ip, port, model)

        else:
            return jsonify({"error": "backend inconnu"}), 400

        filename, exec_output = _save_and_run(response_text)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({
        "response": response_text,
        "saved_as": filename,
        "exec_output": exec_output,
    })
