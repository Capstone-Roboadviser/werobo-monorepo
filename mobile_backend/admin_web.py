from fastapi.responses import HTMLResponse


def render_admin_page() -> HTMLResponse:
    html = """<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Robo Mobile Admin</title>
  <style>
    :root {
      --bg: #f5f7fb;
      --card: #ffffff;
      --text: #122033;
      --muted: #5b6b7f;
      --line: #d8e0ea;
      --primary: #133c7a;
      --primary-soft: #e8f0ff;
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
      max-width: 1280px;
      margin: 0 auto;
      padding: 24px;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin-bottom: 20px;
    }
    .title h1 {
      margin: 0;
      font-size: 28px;
    }
    .title p {
      margin: 6px 0 0;
      color: var(--muted);
    }
    .grid {
      display: grid;
      grid-template-columns: 1.2fr 1fr;
      gap: 20px;
    }
    .card {
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      padding: 20px;
      box-shadow: 0 6px 20px rgba(17, 24, 39, 0.04);
    }
    .card h2 {
      margin: 0 0 12px;
      font-size: 18px;
    }
    .card p.helper {
      margin: -4px 0 16px;
      color: var(--muted);
      font-size: 14px;
      line-height: 1.5;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
      margin-bottom: 14px;
    }
    .stat {
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 14px;
      background: #fbfcfe;
    }
    .stat .label {
      font-size: 12px;
      color: var(--muted);
      margin-bottom: 6px;
    }
    .stat .value {
      font-size: 18px;
      font-weight: 700;
    }
    .row {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
      margin-bottom: 12px;
    }
    .field {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .field.full { grid-column: 1 / -1; }
    label {
      font-size: 13px;
      color: var(--muted);
    }
    input, textarea, select {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 10px 12px;
      font: inherit;
      background: white;
    }
    textarea {
      min-height: 90px;
      resize: vertical;
    }
    .actions {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      margin-top: 14px;
    }
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
    button.secondary {
      background: white;
      color: var(--primary);
    }
    button.danger {
      background: white;
      border-color: #d92d20;
      color: #d92d20;
    }
    button.ghost {
      background: transparent;
      border-color: var(--line);
      color: var(--text);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 10px 8px;
      text-align: left;
      vertical-align: top;
    }
    th {
      color: var(--muted);
      font-size: 12px;
      font-weight: 600;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      border-radius: 999px;
      padding: 4px 10px;
      font-size: 12px;
      font-weight: 700;
    }
    .pill.ok {
      color: var(--ok);
      background: var(--ok-soft);
    }
    .pill.warn {
      color: var(--warn);
      background: var(--warn-soft);
    }
    .pill.danger {
      color: var(--danger);
      background: var(--danger-soft);
    }
    .version-item {
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 14px;
      margin-bottom: 10px;
    }
    .version-head {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 10px;
    }
    .version-head strong {
      font-size: 16px;
    }
    .version-meta {
      color: var(--muted);
      font-size: 13px;
      line-height: 1.5;
    }
    .instrument-table input {
      min-width: 100px;
      padding: 8px 10px;
      border-radius: 10px;
    }
    .cell-stack {
      display: flex;
      flex-direction: column;
      gap: 8px;
      min-width: 170px;
    }
    .cell-actions {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
    }
    .mini {
      padding: 6px 10px;
      border-radius: 10px;
      font-size: 12px;
      line-height: 1;
    }
    .search-results {
      border: 1px solid var(--line);
      border-radius: 12px;
      background: #fbfcfe;
      overflow: hidden;
    }
    .search-results[hidden] {
      display: none;
    }
    .search-result-item {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      padding: 10px;
      border-bottom: 1px solid var(--line);
    }
    .search-result-item:last-child {
      border-bottom: 0;
    }
    .search-result-main {
      min-width: 0;
    }
    .search-result-symbol {
      font-size: 12px;
      font-weight: 800;
      color: var(--primary);
      margin-bottom: 3px;
    }
    .search-result-name {
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 3px;
    }
    .search-result-meta {
      font-size: 12px;
      color: var(--muted);
      line-height: 1.4;
      word-break: break-word;
    }
    .notice, .error {
      border-radius: 12px;
      padding: 12px 14px;
      font-size: 14px;
      line-height: 1.5;
      margin-top: 12px;
      white-space: pre-wrap;
    }
    .notice {
      background: var(--primary-soft);
      color: var(--primary);
    }
    .error {
      background: var(--danger-soft);
      color: var(--danger);
    }
    .readiness-list {
      margin: 0;
      padding-left: 18px;
      color: var(--muted);
    }
    .role-panel {
      margin: 18px 0;
      border: 1px solid var(--line);
      border-radius: 16px;
      padding: 16px;
      background: #fbfcfe;
    }
    .role-panel-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      margin-bottom: 12px;
    }
    .role-panel-header strong {
      display: block;
      font-size: 15px;
    }
    .role-panel-header span {
      display: block;
      color: var(--muted);
      font-size: 13px;
      margin-top: 4px;
    }
    .asset-role-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }
    .asset-role-card {
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 12px;
      background: white;
    }
    .asset-role-name {
      font-size: 14px;
      font-weight: 700;
      margin-bottom: 3px;
    }
    .asset-role-meta {
      font-size: 12px;
      color: var(--muted);
      margin-bottom: 10px;
    }
    .asset-role-help {
      margin-top: 8px;
      color: var(--muted);
      font-size: 12px;
      line-height: 1.5;
      white-space: pre-line;
    }
    @media (max-width: 980px) {
      .grid { grid-template-columns: 1fr; }
      .row, .stats { grid-template-columns: 1fr; }
      .asset-role-grid { grid-template-columns: 1fr; }
      .container { padding: 16px; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="title">
        <h1>모바일 백엔드 유니버스 관리</h1>
        <p>종목 등록, 유니버스 버전 관리, 가격 갱신만 빠르게 할 수 있는 가벼운 관리자 화면입니다.</p>
      </div>
      <div class="actions">
        <button class="secondary" id="reload-all">새로고침</button>
      </div>
    </div>

    <div class="grid">
      <section class="card">
        <h2>현재 상태</h2>
        <p class="helper">active 유니버스와 가격 데이터 상태를 한 번에 확인합니다.</p>
        <div class="stats">
          <div class="stat">
            <div class="label">DB 연결</div>
            <div class="value" id="db-status">-</div>
          </div>
          <div class="stat">
            <div class="label">Active 버전</div>
            <div class="value" id="active-version-name">-</div>
          </div>
          <div class="stat">
            <div class="label">가격 행 수</div>
            <div class="value" id="price-row-count">-</div>
          </div>
          <div class="stat">
            <div class="label">공통 시작일</div>
            <div class="value" id="aligned-start-date">-</div>
          </div>
        </div>
        <div id="status-detail" class="notice">상태를 불러오는 중입니다.</div>
      </section>

      <section class="card">
        <h2>가격 갱신</h2>
        <p class="helper">active 유니버스 기준으로 가격을 증분 또는 전체 백필합니다.</p>
        <div class="row">
          <div class="field">
            <label for="refresh-mode">갱신 모드</label>
            <select id="refresh-mode">
              <option value="incremental">incremental</option>
              <option value="full">full</option>
            </select>
          </div>
          <div class="field">
            <label for="lookback-years">전체 갱신 연수</label>
            <input id="lookback-years" type="number" value="5" min="1" max="20" />
          </div>
        </div>
        <div class="actions">
          <button id="refresh-prices">가격 갱신 실행</button>
          <button class="secondary" id="load-readiness">준비 상태 확인</button>
        </div>
        <div id="refresh-result" class="notice" style="display:none"></div>
        <div id="readiness-panel" class="notice" style="display:none"></div>
      </section>
    </div>

    <section class="card" style="margin-top: 20px;">
      <h2>새 유니버스 버전 생성</h2>
      <p class="helper">종목명 검색 또는 티커 자동채움으로 종목을 등록하고 새 버전을 만들 수 있습니다.</p>
      <div class="row">
        <div class="field">
          <label for="version-name">버전명</label>
          <input id="version-name" type="text" placeholder="예: 2026-04 mobile universe" />
        </div>
        <div class="field">
          <label for="version-notes">메모</label>
          <input id="version-notes" type="text" placeholder="선택 사항" />
        </div>
      </div>
      <div class="field full">
        <label><input id="version-activate" type="checkbox" checked /> 생성 후 즉시 active로 전환</label>
      </div>
      <div class="role-panel">
        <div class="role-panel-header">
          <div>
            <strong>자산군별 role 설정</strong>
            <span>이 버전에서 각 자산군을 대표종목형으로 볼지, 동일비중 바스켓으로 볼지 정합니다.</span>
          </div>
          <button class="secondary" id="reset-asset-roles" type="button">기본값 복원</button>
        </div>
        <div id="asset-role-config" class="notice">자산군 role 설정을 불러오는 중입니다.</div>
      </div>
      <table class="instrument-table" id="instrument-table">
        <thead>
          <tr>
            <th>티커 / 자동채움</th>
            <th>종목명 검색</th>
            <th>자산군 코드</th>
            <th>자산군 이름</th>
            <th>시장</th>
            <th>통화</th>
            <th>기본가중치</th>
            <th></th>
          </tr>
        </thead>
        <tbody id="instrument-body"></tbody>
      </table>
      <div class="actions">
        <button class="secondary" id="add-row">행 추가</button>
        <button id="create-version">버전 생성</button>
      </div>
      <div id="create-result" class="notice" style="display:none"></div>
      <div id="create-error" class="error" style="display:none"></div>
    </section>

    <section class="card" style="margin-top: 20px;">
      <h2>유니버스 버전 목록</h2>
      <p class="helper">active 전환, 상세 조회, 삭제를 이곳에서 처리합니다.</p>
      <div id="version-list" class="notice">버전 목록을 불러오는 중입니다.</div>
    </section>

    <section class="card" style="margin-top: 20px;">
      <h2>버전 상세</h2>
      <p class="helper">선택한 유니버스 버전의 종목 구성을 확인합니다.</p>
      <div id="version-detail" class="notice">상세를 보려면 버전 목록에서 "상세"를 눌러주세요.</div>
    </section>
  </div>

  <template id="instrument-row-template">
    <tr>
      <td>
        <div class="cell-stack">
          <input data-field="ticker" placeholder="QQQ" />
          <div class="cell-actions">
            <button class="secondary mini row-autofill" type="button">자동채움</button>
          </div>
        </div>
      </td>
      <td>
        <div class="cell-stack">
          <input data-field="name" placeholder="종목명 입력 후 검색" />
          <div class="cell-actions">
            <button class="secondary mini row-search" type="button">이름 검색</button>
          </div>
          <div class="search-results" hidden></div>
        </div>
      </td>
      <td><input data-field="sector_code" placeholder="us_growth" /></td>
      <td><input data-field="sector_name" placeholder="미국 성장주" /></td>
      <td><input data-field="market" placeholder="NASDAQ" /></td>
      <td><input data-field="currency" placeholder="USD" value="USD" /></td>
      <td><input data-field="base_weight" placeholder="선택" /></td>
      <td><button class="ghost row-remove" type="button">삭제</button></td>
    </tr>
  </template>

  <script>
    const $ = (selector) => document.querySelector(selector);
    const $$ = (selector) => Array.from(document.querySelectorAll(selector));
    let assetCatalog = [];
    let assetRoleTemplates = [];

    function showMessage(selector, text, isError = false) {
      const el = $(selector);
      el.style.display = 'block';
      el.textContent = text;
      el.className = isError ? 'error' : 'notice';
    }

    function hideMessage(selector) {
      const el = $(selector);
      el.style.display = 'none';
      el.textContent = '';
    }

    function normalizeTicker(value) {
      return (value || '').trim().toUpperCase();
    }

    function defaultAssetRoleMap() {
      return Object.fromEntries(assetCatalog.map((asset) => [asset.code, asset.role_key]));
    }

    function findRoleTemplate(roleKey) {
      return assetRoleTemplates.find((item) => item.key === roleKey) || null;
    }

    function updateRoleCardDescription(card, roleKey) {
      const help = card.querySelector('.asset-role-help');
      const template = findRoleTemplate(roleKey);
      help.textContent = template
        ? `${template.name} · ${template.selection_mode} / ${template.weighting_mode}\n${template.description}`
        : '선택한 role 정보를 찾을 수 없습니다.';
    }

    function renderAssetRoleSelectors(selectedMap = {}) {
      const host = $('#asset-role-config');
      if (!assetCatalog.length || !assetRoleTemplates.length) {
        host.className = 'notice';
        host.textContent = '표시할 자산군 role 설정이 없습니다.';
        return;
      }

      host.className = 'asset-role-grid';
      host.innerHTML = assetCatalog.map((asset) => {
        const selectedRoleKey = selectedMap[asset.code] || asset.role_key;
        const options = assetRoleTemplates.map((template) => `
          <option value="${template.key}" ${template.key === selectedRoleKey ? 'selected' : ''}>
            ${template.name} (${template.key})
          </option>
        `).join('');
        return `
          <div class="asset-role-card" data-asset-code="${asset.code}">
            <div class="asset-role-name">${asset.name}</div>
            <div class="asset-role-meta">${asset.code}</div>
            <select data-role-select="${asset.code}">
              ${options}
            </select>
            <div class="asset-role-help"></div>
          </div>
        `;
      }).join('');

      $$('#asset-role-config [data-role-select]').forEach((select) => {
        const card = select.closest('.asset-role-card');
        updateRoleCardDescription(card, select.value);
        select.addEventListener('change', () => {
          updateRoleCardDescription(card, select.value);
        });
      });
    }

    function collectAssetRoles() {
      return assetCatalog.map((asset) => {
        const select = document.querySelector(`[data-role-select="${asset.code}"]`);
        return {
          asset_code: asset.code,
          role_key: select ? select.value : asset.role_key,
        };
      });
    }

    function findDuplicateTicker(ticker, currentRow = null) {
      const normalized = normalizeTicker(ticker);
      if (!normalized) return null;
      return $$('#instrument-body tr').find((row) => {
        if (currentRow && row === currentRow) return false;
        return normalizeTicker(row.querySelector('[data-field="ticker"]').value) === normalized;
      }) || null;
    }

    async function lookupTicker(ticker) {
      const normalized = normalizeTicker(ticker);
      return requestJson(`/admin/api/tickers/lookup?ticker=${encodeURIComponent(normalized)}`);
    }

    async function autofillRowFromTicker(row, { silent = false } = {}) {
      const tickerInput = row.querySelector('[data-field="ticker"]');
      const ticker = normalizeTicker(tickerInput.value);
      tickerInput.value = ticker;
      if (!ticker) {
        if (!silent) showMessage('#create-error', '티커를 먼저 입력해주세요.', true);
        return;
      }

      const duplicate = findDuplicateTicker(ticker, row);
      if (duplicate) {
        if (!silent) showMessage('#create-error', `${ticker} 는 이미 다른 행에 추가되어 있습니다.`, true);
        return;
      }

      try {
        const data = await lookupTicker(ticker);
        row.querySelector('[data-field="name"]').value = data.name || ticker;
        row.querySelector('[data-field="market"]').value = data.market || '';
        row.querySelector('[data-field="currency"]').value = data.currency || '';
        hideMessage('#create-error');
      } catch (error) {
        if (!silent) {
          showMessage('#create-error', `${error.message}\n필요하면 종목명/시장/통화를 직접 입력한 뒤 저장할 수 있습니다.`, true);
        }
      }
    }

    function hideRowSearchResults(row) {
      const resultsEl = row.querySelector('.search-results');
      resultsEl.hidden = true;
      resultsEl.innerHTML = '';
    }

    function renderRowSearchResults(row, results) {
      const resultsEl = row.querySelector('.search-results');
      if (!results.length) {
        resultsEl.hidden = false;
        resultsEl.innerHTML = '<div class="search-result-item"><div class="search-result-main"><div class="search-result-name">검색 결과가 없습니다.</div><div class="search-result-meta">정확한 티커를 직접 입력하고 자동채움을 사용해보세요.</div></div></div>';
        return;
      }

      resultsEl.hidden = false;
      resultsEl.innerHTML = results.map((item) => `
        <div class="search-result-item">
          <div class="search-result-main">
            <div class="search-result-symbol">${item.ticker}</div>
            <div class="search-result-name">${item.name}</div>
            <div class="search-result-meta">${[item.exchange, item.currency, item.quote_type].filter(Boolean).join(' · ')}</div>
          </div>
          <button class="secondary mini pick-search-result" type="button" data-ticker="${item.ticker}">선택</button>
        </div>
      `).join('');

      Array.from(resultsEl.querySelectorAll('.pick-search-result')).forEach((button) => {
        button.addEventListener('click', async () => {
          const ticker = button.getAttribute('data-ticker');
          const match = results.find((item) => item.ticker === ticker);
          const duplicate = findDuplicateTicker(ticker, row);
          if (duplicate) {
            showMessage('#create-error', `${ticker} 는 이미 다른 행에 추가되어 있습니다.`, true);
            return;
          }

          row.querySelector('[data-field="ticker"]').value = ticker || '';
          row.querySelector('[data-field="name"]').value = match?.name || '';
          row.querySelector('[data-field="market"]').value = match?.market || match?.exchange || '';
          row.querySelector('[data-field="currency"]').value = match?.currency || '';
          hideRowSearchResults(row);

          if (!match?.market || !match?.currency) {
            await autofillRowFromTicker(row, { silent: true });
          }
          hideMessage('#create-error');
        });
      });
    }

    async function searchRowCandidates(row) {
      const query = row.querySelector('[data-field="name"]').value.trim()
        || normalizeTicker(row.querySelector('[data-field="ticker"]').value);
      if (!query) {
        showMessage('#create-error', '종목명 또는 티커를 먼저 입력해주세요.', true);
        return;
      }
      try {
        const data = await requestJson(`/admin/api/tickers/search?query=${encodeURIComponent(query)}&max_results=8`);
        renderRowSearchResults(row, data.results || []);
        hideMessage('#create-error');
      } catch (error) {
        hideRowSearchResults(row);
        showMessage('#create-error', error.message, true);
      }
    }

    function addInstrumentRow(seed = {}) {
      const template = $('#instrument-row-template');
      const fragment = template.content.cloneNode(true);
      const row = fragment.querySelector('tr');
      row.querySelectorAll('input').forEach((input) => {
        const key = input.dataset.field;
        if (seed[key] !== undefined && seed[key] !== null) {
          input.value = seed[key];
        }
      });
      row.querySelector('.row-remove').addEventListener('click', () => {
        row.remove();
      });
      row.querySelector('.row-autofill').addEventListener('click', async () => {
        await autofillRowFromTicker(row);
      });
      row.querySelector('.row-search').addEventListener('click', async () => {
        await searchRowCandidates(row);
      });
      row.querySelector('[data-field="ticker"]').addEventListener('blur', async () => {
        const ticker = normalizeTicker(row.querySelector('[data-field="ticker"]').value);
        const name = row.querySelector('[data-field="name"]').value.trim();
        if (ticker && !name) {
          await autofillRowFromTicker(row, { silent: true });
        }
      });
      row.querySelector('[data-field="name"]').addEventListener('keydown', async (event) => {
        if (event.key === 'Enter') {
          event.preventDefault();
          await searchRowCandidates(row);
        }
      });
      $('#instrument-body').appendChild(row);
    }

    function collectInstruments() {
      return $$('#instrument-body tr').map((row) => {
        const payload = {};
        row.querySelectorAll('input[data-field]').forEach((input) => {
          const key = input.dataset.field;
          const raw = input.value.trim();
          payload[key] = raw;
        });
        if (payload.base_weight === '') {
          payload.base_weight = null;
        } else if (payload.base_weight != null) {
          payload.base_weight = Number(payload.base_weight);
        }
        return payload;
      }).filter((item) => item.ticker && item.name && item.sector_code && item.sector_name && item.market && item.currency);
    }

    async function requestJson(url, options = {}) {
      const response = await fetch(url, {
        headers: { 'Content-Type': 'application/json' },
        ...options,
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.detail || '요청 처리 중 오류가 발생했습니다.');
      }
      return data;
    }

    function renderStatus(status) {
      $('#db-status').textContent = status.database_configured ? '연결됨' : '미설정';
      $('#active-version-name').textContent = status.active_version ? status.active_version.version_name : '없음';
      $('#price-row-count').textContent = status.price_stats ? String(status.price_stats.total_rows) : '-';
      $('#aligned-start-date').textContent = status.price_window?.aligned_start_date || '-';
      const detail = [
        'active: ' + (status.active_version ? status.active_version.version_name : '없음'),
        'latest job: ' + (status.latest_refresh_job ? `${status.latest_refresh_job.status} (${status.latest_refresh_job.message || '메시지 없음'})` : '없음'),
        'window: ' + (status.price_window ? `${status.price_window.aligned_start_date || '-'} ~ ${status.price_window.aligned_end_date || '-'}` : '없음'),
      ].join('\\n');
      showMessage('#status-detail', detail, false);
    }

    function renderVersionList(versions) {
      const host = $('#version-list');
      if (!versions.length) {
        host.className = 'notice';
        host.textContent = '아직 생성된 유니버스 버전이 없습니다.';
        return;
      }
      host.className = '';
      host.textContent = '';
      versions.forEach((version) => {
        const wrap = document.createElement('div');
        wrap.className = 'version-item';
        wrap.innerHTML = `
          <div class="version-head">
            <div>
              <strong>${version.version_name}</strong>
              <div class="version-meta">ID ${version.version_id} · 종목 ${version.instrument_count}개 · 생성 ${version.created_at}</div>
              <div class="version-meta">${version.notes || '메모 없음'}</div>
            </div>
            <div>${version.is_active ? '<span class="pill ok">ACTIVE</span>' : '<span class="pill warn">INACTIVE</span>'}</div>
          </div>
          <div class="actions">
            <button class="secondary detail-btn">상세</button>
            <button class="secondary activate-btn">활성화</button>
            <button class="danger delete-btn">삭제</button>
          </div>
        `;
        wrap.querySelector('.detail-btn').addEventListener('click', () => loadVersionDetail(version.version_id));
        wrap.querySelector('.activate-btn').addEventListener('click', () => activateVersion(version.version_id));
        wrap.querySelector('.delete-btn').addEventListener('click', () => deleteVersion(version.version_id));
        host.appendChild(wrap);
      });
    }

    function renderVersionDetail(detail) {
      const host = $('#version-detail');
      const roleRows = (detail.asset_roles || []).map((item) => `
        <tr>
          <td>${item.asset_name}</td>
          <td>${item.asset_code}</td>
          <td>${item.role_name}</td>
          <td>${item.role_key}</td>
          <td>${item.selection_mode}</td>
          <td>${item.weighting_mode}</td>
        </tr>
      `).join('');
      const rows = detail.instruments.map((item) => `
        <tr>
          <td>${item.ticker}</td>
          <td>${item.name}</td>
          <td>${item.sector_code}</td>
          <td>${item.sector_name}</td>
          <td>${item.market}</td>
          <td>${item.currency}</td>
          <td>${item.base_weight ?? '-'}</td>
        </tr>
      `).join('');
      host.className = '';
      host.innerHTML = `
        <div class="notice" style="margin-top:0; margin-bottom:12px;">
          ${detail.version_name} · 종목 ${detail.instrument_count}개 · ${detail.is_active ? 'active' : 'inactive'}
        </div>
        <div style="margin-bottom:16px;">
          <strong style="display:block; margin-bottom:8px;">자산군별 role</strong>
          <table>
            <thead>
              <tr>
                <th>자산군 이름</th>
                <th>자산군 코드</th>
                <th>role 이름</th>
                <th>role key</th>
                <th>selection</th>
                <th>weighting</th>
              </tr>
            </thead>
            <tbody>${roleRows}</tbody>
          </table>
        </div>
        <table>
          <thead>
            <tr>
              <th>티커</th>
              <th>종목명</th>
              <th>자산군 코드</th>
              <th>자산군 이름</th>
              <th>시장</th>
              <th>통화</th>
              <th>기본가중치</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      `;
    }

    function renderReadiness(readiness) {
      const host = $('#readiness-panel');
      const issues = readiness.issues.length
        ? '<ul class="readiness-list">' + readiness.issues.map((item) => `<li>${item}</li>`).join('') + '</ul>'
        : '<div>문제 없음</div>';
      const shortHistory = readiness.short_history_instruments.length
        ? '<ul class="readiness-list">' + readiness.short_history_instruments.map((item) => `<li>${item.ticker} · ${item.history_years}년 · ${item.first_price_date || '-'} ~ ${item.last_price_date || '-'}</li>`).join('') + '</ul>'
        : '<div>짧은 이력 종목 없음</div>';
      host.innerHTML = `
        <strong>${readiness.ready ? '준비 완료' : '준비 미완료'}</strong>
        <div style="margin-top:8px;">${readiness.summary}</div>
        <div style="margin-top:12px;"><strong>이슈</strong>${issues}</div>
        <div style="margin-top:12px;"><strong>짧은 이력 종목</strong>${shortHistory}</div>
      `;
      host.style.display = 'block';
      host.className = readiness.ready ? 'notice' : 'error';
    }

    async function loadStatus() {
      const status = await requestJson('/admin/api/universe/status');
      renderStatus(status);
    }

    async function loadVersions() {
      const versions = await requestJson('/admin/api/universe/versions');
      renderVersionList(versions);
    }

    async function loadAssetRoleConfig() {
      const config = await requestJson('/admin/api/universe/asset-role-config');
      assetCatalog = config.assets || [];
      assetRoleTemplates = config.role_templates || [];
      renderAssetRoleSelectors(defaultAssetRoleMap());
    }

    async function loadVersionDetail(versionId) {
      const detail = await requestJson(`/admin/api/universe/versions/${versionId}`);
      renderVersionDetail(detail);
    }

    async function loadReadiness() {
      const readiness = await requestJson('/admin/api/universe/readiness');
      renderReadiness(readiness);
    }

    async function activateVersion(versionId) {
      if (!confirm('이 버전을 active로 전환할까요?')) return;
      await requestJson(`/admin/api/universe/versions/${versionId}/activate`, { method: 'POST' });
      await reloadAll();
    }

    async function deleteVersion(versionId) {
      if (!confirm('이 유니버스 버전을 삭제할까요?')) return;
      await requestJson(`/admin/api/universe/versions/${versionId}`, { method: 'DELETE' });
      $('#version-detail').className = 'notice';
      $('#version-detail').textContent = '상세를 보려면 버전 목록에서 "상세"를 눌러주세요.';
      await reloadAll();
    }

    async function createVersion() {
      hideMessage('#create-result');
      hideMessage('#create-error');
      const instruments = collectInstruments();
      const payload = {
        version_name: $('#version-name').value.trim(),
        notes: $('#version-notes').value.trim() || null,
        activate: $('#version-activate').checked,
        asset_roles: collectAssetRoles(),
        instruments,
      };
      if (!payload.version_name) {
        showMessage('#create-error', '버전명을 입력해주세요.', true);
        return;
      }
      if (!payload.instruments.length) {
        showMessage('#create-error', '최소 한 개 이상의 종목 행을 채워주세요.', true);
        return;
      }
      try {
        const result = await requestJson('/admin/api/universe/versions', {
          method: 'POST',
          body: JSON.stringify(payload),
        });
        showMessage('#create-result', `버전 생성 완료: ${result.version_name} (ID ${result.version_id})`);
        await reloadAll();
      } catch (error) {
        showMessage('#create-error', error.message, true);
      }
    }

    async function refreshPrices() {
      hideMessage('#refresh-result');
      try {
        const payload = {
          version_id: null,
          refresh_mode: $('#refresh-mode').value,
          full_lookback_years: Number($('#lookback-years').value || '5'),
        };
        const result = await requestJson('/admin/api/prices/refresh', {
          method: 'POST',
          body: JSON.stringify(payload),
        });
        showMessage('#refresh-result', `갱신 완료\\njob: ${result.job.status}\\nmessage: ${result.job.message || '-'}\\nrows: ${result.price_stats.total_rows}`);
        await reloadAll();
      } catch (error) {
        showMessage('#refresh-result', error.message, true);
      }
    }

    async function reloadAll() {
      await Promise.all([loadStatus(), loadVersions(), loadAssetRoleConfig()]);
    }

    $('#reload-all').addEventListener('click', reloadAll);
    $('#add-row').addEventListener('click', () => addInstrumentRow());
    $('#reset-asset-roles').addEventListener('click', () => {
      renderAssetRoleSelectors(defaultAssetRoleMap());
    });
    $('#create-version').addEventListener('click', createVersion);
    $('#refresh-prices').addEventListener('click', refreshPrices);
    $('#load-readiness').addEventListener('click', loadReadiness);

    addInstrumentRow({
      ticker: 'QQQ',
      name: 'Invesco QQQ Trust',
      sector_code: 'us_growth',
      sector_name: '미국 성장주',
      market: 'NASDAQ',
      currency: 'USD',
    });
    addInstrumentRow({
      ticker: 'SHY',
      name: 'iShares 1-3 Year Treasury Bond ETF',
      sector_code: 'short_term_bond',
      sector_name: '단기 채권',
      market: 'NASDAQ',
      currency: 'USD',
    });
    reloadAll().catch((error) => {
      showMessage('#status-detail', error.message, true);
      showMessage('#version-list', error.message, true);
    });
  </script>
</body>
</html>"""
    return HTMLResponse(content=html)
