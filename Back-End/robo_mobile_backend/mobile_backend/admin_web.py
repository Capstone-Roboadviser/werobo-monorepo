from fastapi.responses import HTMLResponse


def render_admin_page() -> HTMLResponse:
    html = """<!DOCTYPE html>
<html lang="ko" data-theme="light">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Universe / WeRobo Admin</title>
  <script>
    // Set theme before first paint to prevent light-mode flash on navigation.
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

      --text-2xs: 10.5px;
      --text-xs: 11.5px;
      --text-sm: 12.5px;
      --text-base: 13.5px;
      --text-md: 14.5px;
      --text-lg: 16px;
      --text-xl: 19px;
      --text-2xl: 24px;

      --sp-1: 4px;
      --sp-2: 8px;
      --sp-3: 12px;
      --sp-4: 16px;
      --sp-5: 24px;
      --sp-6: 32px;
      --sp-7: 48px;

      --r-1: 3px;
      --r-2: 5px;
      --r-3: 7px;
      --r-4: 10px;

      /* Light theme — cool paper, TradingView cobalt accent */
      --bg: oklch(98% 0.004 255);
      --surface: oklch(100% 0 0);
      --surface-2: oklch(98.5% 0.005 255);
      --surface-3: oklch(96% 0.008 255);
      --fg: oklch(22% 0.018 255);
      --fg-2: oklch(42% 0.018 255);
      --fg-3: oklch(58% 0.016 255);
      --fg-4: oklch(72% 0.012 255);
      --line: oklch(91% 0.010 255);
      --line-2: oklch(82% 0.014 255);
      --line-3: oklch(68% 0.018 255);

      --accent: oklch(56% 0.22 260);
      --accent-hover: oklch(50% 0.24 260);
      --accent-fg: oklch(99% 0.003 260);
      --accent-soft: oklch(94% 0.045 260);

      --pos: oklch(50% 0.15 155);
      --pos-soft: oklch(94% 0.050 155);
      --neg: oklch(52% 0.19 28);
      --neg-soft: oklch(96% 0.028 28);
      --warn: oklch(62% 0.14 82);
      --warn-soft: oklch(95% 0.045 82);

      --shadow-sm: 0 1px 0 oklch(40% 0.020 255 / 0.05);
      --shadow-md: 0 1px 2px oklch(40% 0.020 255 / 0.08), 0 4px 12px oklch(40% 0.020 255 / 0.05);

      color-scheme: light;
    }

    [data-theme="dark"] {
      --bg: oklch(15% 0.015 255);
      --surface: oklch(19% 0.017 255);
      --surface-2: oklch(22.5% 0.018 255);
      --surface-3: oklch(27% 0.018 255);
      --fg: oklch(94% 0.008 255);
      --fg-2: oklch(74% 0.014 255);
      --fg-3: oklch(58% 0.017 255);
      --fg-4: oklch(42% 0.017 255);
      --line: oklch(28% 0.018 255);
      --line-2: oklch(36% 0.021 255);
      --line-3: oklch(48% 0.023 255);

      --accent: oklch(70% 0.18 260);
      --accent-hover: oklch(76% 0.16 260);
      --accent-fg: oklch(15% 0.015 255);
      --accent-soft: oklch(32% 0.090 260);

      --pos: oklch(72% 0.17 155);
      --pos-soft: oklch(30% 0.055 155);
      --neg: oklch(72% 0.19 28);
      --neg-soft: oklch(32% 0.055 28);
      --warn: oklch(80% 0.14 82);
      --warn-soft: oklch(32% 0.055 82);

      --shadow-sm: 0 1px 0 oklch(4% 0 0 / 0.35);
      --shadow-md: 0 1px 2px oklch(4% 0 0 / 0.45), 0 4px 14px oklch(4% 0 0 / 0.35);

      color-scheme: dark;
    }

    * { box-sizing: border-box; }
    html { height: 100%; }
    body {
      margin: 0;
      min-height: 100%;
      background: var(--bg);
      color: var(--fg);
      font-family: var(--font-ui);
      font-size: var(--text-base);
      font-variant-numeric: tabular-nums;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
      line-height: 1.45;
    }
    ::selection { background: var(--accent); color: var(--accent-fg); }

    /* ─ Top utility rail ─ */
    .rail {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: var(--sp-4);
      padding: 10px var(--sp-5);
      border-bottom: 1px solid var(--line);
      background: var(--surface);
      font-size: var(--text-xs);
      color: var(--fg-3);
      letter-spacing: 0.01em;
    }
    .rail-brand {
      display: inline-flex;
      align-items: center;
      gap: var(--sp-2);
      font-family: var(--font-mono);
      font-size: var(--text-xs);
      color: var(--fg);
      font-weight: 500;
      letter-spacing: 0.02em;
    }
    .rail-brand .mark {
      display: inline-block;
      width: 7px; height: 7px;
      border-radius: 1px;
      background: var(--accent);
    }
    .rail-brand .slash { color: var(--fg-4); margin: 0 2px; }
    .rail-brand .section { color: var(--fg-2); }
    .rail-nav {
      display: inline-flex;
      align-items: center;
      gap: var(--sp-4);
    }
    .rail-nav a {
      color: var(--fg-2);
      text-decoration: none;
      font-family: var(--font-mono);
      font-size: var(--text-xs);
      padding: 3px 6px;
      border-radius: var(--r-1);
      transition: background 120ms;
    }
    .rail-nav a[aria-current="page"] {
      color: var(--fg);
      background: var(--surface-3);
    }
    .rail-nav a:hover { background: var(--surface-3); color: var(--fg); }
    .theme-toggle {
      display: inline-grid;
      grid-template-columns: 1fr 1fr;
      background: var(--surface-2);
      border: 1px solid var(--line);
      border-radius: var(--r-2);
      padding: 2px;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      letter-spacing: 0.08em;
    }
    .theme-toggle button {
      appearance: none;
      border: 0;
      background: transparent;
      color: var(--fg-3);
      padding: 3px 10px;
      border-radius: var(--r-1);
      cursor: pointer;
      font: inherit;
      text-transform: uppercase;
    }
    .theme-toggle button[aria-pressed="true"] {
      background: var(--surface);
      color: var(--fg);
      box-shadow: var(--shadow-sm);
    }

    /* ─ Page shell ─ */
    .shell {
      max-width: 1320px;
      margin: 0 auto;
      padding: var(--sp-5) var(--sp-5) var(--sp-7);
    }
    .page-head {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      gap: var(--sp-4);
      flex-wrap: wrap;
      padding: var(--sp-5) 0 var(--sp-4);
      border-bottom: 1px solid var(--line);
      margin-bottom: var(--sp-5);
    }
    .page-head h1 {
      margin: 0;
      font-size: var(--text-2xl);
      font-weight: 600;
      letter-spacing: -0.015em;
    }
    .page-head .eyebrow {
      display: block;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      letter-spacing: 0.12em;
      color: var(--fg-3);
      text-transform: uppercase;
      margin-bottom: 6px;
    }
    .page-head .subtitle {
      margin: 4px 0 0;
      max-width: 62ch;
      color: var(--fg-3);
      font-size: var(--text-sm);
    }
    .page-head .actions {
      display: flex;
      gap: var(--sp-2);
      flex-wrap: wrap;
    }

    /* ─ Status strip ─ */
    .status-strip {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 0;
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      background: var(--surface);
      overflow: hidden;
      margin-bottom: var(--sp-5);
    }
    .strip-cell {
      padding: 14px 18px;
      border-right: 1px solid var(--line);
      min-width: 0;
    }
    .strip-cell:last-child { border-right: 0; }
    .strip-label {
      display: block;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      letter-spacing: 0.14em;
      text-transform: uppercase;
      margin-bottom: 4px;
    }
    .strip-value {
      font-size: var(--text-lg);
      font-weight: 600;
      color: var(--fg);
      letter-spacing: -0.01em;
      font-feature-settings: 'tnum';
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .strip-value.mono {
      font-family: var(--font-mono);
      font-weight: 500;
      font-size: var(--text-md);
    }
    .strip-sub {
      font-size: var(--text-xs);
      color: var(--fg-3);
      font-family: var(--font-mono);
      margin-top: 2px;
    }

    /* ─ Section + card ─ */
    .grid-2 {
      display: grid;
      grid-template-columns: 1.4fr 1fr;
      gap: var(--sp-4);
      margin-bottom: var(--sp-5);
    }
    .card {
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      padding: var(--sp-5);
    }
    .card + .card { margin-top: var(--sp-4); }
    .card-head {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      gap: var(--sp-3);
      margin-bottom: var(--sp-4);
    }
    .card-head h2 {
      margin: 0;
      font-size: var(--text-lg);
      font-weight: 600;
      letter-spacing: -0.005em;
    }
    .card-head .eyebrow {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.14em;
    }
    .card-head .tag {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.14em;
      padding: 2px 7px;
      background: var(--surface-3);
      border-radius: var(--r-1);
    }
    .helper {
      color: var(--fg-3);
      font-size: var(--text-sm);
      line-height: 1.5;
      margin: -8px 0 var(--sp-4);
      max-width: 68ch;
    }

    /* ─ Form ─ */
    .row {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: var(--sp-3);
      margin-bottom: var(--sp-3);
    }
    .field {
      display: flex;
      flex-direction: column;
      gap: 5px;
      min-width: 0;
    }
    .field.full { grid-column: 1 / -1; }
    label {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.1em;
      font-weight: 500;
    }
    input, textarea, select {
      width: 100%;
      border: 1px solid var(--line-2);
      border-radius: var(--r-2);
      padding: 8px 10px;
      font: inherit;
      font-size: var(--text-sm);
      background: var(--surface);
      color: var(--fg);
      transition: border-color 120ms, box-shadow 120ms;
    }
    input::placeholder, textarea::placeholder {
      color: var(--fg-4);
    }
    input:focus, textarea:focus, select:focus {
      outline: 0;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-soft);
    }
    textarea {
      min-height: 80px;
      resize: vertical;
    }
    input[type="checkbox"] {
      width: auto;
      accent-color: var(--accent);
      margin-right: 6px;
    }

    /* ─ Actions / buttons ─ */
    .actions {
      display: flex;
      gap: var(--sp-2);
      flex-wrap: wrap;
      margin-top: var(--sp-4);
    }
    button {
      appearance: none;
      border: 1px solid var(--accent);
      background: var(--accent);
      color: var(--accent-fg);
      border-radius: var(--r-2);
      padding: 8px 14px;
      font: inherit;
      font-size: var(--text-sm);
      font-weight: 500;
      letter-spacing: 0.01em;
      cursor: pointer;
      transition: background 120ms, border-color 120ms, color 120ms;
    }
    button:hover:not(:disabled) {
      background: var(--accent-hover);
      border-color: var(--accent-hover);
    }
    button:disabled {
      opacity: 0.55;
      cursor: not-allowed;
    }
    button.secondary {
      background: var(--surface);
      color: var(--fg);
      border-color: var(--line-2);
    }
    button.secondary:hover:not(:disabled) {
      background: var(--surface-3);
      border-color: var(--line-3);
    }
    button.ghost {
      background: transparent;
      color: var(--fg-2);
      border-color: transparent;
    }
    button.ghost:hover:not(:disabled) {
      color: var(--fg);
      background: var(--surface-3);
    }
    button.danger {
      background: var(--surface);
      color: var(--neg);
      border-color: var(--line-2);
    }
    button.danger:hover:not(:disabled) {
      color: var(--neg);
      border-color: var(--neg);
      background: var(--neg-soft);
    }
    button.mini {
      padding: 5px 9px;
      font-size: var(--text-2xs);
      border-radius: var(--r-1);
      letter-spacing: 0.04em;
    }

    a { color: var(--accent); }
    a.nav-link {
      font-family: var(--font-mono);
      font-size: var(--text-xs);
      color: var(--fg-2);
      text-decoration: none;
      padding: 6px 10px;
      border-radius: var(--r-2);
      border: 1px solid var(--line-2);
      background: var(--surface);
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    a.nav-link:hover { color: var(--fg); border-color: var(--line-3); background: var(--surface-3); }

    /* ─ Tables ─ */
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: var(--text-sm);
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 9px 10px;
      text-align: left;
      vertical-align: top;
    }
    tbody tr:last-child td { border-bottom: 0; }
    th {
      color: var(--fg-3);
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      padding-top: 8px;
      padding-bottom: 8px;
      background: var(--surface-2);
      border-bottom: 1px solid var(--line-2);
      position: sticky;
      top: 0;
    }
    td code, .mono { font-family: var(--font-mono); }
    .instrument-table { margin-top: var(--sp-3); }
    .instrument-table td { padding: 8px 8px; }
    .instrument-table input {
      min-width: 100px;
      padding: 6px 8px;
      font-size: var(--text-sm);
      border-radius: var(--r-2);
    }
    .instrument-table select {
      padding: 6px 8px;
      font-size: var(--text-sm);
    }
    .cell-stack {
      display: flex;
      flex-direction: column;
      gap: 6px;
      min-width: 160px;
    }
    .cell-actions {
      display: flex;
      gap: 4px;
      flex-wrap: wrap;
    }

    /* ─ Chips / pills ─ */
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      border-radius: var(--r-1);
      padding: 2px 8px;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      font-weight: 600;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .pill::before {
      content: '';
      display: inline-block;
      width: 6px; height: 6px;
      border-radius: 50%;
      background: currentColor;
    }
    .pill.ok    { color: var(--pos); background: var(--pos-soft); }
    .pill.warn  { color: var(--warn); background: var(--warn-soft); }
    .pill.danger{ color: var(--neg); background: var(--neg-soft); }

    /* ─ Search results ─ */
    .search-results {
      border: 1px solid var(--line);
      border-radius: var(--r-2);
      background: var(--surface-2);
      overflow: hidden;
    }
    .search-results[hidden] { display: none; }
    .search-result-item {
      display: flex;
      justify-content: space-between;
      gap: var(--sp-2);
      padding: 10px;
      border-bottom: 1px solid var(--line);
    }
    .search-result-item:last-child { border-bottom: 0; }
    .search-result-main { min-width: 0; }
    .search-result-symbol {
      font-family: var(--font-mono);
      font-size: var(--text-xs);
      font-weight: 600;
      color: var(--accent);
      margin-bottom: 2px;
      letter-spacing: 0.03em;
    }
    .search-result-name {
      font-size: var(--text-sm);
      font-weight: 500;
      margin-bottom: 2px;
    }
    .search-result-meta {
      font-size: var(--text-xs);
      color: var(--fg-3);
      font-family: var(--font-mono);
      word-break: break-word;
    }

    /* ─ Notices / messages ─ */
    .notice, .error {
      border: 1px solid var(--line);
      background: var(--surface-2);
      border-radius: var(--r-2);
      padding: 10px 14px;
      font-size: var(--text-sm);
      line-height: 1.55;
      margin-top: var(--sp-3);
      white-space: pre-wrap;
      color: var(--fg-2);
      font-family: var(--font-mono);
    }
    .error {
      color: var(--neg);
      background: var(--neg-soft);
      border-color: color-mix(in oklab, var(--neg) 30%, var(--line));
    }
    .readiness-list {
      margin: 6px 0 0;
      padding-left: 18px;
      color: var(--fg-2);
      font-family: var(--font-ui);
      font-size: var(--text-sm);
    }

    /* ─ Role / asset panel ─ */
    .role-panel {
      margin: var(--sp-4) 0;
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      padding: var(--sp-4);
      background: var(--surface-2);
    }
    .role-panel-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: var(--sp-3);
      margin-bottom: var(--sp-3);
    }
    .role-panel-header strong {
      display: block;
      font-size: var(--text-md);
      font-weight: 600;
    }
    .role-panel-header span {
      display: block;
      color: var(--fg-3);
      font-size: var(--text-xs);
      margin-top: 2px;
    }
    .asset-role-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: var(--sp-3);
    }
    .asset-role-card {
      border: 1px solid var(--line);
      border-radius: var(--r-2);
      padding: 14px 14px 12px;
      background: var(--surface);
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .asset-role-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: var(--sp-3);
      line-height: 1.15;
    }
    .asset-role-name {
      font-size: var(--text-md);
      font-weight: 500;
      letter-spacing: -0.005em;
      color: var(--fg);
    }
    .asset-role-code {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-4);
      letter-spacing: 0.06em;
      flex-shrink: 0;
    }
    .asset-role-card select { margin-top: 2px; }
    .asset-role-spec {
      margin: 2px 0 0;
      padding: 10px 0 0;
      border-top: 1px dashed var(--line);
      display: grid;
      gap: 5px;
    }
    .asset-role-spec-row {
      display: grid;
      grid-template-columns: 36px 1fr;
      align-items: baseline;
      column-gap: 10px;
    }
    .asset-role-spec dt {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      font-weight: 500;
      color: var(--fg-4);
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }
    .asset-role-spec dd {
      margin: 0;
      font-family: var(--font-mono);
      font-size: var(--text-xs);
      color: var(--fg-2);
      line-height: 1.35;
      overflow-wrap: anywhere;
    }
    .asset-role-spec dd.is-empty {
      color: var(--fg-4);
    }
    .asset-role-note {
      margin: 2px 0 0;
      color: var(--fg-3);
      font-size: var(--text-xs);
      line-height: 1.55;
      max-width: 52ch;
    }

    /* ─ Version list ─ */
    #version-list {
      display: flex;
      flex-direction: column;
      gap: 0;
    }
    #version-list.notice { display: block; }
    .version-item {
      border-top: 1px solid var(--line);
      padding: 18px 0 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .version-item:first-child { border-top: 0; padding-top: 4px; }
    .version-head {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: var(--sp-3);
      align-items: baseline;
    }
    .version-title {
      display: flex;
      align-items: baseline;
      gap: 10px;
      min-width: 0;
    }
    .version-title strong {
      font-size: var(--text-md);
      font-weight: 600;
      letter-spacing: -0.01em;
      color: var(--fg);
    }
    .version-stats {
      margin: 0;
      padding: 0;
      display: flex;
      flex-wrap: wrap;
      column-gap: var(--sp-6);
      row-gap: var(--sp-3);
      align-items: baseline;
      max-width: 640px;
    }
    .version-stat {
      display: flex;
      flex-direction: column;
      gap: 3px;
      min-width: 0;
    }
    .version-stat dt {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-4);
      letter-spacing: 0.16em;
      text-transform: uppercase;
      line-height: 1;
      margin: 0;
    }
    .version-stat dd {
      margin: 0;
      font-family: var(--font-mono);
      font-size: var(--text-sm);
      color: var(--fg);
      font-variant-numeric: tabular-nums;
      line-height: 1.2;
      white-space: nowrap;
    }
    .version-stat dd .unit {
      color: var(--fg-3);
      margin-left: 4px;
      font-size: var(--text-2xs);
      letter-spacing: 0.06em;
    }
    .version-memo {
      margin: 0;
      color: var(--fg-2);
      font-size: var(--text-xs);
      line-height: 1.55;
      max-width: 60ch;
      text-indent: -1em;
      padding-left: 1em;
    }
    .version-memo::before {
      content: '— ';
      color: var(--fg-4);
    }
    .version-item .actions {
      margin-top: 2px;
    }

    /* ─ Inline detail panel (accordion) ─ */
    .version-detail-panel {
      display: grid;
      grid-template-rows: 0fr;
      transition: grid-template-rows 220ms cubic-bezier(0.22, 1, 0.36, 1);
    }
    .version-detail-panel > .panel-inner {
      overflow: hidden;
      min-height: 0;
    }
    .version-detail-panel.open { grid-template-rows: 1fr; }
    .version-detail-panel.open > .panel-inner {
      margin-top: var(--sp-3);
      padding: var(--sp-4);
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      background: var(--surface-2);
    }
    .version-detail-panel .notice {
      margin-top: 0;
      margin-bottom: var(--sp-3);
      background: var(--surface);
    }
    .version-detail-panel .detail-section-label {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin: var(--sp-4) 0 var(--sp-2);
    }
    .version-detail-panel .detail-table-wrap {
      overflow-x: auto;
      border: 1px solid var(--line);
      border-radius: var(--r-2);
      margin-bottom: var(--sp-3);
      background: var(--surface);
    }
    .version-detail-panel .detail-table-wrap:last-child { margin-bottom: 0; }
    .version-detail-panel table { min-width: max-content; }
    .version-detail-panel th,
    .version-detail-panel td { white-space: nowrap; }
    .version-item.detail-open .detail-btn {
      background: var(--accent-soft);
      color: var(--accent);
      border-color: color-mix(in oklab, var(--accent) 35%, var(--line-2));
    }

    @media (max-width: 980px) {
      .grid-2 { grid-template-columns: 1fr; }
      .row { grid-template-columns: 1fr; }
      .shell { padding: var(--sp-4); }
      .rail { padding: 10px var(--sp-4); flex-wrap: wrap; }
      .strip-cell { border-right: 0; border-bottom: 1px solid var(--line); }
      .strip-cell:last-child { border-bottom: 0; }
      .version-head { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="rail">
    <span class="rail-brand">
      <span class="mark"></span>
      <span>WEROBO</span>
      <span class="slash">/</span>
      <span class="section">UNIVERSE</span>
    </span>
    <nav class="rail-nav">
      <a href="/admin" aria-current="page">관리</a>
      <a href="/admin/comparison">비교 보드</a>
    </nav>
    <div class="theme-toggle" role="group" aria-label="테마 전환">
      <button type="button" data-theme-set="light" aria-pressed="true">DAY</button>
      <button type="button" data-theme-set="dark" aria-pressed="false">NIGHT</button>
    </div>
  </div>

  <div class="shell">
    <header class="page-head">
      <div>
        <span class="eyebrow">Admin · Universe</span>
        <h1>유니버스 관리</h1>
        <p class="subtitle">종목 등록, 버전 발행, 가격 갱신을 한 화면에서 처리합니다. 모바일 백엔드가 소비하는 active 유니버스를 여기서 결정합니다.</p>
      </div>
      <div class="actions">
        <a class="nav-link" href="/admin/comparison">비교 보드 →</a>
        <button class="secondary" id="reload-all">새로고침</button>
      </div>
    </header>

    <section class="status-strip" aria-label="Active universe status">
      <div class="strip-cell">
        <span class="strip-label">DB</span>
        <div class="strip-value" id="db-status">—</div>
      </div>
      <div class="strip-cell">
        <span class="strip-label">Active Version</span>
        <div class="strip-value" id="active-version-name">—</div>
      </div>
      <div class="strip-cell">
        <span class="strip-label">Price Rows</span>
        <div class="strip-value mono" id="price-row-count">—</div>
      </div>
      <div class="strip-cell">
        <span class="strip-label">Aligned Start</span>
        <div class="strip-value mono" id="aligned-start-date">—</div>
      </div>
    </section>
    <div id="status-detail" class="notice">상태를 불러오는 중입니다.</div>

    <div class="grid-2">
      <section class="card">
        <div class="card-head">
          <div>
            <span class="eyebrow">Section 01 · Prices</span>
            <h2>가격 갱신</h2>
          </div>
        </div>
        <p class="helper">active 유니버스 기준으로 가격을 증분 또는 전체 백필합니다. 성공 시 frontier / comparison snapshot과 사용자 자산 snapshot이 자동으로 재생성됩니다.</p>
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

      <section class="card">
        <div class="card-head">
          <div>
            <span class="eyebrow">Section 02 · State</span>
            <h2>상태 로그</h2>
          </div>
        </div>
        <p class="helper">마지막 refresh 결과, frontier snapshot, comparison snapshot의 상태 요약입니다.</p>
        <div id="status-log" class="notice">—</div>
      </section>
    </div>

    <section class="card">
      <div class="card-head">
        <div>
          <span class="eyebrow">Section 03 · Authoring</span>
          <h2 id="version-form-title">새 유니버스 버전 생성</h2>
        </div>
      </div>
      <p class="helper" id="version-form-helper">종목명 검색 또는 티커 자동채움으로 종목을 등록하고 새 버전을 만들 수 있습니다.</p>
      <div id="form-mode-banner" class="notice" style="display:none"></div>
      <div class="row">
        <div class="field">
          <label for="version-name">버전명</label>
          <input id="version-name" type="text" placeholder="2026-04 mobile universe" />
        </div>
        <div class="field">
          <label for="version-notes">메모</label>
          <input id="version-notes" type="text" placeholder="선택 사항" />
        </div>
      </div>
      <div class="field full">
        <label style="display:inline-flex; align-items:center; gap:8px; text-transform:none; letter-spacing:0; font-family:var(--font-ui); font-size:var(--text-sm); color:var(--fg-2);">
          <input id="version-activate" type="checkbox" checked /> 저장 후 active로 전환
        </label>
      </div>
      <div class="role-panel">
        <div class="role-panel-header">
          <div>
            <strong>자산군별 role 설정</strong>
            <span>자산군별 후보 선택 방식, 바스켓 내부 가중 방식, 기대수익률 모드를 함께 정합니다.</span>
          </div>
          <button class="secondary mini" id="reset-asset-roles" type="button">기본값 복원</button>
        </div>
        <div id="asset-role-config" class="notice">자산군 role 설정을 불러오는 중입니다.</div>
      </div>
      <div style="overflow-x: auto;">
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
      </div>
      <div class="actions">
        <button class="secondary mini" id="add-row">+ 행 추가</button>
        <div style="flex:1"></div>
        <button class="ghost" id="cancel-edit" type="button" style="display:none">수정 취소</button>
        <button id="submit-version">버전 생성</button>
      </div>
      <div id="create-result" class="notice" style="display:none"></div>
      <div id="create-error" class="error" style="display:none"></div>
    </section>

    <section class="card">
      <div class="card-head">
        <div>
          <span class="eyebrow">Section 04 · Registry</span>
          <h2>유니버스 버전 목록</h2>
        </div>
      </div>
      <p class="helper">active 전환, 상세 조회, 삭제를 이곳에서 처리합니다.</p>
      <div id="version-list" class="notice">버전 목록을 불러오는 중입니다.</div>
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
      <td><select data-field="sector_code"></select></td>
      <td><input data-field="sector_name" placeholder="미국 성장주" readonly /></td>
      <td><input data-field="market" placeholder="NASDAQ" /></td>
      <td><input data-field="currency" placeholder="USD" value="USD" /></td>
      <td><input data-field="base_weight" placeholder="선택" /></td>
      <td><button class="ghost mini row-remove" type="button">삭제</button></td>
    </tr>
  </template>

  <script>
    // Theme toggle
    (function(){
      const root = document.documentElement;
      const stored = localStorage.getItem('werobo-theme');
      const initial = stored === 'dark' || stored === 'light'
        ? stored
        : (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      root.setAttribute('data-theme', initial);
      document.querySelectorAll('[data-theme-set]').forEach(btn => {
        const target = btn.getAttribute('data-theme-set');
        btn.setAttribute('aria-pressed', String(target === initial));
        btn.addEventListener('click', () => {
          root.setAttribute('data-theme', target);
          localStorage.setItem('werobo-theme', target);
          document.querySelectorAll('[data-theme-set]').forEach(b => {
            b.setAttribute('aria-pressed', String(b.getAttribute('data-theme-set') === target));
          });
        });
      });
    })();

    const $ = (selector) => document.querySelector(selector);
    const $$ = (selector) => Array.from(document.querySelectorAll(selector));
    let assetCatalog = [];
    let assetRoleTemplates = [];
    let editingVersionId = null;
    let isRefreshingPrices = false;
    let refreshLoadingTimer = null;
    let refreshLoadingStartedAt = null;
    let refreshLoadingTargetLabel = 'active 버전';

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

    function formatElapsedSeconds(totalSeconds) {
      const seconds = Math.max(0, Math.floor(totalSeconds));
      const minutes = Math.floor(seconds / 60);
      const remainingSeconds = seconds % 60;
      if (minutes <= 0) return `${remainingSeconds}초`;
      return `${minutes}분 ${remainingSeconds}초`;
    }

    function renderRefreshLoadingMessage() {
      if (!refreshLoadingStartedAt) return;
      const elapsedSeconds = (Date.now() - refreshLoadingStartedAt) / 1000;
      const refreshMode = $('#refresh-mode').value;
      showMessage(
        '#refresh-result',
        [
          '가격 갱신 실행 중입니다.',
          `대상: ${refreshLoadingTargetLabel}`,
          `모드: ${refreshMode}`,
          `경과 시간: ${formatElapsedSeconds(elapsedSeconds)}`,
          '중복 실행을 막기 위해 버튼이 잠겨 있습니다.',
        ].join('\\n'),
      );
    }

    function setRefreshLoadingState(isLoading, targetLabel = 'active 버전') {
      isRefreshingPrices = isLoading;
      refreshLoadingTargetLabel = targetLabel;
      $('#refresh-prices').disabled = isLoading;
      $('#refresh-mode').disabled = isLoading;
      $('#lookback-years').disabled = isLoading;
      $$('.version-refresh-btn').forEach((button) => {
        button.disabled = isLoading;
      });

      if (isLoading) {
        refreshLoadingStartedAt = Date.now();
        $('#refresh-prices').textContent = '가격 갱신 중...';
        renderRefreshLoadingMessage();
        refreshLoadingTimer = window.setInterval(renderRefreshLoadingMessage, 1000);
        return;
      }

      $('#refresh-prices').textContent = '가격 갱신 실행';
      refreshLoadingStartedAt = null;
      refreshLoadingTargetLabel = 'active 버전';
      if (refreshLoadingTimer) {
        window.clearInterval(refreshLoadingTimer);
        refreshLoadingTimer = null;
      }
    }

    function buildRefreshResultMessage(result, targetLabel) {
      const snapshotMessage = result.frontier_snapshot
        ? `\\nsnapshot: ${result.frontier_snapshot.status} (${result.frontier_snapshot.snapshot_count})\\nsnapshot message: ${result.frontier_snapshot.message || '-'}`
        : '';
      const comparisonSnapshotMessage = result.comparison_backtest_snapshot
        ? `\\ncomparison snapshot: ${result.comparison_backtest_snapshot.status} (${result.comparison_backtest_snapshot.snapshot_count})\\ncomparison snapshot message: ${result.comparison_backtest_snapshot.message || '-'}`
        : '';
      return `갱신 완료\\n대상: ${targetLabel}\\njob: ${result.job.status}\\nmessage: ${result.job.message || '-'}\\nrows: ${result.price_stats.total_rows}${snapshotMessage}${comparisonSnapshotMessage}`;
    }

    function normalizeTicker(value) {
      return (value || '').trim().toUpperCase();
    }

    function defaultAssetRoleMap() {
      return Object.fromEntries(assetCatalog.map((asset) => [asset.code, asset.role_key]));
    }

    function defaultSeedRows() {
      return [
        {
          ticker: 'QQQ',
          name: 'Invesco QQQ Trust',
          sector_code: 'us_growth',
          sector_name: '미국 성장주',
          market: 'NASDAQ',
          currency: 'USD',
        },
        {
          ticker: 'SHY',
          name: 'iShares 1-3 Year Treasury Bond ETF',
          sector_code: 'short_term_bond',
          sector_name: '단기 채권',
          market: 'NASDAQ',
          currency: 'USD',
        },
      ];
    }

    function collectCurrentAssetRoleMap() {
      const entries = $$('#asset-role-config [data-role-select]').map((select) => [
        select.getAttribute('data-role-select'),
        select.value,
      ]);
      return Object.fromEntries(entries);
    }

    function findAssetByCode(assetCode) {
      return assetCatalog.find((asset) => asset.code === assetCode) || null;
    }

    function buildAssetSelectOptions(selectedCode = '') {
      if (!assetCatalog.length) {
        return '<option value="">자산군 불러오는 중</option>';
      }

      const fallbackCode = selectedCode || assetCatalog[0]?.code || '';
      return assetCatalog.map((asset) => `
        <option value="${asset.code}" ${asset.code === fallbackCode ? 'selected' : ''}>
          ${asset.name} (${asset.code})
        </option>
      `).join('');
    }

    function syncRowAssetSelection(row, preferredCode = '', preferredName = '') {
      const sectorCodeSelect = row.querySelector('select[data-field="sector_code"]');
      const sectorNameInput = row.querySelector('[data-field="sector_name"]');
      if (!sectorCodeSelect || !sectorNameInput) return;

      const currentCode = preferredCode || sectorCodeSelect.value || sectorCodeSelect.dataset.selectedCode || '';
      sectorCodeSelect.innerHTML = buildAssetSelectOptions(currentCode);
      const resolvedCode = sectorCodeSelect.value || currentCode;
      const asset = findAssetByCode(resolvedCode);
      sectorNameInput.value = asset ? asset.name : preferredName || '';
      sectorCodeSelect.dataset.selectedCode = resolvedCode;
    }

    function syncAllInstrumentAssetSelections() {
      $$('#instrument-body tr').forEach((row) => {
        const sectorCodeSelect = row.querySelector('select[data-field="sector_code"]');
        const sectorNameInput = row.querySelector('[data-field="sector_name"]');
        syncRowAssetSelection(
          row,
          sectorCodeSelect?.value || sectorCodeSelect?.dataset.selectedCode || '',
          sectorNameInput?.value || '',
        );
      });
    }

    function findRoleTemplate(roleKey) {
      return assetRoleTemplates.find((item) => item.key === roleKey) || null;
    }

    function updateRoleCardDescription(card, roleKey) {
      const template = findRoleTemplate(roleKey);
      const setSpec = (field, value) => {
        const dd = card.querySelector(`[data-spec="${field}"]`);
        if (!dd) return;
        if (value) {
          dd.textContent = value;
          dd.classList.remove('is-empty');
        } else {
          dd.textContent = '—';
          dd.classList.add('is-empty');
        }
      };
      const note = card.querySelector('.asset-role-note');
      if (template) {
        setSpec('key', template.key);
        setSpec('sel', template.selection_mode);
        setSpec('wgt', template.weighting_mode);
        setSpec('ret', template.return_mode);
        note.textContent = template.description || '';
        note.style.display = template.description ? '' : 'none';
      } else {
        setSpec('key', '');
        setSpec('sel', '');
        setSpec('wgt', '');
        setSpec('ret', '');
        note.textContent = '선택한 role 정보를 찾을 수 없습니다.';
        note.style.display = '';
      }
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
            ${template.name}
          </option>
        `).join('');
        return `
          <div class="asset-role-card" data-asset-code="${asset.code}">
            <div class="asset-role-head">
              <span class="asset-role-name">${asset.name}</span>
              <span class="asset-role-code">${asset.code}</span>
            </div>
            <select data-role-select="${asset.code}">
              ${options}
            </select>
            <dl class="asset-role-spec">
              <div class="asset-role-spec-row"><dt>KEY</dt><dd data-spec="key"></dd></div>
              <div class="asset-role-spec-row"><dt>SEL</dt><dd data-spec="sel"></dd></div>
              <div class="asset-role-spec-row"><dt>WGT</dt><dd data-spec="wgt"></dd></div>
              <div class="asset-role-spec-row"><dt>RET</dt><dd data-spec="ret"></dd></div>
            </dl>
            <p class="asset-role-note"></p>
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

    function clearInstrumentRows() {
      $('#instrument-body').innerHTML = '';
    }

    function seedDefaultInstrumentRows() {
      clearInstrumentRows();
      defaultSeedRows().forEach((item) => addInstrumentRow(item));
    }

    function enterCreateMode() {
      editingVersionId = null;
      $('#version-form-title').textContent = '새 유니버스 버전 생성';
      $('#version-form-helper').textContent = '종목명 검색 또는 티커 자동채움으로 종목을 등록하고 새 버전을 만들 수 있습니다.';
      $('#submit-version').textContent = '버전 생성';
      $('#cancel-edit').style.display = 'none';
      hideMessage('#form-mode-banner');
      $('#version-name').value = '';
      $('#version-notes').value = '';
      $('#version-activate').checked = true;
      renderAssetRoleSelectors(defaultAssetRoleMap());
      seedDefaultInstrumentRows();
    }

    function enterEditMode(detail) {
      editingVersionId = detail.version_id;
      $('#version-form-title').textContent = '유니버스 버전 수정';
      $('#version-form-helper').textContent = '기존 버전의 종목 구성과 자산군별 role을 수정한 뒤 다시 저장할 수 있습니다.';
      $('#submit-version').textContent = '버전 수정';
      $('#cancel-edit').style.display = 'inline-flex';
      showMessage(
        '#form-mode-banner',
        `현재 ID ${detail.version_id} · ${detail.version_name} 수정 중입니다.\n저장하면 이 버전의 종목 구성과 자산군 role 스냅샷이 교체됩니다.`,
      );
      $('#version-name').value = detail.version_name || '';
      $('#version-notes').value = detail.notes || '';
      $('#version-activate').checked = Boolean(detail.is_active);
      const selectedRoleMap = Object.fromEntries(
        (detail.asset_roles || []).map((item) => [item.asset_code, item.role_key]),
      );
      renderAssetRoleSelectors(selectedRoleMap);
      clearInstrumentRows();
      (detail.instruments || []).forEach((item) => addInstrumentRow(item));
      if (!(detail.instruments || []).length) {
        addInstrumentRow();
      }
      window.scrollTo({ top: 0, behavior: 'smooth' });
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
      const sectorCodeSelect = row.querySelector('select[data-field="sector_code"]');
      if (sectorCodeSelect) {
        sectorCodeSelect.dataset.selectedCode = seed.sector_code || '';
        syncRowAssetSelection(row, seed.sector_code || '', seed.sector_name || '');
        sectorCodeSelect.addEventListener('change', () => {
          syncRowAssetSelection(row, sectorCodeSelect.value);
        });
      }
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
        row.querySelectorAll('input[data-field], select[data-field]').forEach((field) => {
          const key = field.dataset.field;
          const raw = (field.value || '').trim();
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
      $('#price-row-count').textContent = status.price_stats ? Number(status.price_stats.total_rows).toLocaleString() : '—';
      $('#aligned-start-date').textContent = status.price_window?.aligned_start_date || '—';

      const window = status.price_window
        ? `${status.price_window.aligned_start_date || '—'} → ${status.price_window.aligned_end_date || '—'}`
        : '없음';
      const latest = status.latest_refresh_job
        ? `${status.latest_refresh_job.status} · ${status.latest_refresh_job.message || '메시지 없음'}`
        : '없음';

      const detail = [
        `active : ${status.active_version ? status.active_version.version_name : '없음'}`,
        `window : ${window}`,
      ].join('\\n');
      showMessage('#status-detail', detail, false);

      const log = [
        `latest  : ${latest}`,
        `db      : ${status.database_configured ? 'connected' : 'not configured'}`,
      ].join('\\n');
      showMessage('#status-log', log, false);
    }

    function formatVersionTimestamp(iso) {
      if (!iso) return { date: '—', time: '' };
      const match = String(iso).match(/^(\\d{4}-\\d{2}-\\d{2})[T ](\\d{2}:\\d{2})/);
      if (!match) return { date: String(iso), time: '' };
      return { date: match[1], time: match[2] };
    }

    function escapeHtml(value) {
      return String(value).replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
      }[c]));
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
        wrap.dataset.versionId = String(version.version_id);
        const stamp = formatVersionTimestamp(version.created_at);
        const memoHtml = version.notes
          ? `<p class="version-memo">${escapeHtml(version.notes)}</p>`
          : '';
        wrap.innerHTML = `
          <div class="version-head">
            <div class="version-title">
              <strong>${escapeHtml(version.version_name)}</strong>
            </div>
            <div>${version.is_active ? '<span class="pill ok">Active</span>' : '<span class="pill warn">Inactive</span>'}</div>
          </div>
          <dl class="version-stats">
            <div class="version-stat">
              <dt>ID</dt>
              <dd>#${version.version_id}</dd>
            </div>
            <div class="version-stat">
              <dt>Holdings</dt>
              <dd>${version.instrument_count}<span class="unit">종목</span></dd>
            </div>
            <div class="version-stat">
              <dt>Created</dt>
              <dd>${stamp.date}${stamp.time ? `<span class="unit">${stamp.time} UTC</span>` : ''}</dd>
            </div>
          </dl>
          ${memoHtml}
          <div class="actions">
            <button class="secondary mini detail-btn" aria-expanded="false">상세</button>
            <button class="secondary mini edit-btn">수정</button>
            <button class="secondary mini activate-btn">활성화</button>
            <button class="secondary mini version-refresh-btn">리프레시</button>
            <button class="danger mini delete-btn">삭제</button>
          </div>
          <div class="version-detail-panel"><div class="panel-inner"></div></div>
        `;
        wrap.querySelector('.detail-btn').addEventListener('click', () => loadVersionDetail(version.version_id));
        wrap.querySelector('.edit-btn').addEventListener('click', () => startEditVersion(version.version_id));
        wrap.querySelector('.activate-btn').addEventListener('click', () => activateVersion(version.version_id));
        wrap.querySelector('.version-refresh-btn').addEventListener('click', () => refreshPrices(version.version_id, version.version_name));
        wrap.querySelector('.delete-btn').addEventListener('click', () => deleteVersion(version.version_id));
        host.appendChild(wrap);
      });
    }

    function renderVersionDetail(detail, host) {
      const roleRows = (detail.asset_roles || []).map((item) => `
        <tr>
          <td>${item.asset_name}</td>
          <td><span class="mono">${item.asset_code}</span></td>
          <td>${item.role_name}</td>
          <td><span class="mono">${item.role_key}</span></td>
          <td><span class="mono">${item.selection_mode}</span></td>
          <td><span class="mono">${item.weighting_mode}</span></td>
          <td><span class="mono">${item.return_mode}</span></td>
        </tr>
      `).join('');
      const rows = detail.instruments.map((item) => `
        <tr>
          <td><span class="mono" style="color:var(--accent); font-weight:600;">${item.ticker}</span></td>
          <td>${item.name}</td>
          <td><span class="mono">${item.sector_code}</span></td>
          <td>${item.sector_name}</td>
          <td>${item.market}</td>
          <td><span class="mono">${item.currency}</span></td>
          <td><span class="mono">${item.base_weight ?? '—'}</span></td>
        </tr>
      `).join('');
      host.innerHTML = `
        <div class="notice">
          <strong style="color:var(--fg); font-family:var(--font-ui);">${detail.version_name}</strong>  ·  종목 ${detail.instrument_count}개  ·  ${detail.is_active ? '<span class="pill ok" style="margin-left:6px;">Active</span>' : '<span class="pill warn" style="margin-left:6px;">Inactive</span>'}
        </div>
        <div class="detail-section-label">Asset Roles</div>
        <div class="detail-table-wrap">
          <table>
            <thead>
              <tr>
                <th>자산군 이름</th>
                <th>자산군 코드</th>
                <th>role 이름</th>
                <th>role key</th>
                <th>selection</th>
                <th>weighting</th>
                <th>return</th>
              </tr>
            </thead>
            <tbody>${roleRows}</tbody>
          </table>
        </div>
        <div class="detail-section-label">Instruments</div>
        <div class="detail-table-wrap">
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
        </div>
      `;
    }

    function renderReadiness(readiness) {
      const host = $('#readiness-panel');
      const issues = readiness.issues.length
        ? '<ul class="readiness-list">' + readiness.issues.map((item) => `<li>${item}</li>`).join('') + '</ul>'
        : '<div style="color:var(--fg-3);">문제 없음</div>';
      const shortHistory = readiness.short_history_instruments.length
        ? '<ul class="readiness-list">' + readiness.short_history_instruments.map((item) => `<li>${item.ticker} · ${item.history_years}년 · ${item.first_price_date || '-'} ~ ${item.last_price_date || '-'}</li>`).join('') + '</ul>'
        : '<div style="color:var(--fg-3);">짧은 이력 종목 없음</div>';
      host.innerHTML = `
        <strong style="color:var(--fg); font-family:var(--font-ui);">${readiness.ready ? '준비 완료' : '준비 미완료'}</strong>
        <div style="margin-top:6px;">${readiness.summary}</div>
        <div style="margin-top:10px;"><strong style="font-family:var(--font-mono); font-size:var(--text-2xs); text-transform:uppercase; letter-spacing:0.12em; color:var(--fg-3);">이슈</strong>${issues}</div>
        <div style="margin-top:10px;"><strong style="font-family:var(--font-mono); font-size:var(--text-2xs); text-transform:uppercase; letter-spacing:0.12em; color:var(--fg-3);">짧은 이력 종목</strong>${shortHistory}</div>
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
      const currentRoleMap = collectCurrentAssetRoleMap();
      const config = await requestJson('/admin/api/universe/asset-role-config');
      assetCatalog = config.assets || [];
      assetRoleTemplates = config.role_templates || [];
      const selectedMap = editingVersionId && Object.keys(currentRoleMap).length
        ? currentRoleMap
        : defaultAssetRoleMap();
      renderAssetRoleSelectors(selectedMap);
      syncAllInstrumentAssetSelections();
    }

    function collapseAllDetailPanels(exceptItem = null) {
      document.querySelectorAll('.version-item.detail-open').forEach((el) => {
        if (el === exceptItem) return;
        el.classList.remove('detail-open');
        el.querySelector('.version-detail-panel').classList.remove('open');
        const btn = el.querySelector('.detail-btn');
        btn.textContent = '상세';
        btn.setAttribute('aria-expanded', 'false');
      });
    }

    async function loadVersionDetail(versionId) {
      const item = document.querySelector(`.version-item[data-version-id="${versionId}"]`);
      if (!item) return;
      const panel = item.querySelector('.version-detail-panel');
      const inner = panel.querySelector('.panel-inner');
      const btn = item.querySelector('.detail-btn');
      const wasOpen = panel.classList.contains('open');

      collapseAllDetailPanels(item);

      if (wasOpen) {
        panel.classList.remove('open');
        item.classList.remove('detail-open');
        btn.textContent = '상세';
        btn.setAttribute('aria-expanded', 'false');
        return;
      }

      panel.classList.add('open');
      item.classList.add('detail-open');
      btn.textContent = '접기';
      btn.setAttribute('aria-expanded', 'true');
      inner.innerHTML = '<div class="notice">로딩 중...</div>';

      try {
        const detail = await requestJson(`/admin/api/universe/versions/${versionId}`);
        renderVersionDetail(detail, inner);
        requestAnimationFrame(() => panel.scrollIntoView({ block: 'nearest', behavior: 'smooth' }));
      } catch (err) {
        inner.innerHTML = `<div class="error">상세 정보를 불러오지 못했습니다: ${err.message || err}</div>`;
      }
    }

    async function startEditVersion(versionId) {
      hideMessage('#create-result');
      hideMessage('#create-error');
      const detail = await requestJson(`/admin/api/universe/versions/${versionId}`);
      enterEditMode(detail);
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
      await reloadAll();
    }

    async function submitVersionForm() {
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
        const isEditMode = editingVersionId !== null;
        const url = isEditMode
          ? `/admin/api/universe/versions/${editingVersionId}`
          : '/admin/api/universe/versions';
        const method = isEditMode ? 'PUT' : 'POST';
        const result = await requestJson(url, {
          method,
          body: JSON.stringify(payload),
        });
        showMessage(
          '#create-result',
          isEditMode
            ? `버전 수정 완료: ${result.version_name} (ID ${result.version_id})`
            : `버전 생성 완료: ${result.version_name} (ID ${result.version_id})`,
        );
        enterCreateMode();
        await reloadAll();
        await loadVersionDetail(result.version_id);
      } catch (error) {
        showMessage('#create-error', error.message, true);
      }
    }

    async function refreshPrices(versionId = null, targetLabel = 'active 버전') {
      if (isRefreshingPrices) return;
      hideMessage('#refresh-result');
      if (!confirm(`"${targetLabel}" 기준으로 가격 갱신과 snapshot 재생성을 실행할까요?`)) return;
      setRefreshLoadingState(true, targetLabel);
      try {
        const payload = {
          version_id: versionId,
          refresh_mode: $('#refresh-mode').value,
          full_lookback_years: Number($('#lookback-years').value || '5'),
        };
        const result = await requestJson('/admin/api/prices/refresh', {
          method: 'POST',
          body: JSON.stringify(payload),
        });
        showMessage('#refresh-result', buildRefreshResultMessage(result, targetLabel));
        await reloadAll();
      } catch (error) {
        showMessage('#refresh-result', error.message, true);
      } finally {
        setRefreshLoadingState(false);
      }
    }

    async function reloadAll() {
      await Promise.all([loadStatus(), loadVersions(), loadAssetRoleConfig()]);
    }

    $('#reload-all').addEventListener('click', reloadAll);
    $('#add-row').addEventListener('click', () => addInstrumentRow());
    $('#reset-asset-roles').addEventListener('click', () => {
      if (editingVersionId !== null) return;
      renderAssetRoleSelectors(defaultAssetRoleMap());
    });
    $('#submit-version').addEventListener('click', submitVersionForm);
    $('#cancel-edit').addEventListener('click', enterCreateMode);
    $('#refresh-prices').addEventListener('click', refreshPrices);
    $('#load-readiness').addEventListener('click', loadReadiness);
    seedDefaultInstrumentRows();
    reloadAll().catch((error) => {
      showMessage('#status-detail', error.message, true);
      showMessage('#version-list', error.message, true);
    });
  </script>
</body>
</html>"""
    return HTMLResponse(content=html)
