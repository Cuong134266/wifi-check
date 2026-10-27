(function () {
  'use strict';

  const originalShowResult = showResult;
  let notifiedSession = -1;

  function selectedCardPayload() {
    if (!picked) return null;
    const selected = catalog[picked.id];
    return {
      id: selected.id,
      name: selected.name,
      vn: selected.vn,
      family: selected.family,
      keywords: selected.keywords,
      overview: selected.overview,
      love: selected.love,
      work: selected.work,
      shadow: selected.shadow,
      action: selected.action,
      question: selected.question,
      dailyMessage: selected.dailyMessage,
      caution: selected.caution,
      smallAction: selected.smallAction,
      symbol: selected.symbol,
      lens: selected.lens,
      topic: document.querySelector('#topic')?.value || 'self',
      artworkSvg: picked.el.querySelector('.front svg')?.outerHTML || '',
      artworkUrl: picked.el.querySelector('.front img')?.src || ''
    };
  }

  function requestCheckin() {
    const card = selectedCardPayload();
    if (!card) return;

    const message = JSON.stringify({
      type: 'lune-card-selected',
      card
    });

    if (window.parent && window.parent !== window) {
      window.parent.postMessage(message, window.location.origin);
    }
    if (window.LuneCheckin && window.LuneCheckin.postMessage) {
      window.LuneCheckin.postMessage(message);
    }
  }

  function ensureStatusPanel() {
    let panel = document.querySelector('#luneCheckinStatus');
    if (panel) return panel;

    panel = document.createElement('section');
    panel.id = 'luneCheckinStatus';
    panel.className = 'lune-checkin-status is-loading';
    panel.setAttribute('role', 'status');
    panel.setAttribute('aria-live', 'polite');
    panel.innerHTML =
      '<div class="lune-checkin-icon" aria-hidden="true"></div>' +
      '<div class="lune-checkin-copy">' +
        '<strong>Đang check-in…</strong>' +
        '<p>Đang xác minh tài khoản, vị trí và mạng công ty.</p>' +
        '<div class="lune-checkin-meta"></div>' +
      '</div>';

    const actions = document.querySelector('.result-actions');
    const reading = document.querySelector('#reading');
    if (actions) actions.before(panel);
    else if (reading) reading.append(panel);
    return panel;
  }

  function renderCheckinStatus(payload) {
    const panel = ensureStatusPanel();
    const state = ['loading', 'success', 'error'].includes(payload.state)
      ? payload.state
      : 'loading';
    panel.className = 'lune-checkin-status is-' + state;

    const title = payload.title || (state === 'success'
      ? 'Check-in thành công'
      : state === 'error'
        ? 'Không thể check-in'
        : 'Đang check-in…');
    const message = payload.message || (state === 'loading'
      ? 'Đang xác minh tài khoản, vị trí và mạng công ty.'
      : '');
    panel.querySelector('strong').textContent = title;
    panel.querySelector('p').textContent = message;

    const values = [payload.time, payload.distance, payload.method]
      .filter(value => typeof value === 'string' && value.trim());
    panel.querySelector('.lune-checkin-meta').innerHTML = values
      .map(value => '<span></span>')
      .join('');
    panel.querySelectorAll('.lune-checkin-meta span')
      .forEach((node, index) => { node.textContent = values[index]; });

    document.querySelectorAll('#next, #reset').forEach(button => {
      button.disabled = state === 'loading';
    });
  }

  window.addEventListener('message', function (event) {
    let payload = event.data;
    if (typeof payload === 'string') {
      try { payload = JSON.parse(payload); } catch (_) { return; }
    }
    if (payload && payload.type === 'lune-command' && payload.command === 'next') {
      start(false);
      return;
    }
    if (!payload || payload.type !== 'lune-checkin-status') return;
    renderCheckinStatus(payload);
  });

  showResult = function () {
    originalShowResult();
    if (!picked || notifiedSession === session) return;
    notifiedSession = session;
    requestCheckin();
  };
})();
