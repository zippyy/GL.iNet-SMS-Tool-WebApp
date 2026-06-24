(() => {
  const api = '/cgi-bin/glinet-sms-webapp';
  const messages = document.getElementById('messages');
  const refresh = document.getElementById('refresh');
  const form = document.getElementById('send-form');
  const send = document.getElementById('send');
  const status = document.getElementById('send-status');
  const text = document.getElementById('text');
  const count = document.getElementById('char-count');
  const autoRefresh = document.getElementById('auto-refresh');
  let box = 'incoming';

  const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
  }[c]));

  async function request(url, options = {}) {
    const response = await fetch(url, { cache: 'no-store', ...options });
    const raw = await response.text();
    let data;
    try { data = JSON.parse(raw); } catch { throw new Error(raw || `Request failed (${response.status})`); }
    if (!response.ok || data.ok === false) throw new Error(data.error || `Request failed (${response.status})`);
    return data;
  }

  function render(list) {
    if (!list.length) {
      messages.innerHTML = '<p class="empty">No messages in this folder.</p>';
      return;
    }
    messages.innerHTML = list.map(item => {
      const who = item.from || item.to || 'Unknown sender';
      const time = item.received || item.sent || '';
      return `<article class="message">
        <div class="meta">
          <strong>${escapeHtml(who)}</strong>
          ${item.modem ? `<span class="tag">${escapeHtml(item.modem)}</span>` : ''}
          ${time ? `<span>${escapeHtml(time)}</span>` : ''}
          ${item.file ? `<span>${escapeHtml(item.file)}</span>` : ''}
        </div>
        <div class="body">${escapeHtml(item.body || '')}</div>
      </article>`;
    }).join('');
  }

  async function load() {
    refresh.disabled = true;
    try {
      const result = await request(`${api}?action=list&box=${encodeURIComponent(box)}`);
      render(result.messages || []);
    } catch (error) {
      messages.innerHTML = `<p class="error">${escapeHtml(error.message)}</p>`;
    } finally {
      refresh.disabled = false;
    }
  }

  text.addEventListener('input', () => { count.textContent = text.value.length; });
  refresh.addEventListener('click', load);
  document.querySelectorAll('[data-box]').forEach(tab => {
    tab.addEventListener('click', () => {
      box = tab.dataset.box;
      document.querySelectorAll('[data-box]').forEach(button => button.classList.toggle('active', button === tab));
      load();
    });
  });

  form.addEventListener('submit', async event => {
    event.preventDefault();
    status.className = '';
    status.textContent = 'Sending message…';
    send.disabled = true;
    try {
      const data = await request(`${api}?action=send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
        body: new URLSearchParams(new FormData(form)).toString()
      });
      status.textContent = data.message || 'SMS sent.';
      form.reset();
      count.textContent = '0';
      setTimeout(load, 350);
    } catch (error) {
      status.className = 'error';
      status.textContent = error.message;
    } finally {
      send.disabled = false;
    }
  });

  setInterval(() => { if (autoRefresh.checked) load(); }, 15000);
  load();
})();
