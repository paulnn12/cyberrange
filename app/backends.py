import os
import anthropic
import requests
from pathlib import Path

# ---------------------------------------------------------------------------
# Prompt de contexte injecté avant chaque message utilisateur.
# Modifiez cette variable pour changer le comportement du LLM.
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = (Path(__file__).parent / "system_prompt.md").read_text(encoding="utf-8")
# ---------------------------------------------------------------------------


def query_anthropic(prompt: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY non définie")

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=16000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def query_ollama(prompt: str, ip: str, port: str, model: str) -> str:
    # /api/chat permet de passer system séparément (meilleure inférence que la
    # concaténation dans le prompt) et d'éviter de saturer le contexte utilisateur.
    url = f"http://{ip}:{port}/api/chat"
    response = requests.post(
        url,
        json={
            "model": model,
            "stream": False,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": prompt},
            ],
            "options": {
                # Fenêtre de contexte large pour absorber le system prompt volumineux.
                # La plupart des modèles récents supportent 32 k+; réduire si OOM.
                "num_ctx":     32768,
                "num_predict": 16000,
                "temperature": 0.2,
            },
        },
        timeout=300,
    )
    response.raise_for_status()
    return response.json()["message"]["content"]
