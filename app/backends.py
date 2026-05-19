import os
import anthropic
import requests
from pathlib import Path

# ---------------------------------------------------------------------------
# System prompt injected before every user message.
# Edit system_prompt.md to change the LLM's behaviour.
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = (Path(__file__).parent / "system_prompt.md").read_text(encoding="utf-8")
# ---------------------------------------------------------------------------


def query_anthropic(prompt: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY is not set")

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=16000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def query_ollama(prompt: str, ip: str, port: str, model: str) -> str:
    # /api/chat keeps the system prompt separate from the user turn,
    # which improves inference quality vs. concatenating into the prompt field.
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
                # Large context window to fit the system prompt.
                # Reduce to 16384 if the model runs out of memory.
                "num_ctx":     32768,
                "num_predict": 16000,
                "temperature": 0.2,
            },
        },
        timeout=300,
    )
    response.raise_for_status()
    return response.json()["message"]["content"]
