import os
import anthropic
import requests

# ---------------------------------------------------------------------------
# Prompt de contexte injecté avant chaque message utilisateur.
# Modifiez cette variable pour changer le comportement du LLM.
# ---------------------------------------------------------------------------
SYSTEM_CONTEXT = """Tu es un expert en scripting shell (bash).
Réponds UNIQUEMENT avec le script shell demandé, sans explication ni balise markdown.
Le script doit être directement exécutable."""
# ---------------------------------------------------------------------------


def _build_prompt(user_input: str) -> str:
    return f"{SYSTEM_CONTEXT}\n\n{user_input}"


def query_anthropic(prompt: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY non définie")

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[{"role": "user", "content": _build_prompt(prompt)}],
    )
    return message.content[0].text


def query_ollama(prompt: str, ip: str, port: str, model: str) -> str:
    url = f"http://{ip}:{port}/api/generate"
    response = requests.post(
        url,
        json={"model": model, "prompt": _build_prompt(prompt), "stream": False},
        timeout=120,
    )
    response.raise_for_status()
    return response.json().get("response", "")
