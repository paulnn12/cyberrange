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


def _build_prompt(user_input: str) -> str:
    return user_input


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
    url = f"http://{ip}:{port}/api/generate"
    response = requests.post(
        url,
        json={
            "model": model,
            "prompt": _build_prompt(prompt),
            "stream": False,
            "options": {
                "num_predict": 16000,
                "temperature": 0.2,
            },
        },
        timeout=300,
    )
    response.raise_for_status()
    return response.json().get("response", "")
