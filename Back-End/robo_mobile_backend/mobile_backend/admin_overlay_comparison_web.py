from fastapi.responses import HTMLResponse


def render_admin_overlay_comparison_page() -> HTMLResponse:
    html = """<!DOCTYPE html>
<html lang="ko" data-theme="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>USMV Overlay Impact / ALFIN Admin</title>
  <script>
    (function(){
      try {
        var stored = localStorage.getItem('werobo-theme');
        var theme = stored === 'dark' || stored === 'light'
          ? stored
          : (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
        document.documentElement.setAttribute('data-theme', theme);
      } catch (e) {}
    })();
  </script>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Sono:wght@300;400;500;600;700&family=Azeret+Mono:wght@400;500;600&display=swap" />
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css" />
  <style>
    :root {
      --font-ui: 'Sono', 'Pretendard', ui-sans-serif, system-ui, -apple-system, sans-serif;
      --font-mono: 'Azeret Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
      --text-2xs: 10.5px; --text-xs: 11.5px; --text-sm: 12.5px; --text-base: 13.5px;
      --text-md: 14.5px; --text-lg: 16px; --text-xl: 19px; --text-2xl: 24px;
      --sp-1: 4px; --sp-2: 8px; --sp-3: 12px; --sp-4: 16px; --sp-5: 24px; --sp-6: 32px; --sp-7: 48px;
      --r-1: 3px; --r-2: 5px; --r-3: 7px; --r-4: 10px;
      --bg: oklch(98% 0.004 255); --surface: oklch(100% 0 0); --surface-2: oklch(98.5% 0.005 255);
      --surface-3: oklch(96% 0.008 255); --fg: oklch(22% 0.018 255); --fg-2: oklch(42% 0.018 255);
      --fg-3: oklch(58% 0.016 255); --fg-4: oklch(72% 0.012 255); --line: oklch(91% 0.010 255);
      --line-2: oklch(82% 0.014 255); --line-3: oklch(68% 0.018 255);
      --accent: oklch(56% 0.22 260); --accent-hover: oklch(50% 0.24 260); --accent-fg: oklch(99% 0.003 260);
      --accent-soft: oklch(94% 0.045 260); --pos: oklch(50% 0.15 155); --neg: oklch(52% 0.19 28);
      --warn: oklch(62% 0.14 82); --shadow-sm: 0 1px 0 oklch(40% 0.020 255 / 0.05);
      --chart-grid: oklch(91% 0.010 255); --chart-axis: oklch(58% 0.016 255); --chart-frontier: oklch(56% 0.22 260);
      --chart-mu: oklch(52% 0.19 28); --chart-muted-line: oklch(72% 0.012 255);
      color-scheme: light;
    }
    [data-theme="dark"] {
      --bg: oklch(15% 0.015 255); --surface: oklch(19% 0.017 255); --surface-2: oklch(22.5% 0.018 255);
      --surface-3: oklch(27% 0.018 255); --fg: oklch(94% 0.008 255); --fg-2: oklch(74% 0.014 255);
      --fg-3: oklch(58% 0.017 255); --fg-4: oklch(42% 0.017 255); --line: oklch(28% 0.018 255);
      --line-2: oklch(36% 0.021 255); --line-3: oklch(48% 0.023 255);
      --accent: oklch(70% 0.18 260); --accent-hover: oklch(76% 0.16 260); --accent-fg: oklch(15% 0.015 255);
      --accent-soft: oklch(32% 0.090 260); --pos: oklch(72% 0.17 155); --neg: oklch(72% 0.19 28);
      --warn: oklch(80% 0.14 82); --shadow-sm: 0 1px 0 oklch(4% 0 0 / 0.35);
      --chart-grid: oklch(26% 0.018 255); --chart-axis: oklch(62% 0.017 255); --chart-frontier: oklch(72% 0.18 260);
      --chart-mu: oklch(72% 0.19 28); --chart-muted-line: oklch(42% 0.017 255);
      color-scheme: dark;
    }
    * { box-sizing: border-box; }
    html { height: 100%; }
    body {
      margin: 0; min-height: 100%; background: var(--bg); color: var(--fg);
      font-family: var(--font-ui); font-size: var(--text-base); font-variant-numeric: tabular-nums;
      -webkit-font-smoothing: antialiased; line-height: 1.45;
    }
    .rail {
      display: flex; align-items: center; justify-content: space-between; gap: var(--sp-4);
      padding: 10px var(--sp-5); border-bottom: 1px solid var(--line); background: var(--surface);
      font-size: var(--text-xs); color: var(--fg-3);
    }
    .rail-brand {
      display: inline-flex; align-items: center; gap: var(--sp-2); font-family: var(--font-mono);
      font-size: var(--text-xs); color: var(--fg); font-weight: 500; letter-spacing: 0.02em;
    }
    .rail-brand .mark { display: inline-block; width: 7px; height: 7px; border-radius: 1px; background: var(--accent); }
    .rail-brand .slash { color: var(--fg-4); margin: 0 2px; }
    .rail-brand .section { color: var(--fg-2); }
    .rail-nav { display: inline-flex; align-items: center; gap: var(--sp-4); }
    .rail-nav a {
      color: var(--fg-2); text-decoration: none; font-family: var(--font-mono);
      font-size: var(--text-xs); padding: 3px 6px; border-radius: var(--r-1);
    }
    .rail-nav a[aria-current="page"] { color: var(--fg); background: var(--surface-3); }
    .rail-nav a:hover { background: var(--surface-3); color: var(--fg); }
    .theme-toggle {
      display: inline-grid; grid-template-columns: 1fr 1fr; background: var(--surface-2);
      border: 1px solid var(--line); border-radius: var(--r-2); padding: 2px;
      font-family: var(--font-mono); font-size: var(--text-2xs); letter-spacing: 0.08em;
    }
    .theme-toggle button {
      appearance: none; border: 0; background: transparent; color: var(--fg-3);
      padding: 3px 10px; border-radius: var(--r-1); cursor: pointer; font: inherit; text-transform: uppercase;
    }
    .theme-toggle button[aria-pressed="true"] { background: var(--surface); color: var(--fg); box-shadow: var(--shadow-sm); }
    .shell { max-width: 1440px; margin: 0 auto; padding: var(--sp-5) var(--sp-5) var(--sp-7); }
    .page-head {
      display: flex; justify-content: space-between; align-items: flex-end; gap: var(--sp-4); flex-wrap: wrap;
      padding: var(--sp-5) 0 var(--sp-4); border-bottom: 1px solid var(--line); margin-bottom: var(--sp-5);
    }
    .page-head h1 { margin: 0; font-size: var(--text-2xl); font-weight: 600; letter-spacing: -0.015em; }
    .eyebrow {
      display: block; font-family: var(--font-mono); font-size: var(--text-2xs); letter-spacing: 0.12em;
      color: var(--fg-3); text-transform: uppercase; margin-bottom: 6px;
    }
    .subtitle { margin: 4px 0 0; max-width: 70ch; color: var(--fg-3); font-size: var(--text-sm); }
    .card {
      background: var(--surface); border: 1px solid var(--line); border-radius: var(--r-3);
      padding: var(--sp-4) var(--sp-5); margin-bottom: var(--sp-4);
    }
    .card-head { display: flex; justify-content: space-between; align-items: baseline; gap: var(--sp-3); margin-bottom: var(--sp-3); }
    .card-head h2 { margin: 0; font-size: var(--text-lg); font-weight: 600; }
    .form-grid { display: grid; grid-template-columns: repeat(5, minmax(140px, 1fr)) auto; gap: var(--sp-3); align-items: end; }
    .field label {
      display: block; font-family: var(--font-mono); font-size: var(--text-2xs); color: var(--fg-3);
      text-transform: uppercase; letter-spacing: 0.1em; margin-bottom: 4px;
    }
    .field input, .field select {
      width: 100%; border: 1px solid var(--line-2); border-radius: var(--r-2);
      padding: 8px 10px; background: var(--surface); color: var(--fg); font: inherit; font-size: var(--text-sm);
    }
    .field input:focus, .field select:focus { outline: 0; border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
    button {
      appearance: none; border: 1px solid var(--accent); background: var(--accent); color: var(--accent-fg);
      border-radius: var(--r-2); padding: 8px 14px; font: inherit; font-size: var(--text-sm); font-weight: 500; cursor: pointer;
    }
    button:hover:not(:disabled) { background: var(--accent-hover); border-color: var(--accent-hover); }
    button:disabled { opacity: 0.55; cursor: not-allowed; }
    .status { margin-top: var(--sp-3); color: var(--fg-3); font-family: var(--font-mono); font-size: var(--text-xs); }
    .status.error { color: var(--neg); }
    .metric-grid { display: grid; grid-template-columns: repeat(4, minmax(180px, 1fr)); gap: var(--sp-3); }
    .metric {
      background: var(--surface-2); border: 1px solid var(--line); border-radius: var(--r-2);
      padding: var(--sp-3);
    }
    .metric .label { font-family: var(--font-mono); color: var(--fg-3); font-size: var(--text-2xs); letter-spacing: 0.1em; text-transform: uppercase; }
    .metric .value { margin-top: 6px; font-size: var(--text-xl); font-weight: 600; color: var(--fg); }
    .metric .value.pos { color: var(--pos); }
    .metric .value.neg { color: var(--neg); }
    .chart-wrap { min-height: 420px; }
    svg { width: 100%; height: 420px; display: block; }
    .legend { display: flex; gap: var(--sp-3); flex-wrap: wrap; margin-top: var(--sp-2); color: var(--fg-2); font-size: var(--text-xs); }
    .legend-item { display: inline-flex; align-items: center; gap: 6px; }
    .swatch { width: 18px; height: 2px; display: inline-block; border-radius: 999px; }
    .table-wrap { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
    th, td { text-align: right; padding: 9px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
    th:first-child, td:first-child { text-align: left; }
    th { color: var(--fg-3); font-family: var(--font-mono); font-size: var(--text-2xs); letter-spacing: 0.08em; text-transform: uppercase; }
    .asset-cell { display: inline-flex; align-items: center; gap: 8px; }
    .asset-dot { width: 8px; height: 8px; border-radius: 2px; display: inline-block; }
    .nested-cell { background: var(--surface-2); padding: 0; }
    details { padding: var(--sp-3) var(--sp-4); }
    summary { cursor: pointer; color: var(--fg-2); font-weight: 500; }
    .nested-table { margin-top: var(--sp-2); font-size: var(--text-xs); }
    .nested-table th, .nested-table td { padding: 7px 8px; }
    .empty { padding: var(--sp-6); color: var(--fg-3); text-align: center; font-family: var(--font-mono); font-size: var(--text-sm); }
    @media (max-width: 980px) {
      .form-grid, .metric-grid { grid-template-columns: 1fr; }
      .rail { align-items: flex-start; flex-direction: column; }
      .shell { padding: var(--sp-4); }
    }
  </style>
</head>
<body>
  <div class="rail">
    <span class="rail-brand">
      <span class="mark"></span>
      <span>ALFIN</span>
      <span class="slash">/</span>
      <span class="section">OVERLAY</span>
    </span>
    <nav class="rail-nav">
      <a href="/admin">관리</a>
      <a href="/admin/comparison">비교 보드</a>
      <a href="/admin/comparison/usmv-overlay" aria-current="page">Overlay 비교</a>
    </nav>
    <div class="theme-toggle" role="group" aria-label="테마 전환">
      <button type="button" data-theme-set="light" aria-pressed="false">DAY</button>
      <button type="button" data-theme-set="dark" aria-pressed="true">NIGHT</button>
    </div>
  </div>
  <main class="shell">
    <header class="page-head">
      <div>
        <span class="eyebrow">Admin · Overlay Impact</span>
        <h1>USMV Overlay 유니버스 효과</h1>
        <p class="subtitle">`portfolio_USMV_overlay`를 기존 유니버스에 넣었을 때와 넣지 않았을 때의 Efficient Frontier를 같은 기간, 같은 제약조건으로 비교합니다.</p>
      </div>
    </header>

    <section class="card">
      <div class="card-head">
        <div>
          <span class="eyebrow">Inputs</span>
          <h2>비교 조건</h2>
        </div>
      </div>
      <form id="impact-form" class="form-grid">
        <div class="field">
          <label for="version">Universe</label>
          <select id="version" required></select>
        </div>
        <div class="field">
          <label for="start-date">Start</label>
          <input id="start-date" type="date" value="2023-01-04" />
        </div>
        <div class="field">
          <label for="end-date">End</label>
          <input id="end-date" type="date" value="2026-04-16" />
        </div>
        <div class="field">
          <label for="sample-points">Points</label>
          <input id="sample-points" type="number" min="3" max="101" value="61" />
        </div>
        <div class="field">
          <label for="overlay-max">Overlay Max</label>
          <input id="overlay-max" type="number" min="0" max="100" step="1" value="30" />
        </div>
        <button id="run-button" type="submit">계산</button>
      </form>
      <div id="status" class="status">카탈로그 로딩 중</div>
    </section>

    <section id="summary-card" class="card" hidden>
      <div class="card-head">
        <div>
          <span class="eyebrow">Universe Delta</span>
          <h2>프론티어 전체 비교</h2>
        </div>
      </div>
      <div class="metric-grid" id="metrics"></div>
    </section>

    <section id="chart-card" class="card" hidden>
      <div class="card-head">
        <div>
          <span class="eyebrow">Efficient Frontier</span>
          <h2>기존 유니버스 vs Overlay 포함 유니버스</h2>
        </div>
      </div>
      <div class="chart-wrap">
        <svg id="frontier-svg" role="img" aria-label="efficient frontier comparison"></svg>
        <div class="legend" id="frontier-legend"></div>
      </div>
    </section>

    <section id="table-card" class="card" hidden>
      <div class="card-head">
        <div>
          <span class="eyebrow">Same Risk Summary</span>
          <h2>자산군 추가 효과</h2>
        </div>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>항목</th>
              <th>기존 유니버스</th>
              <th>Overlay 포함 유니버스</th>
              <th>차이</th>
            </tr>
          </thead>
          <tbody id="summary-body"></tbody>
        </table>
      </div>
    </section>

    <section id="composition-card" class="card" hidden>
      <div class="card-head">
        <div>
          <span class="eyebrow">Max Sharpe Composition</span>
          <h2>Max Sharpe 구성 비교</h2>
        </div>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>자산군 단위</th>
              <th>기존 유니버스</th>
              <th>Overlay 포함 유니버스</th>
              <th>차이</th>
              <th>종목 단위</th>
            </tr>
          </thead>
          <tbody id="composition-body"></tbody>
        </table>
      </div>
    </section>
  </main>

  <script>
    const $ = sel => document.querySelector(sel);
    const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    })[ch]);
    const fmtPct = (value, digits = 1) => Number.isFinite(value) ? `${(value * 100).toFixed(digits)}%` : '-';
    const fmtSignedPct = (value, digits = 1) => {
      if (!Number.isFinite(value)) return '-';
      const pct = value * 100;
      return `${pct > 0 ? '+' : ''}${pct.toFixed(digits)}%`;
    };
    const fmtNumber = (value, digits = 2) => Number.isFinite(value) ? value.toFixed(digits) : '-';
    const fmtSignedNumber = (value, digits = 2) => {
      if (!Number.isFinite(value)) return '-';
      return `${value > 0 ? '+' : ''}${value.toFixed(digits)}`;
    };
    const fmtWeight = value => Number.isFinite(value) ? `${(value * 100).toFixed(1)}%` : '-';
    const svgNS = 'http://www.w3.org/2000/svg';
    const svgEl = (name, attrs = {}) => {
      const el = document.createElementNS(svgNS, name);
      Object.entries(attrs).forEach(([key, value]) => {
        if (value !== null && value !== undefined) el.setAttribute(key, value);
      });
      return el;
    };

    function setTheme(theme) {
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem('werobo-theme', theme);
      document.querySelectorAll('[data-theme-set]').forEach(btn => {
        btn.setAttribute('aria-pressed', btn.dataset.themeSet === theme ? 'true' : 'false');
      });
    }
    document.querySelectorAll('[data-theme-set]').forEach(btn => {
      btn.addEventListener('click', () => {
        setTheme(btn.dataset.themeSet);
        if (window.currentResult) renderResult(window.currentResult);
      });
    });
    setTheme(document.documentElement.getAttribute('data-theme') || 'dark');

    function setStatus(text, isError = false) {
      const el = $('#status');
      el.textContent = text;
      el.classList.toggle('error', isError);
    }

    async function requestJson(url, options) {
      const res = await fetch(url, options);
      const text = await res.text();
      let data = {};
      try { data = text ? JSON.parse(text) : {}; } catch (e) {}
      if (!res.ok) {
        throw new Error(data.detail || res.statusText || '요청 실패');
      }
      return data;
    }

    async function loadCatalog() {
      const catalog = await requestJson('/admin/api/comparison/catalog');
      const select = $('#version');
      select.innerHTML = '';
      catalog.versions.forEach(version => {
        const option = document.createElement('option');
        option.value = String(version.version_id);
        option.textContent = `${version.version_name || `Version ${version.version_id}`}${version.is_active ? ' · active' : ''}`;
        if (version.is_active) option.selected = true;
        select.appendChild(option);
      });
      if (!catalog.versions.length) {
        const option = document.createElement('option');
        option.textContent = '유니버스 없음';
        option.disabled = true;
        select.appendChild(option);
      }
      setStatus('준비됨');
    }

    async function runImpact() {
      const versionId = Number($('#version').value);
      if (!Number.isInteger(versionId)) {
        setStatus('유니버스를 선택해주세요.', true);
        return;
      }
      const payload = {
        version_id: versionId,
        start_date: $('#start-date').value || null,
        end_date: $('#end-date').value || null,
        sample_points: Number($('#sample-points').value || 61),
        overlay_max_weight: Number($('#overlay-max').value || 30) / 100,
      };
      $('#run-button').disabled = true;
      setStatus('계산 중');
      try {
        const result = await requestJson('/admin/api/comparison/usmv-overlay-impact', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        window.currentResult = result;
        renderResult(result);
        setStatus(`${result.period.start_date} → ${result.period.end_date} · ${result.period.return_rows} return rows`);
      } catch (error) {
        setStatus(error.message, true);
      } finally {
        $('#run-button').disabled = false;
      }
    }

    function renderResult(result) {
      $('#summary-card').hidden = false;
      $('#chart-card').hidden = false;
      $('#table-card').hidden = false;
      $('#composition-card').hidden = false;
      renderMetrics(result);
      renderFrontierChart(result);
      renderSummaryTable(result);
      renderCompositionTable(result);
    }

    function renderMetrics(result) {
      const summary = result.frontier_comparison?.summary || {};
      const baselineMax = summary.baseline_max_sharpe || {};
      const overlayMax = summary.with_overlay_max_sharpe || {};
      const metrics = [
        ['기존 Max Sharpe', fmtNumber(baselineMax.sharpe_ratio), baselineMax.sharpe_ratio],
        ['포함 Max Sharpe', fmtNumber(overlayMax.sharpe_ratio), overlayMax.sharpe_ratio],
        ['Max Sharpe 개선폭', fmtSignedNumber(summary.delta_max_sharpe), summary.delta_max_sharpe],
        ['Max Sharpe Overlay 비중', fmtWeight(overlayMax.overlay_weight), overlayMax.overlay_weight],
      ];
      $('#metrics').innerHTML = metrics.map(([label, value, raw]) => {
        const cls = Number(raw) > 0 ? 'pos' : (Number(raw) < 0 ? 'neg' : '');
        return `<div class="metric"><div class="label">${label}</div><div class="value ${cls}">${value}</div></div>`;
      }).join('');
    }

    function chartColors() {
      const style = getComputedStyle(document.documentElement);
      return {
        grid: style.getPropertyValue('--chart-grid').trim(),
        axis: style.getPropertyValue('--chart-axis').trim(),
        muted: style.getPropertyValue('--chart-muted-line').trim(),
      };
    }

    function renderFrontierChart(result) {
      const baseline = (result.baseline?.frontier_points || []).map(p => ({ ...p, label: '기존 유니버스', color: '#f97316' }));
      const overlay = (result.with_overlay?.frontier_points || []).map(p => ({ ...p, label: 'Overlay 포함', color: result.overlay?.color || '#38bdf8' }));
      const series = [
        { key: 'baseline', label: '기존 유니버스', color: '#f97316', points: baseline },
        { key: 'overlay', label: 'Overlay 포함', color: result.overlay?.color || '#38bdf8', points: overlay },
      ];
      const values = [...baseline, ...overlay];
      drawXYChart({
        svg: $('#frontier-svg'),
        legend: $('#frontier-legend'),
        series,
        values,
        xValue: p => p.volatility * 100,
        yValue: p => p.expected_return * 100,
        xLabel: '변동성',
        yFormatter: v => `${v.toFixed(1)}%`,
        xFormatter: v => `${v.toFixed(1)}%`,
      });
    }

    function drawXYChart({ svg, legend, series, values, xValue, yValue, xFormatter, yFormatter }) {
      while (svg.firstChild) svg.removeChild(svg.firstChild);
      legend.innerHTML = '';
      const C = chartColors();
      const W = 960, H = 420, padL = 56, padR = 28, padT = 24, padB = 40;
      svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
      if (!values.length) {
        const empty = svgEl('text', { x: W / 2, y: H / 2, fill: C.axis, 'text-anchor': 'middle', 'font-size': '12' });
        empty.textContent = '데이터 없음';
        svg.appendChild(empty);
        return;
      }
      let minX = Math.min(...values.map(xValue));
      let maxX = Math.max(...values.map(xValue));
      let minY = Math.min(...values.map(yValue));
      let maxY = Math.max(...values.map(yValue));
      if (minX === maxX) { minX -= 1; maxX += 1; }
      if (minY === maxY) { minY -= 1; maxY += 1; }
      const yPad = (maxY - minY) * 0.08;
      minY -= yPad; maxY += yPad;
      const sx = x => padL + ((x - minX) / (maxX - minX)) * (W - padL - padR);
      const sy = y => padT + (1 - ((y - minY) / (maxY - minY))) * (H - padT - padB);
      for (let i = 0; i <= 5; i++) {
        const y = padT + ((H - padT - padB) * i) / 5;
        svg.appendChild(svgEl('line', { x1: padL, y1: y, x2: W - padR, y2: y, stroke: C.grid, 'stroke-width': '1', 'stroke-dasharray': i === 0 || i === 5 ? null : '2,3' }));
        const yVal = maxY - ((maxY - minY) * i) / 5;
        const t = svgEl('text', { x: padL - 8, y: y + 3.5, fill: C.axis, 'font-size': '10', 'font-family': 'Azeret Mono, monospace', 'text-anchor': 'end' });
        t.textContent = yFormatter(yVal);
        svg.appendChild(t);
      }
      series.forEach(line => {
        const points = line.points || [];
        if (points.length < 2) return;
        const d = points.map((point, index) => {
          const command = index === 0 ? 'M' : 'L';
          return `${command} ${sx(xValue({ ...point, index })).toFixed(2)} ${sy(yValue(point)).toFixed(2)}`;
        }).join(' ');
        svg.appendChild(svgEl('path', {
          d, fill: 'none', stroke: line.color || C.muted, 'stroke-width': '2',
          'stroke-linecap': 'round', 'stroke-linejoin': 'round',
          'stroke-dasharray': line.style === 'dashed' ? '5,5' : null,
        }));
      });
      for (let i = 0; i <= 4; i++) {
        const xVal = minX + ((maxX - minX) * i) / 4;
        const x = sx(xVal);
        const t = svgEl('text', { x, y: H - 12, fill: C.axis, 'font-size': '10', 'font-family': 'Azeret Mono, monospace', 'text-anchor': 'middle' });
        t.textContent = xFormatter(xVal);
        svg.appendChild(t);
      }
      series.forEach(line => {
        const item = document.createElement('span');
        item.className = 'legend-item';
        item.innerHTML = `<span class="swatch" style="background:${line.color || C.muted}"></span><span>${line.label}</span>`;
        legend.appendChild(item);
      });
    }

    function renderSummaryTable(result) {
      const summary = result.frontier_comparison?.summary || {};
      const best = summary.best_point;
      const bestBaseline = best?.baseline || {};
      const bestOverlay = best?.with_overlay || {};
      const baselineMax = summary.baseline_max_sharpe || {};
      const overlayMax = summary.with_overlay_max_sharpe || {};
      const rows = [
        {
          label: '전체 프론티어 평균',
          baseline: `${summary.matched_point_count ?? 0}개 동일 위험점`,
          overlay: `평균 Overlay ${fmtWeight(summary.average_overlay_weight)}`,
          delta: fmtSignedPct(summary.average_delta_expected_return),
        },
        {
          label: '가장 개선된 동일 위험점',
          baseline: `${fmtPct(bestBaseline.expected_return)} / ${fmtPct(bestBaseline.volatility)}`,
          overlay: `${fmtPct(bestOverlay.expected_return)} / ${fmtPct(bestOverlay.volatility)}`,
          delta: fmtSignedPct(best?.delta_expected_return),
        },
        {
          label: 'Overlay 채택',
          baseline: '-',
          overlay: `최대 ${fmtWeight(summary.max_overlay_weight)}`,
          delta: `${summary.improved_point_count ?? 0}/${summary.matched_point_count ?? 0}개 지점 개선`,
        },
        {
          label: 'Max Sharpe',
          baseline: fmtNumber(baselineMax.sharpe_ratio),
          overlay: `${fmtNumber(overlayMax.sharpe_ratio)} · Overlay ${fmtWeight(overlayMax.overlay_weight)}`,
          delta: fmtSignedNumber(summary.delta_max_sharpe),
        },
      ];
      $('#summary-body').innerHTML = rows.map(row => `
        <tr>
          <td>${row.label}</td>
          <td>${row.baseline}</td>
          <td>${row.overlay}</td>
          <td>${row.delta}</td>
        </tr>
      `).join('');
    }

    function renderCompositionTable(result) {
      const rows = result.frontier_comparison?.max_sharpe_composition?.assets || [];
      if (!rows.length) {
        $('#composition-body').innerHTML = '<tr><td colspan="5" class="empty">구성 데이터 없음</td></tr>';
        return;
      }
      $('#composition-body').innerHTML = rows.map(row => {
        const instruments = row.instruments || [];
        const instrumentRows = instruments.length
          ? instruments.map(instrument => `
              <tr>
                <td>${escapeHtml(instrument.ticker)}</td>
                <td>${escapeHtml(instrument.name)}</td>
                <td>${fmtWeight(instrument.baseline_weight)}</td>
                <td>${fmtWeight(instrument.with_overlay_weight)}</td>
                <td>${fmtSignedPct(instrument.delta_weight)}</td>
              </tr>
            `).join('')
          : '<tr><td colspan="5" class="empty">종목 데이터 없음</td></tr>';
        return `
          <tr>
            <td>
              <span class="asset-cell">
                <span class="asset-dot" style="background:${escapeHtml(row.color)}"></span>
                <span>${escapeHtml(row.label)}</span>
              </span>
            </td>
            <td>${fmtWeight(row.baseline_weight)}</td>
            <td>${fmtWeight(row.with_overlay_weight)}</td>
            <td>${fmtSignedPct(row.delta_weight)}</td>
            <td>${instruments.length}개</td>
          </tr>
          <tr>
            <td colspan="5" class="nested-cell">
              <details>
                <summary>종목 단위</summary>
                <table class="nested-table">
                  <thead>
                    <tr>
                      <th>티커</th>
                      <th>종목명</th>
                      <th>기존</th>
                      <th>포함</th>
                      <th>차이</th>
                    </tr>
                  </thead>
                  <tbody>${instrumentRows}</tbody>
                </table>
              </details>
            </td>
          </tr>
        `;
      }).join('');
    }

    document.addEventListener('DOMContentLoaded', async () => {
      $('#impact-form').addEventListener('submit', ev => {
        ev.preventDefault();
        runImpact();
      });
      try {
        await loadCatalog();
      } catch (error) {
        setStatus(error.message, true);
      }
    });
  </script>
</body>
</html>
"""
    return HTMLResponse(content=html)
