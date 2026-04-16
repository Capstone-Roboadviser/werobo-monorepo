from fastapi.responses import HTMLResponse


def render_admin_comparison_page() -> HTMLResponse:
    html = """<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Robo Mobile · Universe Comparison</title>
  <style>
    :root {
      --bg: #f5f7fb;
      --card: #ffffff;
      --text: #122033;
      --muted: #5b6b7f;
      --line: #d8e0ea;
      --primary: #133c7a;
      --primary-soft: #e8f0ff;
      --primary-accent: #20A7DB;
      --danger: #b42318;
      --danger-soft: #fef3f2;
      --ok: #027a48;
      --ok-soft: #ecfdf3;
      --warn: #b54708;
      --warn-soft: #fffaeb;
      --radius: 16px;
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .container {
      max-width: 1480px;
      margin: 0 auto;
      padding: 24px;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin-bottom: 16px;
      flex-wrap: wrap;
    }
    .title h1 { margin: 0; font-size: 26px; }
    .title p { margin: 4px 0 0; color: var(--muted); font-size: 14px; }
    .actions { display: flex; gap: 10px; flex-wrap: wrap; }
    button {
      border: 1px solid var(--primary);
      background: var(--primary);
      color: white;
      border-radius: 12px;
      padding: 10px 14px;
      font: inherit;
      font-weight: 600;
      cursor: pointer;
    }
    button.secondary { background: white; color: var(--primary); }
    button.danger { background: white; border-color: #d92d20; color: #d92d20; }
    button.ghost { background: transparent; border-color: var(--line); color: var(--text); }
    button:disabled { opacity: 0.55; cursor: wait; }
    button.mini { padding: 6px 10px; font-size: 12px; }

    .card {
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      padding: 18px;
      box-shadow: 0 6px 20px rgba(17, 24, 39, 0.04);
      margin-bottom: 16px;
    }
    .card h2 { margin: 0 0 6px; font-size: 17px; }
    .card .helper { margin: 0 0 12px; color: var(--muted); font-size: 13px; }

    .snapshot-bar {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
    }
    .snapshot-list {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      flex: 1;
    }
    .snapshot-chip {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 10px;
      border: 1px solid var(--line);
      border-radius: 999px;
      background: #fbfcfe;
      font-size: 13px;
      cursor: pointer;
    }
    .snapshot-chip.active {
      border-color: var(--primary-accent);
      background: var(--primary-soft);
      color: var(--primary);
      font-weight: 600;
    }
    .snapshot-chip .x {
      border: none;
      background: transparent;
      color: var(--muted);
      cursor: pointer;
      padding: 0 2px;
      font-size: 14px;
    }
    .snapshot-chip .x:hover { color: var(--danger); }

    .graph-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(540px, 1fr));
      gap: 16px;
    }
    .graph-set {
      background: white;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      padding: 14px;
      box-shadow: 0 4px 14px rgba(17, 24, 39, 0.04);
    }
    .graph-set-head {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;
    }
    .graph-set-head input.title-input {
      flex: 1;
      border: none;
      background: transparent;
      font: inherit;
      font-size: 16px;
      font-weight: 700;
      padding: 4px 0;
    }
    .graph-set-head input.title-input:focus { outline: 1px solid var(--primary-accent); border-radius: 4px; }

    .controls {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
      margin-bottom: 12px;
    }
    .field { display: flex; flex-direction: column; gap: 4px; }
    .field label {
      font-size: 11px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }
    .field input, .field select {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 8px 10px;
      font: inherit;
      background: white;
      font-size: 13px;
    }

    .chart-block {
      border: 1px solid var(--line);
      border-radius: 12px;
      background: #fbfcfe;
      padding: 12px;
      margin-bottom: 10px;
    }
    .chart-title {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      font-size: 12px;
      color: var(--muted);
      margin-bottom: 6px;
    }
    .chart-title strong { color: var(--text); font-size: 13px; font-weight: 600; }
    .chart-svg {
      width: 100%;
      height: 240px;
      display: block;
      cursor: grab;
      touch-action: none;
    }
    .chart-svg.dragging { cursor: grabbing; }
    .profit-svg { height: 240px; cursor: default; }

    .legend {
      display: flex;
      flex-wrap: wrap;
      gap: 8px 14px;
      margin-top: 8px;
      font-size: 11px;
      color: var(--muted);
    }
    .legend-item { display: inline-flex; align-items: center; gap: 5px; }
    .legend-swatch {
      width: 12px;
      height: 3px;
      border-radius: 2px;
      display: inline-block;
    }
    .legend-swatch.dashed {
      background: repeating-linear-gradient(
        to right, currentColor 0 4px, transparent 4px 8px
      );
    }

    .selection-summary {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      font-size: 12px;
      color: var(--muted);
      margin-top: 8px;
    }
    .selection-summary .pill {
      background: var(--primary-soft);
      color: var(--primary);
      padding: 4px 8px;
      border-radius: 999px;
      font-weight: 600;
    }

    .empty-state {
      padding: 28px;
      text-align: center;
      color: var(--muted);
      font-size: 13px;
    }
    .err {
      background: var(--danger-soft);
      color: var(--danger);
      border-radius: 10px;
      padding: 8px 12px;
      font-size: 12px;
      margin-top: 6px;
    }
    .loading {
      color: var(--muted);
      font-size: 12px;
      padding: 6px 10px;
    }
    .nav-link {
      color: var(--primary);
      text-decoration: none;
      font-size: 13px;
      font-weight: 600;
    }
    .nav-link:hover { text-decoration: underline; }

    @media (max-width: 720px) {
      .graph-grid { grid-template-columns: 1fr; }
      .controls { grid-template-columns: 1fr 1fr; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="title">
        <h1>유니버스 비교 보드</h1>
        <p>여러 유니버스의 efficient frontier와 백테스트 수익선을 한 화면에서 비교합니다.</p>
      </div>
      <div class="actions">
        <a class="nav-link" href="/admin">← 유니버스 관리로</a>
      </div>
    </div>

    <section class="card">
      <h2>스냅샷</h2>
      <p class="helper">현재 보드 상태를 저장하고 나중에 불러올 수 있어요.</p>
      <div class="snapshot-bar">
        <button id="save-snapshot">현재 상태 저장</button>
        <button class="secondary" id="add-graph-set">+ 그래프 세트 추가</button>
        <div class="snapshot-list" id="snapshot-list">
          <span class="loading" id="snapshot-loading">스냅샷을 불러오는 중...</span>
        </div>
      </div>
      <div class="err" id="snapshot-error" style="display:none"></div>
    </section>

    <div class="graph-grid" id="graph-grid"></div>
    <div class="empty-state" id="empty-state" style="display:none">
      그래프 세트가 없습니다. "+ 그래프 세트 추가"를 눌러주세요.
    </div>
  </div>

  <template id="graph-set-template">
    <div class="graph-set" data-graph-id="">
      <div class="graph-set-head">
        <input type="text" class="title-input" placeholder="그래프 세트 이름" />
        <button class="ghost mini btn-remove">삭제</button>
      </div>
      <div class="controls">
        <div class="field">
          <label>유니버스</label>
          <select class="ctrl-version"></select>
        </div>
        <div class="field">
          <label>Frontier 기준일</label>
          <input type="date" class="ctrl-as-of" />
        </div>
        <div class="field">
          <label>백테스트 시작일</label>
          <input type="date" class="ctrl-start" />
        </div>
      </div>
      <div class="chart-block">
        <div class="chart-title">
          <strong>Efficient Frontier</strong>
          <span class="frontier-status">유니버스를 선택하세요.</span>
        </div>
        <svg class="chart-svg frontier-svg" viewBox="0 0 600 240" preserveAspectRatio="none"></svg>
        <div class="selection-summary"></div>
      </div>
      <div class="chart-block">
        <div class="chart-title">
          <strong>Backtest Profit</strong>
          <span class="profit-status">포트폴리오를 선택하세요.</span>
        </div>
        <svg class="chart-svg profit-svg" viewBox="0 0 600 240" preserveAspectRatio="none"></svg>
        <div class="legend"></div>
      </div>
      <div class="err graph-error" style="display:none"></div>
    </div>
  </template>

  <script>
    const $ = (sel, root = document) => root.querySelector(sel);
    const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

    let catalog = { assets: [], versions: [] };
    let assetByCode = {};
    const graphSets = new Map(); // id -> state
    let snapshots = [];
    let activeSnapshotId = null;
    let graphSetSeq = 0;

    const NEW_GROWTH_CODE = 'new_growth';
    const TREASURY_KEY = 'treasury';

    function nextGraphSetId() {
      graphSetSeq += 1;
      return `gs${graphSetSeq}`;
    }

    function fmtPct(value, digits = 1) {
      if (value === null || value === undefined || Number.isNaN(value)) return '-';
      return `${(value * 100).toFixed(digits)}%`;
    }
    function fmtPctRaw(value, digits = 1) {
      if (value === null || value === undefined || Number.isNaN(value)) return '-';
      return `${value.toFixed(digits)}%`;
    }

    async function api(path, init) {
      const res = await fetch(path, {
        headers: { 'content-type': 'application/json' },
        ...init,
      });
      if (!res.ok) {
        let msg = `HTTP ${res.status}`;
        try {
          const data = await res.json();
          if (data?.detail) msg = data.detail;
        } catch {}
        throw new Error(msg);
      }
      return res.json();
    }

    // ── Catalog & init ──
    async function loadCatalog() {
      catalog = await api('/admin/api/comparison/catalog');
      assetByCode = Object.fromEntries(catalog.assets.map(a => [a.code, a]));
    }

    // ── Snapshots ──
    async function loadSnapshots() {
      try {
        const data = await api('/admin/api/comparison/snapshots');
        snapshots = data.snapshots || [];
      } catch (e) {
        snapshots = [];
        $('#snapshot-error').style.display = 'block';
        $('#snapshot-error').textContent = `스냅샷 불러오기 실패: ${e.message}`;
      }
      renderSnapshots();
    }

    function renderSnapshots() {
      const list = $('#snapshot-list');
      list.innerHTML = '';
      if (!snapshots.length) {
        const span = document.createElement('span');
        span.className = 'loading';
        span.textContent = '저장된 스냅샷이 없습니다.';
        list.appendChild(span);
        return;
      }
      snapshots.forEach(snap => {
        const chip = document.createElement('span');
        chip.className = 'snapshot-chip' + (snap.id === activeSnapshotId ? ' active' : '');
        const label = document.createElement('span');
        label.textContent = snap.name;
        label.onclick = () => loadSnapshot(snap.id);
        const xBtn = document.createElement('button');
        xBtn.className = 'x';
        xBtn.textContent = '×';
        xBtn.title = '삭제';
        xBtn.onclick = (ev) => {
          ev.stopPropagation();
          deleteSnapshot(snap.id);
        };
        chip.appendChild(label);
        chip.appendChild(xBtn);
        list.appendChild(chip);
      });
    }

    async function saveSnapshot() {
      const name = prompt('저장할 스냅샷 이름을 입력하세요.', `보드 ${new Date().toLocaleString()}`);
      if (!name) return;
      const payload = {
        graph_sets: Array.from(graphSets.values()).map(g => ({
          name: g.name,
          version_id: g.versionId,
          as_of_date: g.asOfDate,
          start_date: g.startDate,
          point_index: g.pointIndex,
        })),
      };
      try {
        const created = await api('/admin/api/comparison/snapshots', {
          method: 'POST',
          body: JSON.stringify({ name, payload }),
        });
        snapshots.unshift(created);
        activeSnapshotId = created.id;
        renderSnapshots();
      } catch (e) {
        alert(`저장 실패: ${e.message}`);
      }
    }

    async function deleteSnapshot(id) {
      if (!confirm('스냅샷을 삭제하시겠어요?')) return;
      try {
        await api(`/admin/api/comparison/snapshots/${id}`, { method: 'DELETE' });
        snapshots = snapshots.filter(s => s.id !== id);
        if (activeSnapshotId === id) activeSnapshotId = null;
        renderSnapshots();
      } catch (e) {
        alert(`삭제 실패: ${e.message}`);
      }
    }

    async function loadSnapshot(id) {
      const snap = snapshots.find(s => s.id === id);
      if (!snap) return;
      activeSnapshotId = id;
      renderSnapshots();
      // Clear and rebuild graph sets
      graphSets.clear();
      $('#graph-grid').innerHTML = '';
      const sets = snap.payload?.graph_sets || [];
      for (const item of sets) {
        addGraphSet({
          name: item.name,
          versionId: item.version_id,
          asOfDate: item.as_of_date,
          startDate: item.start_date,
          pointIndex: item.point_index,
        });
      }
      updateEmptyState();
    }

    // ── Graph set lifecycle ──
    function updateEmptyState() {
      $('#empty-state').style.display = graphSets.size === 0 ? 'block' : 'none';
    }

    function addGraphSet(initial) {
      const id = nextGraphSetId();
      const state = {
        id,
        name: initial?.name || `그래프 세트 ${graphSets.size + 1}`,
        versionId: initial?.versionId || (catalog.versions.find(v => v.is_active)?.version_id ?? catalog.versions[0]?.version_id ?? null),
        asOfDate: initial?.asOfDate || null,
        startDate: initial?.startDate || null,
        pointIndex: initial?.pointIndex ?? null,
        frontier: null,
        selection: null,
        backtest: null,
        rootEl: null,
      };
      graphSets.set(id, state);

      const tmpl = $('#graph-set-template');
      const node = tmpl.content.cloneNode(true);
      const root = node.querySelector('.graph-set');
      root.dataset.graphId = id;
      state.rootEl = root;

      const titleInput = $('.title-input', root);
      titleInput.value = state.name;
      titleInput.addEventListener('input', () => { state.name = titleInput.value; });

      const versionSelect = $('.ctrl-version', root);
      versionSelect.innerHTML = '';
      catalog.versions.forEach(v => {
        const opt = document.createElement('option');
        opt.value = v.version_id;
        opt.textContent = v.version_name + (v.is_active ? ' (active)' : '');
        if (v.version_id === state.versionId) opt.selected = true;
        versionSelect.appendChild(opt);
      });
      versionSelect.addEventListener('change', () => {
        state.versionId = parseInt(versionSelect.value, 10);
        state.pointIndex = null;
        refreshFrontier(state);
      });

      const asOf = $('.ctrl-as-of', root);
      if (state.asOfDate) asOf.value = state.asOfDate;
      asOf.addEventListener('change', () => {
        state.asOfDate = asOf.value || null;
        refreshFrontier(state);
      });

      const startInput = $('.ctrl-start', root);
      if (state.startDate) startInput.value = state.startDate;
      startInput.addEventListener('change', () => {
        state.startDate = startInput.value || null;
        refreshBacktest(state);
      });

      $('.btn-remove', root).addEventListener('click', () => removeGraphSet(id));

      $('#graph-grid').appendChild(node);
      updateEmptyState();
      refreshFrontier(state);
    }

    function removeGraphSet(id) {
      const st = graphSets.get(id);
      if (!st) return;
      st.rootEl?.remove();
      graphSets.delete(id);
      updateEmptyState();
    }

    // ── Frontier fetch + render ──
    async function refreshFrontier(state) {
      if (!state.versionId) {
        setFrontierStatus(state, '유니버스를 선택하세요.');
        return;
      }
      setFrontierStatus(state, '계산 중...');
      clearError(state);
      try {
        const data = await api('/admin/api/comparison/frontier', {
          method: 'POST',
          body: JSON.stringify({
            version_id: state.versionId,
            as_of_date: state.asOfDate,
            sample_points: 61,
          }),
        });
        state.frontier = data;
        if (state.pointIndex === null || state.pointIndex >= data.total_point_count) {
          // Default to balanced (middle)
          const points = data.points;
          const balanced = points.find(p => p.representative_code === 'balanced');
          state.pointIndex = balanced ? balanced.index : points[Math.floor(points.length / 2)].index;
        }
        renderFrontier(state);
        applySelectionFromFrontier(state);
        await refreshBacktest(state);
      } catch (e) {
        state.frontier = null;
        showError(state, `Frontier 계산 실패: ${e.message}`);
        setFrontierStatus(state, '오류');
        clearFrontierSvg(state);
      }
    }

    // Read selected point's weights/sector breakdown from cached frontier data —
    // avoids a second heavyweight backend call on every drag.
    function applySelectionFromFrontier(state) {
      if (!state.frontier) return;
      const point = state.frontier.points.find(p => p.index === state.pointIndex);
      if (!point) return;
      state.selection = {
        version_id: state.versionId,
        point_index: point.index,
        volatility: point.volatility,
        expected_return: point.expected_return,
        stock_weights: point.stock_weights || {},
        sector_breakdown: point.sector_breakdown || [],
      };
      renderSelectionSummary(state);
    }

    async function refreshBacktest(state) {
      if (!state.selection) return;
      const profitStatus = $('.profit-status', state.rootEl);
      profitStatus.textContent = '계산 중...';
      try {
        const data = await api('/admin/api/comparison/backtest', {
          method: 'POST',
          body: JSON.stringify({
            version_id: state.versionId,
            stock_weights: state.selection.stock_weights,
            start_date: state.startDate,
          }),
        });
        state.backtest = data;
        renderBacktest(state);
        profitStatus.textContent = `${data.start_date} ~ ${data.end_date}`;
      } catch (e) {
        state.backtest = null;
        showError(state, `Backtest 계산 실패: ${e.message}`);
        profitStatus.textContent = '오류';
        clearProfitSvg(state);
      }
    }

    function setFrontierStatus(state, text) {
      $('.frontier-status', state.rootEl).textContent = text;
    }
    function showError(state, text) {
      const el = $('.graph-error', state.rootEl);
      el.style.display = 'block';
      el.textContent = text;
    }
    function clearError(state) {
      const el = $('.graph-error', state.rootEl);
      el.style.display = 'none';
      el.textContent = '';
    }
    function clearFrontierSvg(state) {
      const svg = $('.frontier-svg', state.rootEl);
      while (svg.firstChild) svg.removeChild(svg.firstChild);
      $('.selection-summary', state.rootEl).innerHTML = '';
    }
    function clearProfitSvg(state) {
      const svg = $('.profit-svg', state.rootEl);
      while (svg.firstChild) svg.removeChild(svg.firstChild);
      $('.legend', state.rootEl).innerHTML = '';
    }

    function svgEl(name, attrs = {}) {
      const el = document.createElementNS('http://www.w3.org/2000/svg', name);
      for (const [k, v] of Object.entries(attrs)) {
        if (v !== null && v !== undefined) el.setAttribute(k, v);
      }
      return el;
    }

    // ── Frontier rendering ──
    function renderFrontier(state) {
      const svg = $('.frontier-svg', state.rootEl);
      const W = 600, H = 240;
      const padL = 40, padR = 24, padT = 16, padB = 30;
      const cw = W - padL - padR;
      const ch = H - padT - padB;
      while (svg.firstChild) svg.removeChild(svg.firstChild);

      const data = state.frontier;
      if (!data || !data.points.length) {
        setFrontierStatus(state, '데이터 없음');
        return;
      }
      const points = data.points;
      const xs = points.map(p => p.volatility);
      const ys = points.map(p => p.expected_return);
      const minX = Math.min(...xs), maxX = Math.max(...xs);
      const minY = Math.min(...ys), maxY = Math.max(...ys);
      const xPad = (maxX - minX) * 0.05 || 0.001;
      const yPad = (maxY - minY) * 0.05 || 0.001;
      const x0 = minX - xPad, x1 = maxX + xPad;
      const y0 = minY - yPad, y1 = maxY + yPad;

      const sx = v => padL + ((v - x0) / (x1 - x0)) * cw;
      const sy = v => padT + (1 - (v - y0) / (y1 - y0)) * ch;

      // grid
      for (let i = 0; i <= 4; i++) {
        const y = padT + (ch * i) / 4;
        svg.appendChild(svgEl('line', {
          x1: padL, y1: y, x2: W - padR, y2: y,
          stroke: '#d8e0ea', 'stroke-width': '0.5', opacity: '0.5',
        }));
        const labelVal = y1 - ((y1 - y0) * i) / 4;
        const t = svgEl('text', {
          x: 4, y: y + 3, fill: '#5b6b7f', 'font-size': '9',
        });
        t.textContent = `${(labelVal * 100).toFixed(1)}%`;
        svg.appendChild(t);
      }
      // x-axis labels
      for (let i = 0; i <= 4; i++) {
        const x = padL + (cw * i) / 4;
        const labelVal = x0 + ((x1 - x0) * i) / 4;
        const t = svgEl('text', {
          x: x - 14, y: H - 8, fill: '#5b6b7f', 'font-size': '9',
        });
        t.textContent = `${(labelVal * 100).toFixed(1)}%`;
        svg.appendChild(t);
      }
      // axis titles
      const yTitle = svgEl('text', { x: 4, y: 11, fill: '#5b6b7f', 'font-size': '10' });
      yTitle.textContent = '기대수익률';
      svg.appendChild(yTitle);
      const xTitle = svgEl('text', {
        x: W - padR - 50, y: H - 18, fill: '#5b6b7f', 'font-size': '10',
      });
      xTitle.textContent = '변동성';
      svg.appendChild(xTitle);

      // smooth path
      const pathD = points.map((p, i) => {
        const x = sx(p.volatility), y = sy(p.expected_return);
        return `${i === 0 ? 'M' : 'L'} ${x.toFixed(2)} ${y.toFixed(2)}`;
      }).join(' ');
      svg.appendChild(svgEl('path', {
        d: pathD,
        fill: 'none',
        stroke: '#20A7DB',
        'stroke-width': '2.4',
        'stroke-linecap': 'round',
        'stroke-linejoin': 'round',
      }));
      // dots
      points.forEach(p => {
        const isRep = !!p.representative_code;
        svg.appendChild(svgEl('circle', {
          cx: sx(p.volatility), cy: sy(p.expected_return),
          r: isRep ? 4 : 2.5,
          fill: isRep ? '#1C96C5' : 'rgba(91,107,127,0.45)',
        }));
      });
      // selected
      const selectedPoint = points.find(p => p.index === state.pointIndex)
        ?? points[Math.floor(points.length / 2)];
      const cx = sx(selectedPoint.volatility);
      const cy = sy(selectedPoint.expected_return);
      svg.appendChild(svgEl('circle', {
        cx, cy, r: 14, fill: '#133c7a', opacity: '0.16',
      }));
      const dot = svgEl('circle', {
        cx, cy, r: 8, fill: '#133c7a', stroke: 'white', 'stroke-width': '2.5',
        class: 'selected-dot',
      });
      svg.appendChild(dot);

      setFrontierStatus(state, `포인트 ${selectedPoint.index} · σ ${fmtPct(selectedPoint.volatility)} · μ ${fmtPct(selectedPoint.expected_return)}`);

      // drag handler — find nearest preview point in screen space
      const findNearest = (clientX, clientY) => {
        const rect = svg.getBoundingClientRect();
        const localX = ((clientX - rect.left) / rect.width) * W;
        const localY = ((clientY - rect.top) / rect.height) * H;
        let best = points[0], bestD = Infinity;
        for (const p of points) {
          const dx = sx(p.volatility) - localX;
          const dy = sy(p.expected_return) - localY;
          const d = dx * dx + dy * dy;
          if (d < bestD) { bestD = d; best = p; }
        }
        return best;
      };

      let dragging = false;
      const onDown = (ev) => {
        dragging = true;
        svg.classList.add('dragging');
        ev.preventDefault();
        onMove(ev);
      };
      const onMove = (ev) => {
        if (!dragging) return;
        const cx = ev.clientX ?? ev.touches?.[0]?.clientX;
        const cy = ev.clientY ?? ev.touches?.[0]?.clientY;
        if (cx === undefined) return;
        const nearest = findNearest(cx, cy);
        if (nearest.index !== state.pointIndex) {
          state.pointIndex = nearest.index;
          renderFrontier(state); // re-render dot
          applySelectionFromFrontier(state); // instant summary update from cached data
          // Debounce backtest call — only one heavyweight request after drag settles.
          clearTimeout(state._dragTimer);
          state._dragTimer = setTimeout(() => refreshBacktest(state), 350);
        }
      };
      const onUp = () => {
        if (!dragging) return;
        dragging = false;
        svg.classList.remove('dragging');
      };
      svg.addEventListener('pointerdown', onDown);
      svg.addEventListener('pointermove', onMove);
      window.addEventListener('pointerup', onUp);
      svg.addEventListener('touchstart', onDown, { passive: false });
      svg.addEventListener('touchmove', onMove, { passive: false });
      window.addEventListener('touchend', onUp);
    }

    function renderSelectionSummary(state) {
      const root = $('.selection-summary', state.rootEl);
      root.innerHTML = '';
      const sel = state.selection;
      if (!sel) return;
      const items = [
        ['σ', fmtPct(sel.volatility)],
        ['μ', fmtPct(sel.expected_return)],
        ['종목수', String(Object.keys(sel.stock_weights).length)],
      ];
      items.forEach(([k, v]) => {
        const span = document.createElement('span');
        span.innerHTML = `<span class="pill">${k}</span> ${v}`;
        root.appendChild(span);
      });
      // sector breakdown chips
      sel.sector_breakdown.slice(0, 6).forEach(b => {
        const asset = assetByCode[b.asset_code];
        if (!asset) return;
        const span = document.createElement('span');
        span.style.color = asset.color;
        span.textContent = `${asset.name} ${(b.weight * 100).toFixed(0)}%`;
        root.appendChild(span);
      });
    }

    // ── Backtest rendering ──
    function renderBacktest(state) {
      const svg = $('.profit-svg', state.rootEl);
      const legendEl = $('.legend', state.rootEl);
      const W = 600, H = 240;
      const padL = 40, padR = 18, padT = 12, padB = 24;
      const cw = W - padL - padR;
      const ch = H - padT - padB;
      while (svg.firstChild) svg.removeChild(svg.firstChild);
      legendEl.innerHTML = '';

      const data = state.backtest;
      if (!data || !data.lines.length) return;

      // Filter lines: per-asset (asset_*) excluding new_growth, plus treasury,
      // plus the selected portfolio line so users can compare performance.
      const PORTFOLIO_KEYS = new Set(['selected', 'balanced', 'conservative', 'growth']);
      const visibleLines = data.lines.filter(line => {
        if (line.key === TREASURY_KEY) return true;
        if (line.key.startsWith('asset_')) {
          const assetCode = line.key.replace(/^asset_/, '');
          return assetCode !== NEW_GROWTH_CODE;
        }
        return PORTFOLIO_KEYS.has(line.key);
      }).map(line => {
        if (PORTFOLIO_KEYS.has(line.key)) {
          return { ...line, label: '선택 포트폴리오', color: '#133c7a', _portfolio: true };
        }
        return line;
      });

      if (!visibleLines.length) return;

      // Build x,y range
      const allDates = new Set();
      let minY = Infinity, maxY = -Infinity;
      visibleLines.forEach(line => {
        line.points.forEach(p => {
          allDates.add(p.date);
          if (p.return_pct < minY) minY = p.return_pct;
          if (p.return_pct > maxY) maxY = p.return_pct;
        });
      });
      if (!isFinite(minY) || !isFinite(maxY)) return;
      const yPad = (maxY - minY) * 0.05 || 1;
      const y0 = minY - yPad, y1 = maxY + yPad;

      const sortedDates = Array.from(allDates).sort();
      const dateIdx = new Map(sortedDates.map((d, i) => [d, i]));
      const dateCount = sortedDates.length;
      const sx = i => padL + (cw * i) / Math.max(1, dateCount - 1);
      const sy = v => padT + (1 - (v - y0) / (y1 - y0)) * ch;

      // grid
      for (let i = 0; i <= 4; i++) {
        const y = padT + (ch * i) / 4;
        svg.appendChild(svgEl('line', {
          x1: padL, y1: y, x2: W - padR, y2: y,
          stroke: '#d8e0ea', 'stroke-width': '0.5', opacity: '0.5',
        }));
        const labelVal = y1 - ((y1 - y0) * i) / 4;
        const t = svgEl('text', {
          x: 4, y: y + 3, fill: '#5b6b7f', 'font-size': '9',
        });
        t.textContent = `${labelVal.toFixed(1)}%`;
        svg.appendChild(t);
      }
      // zero line
      if (y0 < 0 && y1 > 0) {
        const yz = sy(0);
        svg.appendChild(svgEl('line', {
          x1: padL, y1: yz, x2: W - padR, y2: yz,
          stroke: '#5b6b7f', 'stroke-width': '0.6', 'stroke-dasharray': '3,4',
        }));
      }
      // x-axis labels (5 ticks)
      for (let i = 0; i < 5 && dateCount > 1; i++) {
        const idx = Math.round(((dateCount - 1) * i) / 4);
        const date = sortedDates[idx];
        const x = sx(idx);
        const t = svgEl('text', {
          x: x - 22, y: H - 8, fill: '#5b6b7f', 'font-size': '9',
        });
        t.textContent = date.slice(0, 7); // YYYY-MM
        svg.appendChild(t);
      }

      // lines (draw markets first, portfolio last so it's on top)
      const sortedLines = [...visibleLines].sort((a, b) => (a._portfolio ? 1 : 0) - (b._portfolio ? 1 : 0));
      sortedLines.forEach(line => {
        const pts = line.points
          .map(p => [dateIdx.get(p.date), p.return_pct])
          .filter(([i]) => i !== undefined);
        if (pts.length < 2) return;
        const d = pts.map((pt, i) => `${i === 0 ? 'M' : 'L'} ${sx(pt[0]).toFixed(2)} ${sy(pt[1]).toFixed(2)}`).join(' ');
        svg.appendChild(svgEl('path', {
          d, fill: 'none', stroke: line.color || '#64748B',
          'stroke-width': line._portfolio ? '2.6' : '1.6',
          'stroke-linecap': 'round', 'stroke-linejoin': 'round',
          'stroke-dasharray': line.style === 'dashed' ? '5,4' : null,
          opacity: line._portfolio ? '1' : '0.85',
        }));
      });

      // legend
      visibleLines.forEach(line => {
        const item = document.createElement('span');
        item.className = 'legend-item';
        item.style.color = line.color || '#64748B';
        const sw = document.createElement('span');
        sw.className = 'legend-swatch' + (line.style === 'dashed' ? ' dashed' : '');
        sw.style.background = line.style === 'dashed' ? 'transparent' : (line.color || '#64748B');
        sw.style.color = line.color || '#64748B';
        item.appendChild(sw);
        const label = document.createElement('span');
        label.textContent = line.label;
        label.style.color = '#122033';
        item.appendChild(label);
        legendEl.appendChild(item);
      });
    }

    // ── Boot ──
    document.addEventListener('DOMContentLoaded', async () => {
      $('#add-graph-set').addEventListener('click', () => addGraphSet());
      $('#save-snapshot').addEventListener('click', saveSnapshot);
      try {
        await loadCatalog();
      } catch (e) {
        $('#snapshot-loading').textContent = `카탈로그 로딩 실패: ${e.message}`;
        return;
      }
      await loadSnapshots();
      // Add one default graph set on first load
      if (graphSets.size === 0) addGraphSet();
    });
  </script>
</body>
</html>
"""
    return HTMLResponse(content=html)
