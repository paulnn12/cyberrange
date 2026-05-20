const STEP_LABELS = {
  generating:          '✦ Generating script...',
  validating:          '✦ Starting Docker lab...',
  checking:            '✦ Checking services...',
  fixing_attempt_2:    '✦ Auto-fixing (attempt 2/3)...',
  fixing_attempt_3:    '✦ Auto-fixing (attempt 3/3)...',
};

const STEP_PROGRESS = {
  generating:       15,
  validating:       45,
  checking:         70,
  fixing_attempt_2: 78,
  fixing_attempt_3: 88,
};

let _pollTimer = null;

// ---------------------------------------------------------------------------
// Lightweight markdown → HTML renderer (headers, code blocks, lists, bold,
// inline code). Sufficient for the structured README the LLM produces.
// ---------------------------------------------------------------------------
function renderMarkdown(md) {
  const lines = md.split('\n');
  let html = '';
  let inCode = false;
  let codeLang = '';
  let codeBuf = [];
  let inList = false;

  function flushList() {
    if (inList) { html += '</ul>\n'; inList = false; }
  }
  function flushCode() {
    const escaped = codeBuf.join('\n')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    html += `<pre><code>${escaped}</code></pre>\n`;
    codeBuf = []; inCode = false; codeLang = '';
  }
  function inlineFormat(text) {
    return text
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  }

  for (const raw of lines) {
    const line = raw;

    // fenced code block toggle
    if (/^```/.test(line)) {
      if (inCode) {
        flushCode();
      } else {
        flushList();
        inCode = true;
        codeLang = line.slice(3).trim();
      }
      continue;
    }
    if (inCode) { codeBuf.push(line); continue; }

    // headings
    if (/^### /.test(line)) {
      flushList();
      html += `<h3>${inlineFormat(line.slice(4))}</h3>\n`;
    } else if (/^## /.test(line)) {
      flushList();
      html += `<h2>${inlineFormat(line.slice(3))}</h2>\n`;
    } else if (/^# /.test(line)) {
      flushList();
      html += `<h1>${inlineFormat(line.slice(2))}</h1>\n`;
    // list items
    } else if (/^[-*] /.test(line)) {
      if (!inList) { html += '<ul>\n'; inList = true; }
      html += `<li>${inlineFormat(line.slice(2))}</li>\n`;
    // blank line
    } else if (line.trim() === '') {
      flushList();
      html += '\n';
    // paragraph
    } else {
      flushList();
      html += `<p>${inlineFormat(line)}</p>\n`;
    }
  }
  if (inCode) flushCode();
  flushList();
  return html;
}

// ---------------------------------------------------------------------------

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

function setProgress(step) {
  const block = document.getElementById('progress-block');
  const stepEl = document.getElementById('progress-step');
  const bar = document.getElementById('progress-bar');
  if (!step) { block.style.display = 'none'; return; }
  block.style.display = 'block';
  stepEl.textContent = STEP_LABELS[step] || `✦ ${step}...`;
  bar.style.width = (STEP_PROGRESS[step] || 50) + '%';
}

function showValidation(validation) {
  if (!validation || validation.success === null) return;
  const block = document.getElementById('validation-block');
  const badge = document.getElementById('validation-badge');
  block.style.display = 'block';
  if (validation.success) {
    badge.innerHTML =
      `<span class="val-badge val-ok">✓ Lab validated</span>` +
      `<span class="val-attempts">Validated in ${validation.attempts} attempt(s)</span>`;
  } else {
    badge.innerHTML =
      `<span class="val-badge val-warn">⚠ Not validated (3 attempts)</span>` +
      `<span class="val-attempts">${validation.message}</span>`;
  }
}

function showResult(data) {
  // 1. Validation badge first
  if (data.validation) {
    showValidation(data.validation);
  }

  // 2. Script content
  const scriptOutput = document.getElementById('script-output');
  scriptOutput.textContent = data.response;
  scriptOutput.style.display = 'block';

  // 3. Download .sh button
  const dlScriptBtn = document.getElementById('dl-script-btn');
  dlScriptBtn.dataset.filename = data.saved_as;
  dlScriptBtn.style.display = 'block';
  if (data.validation && data.validation.success === false) {
    dlScriptBtn.classList.add('btn-warn');
  }

  // 4. Exec output
  document.getElementById('exec-output').textContent = data.exec_output || '(no output)';
  document.getElementById('exec-block').style.display = 'block';

  // 5. Docker config download
  const dlDirBtn = document.getElementById('dl-dir-btn');
  if (data.new_dirs && data.new_dirs.length > 0) {
    dlDirBtn.dataset.dirname = data.new_dirs[0];
    dlDirBtn.style.display = 'block';
  }

  // 6. README
  if (data.readme) {
    document.getElementById('readme-output').innerHTML = renderMarkdown(data.readme);
    document.getElementById('readme-block').style.display = 'block';
  }
  if (data.readme_filename) {
    const btn = document.getElementById('dl-readme-btn');
    btn._filename = data.readme_filename;
    btn.style.display = 'block';
  }
}

function resetUI() {
  document.getElementById('script-output').style.display = 'none';
  document.getElementById('exec-block').style.display = 'none';
  document.getElementById('dl-script-btn').style.display = 'none';
  document.getElementById('dl-script-btn').classList.remove('btn-warn');
  document.getElementById('dl-dir-btn').style.display = 'none';
  document.getElementById('dl-readme-btn').style.display = 'none';
  document.getElementById('validation-block').style.display = 'none';
  document.getElementById('validation-badge').innerHTML = '';
  document.getElementById('readme-block').style.display = 'none';
  document.getElementById('readme-output').innerHTML = '';
  setProgress(null);
}

function stopPolling() {
  if (_pollTimer) { clearInterval(_pollTimer); _pollTimer = null; }
}

async function sendPrompt() {
  const prompt = document.getElementById('prompt').value.trim();
  if (!prompt) { setStatus('Empty prompt.'); return; }

  const payload = buildPayload(prompt);
  const validationError = validatePayload(payload);
  if (validationError) { setStatus(validationError); return; }

  const sendBtn = document.getElementById('send-btn');
  sendBtn.disabled = true;
  stopPolling();
  resetUI();
  setStatus('Sending…');

  let jobId;
  try {
    const res = await fetch('/prompt/async', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      setStatus('Error: ' + (err.error || res.statusText), 'err');
      sendBtn.disabled = false;
      return;
    }
    const data = await res.json();
    jobId = data.job_id;
  } catch (err) {
    setStatus('Network error: ' + err.message, 'err');
    sendBtn.disabled = false;
    return;
  }

  setStatus('Running…');
  setProgress('generating');

  _pollTimer = setInterval(async () => {
    try {
      const res = await fetch(`/prompt/status/${jobId}`);
      const job = await res.json();

      if (job.step) setProgress(job.step);

      if (job.status === 'done') {
        stopPolling();
        setProgress(null);
        sendBtn.disabled = false;

        const data = job.result;
        if (data.error === 'not_feasible') {
          let msg = 'This scenario cannot be implemented in containers.';
          if (data.reason)     msg += ' ' + data.reason;
          if (data.suggestion) msg += ' Alternative: ' + data.suggestion;
          setStatus(msg, 'not-feasible');
        } else if (data.error) {
          setStatus('Error: ' + data.error, 'err');
        } else {
          const valOk = data.validation && data.validation.success;
          setStatus(
            `Executed → output/${data.saved_as}` + (valOk ? '' : ' ⚠ validation failed'),
            valOk ? 'ok' : 'warn'
          );
          showResult(data);
        }
      } else if (job.status === 'error') {
        stopPolling();
        setProgress(null);
        sendBtn.disabled = false;
        setStatus('Error: ' + (job.result && job.result.error ? job.result.error : 'Unknown error'), 'err');
      }
    } catch (_) {
      // transient network hiccup — keep polling
    }
  }, 3000);
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

function downloadReadme() {
  const filename = document.getElementById('dl-readme-btn')._filename;
  if (filename) window.location.href = `/download-readme/${encodeURIComponent(filename)}`;
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('prompt').addEventListener('keydown', e => {
    if (e.ctrlKey && e.key === 'Enter') sendPrompt();
  });
});
