from fastapi.responses import HTMLResponse


def render_admin_comparison_page() -> HTMLResponse:
    html = """<!DOCTYPE html>
<html lang="ko" data-theme="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Comparison Board / WeRobo Admin</title>
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

      /* Light — cool paper, TradingView cobalt accent */
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
      --shadow-lg: 0 8px 24px oklch(40% 0.020 255 / 0.12), 0 2px 6px oklch(40% 0.020 255 / 0.08);

      /* Chart colors */
      --chart-grid: oklch(91% 0.010 255);
      --chart-axis: oklch(58% 0.016 255);
      --chart-tip-bg: oklch(100% 0 0);
      --chart-tip-border: oklch(85% 0.012 255);
      --chart-tip-fg: oklch(22% 0.018 255);
      --chart-tip-muted: oklch(50% 0.017 255);
      --chart-frontier: oklch(56% 0.22 260);
      --chart-rep: oklch(64% 0.19 260);
      --chart-selected: oklch(22% 0.018 255);
      --chart-selected-stroke: oklch(100% 0 0);
      --chart-selected-halo: oklch(56% 0.22 260 / 0.24);
      --chart-mu: oklch(52% 0.19 28);
      --chart-portfolio: oklch(22% 0.018 255);
      --chart-zero: oklch(60% 0.016 255);
      --chart-muted-line: oklch(72% 0.012 255);

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
      --shadow-lg: 0 10px 28px oklch(4% 0 0 / 0.60), 0 2px 8px oklch(4% 0 0 / 0.45);

      --chart-grid: oklch(26% 0.018 255);
      --chart-axis: oklch(62% 0.017 255);
      --chart-tip-bg: oklch(22.5% 0.018 255);
      --chart-tip-border: oklch(36% 0.021 255);
      --chart-tip-fg: oklch(94% 0.008 255);
      --chart-tip-muted: oklch(70% 0.014 255);
      --chart-frontier: oklch(72% 0.18 260);
      --chart-rep: oklch(80% 0.15 260);
      --chart-selected: oklch(96% 0.008 255);
      --chart-selected-stroke: oklch(19% 0.017 255);
      --chart-selected-halo: oklch(70% 0.18 260 / 0.32);
      --chart-mu: oklch(72% 0.19 28);
      --chart-portfolio: oklch(96% 0.008 255);
      --chart-zero: oklch(52% 0.017 255);
      --chart-muted-line: oklch(42% 0.017 255);

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

    /* Top rail */
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
    .rail-nav { display: inline-flex; align-items: center; gap: var(--sp-4); }
    .rail-nav a {
      color: var(--fg-2);
      text-decoration: none;
      font-family: var(--font-mono);
      font-size: var(--text-xs);
      padding: 3px 6px;
      border-radius: var(--r-1);
      transition: background 120ms;
    }
    .rail-nav a[aria-current="page"] { color: var(--fg); background: var(--surface-3); }
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

    .shell {
      max-width: 1520px;
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

    /* Buttons */
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
      cursor: pointer;
      transition: background 120ms, border-color 120ms;
    }
    button:hover:not(:disabled) { background: var(--accent-hover); border-color: var(--accent-hover); }
    button:disabled { opacity: 0.55; cursor: not-allowed; }
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
    button.mini {
      padding: 5px 9px;
      font-size: var(--text-2xs);
      border-radius: var(--r-1);
      letter-spacing: 0.04em;
    }

    /* Card */
    .card {
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      padding: var(--sp-4) var(--sp-5);
      margin-bottom: var(--sp-4);
    }
    .card-head {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      gap: var(--sp-3);
      margin-bottom: var(--sp-3);
    }
    .card-head h2 {
      margin: 0;
      font-size: var(--text-lg);
      font-weight: 600;
    }
    .card-head .eyebrow {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.14em;
    }
    .helper {
      margin: 0 0 var(--sp-3);
      color: var(--fg-3);
      font-size: var(--text-sm);
      max-width: 72ch;
    }

    /* Snapshot picker */
    .snapshot-bar {
      display: flex;
      align-items: center;
      gap: var(--sp-2);
      flex-wrap: wrap;
    }
    .snapshot-picker { position: relative; }
    .snapshot-trigger {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      background: var(--surface);
      color: var(--fg);
      border: 1px solid var(--line-2);
      min-width: 280px;
      max-width: 460px;
      justify-content: space-between;
      font-weight: 500;
      padding: 8px 12px;
      font-size: var(--text-sm);
    }
    .snapshot-trigger:hover:not(:disabled) { background: var(--surface); border-color: var(--line-3); }
    .snapshot-trigger .snapshot-current {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .snapshot-trigger.dirty .snapshot-current::after {
      content: ' •';
      color: var(--warn);
      font-weight: 700;
    }
    .snapshot-trigger .caret {
      color: var(--fg-3);
      font-size: 10px;
      font-family: var(--font-mono);
    }
    .snapshot-panel {
      position: absolute;
      left: 0;
      top: calc(100% + 6px);
      width: 560px;
      max-width: 92vw;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      box-shadow: var(--shadow-lg);
      z-index: 30;
      padding: var(--sp-3);
      display: flex;
      flex-direction: column;
      gap: var(--sp-2);
    }
    .snapshot-panel[hidden] { display: none; }
    .snapshot-panel-head {
      display: grid;
      grid-template-columns: 1fr 180px;
      gap: var(--sp-2);
    }
    .snapshot-panel-head input,
    .snapshot-panel-head select {
      width: 100%;
      border: 1px solid var(--line-2);
      border-radius: var(--r-2);
      padding: 7px 10px;
      font: inherit;
      font-size: var(--text-sm);
      background: var(--surface);
      color: var(--fg);
    }
    .snapshot-panel-head input:focus,
    .snapshot-panel-head select:focus {
      outline: 0;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-soft);
    }
    .snapshot-panel-filters {
      display: flex;
      gap: var(--sp-2);
      flex-wrap: wrap;
    }
    .snapshot-panel-filters details {
      flex: 1;
      min-width: 200px;
      border: 1px solid var(--line);
      border-radius: var(--r-2);
      background: var(--surface-2);
    }
    .snapshot-panel-filters summary {
      list-style: none;
      cursor: pointer;
      padding: 7px 11px;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      user-select: none;
    }
    .snapshot-panel-filters summary::-webkit-details-marker { display: none; }
    .snapshot-panel-filters summary::after { content: ' ▾'; color: var(--fg-4); }
    .snapshot-panel-filters details[open] summary::after { content: ' ▴'; }
    .filter-options {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
      padding: 0 10px 10px;
    }
    .filter-chip {
      display: inline-flex;
      align-items: center;
      padding: 3px 8px;
      border: 1px solid var(--line-2);
      border-radius: 999px;
      background: var(--surface);
      font-size: var(--text-2xs);
      font-family: var(--font-mono);
      cursor: pointer;
      color: var(--fg-3);
      user-select: none;
      letter-spacing: 0.02em;
    }
    .filter-chip.on {
      background: var(--accent-soft);
      border-color: var(--accent);
      color: var(--accent);
      font-weight: 600;
    }
    .snapshot-results {
      max-height: 420px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .snapshot-folder {
      display: block;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      font-weight: 500;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      padding: 10px 8px 2px;
    }
    .snapshot-row {
      display: flex;
      gap: 10px;
      align-items: flex-start;
      padding: 9px 11px;
      border-radius: var(--r-2);
      cursor: pointer;
      border: 1px solid transparent;
      transition: background 100ms;
    }
    .snapshot-row:hover { background: var(--surface-3); }
    .snapshot-row.active {
      background: var(--accent-soft);
      border-color: color-mix(in oklab, var(--accent) 45%, transparent);
    }
    .snapshot-row-body { flex: 1; min-width: 0; }
    .snapshot-row-name {
      font-size: var(--text-sm);
      font-weight: 500;
      color: var(--fg);
      margin-bottom: 2px;
    }
    .snapshot-row-meta {
      font-size: var(--text-2xs);
      font-family: var(--font-mono);
      color: var(--fg-3);
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    .snapshot-row-universes {
      margin-top: 5px;
      display: flex;
      gap: 4px;
      flex-wrap: wrap;
    }
    .universe-tag {
      display: inline-block;
      padding: 1px 6px;
      background: var(--surface-3);
      color: var(--fg-2);
      font-size: var(--text-2xs);
      font-family: var(--font-mono);
      border-radius: var(--r-1);
      font-weight: 500;
      letter-spacing: 0.02em;
    }
    .snapshot-row-actions { display: flex; gap: 4px; }
    .snapshot-row-actions button {
      padding: 3px 7px;
      font-size: var(--text-2xs);
      border: 1px solid var(--line-2);
      background: var(--surface);
      color: var(--fg-3);
      border-radius: var(--r-1);
    }
    .snapshot-row-actions button:hover {
      color: var(--neg);
      border-color: var(--neg);
      background: var(--neg-soft);
    }
    .snapshot-results-empty {
      padding: 24px;
      text-align: center;
      color: var(--fg-3);
      font-size: var(--text-sm);
      font-family: var(--font-mono);
    }

    /* Save modal */
    .modal-backdrop {
      position: fixed;
      inset: 0;
      background: oklch(4% 0 0 / 0.52);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 50;
      backdrop-filter: blur(2px);
    }
    .modal-backdrop[hidden] { display: none; }
    .modal-card {
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      padding: var(--sp-5);
      width: 440px;
      max-width: 92vw;
      box-shadow: var(--shadow-lg);
    }
    .modal-card h3 {
      margin: 0 0 var(--sp-4);
      font-size: var(--text-lg);
      font-weight: 600;
    }
    .modal-card .field { margin-bottom: var(--sp-3); }
    .modal-card label {
      display: block;
      margin-bottom: 4px;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.1em;
    }
    .modal-card input {
      width: 100%;
      border: 1px solid var(--line-2);
      border-radius: var(--r-2);
      padding: 8px 11px;
      font: inherit;
      font-size: var(--text-sm);
      background: var(--surface);
      color: var(--fg);
    }
    .modal-card input:focus {
      outline: 0;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-soft);
    }
    .modal-actions {
      display: flex;
      justify-content: flex-end;
      gap: var(--sp-2);
      margin-top: var(--sp-4);
    }

    /* Board controls */
    .board-toolbar {
      display: flex;
      align-items: end;
      justify-content: space-between;
      gap: var(--sp-3);
      margin-top: var(--sp-4);
      padding-top: var(--sp-4);
      border-top: 1px solid var(--line);
    }
    .board-toolbar .field {
      min-width: 210px;
      max-width: 260px;
    }

    /* Frontier grid */
    .graph-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(260px, 1fr));
      gap: var(--sp-4);
      margin-bottom: var(--sp-4);
    }
    .graph-set {
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      padding: var(--sp-4);
    }
    .graph-set-head {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: var(--sp-2);
      margin-bottom: var(--sp-3);
    }
    .graph-set-head .title-input {
      flex: 1;
      border: 1px solid transparent;
      background: transparent;
      color: var(--fg);
      font: inherit;
      font-size: var(--text-lg);
      font-weight: 600;
      letter-spacing: -0.005em;
      padding: 5px 8px;
      margin-left: -8px;
      border-radius: var(--r-2);
    }
    .graph-set-head .title-input:focus {
      outline: 0;
      border-color: var(--line-2);
      background: var(--surface-2);
    }
    .graph-set-actions {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      flex-shrink: 0;
    }
    .btn-toggle[aria-pressed="true"] {
      color: var(--pos);
      border-color: color-mix(in oklab, var(--pos) 35%, var(--line-2));
      background: var(--pos-soft);
    }
    .btn-toggle[aria-pressed="false"] {
      color: var(--fg-3);
    }

    .controls {
      display: grid;
      grid-template-columns: 1fr;
      gap: var(--sp-2);
      margin-bottom: var(--sp-3);
    }
    .field { display: flex; flex-direction: column; gap: 5px; }
    .field label {
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.1em;
      font-weight: 500;
    }
    .field input, .field select {
      width: 100%;
      border: 1px solid var(--line-2);
      border-radius: var(--r-2);
      padding: 7px 10px;
      font: inherit;
      font-size: var(--text-sm);
      background: var(--surface);
      color: var(--fg);
      transition: border-color 120ms, box-shadow 120ms;
    }
    .field input:focus, .field select:focus {
      outline: 0;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-soft);
    }

    .chart-block {
      position: relative;
      border: 1px solid var(--line);
      border-radius: var(--r-2);
      background: var(--surface-2);
      padding: var(--sp-3);
      min-width: 0;
    }
    .chart-title {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      font-family: var(--font-mono);
      font-size: var(--text-2xs);
      color: var(--fg-3);
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin-bottom: 8px;
    }
    .chart-title strong {
      color: var(--fg);
      font-size: var(--text-sm);
      font-weight: 600;
      font-family: var(--font-ui);
      letter-spacing: 0;
      text-transform: none;
    }
    .chart-svg {
      width: 100%;
      height: 360px;
      display: block;
      cursor: crosshair;
      touch-action: none;
    }
    .frontier-svg { height: 280px; }
    .chart-svg.dragging { cursor: grabbing; }
    .profit-svg { height: clamp(400px, 34vw, 520px); cursor: crosshair; }

    .backtest-panel {
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: var(--r-3);
      padding: var(--sp-4);
    }
    .backtest-toolbar {
      display: flex;
      align-items: end;
      justify-content: space-between;
      gap: var(--sp-3);
      margin-bottom: var(--sp-3);
    }
    .backtest-picker {
      width: min(320px, 100%);
    }
    .backtest-actions {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 8px;
      flex-wrap: wrap;
    }
    .mode-tabs {
      display: inline-flex;
      gap: 4px;
      padding: 3px;
      border: 1px solid var(--line);
      border-radius: var(--r-2);
      background: var(--surface-2);
    }
    .mode-tabs button {
      background: transparent;
      color: var(--fg-2);
      border-color: transparent;
      min-width: 64px;
    }
    .mode-tabs button[aria-pressed="true"] {
      background: var(--accent);
      color: var(--accent-fg);
      border-color: var(--accent);
    }
    .contribution-toggle {
      min-width: 74px;
      background: var(--surface-2);
      color: var(--fg-2);
      border-color: var(--line);
    }
    .contribution-toggle[aria-pressed="true"] {
      background: var(--fg);
      color: var(--surface);
      border-color: var(--fg);
    }
    .contribution-toggle[hidden] {
      display: none;
    }
    .backtest-chart {
      min-height: 520px;
    }

    .chart-hover-legend {
      position: absolute;
      top: 42px;
      left: 22px;
      font-family: var(--font-mono);
      font-size: 10.5px;
      line-height: 1.45;
      pointer-events: none;
      background: color-mix(in oklab, var(--surface-2) 88%, transparent);
      border: 1px solid var(--line-2);
      border-radius: var(--r-2);
      padding: 8px 10px;
      min-width: 200px;
      max-width: 260px;
      opacity: 0;
      transition: opacity 80ms ease-out;
      backdrop-filter: blur(3px);
      z-index: 2;
    }
    .chart-hover-legend[data-visible="true"] { opacity: 1; }
    .chart-hover-legend .hl-date {
      font-size: 10px;
      color: var(--fg-3);
      letter-spacing: 0.1em;
      margin-bottom: 5px;
      text-transform: uppercase;
    }
    .chart-hover-legend .hl-total {
      display: block;
      color: var(--fg-2);
      letter-spacing: 0;
      margin-top: 2px;
      text-transform: none;
    }
    .chart-hover-legend .hl-row {
      display: grid;
      grid-template-columns: 14px 1fr auto;
      gap: 6px;
      align-items: center;
      color: var(--fg-2);
      padding: 1px 0;
    }
    .chart-hover-legend .hl-row.muted { opacity: 0.4; }
    .chart-hover-legend .hl-row.portfolio { color: var(--fg); font-weight: 600; }
    .chart-hover-legend .hl-dot {
      width: 12px;
      height: 2px;
      border-radius: 1px;
      display: inline-block;
    }
    .chart-hover-legend .hl-dot.dashed {
      background-image: repeating-linear-gradient(to right, currentColor 0 3px, transparent 3px 6px) !important;
    }
    .chart-hover-legend .hl-label {
      font-family: var(--font-ui);
      font-size: 11px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .chart-hover-legend .hl-val {
      font-weight: 600;
      color: var(--fg);
      font-variant-numeric: tabular-nums;
    }
    .chart-hover-legend .hl-subval {
      color: var(--fg-3);
      font-size: 9.5px;
      font-weight: 500;
      margin-left: 4px;
    }
    .chart-hover-legend .hl-val.neg { color: var(--neg); }
    .chart-hover-legend .hl-val.pos { color: var(--pos); }

    .legend {
      display: flex;
      flex-wrap: wrap;
      gap: 6px 12px;
      margin-top: var(--sp-2);
      font-size: var(--text-2xs);
      font-family: var(--font-mono);
      color: var(--fg-3);
    }
    .legend-item {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      cursor: pointer;
      user-select: none;
      padding: 2px 5px;
      border-radius: var(--r-1);
      transition: background 100ms;
      letter-spacing: 0.02em;
    }
    .legend-item:hover { background: var(--surface-3); }
    .legend-item.muted { opacity: 0.35; }
    .legend-item.muted .legend-swatch { background: var(--chart-muted-line) !important; }
    .legend-swatch {
      width: 14px;
      height: 3px;
      border-radius: 1px;
      display: inline-block;
    }
    .legend-swatch.dashed {
      background: repeating-linear-gradient(
        to right, currentColor 0 4px, transparent 4px 8px
      );
    }

    .selection-summary {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      font-size: var(--text-2xs);
      font-family: var(--font-mono);
      color: var(--fg-2);
      margin-top: var(--sp-2);
      align-items: center;
    }
    .selection-summary .summary-item {
      display: inline-flex;
      align-items: center;
      gap: 5px;
    }
    .selection-summary .pill {
      background: var(--surface-3);
      color: var(--fg-3);
      padding: 2px 7px;
      border-radius: var(--r-1);
      font-weight: 600;
      font-size: var(--text-2xs);
      letter-spacing: 0.04em;
      text-transform: uppercase;
    }
    .selection-summary .summary-value {
      color: var(--fg);
      font-weight: 500;
    }
    .selection-summary .summary-sep {
      width: 1px;
      height: 11px;
      background: var(--line-2);
      margin: 0 2px;
    }

    .empty-state {
      padding: 40px 28px;
      text-align: center;
      color: var(--fg-3);
      font-size: var(--text-sm);
      border: 1px dashed var(--line-2);
      border-radius: var(--r-3);
      background: var(--surface-2);
    }
    .err {
      background: var(--neg-soft);
      color: var(--neg);
      border: 1px solid color-mix(in oklab, var(--neg) 30%, var(--line));
      border-radius: var(--r-2);
      padding: 8px 12px;
      font-size: var(--text-xs);
      font-family: var(--font-mono);
      margin-top: 8px;
    }
    .loading {
      color: var(--fg-3);
      font-family: var(--font-mono);
      font-size: var(--text-xs);
      padding: 6px 10px;
    }

    @media (max-width: 980px) {
      .graph-grid { grid-template-columns: 1fr; }
      .controls { grid-template-columns: 1fr; }
      .board-toolbar, .backtest-toolbar { align-items: stretch; flex-direction: column; }
      .board-toolbar .field, .backtest-picker { width: 100%; max-width: none; }
      .backtest-actions { justify-content: flex-start; }
      .rail { padding: 10px var(--sp-4); flex-wrap: wrap; }
      .shell { padding: var(--sp-4); }
    }
  </style>
</head>
<body>
  <div class="rail">
    <span class="rail-brand">
      <span class="mark"></span>
      <span>WEROBO</span>
      <span class="slash">/</span>
      <span class="section">COMPARISON</span>
    </span>
    <nav class="rail-nav">
      <a href="/admin">관리</a>
      <a href="/admin/comparison" aria-current="page">비교 보드</a>
    </nav>
    <div class="theme-toggle" role="group" aria-label="테마 전환">
      <button type="button" data-theme-set="light" aria-pressed="false">DAY</button>
      <button type="button" data-theme-set="dark" aria-pressed="true">NIGHT</button>
    </div>
  </div>

  <div class="shell">
    <header class="page-head">
      <div>
        <span class="eyebrow">Admin · Comparison</span>
        <h1>유니버스 비교 보드</h1>
        <p class="subtitle">여러 유니버스의 efficient frontier와 백테스트 수익선을 한 화면에서 나란히 비교합니다. 스냅샷으로 보드 상태를 저장·복원할 수 있습니다.</p>
      </div>
      <div class="actions">
        <a class="nav-link" href="/admin">← 유니버스 관리</a>
      </div>
    </header>

    <section class="card">
      <div class="card-head">
        <div>
          <span class="eyebrow">Board · Snapshots</span>
          <h2>스냅샷</h2>
        </div>
      </div>
      <p class="helper">보드 상태를 저장·불러오기, 폴더로 정리하고 유니버스로 필터링할 수 있어요.</p>
      <div class="snapshot-bar">
        <div class="snapshot-picker">
          <button class="snapshot-trigger secondary" id="snapshot-trigger" type="button">
            <span class="snapshot-current" id="snapshot-current">— 새 보드 —</span>
            <span class="caret">▾</span>
          </button>
          <div class="snapshot-panel" id="snapshot-panel" hidden>
            <div class="snapshot-panel-head">
              <input type="search" id="snapshot-search" placeholder="이름·폴더·유니버스 검색" />
              <select id="snapshot-sort">
                <option value="updated_desc">최근 수정 순</option>
                <option value="updated_asc">오래된 수정 순</option>
                <option value="created_desc">최근 생성 순</option>
                <option value="name_asc">이름 (가나다)</option>
              </select>
            </div>
            <div class="snapshot-panel-filters">
              <details>
                <summary>유니버스 필터</summary>
                <div class="filter-options" id="snapshot-filter-universes"></div>
              </details>
              <details>
                <summary>폴더 필터</summary>
                <div class="filter-options" id="snapshot-filter-folders"></div>
              </details>
            </div>
            <div class="snapshot-results" id="snapshot-results"></div>
          </div>
        </div>
        <button id="save-snapshot-changes" disabled title="선택된 스냅샷에 현재 상태를 덮어쓰기">변경사항 저장</button>
        <button class="secondary" id="save-snapshot-as">다른 이름으로 저장</button>
      </div>
      <div class="board-toolbar">
        <button class="secondary" id="add-graph-set" type="button">+ 유니버스 추가</button>
        <div class="field">
          <label for="board-basis-date">기준일</label>
          <input type="date" id="board-basis-date" />
        </div>
      </div>
      <div class="err" id="snapshot-error" style="display:none"></div>
    </section>

    <div class="modal-backdrop" id="save-modal" hidden>
      <div class="modal-card">
        <h3 id="save-modal-title">스냅샷 저장</h3>
        <div class="field">
          <label for="save-modal-name">이름</label>
          <input type="text" id="save-modal-name" />
        </div>
        <div class="field">
          <label for="save-modal-folder">폴더 (선택)</label>
          <input type="text" id="save-modal-folder" list="folder-suggest" placeholder="예: 2026-Q2 비교" />
          <datalist id="folder-suggest"></datalist>
        </div>
        <div class="modal-actions">
          <button class="ghost" id="save-modal-cancel" type="button">취소</button>
          <button id="save-modal-confirm" type="button">저장</button>
        </div>
      </div>
    </div>

    <div class="graph-grid" id="graph-grid"></div>
    <div class="empty-state" id="empty-state" style="display:none">
      유니버스가 없습니다. "+ 유니버스 추가"를 눌러주세요.
    </div>

    <section class="backtest-panel">
      <div class="backtest-toolbar">
        <div class="field backtest-picker">
          <label for="single-graph-select">포트폴리오 선택</label>
          <select id="single-graph-select"></select>
        </div>
        <div class="backtest-actions">
          <div class="mode-tabs" role="group" aria-label="백테스트 모드">
            <button type="button" id="mode-single" aria-pressed="true">단일</button>
            <button type="button" id="mode-compare" aria-pressed="false">비교</button>
          </div>
          <button type="button" id="contribution-toggle" class="contribution-toggle" aria-pressed="false">기여도</button>
        </div>
      </div>
      <div class="chart-block backtest-chart">
        <div class="chart-title">
          <strong>Backtest Profit</strong>
          <span id="profit-status">포트폴리오를 선택하세요.</span>
        </div>
        <svg class="chart-svg profit-svg" id="profit-svg" viewBox="0 0 600 360" preserveAspectRatio="none"></svg>
        <div class="chart-hover-legend profit-legend" id="profit-legend" aria-hidden="true"></div>
        <div class="legend" id="backtest-legend"></div>
      </div>
      <div class="err" id="backtest-error" style="display:none"></div>
    </section>
  </div>

  <template id="graph-set-template">
    <div class="graph-set" data-graph-id="">
      <div class="graph-set-head">
        <input type="text" class="title-input" placeholder="유니버스 이름" />
        <div class="graph-set-actions">
          <button class="secondary mini btn-toggle" type="button" aria-pressed="true">리밸 ON</button>
          <button class="ghost mini btn-remove" type="button">삭제</button>
        </div>
      </div>
      <div class="controls">
        <div class="field">
          <label>유니버스</label>
          <select class="ctrl-version"></select>
        </div>
      </div>
      <div class="chart-block">
        <div class="chart-title">
          <strong>Efficient Frontier</strong>
          <span class="frontier-status">유니버스를 선택하세요.</span>
        </div>
        <svg class="chart-svg frontier-svg" viewBox="0 0 600 360" preserveAspectRatio="none"></svg>
        <div class="selection-summary"></div>
      </div>
      <div class="err graph-error" style="display:none"></div>
    </div>
  </template>

  <script>
    // Theme toggle
    (function(){
      const root = document.documentElement;
      const stored = localStorage.getItem('werobo-theme');
      const initial = stored === 'dark' || stored === 'light' ? stored : 'dark';
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
          // Re-render all graphs so SVG colors update
          window.dispatchEvent(new CustomEvent('werobo:theme-changed'));
        });
      });
    })();

    function chartColors() {
      const cs = getComputedStyle(document.documentElement);
      const get = (name) => cs.getPropertyValue(name).trim();
      return {
        grid: get('--chart-grid'),
        axis: get('--chart-axis'),
        tipBg: get('--chart-tip-bg'),
        tipBorder: get('--chart-tip-border'),
        tipFg: get('--chart-tip-fg'),
        tipMuted: get('--chart-tip-muted'),
        frontier: get('--chart-frontier'),
        rep: get('--chart-rep'),
        selected: get('--chart-selected'),
        selectedStroke: get('--chart-selected-stroke'),
        selectedHalo: get('--chart-selected-halo'),
        mu: get('--chart-mu'),
        portfolio: get('--chart-portfolio'),
        zero: get('--chart-zero'),
        mutedLine: get('--chart-muted-line'),
      };
    }

    const $ = (sel, root = document) => root.querySelector(sel);
    const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

    let catalog = { assets: [], versions: [] };
    let assetByCode = {};
    let versionById = {};
    const graphSets = new Map(); // id -> state
    let snapshots = [];
    let activeSnapshotId = null;
    let dirty = false;
    let graphSetSeq = 0;
    let boardBasisDate = null;
    let backtestMode = 'single';
    let selectedBacktestGraphId = null;
    let contributionMode = false;
    let compareHiddenLines = new Set();
    const snapshotFilter = {
      query: '',
      sort: 'updated_desc',
      universes: new Set(),
      folders: new Set(),
    };
    let saveModalState = { mode: 'create' };

    const TREASURY_KEY = 'treasury';
    const MARKET_KEY = 'market';
    const MAX_GRAPH_SETS = 3;
    const COMPARE_COLORS = ['#2563eb', '#f97316', '#10b981'];

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
    function fmtSignedPctRaw(value, digits = 2) {
      if (!Number.isFinite(value)) return '-';
      return `${value >= 0 ? '+' : ''}${value.toFixed(digits)}%`;
    }
    function fmtSignedPctPoint(value, digits = 2) {
      if (!Number.isFinite(value)) return '-';
      return `${value >= 0 ? '+' : ''}${value.toFixed(digits)}%p`;
    }

    async function api(path, init) {
      // Hard timeout so a hung upstream surfaces as an error instead of leaving
      // the UI stuck on "계산 중…" forever.
      const ctl = new AbortController();
      const timer = setTimeout(() => ctl.abort(), 45000);
      let res;
      try {
        res = await fetch(path, {
          headers: { 'content-type': 'application/json' },
          signal: ctl.signal,
          ...init,
        });
      } catch (e) {
        clearTimeout(timer);
        if (e.name === 'AbortError') throw new Error('응답 시간 초과 (45s)');
        throw e;
      }
      clearTimeout(timer);
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

    async function loadCatalog() {
      catalog = await api('/admin/api/comparison/catalog');
      assetByCode = Object.fromEntries(catalog.assets.map(a => [a.code, a]));
      versionById = Object.fromEntries(catalog.versions.map(v => [v.version_id, v]));
    }

    function getDefaultVersionId() {
      return catalog.versions.find(v => v.is_active)?.version_id
        ?? catalog.versions[0]?.version_id
        ?? null;
    }

    function getBasisDateWindow(versionId) {
      return versionById[versionId]?.basis_date_window || null;
    }

    function getBasisDateBounds() {
      const versionIds = graphSets.size
        ? Array.from(graphSets.values()).map(state => state.versionId)
        : [getDefaultVersionId()];
      const windows = versionIds.map(getBasisDateWindow);
      if (!windows.length || windows.some(window => !window)) return null;

      const sortedMinDates = windows
        .map(window => window.min_basis_date)
        .filter(Boolean)
        .sort();
      const sortedMaxDates = windows
        .map(window => window.max_basis_date)
        .filter(Boolean)
        .sort();
      const minDate = sortedMinDates[sortedMinDates.length - 1];
      const maxDate = sortedMaxDates[0];
      if (!minDate || !maxDate || minDate > maxDate) return null;
      return { minDate, maxDate };
    }

    function syncBoardBasisDate(preferredDate) {
      const input = $('#board-basis-date');
      const previous = boardBasisDate;
      const bounds = getBasisDateBounds();
      if (!bounds) {
        boardBasisDate = null;
        if (input) {
          input.value = '';
          input.disabled = true;
          input.removeAttribute('min');
          input.removeAttribute('max');
          input.title = '선택한 유니버스 조합에는 기준일로 사용할 수 있는 충분한 가격 이력이 없습니다.';
        }
        graphSets.forEach(state => {
          state.asOfDate = null;
          state.startDate = null;
        });
        return previous !== boardBasisDate;
      }

      let next = preferredDate || boardBasisDate || bounds.minDate;
      if (next < bounds.minDate) next = bounds.minDate;
      if (next > bounds.maxDate) next = bounds.maxDate;
      boardBasisDate = next;
      if (input) {
        input.disabled = false;
        input.min = bounds.minDate;
        input.max = bounds.maxDate;
        input.value = boardBasisDate;
        input.title = `선택 가능 범위: ${bounds.minDate} ~ ${bounds.maxDate}`;
      }
      graphSets.forEach(state => {
        state.asOfDate = boardBasisDate;
        state.startDate = boardBasisDate;
      });
      return previous !== boardBasisDate;
    }

    function refreshAllFrontiers() {
      graphSets.forEach(state => refreshFrontier(state));
    }

    function buildPayload() {
      const graphList = Array.from(graphSets.values());
      const selectedGraphIndex = graphList.findIndex(g => g.id === selectedBacktestGraphId);
      return {
        board_basis_date: boardBasisDate,
        backtest_mode: backtestMode,
        contribution_mode: contributionMode,
        selected_graph_index: selectedGraphIndex >= 0 ? selectedGraphIndex : 0,
        compare_hidden_lines: Array.from(compareHiddenLines),
        graph_sets: graphList.map(g => {
          const basisDate = boardBasisDate || g.asOfDate || g.startDate || null;
          return {
            name: g.name,
            version_id: g.versionId,
            rebalance_enabled: g.rebalanceEnabled !== false,
            as_of_date: basisDate,
            start_date: basisDate,
            point_index: g.pointIndex,
            hidden_lines: Array.from(g.hiddenLines || []),
            // Preloaded chart data so reopening the snapshot skips /frontier + /backtest calls.
            cached: (g.frontier && g.backtest && g.selection) ? {
              frontier: g.frontier,
              selection: g.selection,
              backtest: g.backtest,
            } : null,
          };
        }),
      };
    }

    function snapshotUniverseIds(snap) {
      const sets = snap?.payload?.graph_sets || [];
      const ids = new Set();
      sets.forEach(s => { if (s.version_id != null) ids.add(s.version_id); });
      return Array.from(ids);
    }

    function snapshotUniverseNames(snap) {
      return snapshotUniverseIds(snap).map(id => versionById[id]?.version_name || `v${id}`);
    }

    function fmtDate(iso) {
      if (!iso) return '-';
      const d = new Date(iso);
      if (Number.isNaN(d.getTime())) return iso;
      return d.toLocaleString();
    }

    function setDirty(value) {
      const next = !!value;
      if (dirty === next) return;
      dirty = next;
      updateSaveButtons();
    }

    function updateSaveButtons() {
      const trigger = $('#snapshot-trigger');
      const saveChanges = $('#save-snapshot-changes');
      const current = $('#snapshot-current');
      const active = snapshots.find(s => s.id === activeSnapshotId);
      if (active) {
        current.textContent = active.folder ? `${active.folder} / ${active.name}` : active.name;
      } else {
        current.textContent = '— 새 보드 —';
      }
      trigger.classList.toggle('dirty', dirty && !!activeSnapshotId);
      saveChanges.disabled = !activeSnapshotId || !dirty;
      saveChanges.title = !activeSnapshotId
        ? '먼저 저장된 스냅샷을 선택하세요.'
        : (!dirty ? '바뀐 내용이 없습니다.' : '선택된 스냅샷을 덮어씁니다.');
    }

    async function loadSnapshots() {
      try {
        const data = await api('/admin/api/comparison/snapshots');
        snapshots = data.snapshots || [];
      } catch (e) {
        snapshots = [];
        $('#snapshot-error').style.display = 'block';
        $('#snapshot-error').textContent = `스냅샷 불러오기 실패: ${e.message}`;
      }
      renderSnapshotPanel();
      updateSaveButtons();
    }

    function renderSnapshotPanel() {
      const universesEl = $('#snapshot-filter-universes');
      universesEl.innerHTML = '';
      catalog.versions.forEach(v => {
        const chip = document.createElement('span');
        chip.className = 'filter-chip' + (snapshotFilter.universes.has(v.version_id) ? ' on' : '');
        chip.textContent = v.version_name;
        chip.onclick = () => {
          if (snapshotFilter.universes.has(v.version_id)) snapshotFilter.universes.delete(v.version_id);
          else snapshotFilter.universes.add(v.version_id);
          renderSnapshotPanel();
        };
        universesEl.appendChild(chip);
      });
      const foldersEl = $('#snapshot-filter-folders');
      foldersEl.innerHTML = '';
      const folderSet = new Set();
      snapshots.forEach(s => folderSet.add(s.folder || ''));
      const folderList = Array.from(folderSet).sort((a, b) => a.localeCompare(b));
      folderList.forEach(f => {
        const chip = document.createElement('span');
        chip.className = 'filter-chip' + (snapshotFilter.folders.has(f) ? ' on' : '');
        chip.textContent = f || '(폴더 없음)';
        chip.onclick = () => {
          if (snapshotFilter.folders.has(f)) snapshotFilter.folders.delete(f);
          else snapshotFilter.folders.add(f);
          renderSnapshotPanel();
        };
        foldersEl.appendChild(chip);
      });

      const dl = $('#folder-suggest');
      dl.innerHTML = '';
      folderList.filter(Boolean).forEach(f => {
        const opt = document.createElement('option');
        opt.value = f;
        dl.appendChild(opt);
      });

      const q = snapshotFilter.query.trim().toLowerCase();
      let rows = snapshots.filter(s => {
        if (snapshotFilter.universes.size) {
          const ids = snapshotUniverseIds(s);
          if (!ids.some(id => snapshotFilter.universes.has(id))) return false;
        }
        if (snapshotFilter.folders.size) {
          if (!snapshotFilter.folders.has(s.folder || '')) return false;
        }
        if (q) {
          const haystack = [
            s.name,
            s.folder || '',
            ...snapshotUniverseNames(s),
          ].join(' ').toLowerCase();
          if (!haystack.includes(q)) return false;
        }
        return true;
      });
      rows = rows.sort((a, b) => {
        switch (snapshotFilter.sort) {
          case 'name_asc': return (a.name || '').localeCompare(b.name || '');
          case 'created_desc': return (b.created_at || '').localeCompare(a.created_at || '');
          case 'updated_asc': return (a.updated_at || '').localeCompare(b.updated_at || '');
          case 'updated_desc':
          default:
            return (b.updated_at || '').localeCompare(a.updated_at || '');
        }
      });

      const resultsEl = $('#snapshot-results');
      resultsEl.innerHTML = '';
      if (!rows.length) {
        const empty = document.createElement('div');
        empty.className = 'snapshot-results-empty';
        empty.textContent = snapshots.length
          ? '필터에 해당하는 스냅샷이 없습니다.'
          : '저장된 스냅샷이 없습니다. "다른 이름으로 저장"으로 첫 스냅샷을 만들어보세요.';
        resultsEl.appendChild(empty);
        return;
      }

      const byFolder = new Map();
      rows.forEach(r => {
        const key = r.folder || '';
        if (!byFolder.has(key)) byFolder.set(key, []);
        byFolder.get(key).push(r);
      });
      const folderOrder = Array.from(byFolder.keys()).sort((a, b) => {
        if (!a) return 1;
        if (!b) return -1;
        return a.localeCompare(b);
      });
      folderOrder.forEach(folder => {
        if (folderOrder.length > 1 || folder) {
          const head = document.createElement('span');
          head.className = 'snapshot-folder';
          head.textContent = folder ? folder : '폴더 없음';
          resultsEl.appendChild(head);
        }
        byFolder.get(folder).forEach(snap => resultsEl.appendChild(buildSnapshotRow(snap)));
      });
    }

    function buildSnapshotRow(snap) {
      const row = document.createElement('div');
      row.className = 'snapshot-row' + (snap.id === activeSnapshotId ? ' active' : '');
      row.onclick = () => { loadSnapshot(snap.id); closeSnapshotPanel(); };

      const body = document.createElement('div');
      body.className = 'snapshot-row-body';
      const name = document.createElement('div');
      name.className = 'snapshot-row-name';
      name.textContent = snap.name;
      body.appendChild(name);

      const meta = document.createElement('div');
      meta.className = 'snapshot-row-meta';
      const updated = document.createElement('span');
      updated.textContent = `수정 ${fmtDate(snap.updated_at)}`;
      meta.appendChild(updated);
      const created = document.createElement('span');
      created.textContent = `생성 ${fmtDate(snap.created_at)}`;
      meta.appendChild(created);
      body.appendChild(meta);

      const universes = snapshotUniverseNames(snap);
      if (universes.length) {
        const tags = document.createElement('div');
        tags.className = 'snapshot-row-universes';
        universes.forEach(name => {
          const tag = document.createElement('span');
          tag.className = 'universe-tag';
          tag.textContent = name;
          tags.appendChild(tag);
        });
        body.appendChild(tags);
      }
      row.appendChild(body);

      const actions = document.createElement('div');
      actions.className = 'snapshot-row-actions';
      const del = document.createElement('button');
      del.type = 'button';
      del.textContent = '삭제';
      del.onclick = (ev) => { ev.stopPropagation(); deleteSnapshot(snap.id); };
      actions.appendChild(del);
      row.appendChild(actions);
      return row;
    }

    function openSnapshotPanel() {
      $('#snapshot-panel').hidden = false;
      $('#snapshot-search').focus();
    }
    function closeSnapshotPanel() { $('#snapshot-panel').hidden = true; }
    function toggleSnapshotPanel() {
      const panel = $('#snapshot-panel');
      panel.hidden ? openSnapshotPanel() : closeSnapshotPanel();
    }

    function openSaveModal({ mode, name, folder }) {
      saveModalState = { mode };
      $('#save-modal-title').textContent = mode === 'rename'
        ? '스냅샷 이름·폴더 변경'
        : '새 스냅샷 저장';
      $('#save-modal-name').value = name || `보드 ${new Date().toLocaleString()}`;
      $('#save-modal-folder').value = folder || '';
      $('#save-modal').hidden = false;
      setTimeout(() => $('#save-modal-name').focus(), 0);
    }
    function closeSaveModal() { $('#save-modal').hidden = true; }

    async function confirmSaveModal() {
      const name = $('#save-modal-name').value.trim();
      const folder = $('#save-modal-folder').value.trim() || null;
      if (!name) { alert('이름을 입력하세요.'); return; }
      const payload = buildPayload();
      try {
        const created = await api('/admin/api/comparison/snapshots', {
          method: 'POST',
          body: JSON.stringify({ name, folder, payload }),
        });
        snapshots = [created, ...snapshots];
        activeSnapshotId = created.id;
        setDirty(false);
        closeSaveModal();
        renderSnapshotPanel();
        updateSaveButtons();
      } catch (e) {
        alert(`저장 실패: ${e.message}`);
      }
    }

    async function saveCurrentChanges() {
      if (!activeSnapshotId) return;
      const payload = buildPayload();
      try {
        const updated = await api(`/admin/api/comparison/snapshots/${activeSnapshotId}`, {
          method: 'PUT',
          body: JSON.stringify({ payload }),
        });
        snapshots = snapshots.map(s => s.id === updated.id ? updated : s);
        setDirty(false);
        renderSnapshotPanel();
        updateSaveButtons();
      } catch (e) {
        alert(`저장 실패: ${e.message}`);
      }
    }

    async function deleteSnapshot(id) {
      if (!confirm('스냅샷을 삭제하시겠어요?')) return;
      try {
        await api(`/admin/api/comparison/snapshots/${id}`, { method: 'DELETE' });
        snapshots = snapshots.filter(s => s.id !== id);
        if (activeSnapshotId === id) {
          activeSnapshotId = null;
          setDirty(false);
        }
        renderSnapshotPanel();
        updateSaveButtons();
      } catch (e) {
        alert(`삭제 실패: ${e.message}`);
      }
    }

    async function loadSnapshot(id) {
      const snap = snapshots.find(s => s.id === id);
      if (!snap) return;
      activeSnapshotId = id;
      graphSets.clear();
      $('#graph-grid').innerHTML = '';
      const sets = snap.payload?.graph_sets || [];
      boardBasisDate = snap.payload?.board_basis_date || sets.find(item => item.as_of_date || item.start_date)?.as_of_date || sets.find(item => item.as_of_date || item.start_date)?.start_date || null;
      $('#board-basis-date').value = boardBasisDate || '';
      for (const item of sets) {
        if (graphSets.size >= MAX_GRAPH_SETS) break;
        const basisDate = boardBasisDate || item.as_of_date || item.start_date || null;
        addGraphSet({
          name: item.name,
          versionId: item.version_id,
          rebalanceEnabled: item.rebalance_enabled !== false,
          asOfDate: basisDate,
          startDate: basisDate,
          pointIndex: item.point_index,
          hiddenLines: item.hidden_lines || [],
          cached: item.cached || null,
        }, { silent: true });
      }
      const graphList = Array.from(graphSets.values());
      backtestMode = snap.payload?.backtest_mode === 'compare' ? 'compare' : 'single';
      contributionMode = snap.payload?.contribution_mode === true;
      compareHiddenLines = new Set(snap.payload?.compare_hidden_lines || []);
      const selectedIndex = Number.isInteger(snap.payload?.selected_graph_index)
        ? snap.payload.selected_graph_index
        : 0;
      selectedBacktestGraphId = graphList[Math.max(0, Math.min(selectedIndex, graphList.length - 1))]?.id || null;
      updateEmptyState();
      setDirty(false);
      renderSnapshotPanel();
      updateSaveButtons();
      updateBacktestControls();
      renderBoardBacktest();
    }

    function updateEmptyState() {
      $('#empty-state').style.display = graphSets.size === 0 ? 'block' : 'none';
      const addButton = $('#add-graph-set');
      if (addButton) {
        addButton.disabled = graphSets.size >= MAX_GRAPH_SETS;
        addButton.title = graphSets.size >= MAX_GRAPH_SETS
          ? '유니버스는 최대 3개까지 추가할 수 있습니다.'
          : '유니버스를 추가합니다.';
      }
    }

    function addGraphSet(initial, opts) {
      if (graphSets.size >= MAX_GRAPH_SETS) {
        alert('유니버스는 최대 3개까지 추가할 수 있습니다.');
        updateEmptyState();
        return;
      }
      const silent = !!opts?.silent;
      const id = nextGraphSetId();
      const basisDate = boardBasisDate || initial?.asOfDate || initial?.startDate || null;
      const state = {
        id,
        name: initial?.name || `유니버스 ${graphSets.size + 1}`,
        versionId: initial?.versionId || getDefaultVersionId(),
        rebalanceEnabled: initial?.rebalanceEnabled !== false,
        asOfDate: basisDate,
        startDate: basisDate,
        pointIndex: initial?.pointIndex ?? null,
        frontier: null,
        selection: null,
        backtest: null,
        hiddenLines: new Set(initial?.hiddenLines || []),
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
      titleInput.addEventListener('input', () => {
        state.name = titleInput.value;
        setDirty(true);
        updateBacktestControls();
        renderBoardBacktest();
      });

      const toggleButton = $('.btn-toggle', root);
      const syncToggle = () => {
        toggleButton.textContent = state.rebalanceEnabled ? '리밸 ON' : '리밸 OFF';
        toggleButton.title = state.rebalanceEnabled
          ? '클릭하면 리밸런싱 미적용 백테스트로 전환합니다.'
          : '클릭하면 리밸런싱 적용 백테스트로 전환합니다.';
        toggleButton.setAttribute('aria-pressed', String(state.rebalanceEnabled));
      };
      syncToggle();
      toggleButton.addEventListener('click', () => {
        state.rebalanceEnabled = !state.rebalanceEnabled;
        state.backtest = null;
        syncToggle();
        setDirty(true);
        if (state.selection) refreshBacktest(state);
        else renderBoardBacktest();
      });

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
        const basisChanged = syncBoardBasisDate();
        setDirty(true);
        updateBacktestControls();
        if (basisChanged) refreshAllFrontiers();
        else refreshFrontier(state);
      });

      $('.btn-remove', root).addEventListener('click', () => removeGraphSet(id));

      $('#graph-grid').appendChild(node);
      if (!selectedBacktestGraphId) selectedBacktestGraphId = id;
      const requestedBasisDate = basisDate || null;
      const basisChanged = syncBoardBasisDate(requestedBasisDate);
      updateEmptyState();
      updateBacktestControls();
      if (!silent) setDirty(true);

      const cache = initial?.cached;
      if (basisChanged) {
        refreshAllFrontiers();
      } else if (
        cache?.frontier?.points?.length
        && cache?.backtest?.lines
        && cache?.selection
        && requestedBasisDate === boardBasisDate
      ) {
        // Hydrate from snapshot payload so charts render without refetching.
        state.frontier = cache.frontier;
        state.selection = cache.selection;
        state.backtest = cache.backtest;
        renderFrontier(state);
        renderSelectionSummary(state);
        if (backtestHasContributionLines(state.backtest)) {
          renderBoardBacktest();
        } else {
          refreshBacktest(state);
        }
      } else {
        refreshFrontier(state);
      }
    }

    function removeGraphSet(id) {
      const st = graphSets.get(id);
      if (!st) return;
      st.rootEl?.remove();
      graphSets.delete(id);
      if (selectedBacktestGraphId === id) {
        selectedBacktestGraphId = Array.from(graphSets.keys())[0] || null;
      }
      const basisChanged = syncBoardBasisDate();
      updateEmptyState();
      updateBacktestControls();
      if (basisChanged) refreshAllFrontiers();
      else renderBoardBacktest();
      setDirty(true);
    }

    async function refreshFrontier(state) {
      if (!state.versionId) {
        setFrontierStatus(state, '유니버스를 선택하세요.');
        return;
      }
      if (!state.asOfDate) {
        state.frontier = null;
        state.selection = null;
        state.backtest = null;
        setFrontierStatus(state, '기준일 범위 없음');
        showError(state, '최소 1년 학습 데이터와 이후 백테스트 구간을 모두 만족하는 기준일이 없습니다.');
        renderBoardBacktest();
        return;
      }
      setFrontierStatus(state, '계산 중…');
      state.backtest = null;
      state.backtestLoading = false;
      renderBoardBacktest();
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
          const points = data.points;
          const balanced = points.find(p => p.representative_code === 'balanced');
          state.pointIndex = balanced ? balanced.index : points[Math.floor(points.length / 2)].index;
        }
        renderFrontier(state);
        applySelectionFromFrontier(state);
        await refreshBacktest(state);
        renderBoardBacktest();
      } catch (e) {
        state.frontier = null;
        state.backtest = null;
        showError(state, `Frontier 계산 실패: ${e.message}`);
        setFrontierStatus(state, '오류');
        clearFrontierSvg(state);
        renderBoardBacktest();
      }
    }

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
      if (!state.startDate) return;
      state.backtestLoading = true;
      renderBoardBacktest();
      try {
        const data = await api('/admin/api/comparison/backtest', {
          method: 'POST',
          body: JSON.stringify({
            version_id: state.versionId,
            stock_weights: state.selection.stock_weights,
            start_date: state.startDate,
            rebalance_enabled: state.rebalanceEnabled !== false,
          }),
        });
        state.backtest = data;
        state.backtestLoading = false;
        renderBoardBacktest();
      } catch (e) {
        state.backtest = null;
        state.backtestLoading = false;
        showError(state, `Backtest 계산 실패: ${e.message}`);
        renderBoardBacktest();
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
    function clearProfitSvg() {
      const svg = $('#profit-svg');
      while (svg.firstChild) svg.removeChild(svg.firstChild);
      $('#backtest-legend').innerHTML = '';
      const hoverEl = $('#profit-legend');
      hoverEl.innerHTML = '';
      hoverEl.setAttribute('data-visible', 'false');
    }

    function svgEl(name, attrs = {}) {
      const el = document.createElementNS('http://www.w3.org/2000/svg', name);
      for (const [k, v] of Object.entries(attrs)) {
        if (v !== null && v !== undefined) el.setAttribute(k, v);
      }
      return el;
    }

    function renderFrontier(state) {
      const svg = $('.frontier-svg', state.rootEl);
      const W = 600, H = 360;
      const padL = 14, padR = 56, padT = 22, padB = 30;
      const cw = W - padL - padR;
      const ch = H - padT - padB;
      while (svg.firstChild) svg.removeChild(svg.firstChild);

      const data = state.frontier;
      if (!data || !data.points.length) {
        setFrontierStatus(state, '데이터 없음');
        return;
      }
      const C = chartColors();
      const points = data.points;
      const xs = points.map(p => p.volatility);
      const ys = points.map(p => p.expected_return);
      const minX = Math.min(...xs), maxX = Math.max(...xs);
      const minY = Math.min(...ys), maxY = Math.max(...ys);
      const xPad = (maxX - minX) * 0.05 || 0.001;
      const yPad = (maxY - minY) * 0.08 || 0.001;
      const x0 = minX - xPad, x1 = maxX + xPad;
      const y0 = minY - yPad, y1 = maxY + yPad;

      const sx = v => padL + ((v - x0) / (x1 - x0)) * cw;
      const sy = v => padT + (1 - (v - y0) / (y1 - y0)) * ch;

      // Gradient defs for area fill under the frontier curve
      const gradId = `fgrad-${state.id}`;
      const defs = svgEl('defs');
      const grad = svgEl('linearGradient', { id: gradId, x1: '0', y1: '0', x2: '0', y2: '1' });
      grad.appendChild(svgEl('stop', { offset: '0%', 'stop-color': C.frontier, 'stop-opacity': '0.22' }));
      grad.appendChild(svgEl('stop', { offset: '100%', 'stop-color': C.frontier, 'stop-opacity': '0' }));
      defs.appendChild(grad);
      svg.appendChild(defs);

      // Horizontal gridlines (subtle)
      for (let i = 0; i <= 4; i++) {
        const y = padT + (ch * i) / 4;
        svg.appendChild(svgEl('line', {
          x1: padL, y1: y, x2: W - padR, y2: y,
          stroke: C.grid, 'stroke-width': '1', opacity: '0.55',
          'stroke-dasharray': i === 0 || i === 4 ? null : '2,3',
        }));
      }

      // Axis separator lines (right price scale + bottom time scale)
      svg.appendChild(svgEl('line', {
        x1: W - padR, y1: padT, x2: W - padR, y2: padT + ch,
        stroke: C.axis, 'stroke-width': '1', opacity: '0.35',
      }));
      svg.appendChild(svgEl('line', {
        x1: padL, y1: padT + ch, x2: W - padR, y2: padT + ch,
        stroke: C.axis, 'stroke-width': '1', opacity: '0.35',
      }));

      // Right-axis labels (E[R] values) — TradingView signature: price labels on right
      for (let i = 0; i <= 4; i++) {
        const y = padT + (ch * i) / 4;
        const labelVal = y1 - ((y1 - y0) * i) / 4;
        const t = svgEl('text', {
          x: W - padR + 6, y: y + 3.5, fill: C.axis, 'font-size': '9.5',
          'font-family': 'Azeret Mono, monospace', 'text-anchor': 'start',
        });
        t.textContent = `${(labelVal * 100).toFixed(2)}%`;
        svg.appendChild(t);
        // tick mark
        svg.appendChild(svgEl('line', {
          x1: W - padR, y1: y, x2: W - padR + 3, y2: y,
          stroke: C.axis, 'stroke-width': '1', opacity: '0.5',
        }));
      }

      // Bottom-axis labels (volatility)
      for (let i = 0; i <= 4; i++) {
        const x = padL + (cw * i) / 4;
        const labelVal = x0 + ((x1 - x0) * i) / 4;
        const t = svgEl('text', {
          x, y: padT + ch + 16, fill: C.axis, 'font-size': '9.5',
          'font-family': 'Azeret Mono, monospace', 'text-anchor': 'middle',
        });
        t.textContent = `${(labelVal * 100).toFixed(2)}%`;
        svg.appendChild(t);
        svg.appendChild(svgEl('line', {
          x1: x, y1: padT + ch, x2: x, y2: padT + ch + 3,
          stroke: C.axis, 'stroke-width': '1', opacity: '0.5',
        }));
      }

      // Axis annotations in corners
      const muLabel = svgEl('text', {
        x: W - padR + 6, y: padT - 9, fill: C.axis, 'font-size': '9',
        'font-family': 'Azeret Mono, monospace', 'letter-spacing': '0.1em',
        'text-anchor': 'start',
      });
      muLabel.textContent = 'μ  E[R]';
      svg.appendChild(muLabel);
      const sigmaLabel = svgEl('text', {
        x: W - padR - 4, y: padT + ch + 16, fill: C.axis, 'font-size': '9',
        'font-family': 'Azeret Mono, monospace', 'letter-spacing': '0.1em',
        'text-anchor': 'end', 'font-style': 'italic',
      });
      sigmaLabel.textContent = 'σ →';
      svg.appendChild(sigmaLabel);

      // Area fill under frontier curve
      const baseY = padT + ch;
      const areaD = points.map((p, i) =>
        `${i === 0 ? 'M' : 'L'} ${sx(p.volatility).toFixed(2)} ${sy(p.expected_return).toFixed(2)}`
      ).join(' ')
        + ` L ${sx(points[points.length - 1].volatility).toFixed(2)} ${baseY.toFixed(2)}`
        + ` L ${sx(points[0].volatility).toFixed(2)} ${baseY.toFixed(2)} Z`;
      svg.appendChild(svgEl('path', {
        d: areaD, fill: `url(#${gradId})`, stroke: 'none',
      }));

      // Frontier curve
      const pathD = points.map((p, i) =>
        `${i === 0 ? 'M' : 'L'} ${sx(p.volatility).toFixed(2)} ${sy(p.expected_return).toFixed(2)}`
      ).join(' ');
      svg.appendChild(svgEl('path', {
        d: pathD, fill: 'none', stroke: C.frontier,
        'stroke-width': '1.8', 'stroke-linecap': 'round', 'stroke-linejoin': 'round',
      }));

      // Representative points only (cleaner than showing all 61 dots)
      points.forEach(p => {
        if (!p.representative_code) return;
        svg.appendChild(svgEl('circle', {
          cx: sx(p.volatility), cy: sy(p.expected_return),
          r: 2.8, fill: C.rep,
        }));
      });

      // Selected point
      const selectedPoint = points.find(p => p.index === state.pointIndex)
        ?? points[Math.floor(points.length / 2)];
      const selCx = sx(selectedPoint.volatility);
      const selCy = sy(selectedPoint.expected_return);

      // Crosshair from selected point to axes
      svg.appendChild(svgEl('line', {
        x1: selCx, y1: padT, x2: selCx, y2: padT + ch,
        stroke: C.frontier, 'stroke-width': '1', 'stroke-dasharray': '2,3', opacity: '0.45',
      }));
      svg.appendChild(svgEl('line', {
        x1: padL, y1: selCy, x2: W - padR, y2: selCy,
        stroke: C.frontier, 'stroke-width': '1', 'stroke-dasharray': '2,3', opacity: '0.45',
      }));

      svg.appendChild(svgEl('circle', { cx: selCx, cy: selCy, r: 12, fill: C.selectedHalo }));
      svg.appendChild(svgEl('circle', {
        cx: selCx, cy: selCy, r: 5.5, fill: C.frontier,
        stroke: C.selectedStroke, 'stroke-width': '2',
      }));

      // Right-axis value pill (μ) — TradingView signature
      const pillW = 52, pillH = 17;
      const pillY = Math.max(padT, Math.min(padT + ch - pillH, selCy - pillH / 2));
      svg.appendChild(svgEl('rect', {
        x: W - padR, y: pillY, width: pillW, height: pillH,
        rx: 2, fill: C.frontier,
      }));
      const pillText = svgEl('text', {
        x: W - padR + pillW / 2, y: pillY + pillH / 2 + 3.5,
        fill: C.selectedStroke, 'font-size': '10.5', 'font-weight': '700',
        'font-family': 'Azeret Mono, monospace', 'text-anchor': 'middle',
      });
      pillText.textContent = `${(selectedPoint.expected_return * 100).toFixed(2)}%`;
      svg.appendChild(pillText);

      // Bottom-axis value pill (σ)
      const volPillW = 56, volPillH = 17;
      const volX = Math.max(padL, Math.min(W - padR - volPillW, selCx - volPillW / 2));
      svg.appendChild(svgEl('rect', {
        x: volX, y: padT + ch, width: volPillW, height: volPillH,
        rx: 2, fill: C.frontier,
      }));
      const volText = svgEl('text', {
        x: volX + volPillW / 2, y: padT + ch + volPillH / 2 + 3.5,
        fill: C.selectedStroke, 'font-size': '10.5', 'font-weight': '700',
        'font-family': 'Azeret Mono, monospace', 'text-anchor': 'middle',
      });
      volText.textContent = `${(selectedPoint.volatility * 100).toFixed(2)}%`;
      svg.appendChild(volText);

      setFrontierStatus(state, `idx ${selectedPoint.index} / ${points.length - 1}`);

      // Drag to change selection — nearest preview point
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
        const ex = ev.clientX ?? ev.touches?.[0]?.clientX;
        const ey = ev.clientY ?? ev.touches?.[0]?.clientY;
        if (ex === undefined) return;
        const nearest = findNearest(ex, ey);
        if (nearest.index !== state.pointIndex) {
          state.pointIndex = nearest.index;
          setDirty(true);
          renderFrontier(state);
          applySelectionFromFrontier(state);
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
        ['N', String(Object.keys(sel.stock_weights).length)],
      ];
      items.forEach(([k, v]) => {
        const span = document.createElement('span');
        span.className = 'summary-item';
        span.innerHTML = `<span class="pill">${k}</span><span class="summary-value">${v}</span>`;
        root.appendChild(span);
      });
      if (sel.sector_breakdown.length) {
        const sep = document.createElement('span');
        sep.className = 'summary-sep';
        root.appendChild(sep);
      }
      sel.sector_breakdown.slice(0, 6).forEach(b => {
        const asset = assetByCode[b.asset_code];
        if (!asset) return;
        const span = document.createElement('span');
        span.className = 'summary-item';
        span.innerHTML = `<span style="display:inline-block; width:7px; height:7px; border-radius:1px; background:${asset.color};"></span><span class="summary-value">${asset.name} ${(b.weight * 100).toFixed(0)}%</span>`;
        root.appendChild(span);
      });
    }

    const MU_KEY = '__mu__';
    const PORTFOLIO_KEYS = new Set(['selected', 'balanced', 'conservative', 'growth']);
    const CONTRIBUTION_PREFIX = 'contribution_';

    function buildBacktestLines(state) {
      const data = state.backtest;
      if (!data || !data.lines.length) return [];

      const C = chartColors();
      const lines = data.lines.filter(line => {
        if (line.key === TREASURY_KEY) return true;
        if (line.key === MARKET_KEY) return true;
        if (line.key.startsWith('asset_')) return true;
        return PORTFOLIO_KEYS.has(line.key);
      }).map(line => {
        if (PORTFOLIO_KEYS.has(line.key)) {
          return { ...line, label: '선택 포트폴리오', color: C.portfolio, _portfolio: true };
        }
        return line;
      });

      const mu = state.selection?.expected_return;
      if (mu !== undefined && mu !== null && lines.length) {
        const allDates = new Set();
        lines.forEach(line => line.points.forEach(p => allDates.add(p.date)));
        const sortedDates = Array.from(allDates).sort();
        if (sortedDates.length >= 2) {
          const start = new Date(sortedDates[0]);
          const muPoints = sortedDates.map(d => {
            const years = (new Date(d) - start) / (365.25 * 86400000);
            return { date: d, return_pct: mu * 100 * years };
          });
          lines.push({
            key: MU_KEY,
            label: `μ projection (${(mu * 100).toFixed(1)}%/y)`,
            color: C.mu,
            style: 'dashed',
            points: muPoints,
            _mu: true,
          });
        }
      }
      return lines;
    }

    function buildContributionLines(state) {
      const data = state.backtest;
      if (!data || !data.lines.length) return [];

      const C = chartColors();
      const portfolioLine = data.lines.find(line => PORTFOLIO_KEYS.has(line.key));
      if (!portfolioLine) return [];

      const totalReturnByDate = new Map(
        portfolioLine.points.map(point => [point.date, Number(point.return_pct)])
      );
      const contributionLines = data.lines
        .filter(line => line.key.startsWith(CONTRIBUTION_PREFIX))
        .map(line => ({
          ...line,
          _contribution: true,
          points: line.points.map(point => {
            const rawContribution = Number(point.return_pct);
            const totalReturn = totalReturnByDate.get(point.date);
            const hasShare = Number.isFinite(rawContribution)
              && Number.isFinite(totalReturn)
              && Math.abs(totalReturn) >= 0.0001;
            const contributionShare = hasShare
              ? (rawContribution / totalReturn) * 100
              : null;
            return {
              ...point,
              return_pct: rawContribution,
              raw_return_pct: rawContribution,
              total_return_pct: Number.isFinite(totalReturn) ? totalReturn : null,
              contribution_share_pct: contributionShare,
            };
          }),
        }));
      if (!contributionLines.length) return [];
      return [{
        ...portfolioLine,
        label: '선택 포트폴리오 기준선',
        color: C.portfolio,
        _portfolio: true,
        points: portfolioLine.points.map(point => ({
          ...point,
          total_return_pct: Number(point.return_pct),
        })),
      }, ...contributionLines];
    }

    function backtestHasContributionLines(backtest) {
      return !!backtest?.lines?.some(line => line.key?.startsWith(CONTRIBUTION_PREFIX));
    }

    function labelForGraphSet(state) {
      const versionName = versionById[state.versionId]?.version_name;
      return (state.name || '').trim() || versionName || `유니버스 ${state.id}`;
    }

    function getSelectedBacktestState() {
      if (!selectedBacktestGraphId || !graphSets.has(selectedBacktestGraphId)) {
        selectedBacktestGraphId = Array.from(graphSets.keys())[0] || null;
      }
      return selectedBacktestGraphId ? graphSets.get(selectedBacktestGraphId) : null;
    }

    function updateBacktestControls() {
      const select = $('#single-graph-select');
      if (!select) return;
      if (!selectedBacktestGraphId || !graphSets.has(selectedBacktestGraphId)) {
        selectedBacktestGraphId = Array.from(graphSets.keys())[0] || null;
      }
      select.innerHTML = '';
      graphSets.forEach(state => {
        const opt = document.createElement('option');
        opt.value = state.id;
        opt.textContent = labelForGraphSet(state);
        select.appendChild(opt);
      });
      select.value = selectedBacktestGraphId || '';
      select.disabled = backtestMode !== 'single' || graphSets.size === 0;
      $('#mode-single').setAttribute('aria-pressed', String(backtestMode === 'single'));
      $('#mode-compare').setAttribute('aria-pressed', String(backtestMode === 'compare'));
      const contributionToggle = $('#contribution-toggle');
      if (contributionToggle) {
        contributionToggle.hidden = backtestMode !== 'single';
        contributionToggle.disabled = graphSets.size === 0;
        contributionToggle.setAttribute('aria-pressed', String(contributionMode));
        contributionToggle.title = contributionMode
          ? '기여도 보기를 끕니다.'
          : '선택 포트폴리오 성장 기여도를 봅니다.';
      }
    }

    function setBacktestMode(mode) {
      backtestMode = mode === 'compare' ? 'compare' : 'single';
      setDirty(true);
      updateBacktestControls();
      renderBoardBacktest();
    }

    function findCommonStartDate(lines) {
      const pointSets = lines.map(line => new Set(line.points.map(point => point.date)));
      const firstDates = lines
        .map(line => line.points[0]?.date)
        .filter(Boolean)
        .sort();
      if (!pointSets.length || firstDates.length !== lines.length) return null;
      const minAllowedDate = firstDates[firstDates.length - 1];
      return [...pointSets[0]]
        .filter(date => date >= minAllowedDate && pointSets.every(set => set.has(date)))
        .sort()[0] || null;
    }

    function rebaseLineAtDate(line, startDate) {
      const basePoint = line.points.find(point => point.date === startDate);
      if (!basePoint) return null;
      const baseReturn = Number(basePoint.return_pct);
      if (!Number.isFinite(baseReturn)) return null;
      const points = line.points
        .filter(point => point.date >= startDate)
        .map(point => {
          const value = Number(point.return_pct);
          if (!Number.isFinite(value)) return null;
          return {
            ...point,
            return_pct: Math.round((value - baseReturn) * 10000) / 10000,
          };
        })
        .filter(Boolean);
      return points.length ? { ...line, points } : null;
    }

    function buildCompareBacktestLines() {
      const lines = Array.from(graphSets.values())
        .filter(state => state.backtest?.lines?.length)
        .map((state, idx) => {
          const line = state.backtest.lines.find(item => PORTFOLIO_KEYS.has(item.key));
          if (!line) return null;
          return {
            ...line,
            key: `compare_${state.id}`,
            label: `${labelForGraphSet(state)} · ${state.rebalanceEnabled === false ? '리밸 OFF' : '리밸 ON'}`,
            color: COMPARE_COLORS[idx % COMPARE_COLORS.length],
            style: 'solid',
            _portfolio: true,
          };
        })
        .filter(Boolean);
      const commonStartDate = findCommonStartDate(lines);
      if (!commonStartDate) return { lines, commonStartDate: null };
      return {
        lines: lines
          .map(line => rebaseLineAtDate(line, commonStartDate))
          .filter(Boolean),
        commonStartDate,
      };
    }

    function renderBoardBacktest() {
      updateBacktestControls();
      const statusEl = $('#profit-status');
      const errorEl = $('#backtest-error');
      errorEl.style.display = 'none';
      errorEl.textContent = '';

      if (graphSets.size === 0) {
        clearProfitSvg();
        statusEl.textContent = '유니버스를 추가하세요.';
        return;
      }

      if (backtestMode === 'compare') {
        const compareStates = Array.from(graphSets.values());
        const loading = compareStates.some(state => state.backtestLoading);
        const compareBacktest = buildCompareBacktestLines();
        const lines = compareBacktest.lines;
        if (compareStates.length < 2) {
          clearProfitSvg();
          statusEl.textContent = '비교할 유니버스를 2개 이상 추가하세요.';
          return;
        }
        if (loading && lines.length < compareStates.length) {
          statusEl.textContent = '계산 중...';
        } else {
          statusEl.textContent = `${lines.length}개 유니버스 비교${compareBacktest.commonStartDate ? ` · ${compareBacktest.commonStartDate}부터` : ''}`;
        }
        if (!lines.length) {
          clearProfitSvg();
          return;
        }
        renderBacktestChart({
          lines,
          hidden: compareHiddenLines,
          onToggle: key => {
            if (compareHiddenLines.has(key)) compareHiddenLines.delete(key);
            else compareHiddenLines.add(key);
            setDirty(true);
            renderBoardBacktest();
          },
        });
        return;
      }

      const selected = getSelectedBacktestState();
      if (!selected) {
        clearProfitSvg();
        statusEl.textContent = '포트폴리오를 선택하세요.';
        return;
      }
      if (selected.backtestLoading && !selected.backtest) {
        clearProfitSvg();
        statusEl.textContent = '계산 중...';
        return;
      }
      const lines = contributionMode
        ? buildContributionLines(selected)
        : buildBacktestLines(selected);
      if (!lines.length) {
        clearProfitSvg();
        statusEl.textContent = selected.backtestLoading ? '계산 중...' : (contributionMode ? '기여도 데이터 없음' : '백테스트 데이터 없음');
        return;
      }
      statusEl.textContent = `${labelForGraphSet(selected)} · ${selected.backtest.start_date} → ${selected.backtest.end_date}${contributionMode ? ' · 포트폴리오 기준선 + 자산군 기여도(%p)' : ''}`;
      renderBacktestChart({
        lines,
        hidden: selected.hiddenLines || new Set(),
        onToggle: key => {
          if (!selected.hiddenLines) selected.hiddenLines = new Set();
          if (selected.hiddenLines.has(key)) selected.hiddenLines.delete(key);
          else selected.hiddenLines.add(key);
          setDirty(true);
          renderBoardBacktest();
        },
      });
    }

    function renderBacktest() {
      renderBoardBacktest();
    }

    function measureSvgViewport(svg, fallbackWidth, fallbackHeight) {
      const rect = svg.getBoundingClientRect();
      const width = Math.max(1, Math.round(rect.width || fallbackWidth));
      const height = Math.max(1, Math.round(rect.height || fallbackHeight));
      svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
      return { width, height };
    }

    function renderBacktestChart({ lines, hidden, onToggle }) {
      const svg = $('#profit-svg');
      const legendEl = $('#backtest-legend');
      const hoverEl = $('#profit-legend');
      const { width: W, height: H } = measureSvgViewport(svg, 600, 430);
      const padL = Math.max(14, Math.round(W * 0.024));
      const padR = Math.max(62, Math.round(W * 0.095));
      const padT = Math.max(22, Math.round(H * 0.06));
      const padB = Math.max(28, Math.round(H * 0.078));
      const cw = W - padL - padR;
      const ch = H - padT - padB;
      while (svg.firstChild) svg.removeChild(svg.firstChild);
      legendEl.innerHTML = '';
      if (hoverEl) { hoverEl.innerHTML = ''; hoverEl.setAttribute('data-visible', 'false'); }

      const C = chartColors();
      const allLines = lines;
      if (!allLines.length) return;
      const isContributionChart = allLines.some(line => line._contribution);
      const formatAxisValue = (value, digits = 1) => (
        isContributionChart ? `${value.toFixed(digits)}%p` : `${value.toFixed(digits)}%`
      );

      const visibleLines = allLines.filter(line => !hidden.has(line.key));

      const allDates = new Set();
      let minY = Infinity, maxY = -Infinity;
      const sourceLines = visibleLines.length ? visibleLines : allLines;
      sourceLines.forEach(line => {
        line.points.forEach(p => {
          allDates.add(p.date);
          if (p.return_pct < minY) minY = p.return_pct;
          if (p.return_pct > maxY) maxY = p.return_pct;
        });
      });
      if (!isFinite(minY) || !isFinite(maxY)) return;
      const yPad = (maxY - minY) * 0.08 || 1;
      const y0 = minY - yPad, y1 = maxY + yPad;

      const sortedDates = Array.from(allDates).sort();
      const dateIdx = new Map(sortedDates.map((d, i) => [d, i]));
      const dateCount = sortedDates.length;
      const sx = i => padL + (cw * i) / Math.max(1, dateCount - 1);
      const sy = v => padT + (1 - (v - y0) / (y1 - y0)) * ch;

      // Horizontal gridlines (subtle dashed, outer solid)
      for (let i = 0; i <= 5; i++) {
        const y = padT + (ch * i) / 5;
        svg.appendChild(svgEl('line', {
          x1: padL, y1: y, x2: W - padR, y2: y,
          stroke: C.grid, 'stroke-width': '1', opacity: '0.55',
          'stroke-dasharray': i === 0 || i === 5 ? null : '2,3',
        }));
      }

      // Axis separators (right price scale + bottom time scale)
      svg.appendChild(svgEl('line', {
        x1: W - padR, y1: padT, x2: W - padR, y2: padT + ch,
        stroke: C.axis, 'stroke-width': '1', opacity: '0.35',
      }));
      svg.appendChild(svgEl('line', {
        x1: padL, y1: padT + ch, x2: W - padR, y2: padT + ch,
        stroke: C.axis, 'stroke-width': '1', opacity: '0.35',
      }));

      // Right-axis value labels
      for (let i = 0; i <= 5; i++) {
        const y = padT + (ch * i) / 5;
        const labelVal = y1 - ((y1 - y0) * i) / 5;
        const t = svgEl('text', {
          x: W - padR + 6, y: y + 3.5, fill: C.axis, 'font-size': '9.5',
          'font-family': 'Azeret Mono, monospace', 'text-anchor': 'start',
        });
        t.textContent = formatAxisValue(labelVal, 0);
        svg.appendChild(t);
        svg.appendChild(svgEl('line', {
          x1: W - padR, y1: y, x2: W - padR + 3, y2: y,
          stroke: C.axis, 'stroke-width': '1', opacity: '0.5',
        }));
      }

      // Zero line — emphasized
      if (y0 < 0 && y1 > 0) {
        const yz = sy(0);
        svg.appendChild(svgEl('line', {
          x1: padL, y1: yz, x2: W - padR, y2: yz,
          stroke: C.zero, 'stroke-width': '1', 'stroke-dasharray': '4,4', opacity: '0.7',
        }));
      }

      // Bottom-axis time labels (6 evenly spaced)
      for (let i = 0; i < 6 && dateCount > 1; i++) {
        const idx = Math.round(((dateCount - 1) * i) / 5);
        const date = sortedDates[idx];
        const x = sx(idx);
        const t = svgEl('text', {
          x, y: padT + ch + 16, fill: C.axis, 'font-size': '9.5',
          'font-family': 'Azeret Mono, monospace',
          'text-anchor': i === 0 ? 'start' : (i === 5 ? 'end' : 'middle'),
        });
        t.textContent = date.slice(0, 7);
        svg.appendChild(t);
        svg.appendChild(svgEl('line', {
          x1: x, y1: padT + ch, x2: x, y2: padT + ch + 3,
          stroke: C.axis, 'stroke-width': '1', opacity: '0.5',
        }));
      }

      // Draw lines: market series first, portfolio above, μ on top
      const sortedLines = [...visibleLines].sort((a, b) => {
        const ord = l => l._mu ? 2 : (l._portfolio ? 1 : 0);
        return ord(a) - ord(b);
      });
      sortedLines.forEach(line => {
        const pts = line.points
          .map(p => [dateIdx.get(p.date), p.return_pct])
          .filter(([i]) => i !== undefined);
        if (pts.length < 2) return;
        const d = pts.map((pt, i) =>
          `${i === 0 ? 'M' : 'L'} ${sx(pt[0]).toFixed(2)} ${sy(pt[1]).toFixed(2)}`
        ).join(' ');
        svg.appendChild(svgEl('path', {
          d, fill: 'none', stroke: line.color || C.mutedLine,
          'stroke-width': line._portfolio ? '2.2' : (line._mu ? '1.4' : '1.2'),
          'stroke-linecap': 'round', 'stroke-linejoin': 'round',
          'stroke-dasharray': line.style === 'dashed' ? '4,4' : null,
          opacity: line._portfolio ? '1' : (line._mu ? '0.85' : '0.82'),
        }));
      });

      // Right-axis "last value" pills — TradingView signature
      // Compute last value per visible line, then stack pills if too close.
      const lastValues = sortedLines.map(line => {
        const pts = line.points.filter(p => dateIdx.has(p.date));
        if (!pts.length) return null;
        const last = pts[pts.length - 1];
        return { line, value: last.return_pct, y: sy(last.return_pct) };
      }).filter(Boolean);
      // Sort by y ascending so we can resolve collisions top-down
      lastValues.sort((a, b) => a.y - b.y);
      const pillH = 16;
      const minGap = 2;
      for (let i = 1; i < lastValues.length; i++) {
        const prev = lastValues[i - 1];
        if (lastValues[i].y < prev.y + pillH + minGap) {
          lastValues[i].y = prev.y + pillH + minGap;
        }
      }
      // Clamp to plot area
      lastValues.forEach(lv => {
        lv.y = Math.max(padT, Math.min(padT + ch - pillH, lv.y));
      });
      lastValues.forEach(lv => {
        const pillW = 52;
        svg.appendChild(svgEl('rect', {
          x: W - padR, y: lv.y, width: pillW, height: pillH,
          rx: 2, fill: lv.line.color || C.mutedLine,
          opacity: lv.line._portfolio ? '1' : (lv.line._mu ? '0.9' : '0.88'),
        }));
        const text = svgEl('text', {
          x: W - padR + pillW / 2, y: lv.y + pillH / 2 + 3.5,
          fill: C.selectedStroke, 'font-size': '10', 'font-weight': '700',
          'font-family': 'Azeret Mono, monospace', 'text-anchor': 'middle',
        });
        text.textContent = formatAxisValue(lv.value, 1);
        svg.appendChild(text);
      });

      // Dual crosshair (vertical + horizontal) — created once, moved on hover
      const cross = svgEl('g', { class: 'crosshair', style: 'pointer-events:none; display:none' });
      const vLine = svgEl('line', {
        y1: padT, y2: padT + ch,
        stroke: C.axis, 'stroke-width': '1', 'stroke-dasharray': '3,3', opacity: '0.6',
      });
      const hLine = svgEl('line', {
        x1: padL, x2: W - padR,
        stroke: C.axis, 'stroke-width': '1', 'stroke-dasharray': '3,3', opacity: '0.6',
      });
      cross.appendChild(vLine);
      cross.appendChild(hLine);
      const crossDots = svgEl('g');
      cross.appendChild(crossDots);
      // Time pill (bottom)
      const timePillBg = svgEl('rect', {
        height: 17, rx: 2, fill: C.tipFg,
      });
      const timePillText = svgEl('text', {
        fill: C.tipBg, 'font-size': '10', 'font-weight': '600',
        'font-family': 'Azeret Mono, monospace', 'text-anchor': 'middle',
      });
      cross.appendChild(timePillBg);
      cross.appendChild(timePillText);
      // Price pill (right)
      const pricePillBg = svgEl('rect', {
        width: 54, height: 17, rx: 2, fill: C.tipFg,
      });
      const pricePillText = svgEl('text', {
        fill: C.tipBg, 'font-size': '10', 'font-weight': '600',
        'font-family': 'Azeret Mono, monospace', 'text-anchor': 'middle',
      });
      cross.appendChild(pricePillBg);
      cross.appendChild(pricePillText);
      svg.appendChild(cross);

      const showCrosshair = (clientX, clientY) => {
        if (!dateCount) return;
        const rect = svg.getBoundingClientRect();
        const localX = ((clientX - rect.left) / rect.width) * W;
        const localY = ((clientY - rect.top) / rect.height) * H;
        if (localX < padL || localX > W - padR || localY < padT || localY > padT + ch) {
          hideCrosshair();
          return;
        }
        const t = (localX - padL) / cw;
        const idx = Math.max(0, Math.min(dateCount - 1, Math.round(t * (dateCount - 1))));
        const date = sortedDates[idx];
        const x = sx(idx);
        vLine.setAttribute('x1', x); vLine.setAttribute('x2', x);
        hLine.setAttribute('y1', localY.toFixed(2)); hLine.setAttribute('y2', localY.toFixed(2));

        // Dots on each visible line at this date
        while (crossDots.firstChild) crossDots.removeChild(crossDots.firstChild);
        const hoverValues = [];
        visibleLines.forEach(line => {
          const pt = line.points.find(p => p.date === date);
          if (!pt) return;
          const yPx = sy(pt.return_pct);
          crossDots.appendChild(svgEl('circle', {
            cx: x, cy: yPx, r: 3.2, fill: line.color || C.mutedLine,
            stroke: C.tipBg, 'stroke-width': '1.2',
          }));
          hoverValues.push({ line, value: pt.return_pct, point: pt });
        });

        // Time pill at bottom edge
        const tpW = 62;
        const tpX = Math.max(padL, Math.min(W - padR - tpW, x - tpW / 2));
        timePillBg.setAttribute('x', tpX);
        timePillBg.setAttribute('y', padT + ch);
        timePillBg.setAttribute('width', tpW);
        timePillText.setAttribute('x', tpX + tpW / 2);
        timePillText.setAttribute('y', padT + ch + 17 / 2 + 3.5);
        timePillText.textContent = date;

        // Price pill at right edge, at horizontal-crosshair height
        const invY = y1 - ((localY - padT) / ch) * (y1 - y0);
        const ppH = 17;
        const ppY = Math.max(padT, Math.min(padT + ch - ppH, localY - ppH / 2));
        pricePillBg.setAttribute('x', W - padR);
        pricePillBg.setAttribute('y', ppY);
        pricePillText.setAttribute('x', W - padR + 54 / 2);
        pricePillText.setAttribute('y', ppY + ppH / 2 + 3.5);
        pricePillText.textContent = formatAxisValue(invY, 1);

        cross.style.display = '';

        // Update HTML hover legend (top-left of plot)
        if (hoverEl) {
          // Sort: portfolio first, markets, μ last
          const sortedHover = [...hoverValues].sort((a, b) => {
            const ord = x => x.line._portfolio ? 0 : (x.line._mu ? 2 : 1);
            return ord(a) - ord(b);
          });
          const totalReturn = sortedHover.find(item =>
            item.line._portfolio && Number.isFinite(item.value)
          )?.value ?? sortedHover.find(item =>
            Number.isFinite(item.point?.total_return_pct)
          )?.point?.total_return_pct;
          const totalHtml = isContributionChart && Number.isFinite(totalReturn)
            ? `<span class="hl-total">포트폴리오 총수익률 ${fmtSignedPctRaw(totalReturn)} · 포폴=100 기준</span>`
            : '';
          let html = `<div class="hl-date">${date}${totalHtml}</div>`;
          sortedHover.forEach(({ line, value, point }) => {
            const cls = ['hl-row'];
            if (line._portfolio) cls.push('portfolio');
            const dotStyle = line.style === 'dashed'
              ? `background: transparent; color: ${line.color || 'currentColor'};`
              : `background: ${line.color || 'currentColor'};`;
            let valCls = value < 0 ? 'hl-val neg' : (value > 0 ? 'hl-val pos' : 'hl-val');
            let valueHtml = `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
            if (line._contribution) {
              const share = point?.contribution_share_pct;
              const rawContribution = point?.raw_return_pct;
              valCls = Number.isFinite(rawContribution) && rawContribution < 0
                ? 'hl-val neg'
                : (Number.isFinite(rawContribution) && rawContribution > 0 ? 'hl-val pos' : 'hl-val');
              valueHtml = Number.isFinite(rawContribution)
                ? fmtSignedPctPoint(rawContribution)
                : '-';
              if (Number.isFinite(share)) {
                valueHtml += `<span class="hl-subval">포폴=100 기준 ${fmtSignedPctRaw(share, 1)}</span>`;
              }
            }
            html += `<div class="${cls.join(' ')}"><span class="hl-dot ${line.style === 'dashed' ? 'dashed' : ''}" style="${dotStyle}"></span><span class="hl-label">${line.label}</span><span class="${valCls}">${valueHtml}</span></div>`;
          });
          hoverEl.innerHTML = html;
          hoverEl.setAttribute('data-visible', 'true');
        }
      };
      const hideCrosshair = () => {
        cross.style.display = 'none';
        if (hoverEl) hoverEl.setAttribute('data-visible', 'false');
      };

      svg.addEventListener('pointermove', (ev) => showCrosshair(ev.clientX, ev.clientY));
      svg.addEventListener('pointerdown', (ev) => showCrosshair(ev.clientX, ev.clientY));
      svg.addEventListener('pointerleave', hideCrosshair);

      // Legend below (toggle visibility)
      allLines.forEach(line => {
        const item = document.createElement('span');
        const isHidden = hidden.has(line.key);
        item.className = 'legend-item' + (isHidden ? ' muted' : '');
        item.title = isHidden ? '클릭하여 다시 표시' : '클릭하여 숨김';
        const sw = document.createElement('span');
        sw.className = 'legend-swatch' + (line.style === 'dashed' ? ' dashed' : '');
        sw.style.background = line.style === 'dashed' ? 'transparent' : (line.color || C.mutedLine);
        sw.style.color = line.color || C.mutedLine;
        item.appendChild(sw);
        const label = document.createElement('span');
        label.textContent = line.label;
        label.style.color = 'var(--fg-2)';
        item.appendChild(label);
        item.addEventListener('click', () => {
          onToggle(line.key);
        });
        legendEl.appendChild(item);
      });
    }

    // Re-render all charts when theme changes
    window.addEventListener('werobo:theme-changed', () => {
      graphSets.forEach(state => {
        if (state.frontier) renderFrontier(state);
      });
      renderBoardBacktest();
    });

    let backtestResizeFrame = null;
    window.addEventListener('resize', () => {
      if (backtestResizeFrame !== null) {
        cancelAnimationFrame(backtestResizeFrame);
      }
      backtestResizeFrame = requestAnimationFrame(() => {
        backtestResizeFrame = null;
        renderBoardBacktest();
      });
    });

    document.addEventListener('DOMContentLoaded', async () => {
      $('#add-graph-set').addEventListener('click', () => addGraphSet());
      $('#board-basis-date').addEventListener('change', (ev) => {
        syncBoardBasisDate(ev.target.value || null);
        refreshAllFrontiers();
        setDirty(true);
      });
      $('#single-graph-select').addEventListener('change', (ev) => {
        selectedBacktestGraphId = ev.target.value || null;
        setDirty(true);
        renderBoardBacktest();
      });
      $('#mode-single').addEventListener('click', () => setBacktestMode('single'));
      $('#mode-compare').addEventListener('click', () => setBacktestMode('compare'));
      $('#contribution-toggle').addEventListener('click', () => {
        contributionMode = !contributionMode;
        setDirty(true);
        updateBacktestControls();
        renderBoardBacktest();
      });
      $('#save-snapshot-changes').addEventListener('click', saveCurrentChanges);
      $('#save-snapshot-as').addEventListener('click', () => {
        const active = snapshots.find(s => s.id === activeSnapshotId);
        openSaveModal({
          mode: 'create',
          name: active ? `${active.name} 복사본` : '',
          folder: active?.folder || '',
        });
      });

      $('#snapshot-trigger').addEventListener('click', toggleSnapshotPanel);
      document.addEventListener('click', (ev) => {
        const picker = document.querySelector('.snapshot-picker');
        if (picker && !picker.contains(ev.target)) closeSnapshotPanel();
      });
      $('#snapshot-search').addEventListener('input', (ev) => {
        snapshotFilter.query = ev.target.value;
        renderSnapshotPanel();
      });
      $('#snapshot-sort').addEventListener('change', (ev) => {
        snapshotFilter.sort = ev.target.value;
        renderSnapshotPanel();
      });

      $('#save-modal-cancel').addEventListener('click', closeSaveModal);
      $('#save-modal-confirm').addEventListener('click', confirmSaveModal);
      $('#save-modal').addEventListener('click', (ev) => {
        if (ev.target.id === 'save-modal') closeSaveModal();
      });
      document.addEventListener('keydown', (ev) => {
        if (ev.key === 'Escape') {
          closeSaveModal();
          closeSnapshotPanel();
        }
      });

      try {
        await loadCatalog();
      } catch (e) {
        const loading = $('#snapshot-error');
        loading.style.display = 'block';
        loading.textContent = `카탈로그 로딩 실패: ${e.message}`;
        return;
      }
      await loadSnapshots();
      updateSaveButtons();
      if (graphSets.size === 0) addGraphSet({}, { silent: true });
      updateBacktestControls();
      renderBoardBacktest();
    });
  </script>
</body>
</html>
"""
    return HTMLResponse(content=html)
