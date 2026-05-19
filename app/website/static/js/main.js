function toggleBackend() {
  const backend = document.getElementById('backend').value;
  document.getElementById('ollama-section').classList.toggle('visible', backend === 'ollama');
}

function buildPayload(prompt) {
  const backend = document.getElementById('backend').value;
  const payload = { backend, prompt };

  if (backend === 'ollama') {
    payload.ip    = document.getElementById('ollama-ip').value.trim();
    payload.port  = document.getElementById('ollama-port').value.trim();
    payload.model = document.getElementById('ollama-model').value.trim();
  }

  return payload;
}

function validatePayload(payload) {
  if (payload.backend === 'ollama' && (!payload.ip || !payload.model)) {
    return 'IP and model are required for Ollama.';
  }
  return null;
}

function setStatus(message, type = '') {
  const el = document.getElementById('status');
  el.className = type;
  el.textContent = message;
}

function showResult(data) {
  const scriptOutput = document.getElementById('script-output');
  scriptOutput.textContent = data.response;
  scriptOutput.style.display = 'block';

  const dlScriptBtn = document.getElementById('dl-script-btn');
  dlScriptBtn.dataset.filename = data.saved_as;
  dlScriptBtn.style.display = 'inline-block';

  document.getElementById('exec-output').textContent = data.exec_output || '(no output)';
  document.getElementById('exec-block').style.display = 'block';

  const dlDirBtn = document.getElementById('dl-dir-btn');
  if (data.new_dirs && data.new_dirs.length > 0) {
    dlDirBtn.dataset.dirname = data.new_dirs[0];
    dlDirBtn.style.display = 'inline-block';
  } else {
    dlDirBtn.style.display = 'none';
  }
}

function resetUI() {
  document.getElementById('script-output').style.display = 'none';
  document.getElementById('exec-block').style.display = 'none';
  document.getElementById('dl-script-btn').style.display = 'none';
  document.getElementById('dl-dir-btn').style.display = 'none';
}

async function sendPrompt() {
  const prompt = document.getElementById('prompt').value.trim();
  if (!prompt) { setStatus('Empty prompt.'); return; }

  const payload = buildPayload(prompt);
  const validationError = validatePayload(payload);
  if (validationError) { setStatus(validationError); return; }

  const sendBtn = document.getElementById('send-btn');
  sendBtn.disabled = true;
  resetUI();
  setStatus('Sending…');

  try {
    const res  = await fetch('/prompt', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();

    if (data.error) {
      setStatus('Error: ' + data.error, 'err');
    } else {
      setStatus(`Executed → output/${data.saved_as}`, 'ok');
      showResult(data);
    }
  } catch (err) {
    setStatus('Network error: ' + err.message, 'err');
  } finally {
    sendBtn.disabled = false;
  }
}

function downloadScript() {
  const content  = document.getElementById('script-output').textContent;
  const filename = document.getElementById('dl-script-btn').dataset.filename || 'response.sh';
  const blob = new Blob([content], { type: 'text/x-shellscript' });
  const anchor = Object.assign(document.createElement('a'), {
    href: URL.createObjectURL(blob),
    download: filename,
  });
  anchor.click();
  URL.revokeObjectURL(anchor.href);
}

function downloadDir() {
  const dirname = document.getElementById('dl-dir-btn').dataset.dirname;
  if (!dirname) return;
  window.location.href = `/download-dir/${encodeURIComponent(dirname)}`;
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('prompt').addEventListener('keydown', e => {
    if (e.ctrlKey && e.key === 'Enter') sendPrompt();
  });
});
