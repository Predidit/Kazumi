/// 嵌入式 HTML 页面，由 LAN HTTP 服务在 `/` 路径返回。
///
/// 设计目标：在 iOS Safari 上跑得舒服，视觉上向 Kazumi 桌面端的 Material 3
/// 风格靠拢。CSS 颜色由 `/api/theme` 返回的桌面端 themeMode + primaryColor
/// 在运行时注入。
const String lanWebIndexHtml = r'''
<!DOCTYPE html>
<html lang="zh" data-theme="auto">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="format-detection" content="telephone=no">
  <title>Kazumi</title>
  <style>
    @font-face {
      font-family: "MiSans";
      src: url("/assets/MiSans-Regular.ttf") format("truetype");
      font-display: swap;
      font-weight: 400;
    }

    :root {
      --primary: #4CAF50;
      --on-primary: #ffffff;
      --primary-container: rgba(76, 175, 80, 0.14);
      --on-primary-container: #1d5224;

      --surface: #fafafa;
      --surface-container-lowest: #ffffff;
      --surface-container: #f4f4f4;
      --surface-container-high: #ececec;
      --surface-container-highest: #e3e3e3;
      --on-surface: #1c1b1f;
      --on-surface-variant: #5b5b62;
      --outline: #b8b8be;
      --outline-variant: #e3e0e3;
      --error: #b3261e;

      --shadow-1: 0 1px 2px rgba(0,0,0,0.06), 0 1px 1px rgba(0,0,0,0.04);
      --shadow-2: 0 2px 6px rgba(0,0,0,0.08), 0 1px 3px rgba(0,0,0,0.04);

      --radius-sm: 10px;
      --radius-md: 14px;
      --radius-lg: 20px;
      --radius-xl: 28px;
    }

    :root[data-theme="dark"] {
      --on-primary-container: #b4f4bb;
      --primary-container: rgba(76, 175, 80, 0.22);

      --surface: #131316;
      --surface-container-lowest: #0e0e10;
      --surface-container: #1c1c1f;
      --surface-container-high: #26262a;
      --surface-container-highest: #303034;
      --on-surface: #e6e1e5;
      --on-surface-variant: #c3c3c7;
      --outline: #6a6a70;
      --outline-variant: #303034;
      --error: #f2b8b5;

      --shadow-1: 0 1px 2px rgba(0,0,0,0.45);
      --shadow-2: 0 4px 12px rgba(0,0,0,0.55);
    }

    @media (prefers-color-scheme: dark) {
      :root[data-theme="auto"] {
        --on-primary-container: #b4f4bb;
        --primary-container: rgba(76, 175, 80, 0.22);

        --surface: #131316;
        --surface-container-lowest: #0e0e10;
        --surface-container: #1c1c1f;
        --surface-container-high: #26262a;
        --surface-container-highest: #303034;
        --on-surface: #e6e1e5;
        --on-surface-variant: #c3c3c7;
        --outline: #6a6a70;
        --outline-variant: #303034;
        --error: #f2b8b5;

        --shadow-1: 0 1px 2px rgba(0,0,0,0.45);
        --shadow-2: 0 4px 12px rgba(0,0,0,0.55);
      }
    }

    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    html, body { margin: 0; padding: 0; }
    body {
      font-family: "MiSans", -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", Roboto, sans-serif;
      background: var(--surface);
      color: var(--on-surface);
      min-height: 100vh;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
      transition: background 0.2s, color 0.2s;
    }

    /* ========== App bar ========== */
    .app-bar {
      position: sticky;
      top: 0;
      z-index: 10;
      background: color-mix(in srgb, var(--surface) 88%, transparent);
      backdrop-filter: saturate(180%) blur(12px);
      -webkit-backdrop-filter: saturate(180%) blur(12px);
      border-bottom: 1px solid var(--outline-variant);
      padding: 12px 16px;
      padding-top: calc(env(safe-area-inset-top) + 12px);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .app-bar .title {
      font-size: 18px;
      font-weight: 600;
      letter-spacing: 0.2px;
      flex: 1;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .icon-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: transparent;
      border: none;
      color: var(--on-surface);
      cursor: pointer;
      font-size: 20px;
      transition: background 0.15s;
      flex-shrink: 0;
    }
    .icon-btn:hover { background: var(--surface-container-high); }
    .icon-btn:active { background: var(--surface-container-highest); }

    /* ========== Container ========== */
    .container {
      max-width: 720px;
      margin: 0 auto;
      padding: 16px;
      padding-bottom: calc(env(safe-area-inset-bottom) + 32px);
    }
    h2 {
      font-size: 15px;
      font-weight: 500;
      color: var(--on-surface-variant);
      margin: 22px 0 10px;
      letter-spacing: 0.3px;
    }
    h2:first-child { margin-top: 4px; }

    /* ========== Search bar ========== */
    .search-bar {
      display: flex;
      align-items: center;
      gap: 6px;
      background: var(--surface-container-high);
      border-radius: var(--radius-xl);
      padding: 4px 4px 4px 8px;
      box-shadow: var(--shadow-1);
      transition: box-shadow 0.15s;
    }
    .search-bar:focus-within { box-shadow: var(--shadow-2); }
    .search-bar select, .search-bar input {
      font: inherit;
      color: var(--on-surface);
      background: transparent;
      border: none;
      outline: none;
    }
    .search-bar input {
      flex: 1;
      min-width: 0;
      padding: 12px 4px;
    }
    .search-bar input::placeholder { color: var(--on-surface-variant); opacity: 0.7; }
    .search-bar select {
      padding: 10px 22px 10px 8px;
      -webkit-appearance: none;
      appearance: none;
      max-width: 38%;
      cursor: pointer;
      border-radius: 18px;
    }
    .search-bar select:hover { background: var(--surface-container-highest); }
    .search-bar .submit {
      flex-shrink: 0;
      background: var(--primary);
      color: var(--on-primary);
      border: none;
      border-radius: 22px;
      width: 44px;
      height: 44px;
      cursor: pointer;
      font-size: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: var(--shadow-1);
    }
    .search-bar .submit:active { transform: scale(0.96); }
    .search-bar .submit:disabled { opacity: 0.5; }

    /* ========== List items ========== */
    .list { display: flex; flex-direction: column; gap: 8px; margin-top: 14px; }
    .item {
      background: var(--surface-container);
      border-radius: var(--radius-md);
      padding: 14px 16px;
      cursor: pointer;
      border: 1px solid var(--outline-variant);
      transition: background 0.15s, transform 0.1s;
      line-height: 1.5;
      font-size: 15px;
    }
    .item:hover { background: var(--surface-container-high); }
    .item:active { transform: scale(0.99); background: var(--surface-container-highest); }

    /* ========== Episode grid ========== */
    .ep-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(92px, 1fr));
      gap: 8px;
    }
    .ep {
      text-align: center;
      padding: 12px 6px;
      background: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--radius-sm);
      cursor: pointer;
      font-size: 13px;
      line-height: 1.35;
      word-break: break-all;
      transition: background 0.15s, border-color 0.15s, color 0.15s;
      color: var(--on-surface);
    }
    .ep:hover { background: var(--surface-container-high); }
    .ep:active, .ep.is-active {
      background: var(--primary-container);
      border-color: var(--primary);
      color: var(--on-primary-container);
    }

    /* ========== Status / error ========== */
    .status {
      padding: 28px 0;
      font-size: 13px;
      color: var(--on-surface-variant);
      text-align: center;
    }
    .error { color: var(--error); }

    /* ========== Player ========== */
    video {
      width: 100%;
      max-height: 78vh;
      background: #000;
      border-radius: var(--radius-md);
      display: block;
      box-shadow: var(--shadow-2);
    }
    .player-meta {
      font-size: 12px;
      color: var(--on-surface-variant);
      margin-top: 10px;
      word-break: break-all;
      line-height: 1.5;
    }
    .player-actions {
      display: flex;
      gap: 8px;
      margin-top: 14px;
    }
    button.tonal {
      flex: 1;
      background: var(--surface-container-high);
      border: 1px solid var(--outline-variant);
      color: var(--on-surface);
      font: inherit;
      padding: 12px 18px;
      border-radius: 22px;
      cursor: pointer;
      transition: background 0.15s;
    }
    button.tonal:hover { background: var(--surface-container-highest); }

    /* ========== Bangumi card (search result) ========== */
    .bangumi-card {
      display: flex;
      gap: 12px;
      background: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--radius-md);
      padding: 12px;
      cursor: pointer;
      transition: background 0.15s;
    }
    .bangumi-card:hover { background: var(--surface-container-high); }
    .bangumi-card .cover {
      width: 78px;
      height: 110px;
      flex-shrink: 0;
      background: var(--surface-container-high);
      border-radius: 8px;
      object-fit: cover;
      box-shadow: var(--shadow-1);
    }
    .bangumi-card .info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
    .bangumi-card .name { font-size: 15px; font-weight: 500; line-height: 1.35; overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
    .bangumi-card .alt { font-size: 12px; color: var(--on-surface-variant); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .bangumi-card .summary { font-size: 12px; color: var(--on-surface-variant); line-height: 1.45; overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
    .bangumi-card .meta { display: flex; gap: 8px; align-items: center; font-size: 12px; color: var(--on-surface-variant); margin-top: auto; }
    .bangumi-card .score { color: var(--primary); font-weight: 600; }

    /* ========== Detail hero ========== */
    .hero {
      position: relative;
      margin: -16px -16px 16px;
      padding: calc(env(safe-area-inset-top) + 16px) 16px 18px;
      overflow: hidden;
      isolation: isolate;
    }
    .hero::before {
      content: "";
      position: absolute;
      inset: -40px;
      background-size: cover;
      background-position: center;
      background-image: var(--hero-bg);
      filter: blur(28px) saturate(120%);
      opacity: 0.45;
      z-index: -2;
    }
    .hero::after {
      content: "";
      position: absolute;
      inset: 0;
      background: linear-gradient(180deg, transparent 0%, var(--surface) 100%);
      z-index: -1;
    }
    .hero-row { display: flex; gap: 14px; }
    .hero-cover {
      width: 110px;
      height: 156px;
      border-radius: 10px;
      object-fit: cover;
      background: var(--surface-container);
      box-shadow: var(--shadow-2);
      flex-shrink: 0;
    }
    .hero-meta { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
    .hero-title { font-size: 18px; font-weight: 600; line-height: 1.3; word-break: break-word; }
    .hero-alt { font-size: 13px; color: var(--on-surface-variant); word-break: break-word; }
    .hero-stat { display: flex; align-items: baseline; gap: 6px; margin-top: 2px; }
    .hero-score { font-size: 24px; font-weight: 700; color: var(--primary); line-height: 1; }
    .hero-stars { font-size: 14px; color: var(--primary); }
    .hero-votes { font-size: 12px; color: var(--on-surface-variant); }
    .hero-rank { font-size: 12px; color: var(--on-surface-variant); }

    .chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
    .chip {
      font-size: 11px;
      padding: 4px 10px;
      border-radius: 12px;
      background: var(--surface-container-high);
      border: 1px solid var(--outline-variant);
      color: var(--on-surface-variant);
    }

    /* ========== Tabs ========== */
    .tabs {
      display: flex;
      gap: 4px;
      border-bottom: 1px solid var(--outline-variant);
      margin: 18px 0 12px;
      overflow-x: auto;
      scrollbar-width: none;
    }
    .tabs::-webkit-scrollbar { display: none; }
    .tab {
      padding: 10px 14px;
      cursor: pointer;
      font-size: 14px;
      color: var(--on-surface-variant);
      border-bottom: 2px solid transparent;
      white-space: nowrap;
      transition: color 0.15s, border-color 0.15s;
    }
    .tab.is-active { color: var(--primary); border-bottom-color: var(--primary); font-weight: 500; }

    /* ========== Summary ========== */
    .summary-card {
      background: var(--surface-container);
      border-radius: var(--radius-md);
      padding: 14px 16px;
      border: 1px solid var(--outline-variant);
      font-size: 14px;
      line-height: 1.65;
      color: var(--on-surface);
      white-space: pre-wrap;
      word-break: break-word;
    }
    .summary-card.collapsed {
      max-height: 8.5em;
      overflow: hidden;
      mask-image: linear-gradient(180deg, #000 70%, transparent 100%);
      -webkit-mask-image: linear-gradient(180deg, #000 70%, transparent 100%);
    }
    .summary-toggle {
      display: block;
      margin: 10px auto 0;
      background: transparent;
      color: var(--primary);
      border: none;
      font: inherit;
      cursor: pointer;
      padding: 6px 12px;
    }

    /* ========== Character / staff / comment grids ========== */
    .char-grid, .staff-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
      gap: 8px;
    }
    .char-card, .staff-card {
      display: flex;
      gap: 10px;
      background: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--radius-md);
      padding: 10px;
      align-items: center;
    }
    .char-card img, .staff-card img {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      object-fit: cover;
      background: var(--surface-container-high);
      flex-shrink: 0;
    }
    .char-card .meta, .staff-card .meta { min-width: 0; line-height: 1.35; }
    .char-card .name, .staff-card .name { font-size: 13px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .char-card .relation, .staff-card .position { font-size: 11px; color: var(--on-surface-variant); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .char-actors { font-size: 11px; color: var(--on-surface-variant); margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

    .comment-card {
      background: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--radius-md);
      padding: 12px 14px;
      margin-bottom: 8px;
    }
    .comment-head {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 13px;
      margin-bottom: 8px;
    }
    .comment-head img { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; background: var(--surface-container-high); }
    .comment-head .username { font-weight: 500; }
    .comment-head .rate { margin-left: auto; font-size: 12px; color: var(--primary); }
    .comment-body { font-size: 13px; line-height: 1.6; color: var(--on-surface); white-space: pre-wrap; word-break: break-word; }

    /* ========== FAB ========== */
    .fab {
      position: fixed;
      right: 18px;
      bottom: calc(env(safe-area-inset-bottom) + 18px);
      background: var(--primary);
      color: var(--on-primary);
      border: none;
      border-radius: 18px;
      padding: 14px 22px;
      font: inherit;
      font-weight: 500;
      cursor: pointer;
      box-shadow: var(--shadow-2);
      z-index: 9;
    }
    .fab:active { transform: scale(0.97); }

    /* ========== Modal ========== */
    .modal-mask {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.45);
      z-index: 50;
      display: flex;
      align-items: flex-end;
      justify-content: center;
    }
    .modal-sheet {
      background: var(--surface-container-lowest);
      width: 100%;
      max-width: 560px;
      max-height: 80vh;
      overflow-y: auto;
      border-radius: var(--radius-lg) var(--radius-lg) 0 0;
      padding: 14px 16px calc(env(safe-area-inset-bottom) + 18px);
      box-shadow: var(--shadow-2);
    }
    @media (min-width: 600px) {
      .modal-mask { align-items: center; }
      .modal-sheet { border-radius: var(--radius-lg); max-height: 86vh; }
    }
    .modal-handle {
      width: 36px; height: 4px; background: var(--outline);
      border-radius: 2px; margin: 0 auto 12px; opacity: 0.6;
    }
    .modal-title { font-size: 16px; font-weight: 600; margin-bottom: 10px; }

    /* ========== Bottom tab bar ========== */
    .tab-bar {
      position: fixed;
      left: 0; right: 0; bottom: 0;
      display: flex;
      background: color-mix(in srgb, var(--surface-container-lowest) 92%, transparent);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      border-top: 1px solid var(--outline-variant);
      padding-top: 4px;
      padding-bottom: calc(env(safe-area-inset-bottom) + 4px);
      z-index: 8;
    }
    .tab-bar .item {
      flex: 1;
      padding: 6px 4px;
      text-align: center;
      font-size: 11px;
      color: var(--on-surface-variant);
      cursor: pointer;
      background: none;
      border: none;
      font-family: inherit;
      transition: color 0.15s;
    }
    .tab-bar .item.is-active { color: var(--primary); font-weight: 500; }
    .tab-bar .icon { font-size: 20px; line-height: 1.2; display: block; margin-bottom: 2px; }
    .bottom-spacer { height: 80px; }

    /* ========== Poster grid ========== */
    .poster-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(108px, 1fr));
      gap: 12px;
    }
    .poster-card { cursor: pointer; }
    .poster-card img {
      width: 100%;
      aspect-ratio: 7 / 10;
      border-radius: 10px;
      object-fit: cover;
      background: var(--surface-container-high);
      box-shadow: var(--shadow-1);
      display: block;
    }
    .poster-card .name {
      font-size: 13px;
      margin-top: 6px;
      line-height: 1.35;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    .poster-card .score {
      font-size: 12px;
      color: var(--primary);
      font-weight: 500;
      margin-top: 2px;
    }

    /* ========== Day chips ========== */
    .day-chips {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      scrollbar-width: none;
      margin-bottom: 14px;
      padding-bottom: 2px;
    }
    .day-chips::-webkit-scrollbar { display: none; }
    .day-chip {
      flex-shrink: 0;
      padding: 8px 14px;
      border-radius: 18px;
      background: var(--surface-container);
      border: 1px solid var(--outline-variant);
      font-size: 13px;
      cursor: pointer;
      transition: background 0.15s;
    }
    .day-chip.is-active {
      background: var(--primary);
      color: var(--on-primary);
      border-color: var(--primary);
    }

    /* ========== History row ========== */
    .history-row {
      display: flex;
      gap: 12px;
      background: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--radius-md);
      padding: 10px 12px;
      margin-bottom: 8px;
      cursor: pointer;
      transition: background 0.15s;
    }
    .history-row:hover { background: var(--surface-container-high); }
    .history-row img {
      width: 54px; height: 76px;
      border-radius: 6px;
      object-fit: cover;
      flex-shrink: 0;
      background: var(--surface-container-high);
    }
    .history-row .meta { min-width: 0; flex: 1; display: flex; flex-direction: column; gap: 4px; }
    .history-row .name { font-size: 14px; font-weight: 500; line-height: 1.35; overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
    .history-row .sub { font-size: 12px; color: var(--on-surface-variant); }

    /* ========== Collect ========== */
    .collect-row {
      display: flex;
      gap: 8px;
      align-items: center;
      margin: 12px 0 4px;
      flex-wrap: wrap;
    }
    .collect-btn {
      background: var(--primary-container);
      color: var(--on-primary-container);
      border: 1px solid transparent;
      padding: 9px 18px;
      border-radius: 18px;
      font: inherit;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      transition: background 0.15s;
    }
    .collect-btn.is-collected { background: var(--primary); color: var(--on-primary); }
    .collect-row .hint { font-size: 12px; color: var(--on-surface-variant); }

    /* ========== Player wrap + danmaku ========== */
    .player-wrap {
      position: relative;
      border-radius: var(--radius-md);
      overflow: hidden;
      box-shadow: var(--shadow-2);
      background: #000;
    }
    .player-wrap video {
      border-radius: 0;
      box-shadow: none;
      display: block;
    }
    .danmaku-canvas {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
    }
    .danmaku-canvas.is-hidden { display: none; }

    .danmaku-panel {
      background: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--radius-md);
      padding: 4px 12px;
      margin-top: 12px;
    }
    .danmaku-panel summary {
      cursor: pointer;
      padding: 10px 0;
      font-size: 13px;
      color: var(--on-surface-variant);
      font-weight: 500;
      list-style: none;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .danmaku-panel summary::-webkit-details-marker { display: none; }
    .danmaku-panel summary::after { content: "▾"; margin-left: auto; opacity: 0.7; }
    .danmaku-panel[open] summary::after { content: "▴"; }
    .danmaku-panel summary .count { font-weight: 400; opacity: 0.7; }
    .danmaku-panel .row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 0;
      font-size: 13px;
      gap: 12px;
    }
    .danmaku-panel input[type="range"] { flex: 1; max-width: 60%; }
    .danmaku-panel input[type="checkbox"] { accent-color: var(--primary); width: 18px; height: 18px; }

    /* ========== Footer ========== */
    .footer {
      margin-top: 32px;
      font-size: 11px;
      color: var(--on-surface-variant);
      text-align: center;
      opacity: 0.6;
      letter-spacing: 0.5px;
    }

    /* iOS Safari focus outline cleanup */
    select:focus-visible, input:focus-visible, button:focus-visible {
      outline: 2px solid var(--primary);
      outline-offset: 2px;
    }
  </style>
</head>
<body>
  <div class="app-bar" id="app-bar">
    <button class="icon-btn" id="back-btn" hidden aria-label="返回">&#x2190;</button>
    <div class="title" id="bar-title">Kazumi</div>
  </div>
  <div class="container" id="app"></div>
  <script>
    "use strict";

    const $app = document.getElementById("app");
    const $barTitle = document.getElementById("bar-title");
    const $backBtn = document.getElementById("back-btn");

    $backBtn.addEventListener("click", () => history.back());

    // ====== Theme ======
    function applyTheme(theme) {
      const root = document.documentElement;
      const mode = theme.themeMode || "system";
      root.dataset.theme = mode === "system" ? "auto" : mode;
      if (theme.primaryColor) {
        root.style.setProperty("--primary", theme.primaryColor);
        // 简单地用 70% 主色 + 加深做 on-primary-container；不追求和 Flutter
        // 的 ColorScheme.fromSeed 完全一致，能视觉关联即可
        root.style.setProperty(
          "--primary-container",
          hexToRgba(theme.primaryColor, 0.16)
        );
      }
    }

    function hexToRgba(hex, alpha) {
      const m = /^#([0-9a-f]{6})$/i.exec(hex);
      if (!m) return hex;
      const n = parseInt(m[1], 16);
      const r = (n >> 16) & 0xff;
      const g = (n >> 8) & 0xff;
      const b = n & 0xff;
      return "rgba(" + r + ", " + g + ", " + b + ", " + alpha + ")";
    }

    async function loadTheme() {
      try {
        const t = await fetchJson("/api/theme");
        applyTheme(t);
      } catch (_) {
        // 静默：默认 :root 配色仍可用
      }
    }

    // ====== Router ======
    function parseRoute() {
      const raw = location.hash.slice(1) || "/home";
      const [path, query] = raw.split("?");
      const params = {};
      if (query) {
        for (const pair of query.split("&")) {
          if (!pair) continue;
          const [k, v] = pair.split("=").map(decodeURIComponent);
          params[k] = v ?? "";
        }
      }
      return { path, params };
    }
    function go(path, params) {
      const qs = params
        ? "?" + Object.entries(params).map(([k, v]) => encodeURIComponent(k) + "=" + encodeURIComponent(v)).join("&")
        : "";
      location.hash = "#" + path + qs;
    }

    // ====== DOM helpers ======
    function el(tag, attrs, ...children) {
      const node = document.createElement(tag);
      for (const [k, v] of Object.entries(attrs || {})) {
        if (k === "onclick") node.addEventListener("click", v);
        else if (k === "class") node.className = v;
        else if (k === "html") node.innerHTML = v;
        else if (v === true) node.setAttribute(k, "");
        else if (v === false || v == null) continue;
        else node.setAttribute(k, v);
      }
      for (const c of children) {
        if (c == null || c === false) continue;
        node.append(typeof c === "string" || typeof c === "number" ? document.createTextNode(String(c)) : c);
      }
      return node;
    }
    function setStatus(parent, msg, isError) {
      parent.innerHTML = "";
      parent.append(el("div", { class: "status" + (isError ? " error" : "") }, msg));
    }

    async function fetchJson(url) {
      const res = await fetch(url);
      if (!res.ok) {
        let detail = res.statusText;
        try {
          const body = await res.json();
          if (body && body.message) detail = body.message;
        } catch (_) {}
        throw new Error("HTTP " + res.status + ": " + detail);
      }
      return res.json();
    }

    function setBar(title, showBack) {
      $barTitle.textContent = title;
      if (showBack) $backBtn.removeAttribute("hidden");
      else $backBtn.setAttribute("hidden", "");
    }

    // ====== Modal ======
    function openModal(builder) {
      const mask = el("div", { class: "modal-mask" });
      const sheet = el("div", { class: "modal-sheet" });
      sheet.append(el("div", { class: "modal-handle" }));
      mask.append(sheet);
      mask.addEventListener("click", (ev) => {
        if (ev.target === mask) mask.remove();
      });
      const close = () => mask.remove();
      builder(sheet, close);
      document.body.append(mask);
      return close;
    }

    // ====== Bangumi helpers ======
    function bestBangumiImage(images) {
      if (!images) return "";
      return images.large || images.common || images.medium || images.small || images.grid || "";
    }
    function renderStars(score) {
      if (!score || score <= 0) return "";
      const full = Math.floor(score / 2);
      const half = score - full * 2 >= 1 ? 1 : 0;
      const empty = 5 - full - half;
      return "★".repeat(full) + (half ? "☆" : "") + "·".repeat(empty);
    }

    // ====== Views ======
    async function renderHome(params) {
      const tab = (params && params.tab) || "popular";
      setBar("Kazumi", false);
      $app.innerHTML = "";

      const main = el("div", { id: "home-main" });
      $app.append(main);

      if (tab === "popular") renderTabPopular(main);
      else if (tab === "timeline") renderTabTimeline(main);
      else if (tab === "collect") renderTabCollect(main);
      else if (tab === "my") renderTabMy(main);
      else renderTabPopular(main);

      $app.append(el("div", { class: "bottom-spacer" }));
      $app.append(buildTabBar(tab));
    }

    function buildTabBar(activeTab) {
      const tabs = [
        { key: "popular",  icon: "★",  label: "推荐" },
        { key: "timeline", icon: "📅", label: "时间表" },
        { key: "collect",  icon: "♥",  label: "追番" },
        { key: "my",       icon: "☰",  label: "我的" },
      ];
      const bar = el("div", { class: "tab-bar" });
      for (const t of tabs) {
        const btn = el(
          "button",
          {
            class: "item" + (t.key === activeTab ? " is-active" : ""),
            onclick: () => go("/home", { tab: t.key }),
          },
          el("span", { class: "icon" }, t.icon),
          el("span", {}, t.label)
        );
        bar.append(btn);
      }
      return bar;
    }

    function buildPosterCard(item) {
      const img = el("img", { loading: "lazy", referrerpolicy: "no-referrer", alt: "" });
      const src = bestBangumiImage(item.images);
      if (src) img.src = src;
      const card = el(
        "div",
        {
          class: "poster-card",
          onclick: () => go("/bangumi", { id: String(item.id) }),
        },
        img,
        el("div", { class: "name" }, item.nameCn || item.name),
        item.ratingScore > 0
          ? el("div", { class: "score" }, "★ " + item.ratingScore.toFixed(1))
          : null
      );
      return card;
    }

    async function renderTabPopular(container) {
      // 顶部：bangumi 搜索
      const input = el("input", {
        type: "search",
        placeholder: "搜索番剧（Bangumi）",
        autocomplete: "off",
        autocorrect: "off",
        spellcheck: "false",
      });
      input.value = localStorage.getItem("lastBangumiKeyword") || "";
      const submit = el("button", { class: "submit", "aria-label": "搜索", type: "submit", html: "&#x2192;" });
      const form = el("form", { class: "search-bar" }, input, submit);
      form.addEventListener("submit", (ev) => {
        ev.preventDefault();
        const keyword = input.value.trim();
        if (!keyword) return;
        localStorage.setItem("lastBangumiKeyword", keyword);
        runBangumiSearch(keyword);
      });
      container.append(form);

      const results = el("div", { class: "list", id: "bangumi-results" });
      container.append(results);

      container.append(el("h2", {}, "趋势"));
      const grid = el("div", { class: "poster-grid" });
      container.append(grid);
      setStatus(grid, "加载中…");
      try {
        const data = await fetchJson("/api/popular");
        grid.innerHTML = "";
        if (!data.items || !data.items.length) {
          setStatus(grid, "暂无趋势数据");
        } else {
          for (const item of data.items) grid.append(buildPosterCard(item));
        }
      } catch (e) {
        setStatus(grid, "加载失败：" + e.message, true);
      }

      if (input.value) runBangumiSearch(input.value);
    }

    async function renderTabTimeline(container) {
      const today = ((new Date().getDay() + 6) % 7) + 1; // 周一=1
      const chips = el("div", { class: "day-chips" });
      const grid = el("div", { class: "poster-grid" });
      container.append(chips, grid);
      setStatus(grid, "加载中…");
      const dayLabels = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"];
      try {
        const data = await fetchJson("/api/timeline");
        const days = data.days || [];
        let active = today;
        const renderDay = () => {
          grid.innerHTML = "";
          const list = days[active - 1] || [];
          if (!list.length) { setStatus(grid, "今日无番剧"); return; }
          for (const item of list) grid.append(buildPosterCard(item));
        };
        const renderChips = () => {
          chips.innerHTML = "";
          for (let i = 1; i <= 7; i++) {
            const len = (days[i - 1] || []).length;
            const c = el(
              "div",
              {
                class: "day-chip" + (i === active ? " is-active" : ""),
                onclick: () => { active = i; renderChips(); renderDay(); },
              },
              dayLabels[i] + " · " + len
            );
            chips.append(c);
          }
        };
        renderChips();
        renderDay();
      } catch (e) {
        setStatus(grid, "加载失败：" + e.message, true);
      }
    }

    async function renderTabCollect(container) {
      setStatus(container, "加载中…");
      try {
        const data = await fetchJson("/api/collect/list");
        container.innerHTML = "";
        const items = data.items || [];
        if (!items.length) {
          setStatus(container, "还没有收藏哦，去推荐页找一部番剧收藏看看吧");
          return;
        }
        const labels = { 1: "在看", 2: "想看", 3: "搁置", 4: "看过", 5: "抛弃" };
        const groups = { 1: [], 2: [], 3: [], 4: [], 5: [] };
        for (const it of items) {
          if (groups[it.type]) groups[it.type].push(it);
        }
        for (const type of [1, 2, 3, 4, 5]) {
          if (!groups[type].length) continue;
          container.append(el("h2", {}, labels[type] + " · " + groups[type].length));
          const grid = el("div", { class: "poster-grid" });
          for (const c of groups[type]) grid.append(buildPosterCard(c.bangumi));
          container.append(grid);
        }
      } catch (e) {
        setStatus(container, "加载失败：" + e.message, true);
      }
    }

    async function renderTabMy(container) {
      container.append(el("h2", {}, "观看历史"));
      const list = el("div", {});
      container.append(list);
      setStatus(list, "加载中…");
      try {
        const data = await fetchJson("/api/history/list");
        const items = data.items || [];
        list.innerHTML = "";
        if (!items.length) {
          setStatus(list, "还没有观看记录");
        } else {
          for (const h of items) {
            const img = el("img", { loading: "lazy", referrerpolicy: "no-referrer", alt: "" });
            const src = bestBangumiImage(h.bangumi.images);
            if (src) img.src = src;
            const epName = h.lastWatchEpisodeName || ("第 " + h.lastWatchEpisode + " 集");
            const lastDate = new Date(h.lastWatchTime);
            const dateStr = lastDate.toLocaleString();
            list.append(
              el(
                "div",
                {
                  class: "history-row",
                  onclick: () => go("/bangumi", { id: String(h.bangumiId) }),
                },
                img,
                el(
                  "div",
                  { class: "meta" },
                  el("div", { class: "name" }, h.bangumi.nameCn || h.bangumi.name),
                  el("div", { class: "sub" }, "上次：" + epName + " · " + dateStr),
                  el("div", { class: "sub" }, "规则：" + h.pluginName)
                )
              )
            );
          }
        }
      } catch (e) {
        setStatus(list, "加载失败：" + e.message, true);
      }

      container.append(el("div", { class: "footer" }, "Kazumi · Web 预览 · 实验性"));
    }

    async function runBangumiSearch(keyword) {
      const results = document.getElementById("bangumi-results");
      if (!results) return;
      setStatus(results, "搜索中…");
      try {
        const data = await fetchJson("/api/bangumi/search?keyword=" + encodeURIComponent(keyword));
        results.innerHTML = "";
        if (!data.items || !data.items.length) {
          setStatus(results, "没有结果");
          return;
        }
        for (const item of data.items) {
          results.append(buildBangumiCard(item));
        }
      } catch (e) {
        setStatus(results, "搜索失败：" + e.message, true);
      }
    }

    function buildBangumiCard(item) {
      const img = el("img", {
        class: "cover",
        loading: "lazy",
        alt: "",
        referrerpolicy: "no-referrer",
      });
      const cover = bestBangumiImage(item.images);
      if (cover) img.src = cover;
      const tagsRow = el("div", { class: "meta" });
      if (item.ratingScore > 0) {
        tagsRow.append(el("span", { class: "score" }, item.ratingScore.toFixed(1)));
      }
      if (item.airDate) tagsRow.append(el("span", {}, item.airDate));
      const info = el(
        "div",
        { class: "info" },
        el("div", { class: "name" }, item.nameCn || item.name),
        item.nameCn && item.name && item.nameCn !== item.name
          ? el("div", { class: "alt" }, item.name)
          : null,
        item.summary
          ? el("div", { class: "summary" }, item.summary)
          : null,
        tagsRow
      );
      const card = el("div", { class: "bangumi-card" }, img, info);
      card.addEventListener("click", () => go("/bangumi", { id: String(item.id) }));
      return card;
    }

    // 旧的 plugin 搜索保留：详情页"开始观看"选源 modal 复用它
    async function pluginSearchOnce(pluginName, keyword) {
      const data = await fetchJson(
        "/api/search?plugin=" + encodeURIComponent(pluginName) + "&keyword=" + encodeURIComponent(keyword)
      );
      return data.items || [];
    }

    async function renderBangumiDetail(params) {
      const id = parseInt(params.id, 10);
      if (!id) { go("/home"); return; }
      setBar("番剧详情", true);
      $app.innerHTML = "";

      const skeleton = el("div", { class: "status" }, "加载中…");
      $app.append(skeleton);

      let bangumi;
      try {
        bangumi = await fetchJson("/api/bangumi/" + id);
      } catch (e) {
        skeleton.remove();
        setStatus($app, "加载番剧详情失败：" + e.message, true);
        return;
      }
      skeleton.remove();

      // Hero
      const cover = bestBangumiImage(bangumi.images);
      const hero = el("div", { class: "hero" });
      if (cover) hero.style.setProperty("--hero-bg", "url('" + cover + "')");
      const coverImg = el("img", { class: "hero-cover", loading: "lazy", alt: "", referrerpolicy: "no-referrer" });
      if (cover) coverImg.src = cover;
      const heroMeta = el("div", { class: "hero-meta" });
      heroMeta.append(el("div", { class: "hero-title" }, bangumi.nameCn || bangumi.name));
      if (bangumi.name && bangumi.nameCn && bangumi.name !== bangumi.nameCn) {
        heroMeta.append(el("div", { class: "hero-alt" }, bangumi.name));
      }
      if (bangumi.ratingScore > 0) {
        const stat = el("div", { class: "hero-stat" });
        stat.append(el("span", { class: "hero-score" }, bangumi.ratingScore.toFixed(1)));
        const stars = renderStars(bangumi.ratingScore);
        if (stars) stat.append(el("span", { class: "hero-stars" }, stars));
        if (bangumi.votes > 0) stat.append(el("span", { class: "hero-votes" }, bangumi.votes + " 人评分"));
        if (bangumi.rank > 0) stat.append(el("span", { class: "hero-rank" }, "Rank #" + bangumi.rank));
        heroMeta.append(stat);
      }
      if (bangumi.airDate) heroMeta.append(el("div", { class: "hero-alt" }, "上映：" + bangumi.airDate));
      if (Array.isArray(bangumi.tags) && bangumi.tags.length) {
        const chips = el("div", { class: "chips" });
        for (const t of bangumi.tags.slice(0, 10)) {
          chips.append(el("span", { class: "chip" }, t.name));
        }
        heroMeta.append(chips);
      }
      hero.append(el("div", { class: "hero-row" }, coverImg, heroMeta));
      $app.append(hero);

      // Collect row
      const collectRow = el("div", { class: "collect-row" });
      const collectBtn = el("button", { class: "collect-btn" }, "+ 收藏");
      const collectHint = el("span", { class: "hint" });
      collectRow.append(collectBtn, collectHint);
      $app.append(collectRow);

      const collectTypes = [
        { value: 1, label: "在看" },
        { value: 2, label: "想看" },
        { value: 3, label: "搁置" },
        { value: 4, label: "看过" },
        { value: 5, label: "抛弃" },
      ];
      const collectLabelOf = (t) => (collectTypes.find((x) => x.value === t) || {}).label || "";
      const updateCollectBtn = (type) => {
        if (type === 0 || type == null) {
          collectBtn.className = "collect-btn";
          collectBtn.textContent = "+ 收藏";
        } else {
          collectBtn.className = "collect-btn is-collected";
          collectBtn.textContent = "已" + collectLabelOf(type);
        }
      };
      let currentCollectType = 0;
      fetchJson("/api/collect?bangumiId=" + id)
        .then((data) => {
          currentCollectType = data.type || 0;
          updateCollectBtn(currentCollectType);
        })
        .catch(() => {});
      collectBtn.addEventListener("click", () => {
        openModal((sheet, _close) => {
          sheet.append(el("div", { class: "modal-title" }, "选择收藏状态"));
          const list = el("div", { class: "list" });
          for (const t of collectTypes) {
            const node = el(
              "div",
              { class: "item" },
              t.label + (t.value === currentCollectType ? " · 当前" : "")
            );
            node.addEventListener("click", async () => {
              try {
                const res = await fetch("/api/collect", {
                  method: "PUT",
                  headers: { "content-type": "application/json" },
                  body: JSON.stringify({ bangumiId: id, type: t.value }),
                });
                if (!res.ok) throw new Error("HTTP " + res.status);
                const body = await res.json();
                currentCollectType = body.type;
                updateCollectBtn(currentCollectType);
                _close();
              } catch (e) {
                collectHint.textContent = "保存失败：" + e.message;
              }
            });
            list.append(node);
          }
          if (currentCollectType !== 0) {
            const removeBtn = el("button", { class: "tonal" }, "取消收藏");
            removeBtn.style.marginTop = "10px";
            removeBtn.style.width = "100%";
            removeBtn.addEventListener("click", async () => {
              try {
                const res = await fetch("/api/collect?bangumiId=" + id, { method: "DELETE" });
                if (!res.ok) throw new Error("HTTP " + res.status);
                currentCollectType = 0;
                updateCollectBtn(0);
                _close();
              } catch (e) {
                collectHint.textContent = "删除失败：" + e.message;
              }
            });
            sheet.append(list, removeBtn);
          } else {
            sheet.append(list);
          }
        });
      });

      // Tabs
      const tabBar = el("div", { class: "tabs" });
      const tabBody = el("div", {});
      const tabs = [
        { key: "summary", label: "简介" },
        { key: "characters", label: "角色" },
        { key: "staff", label: "制作" },
        { key: "comments", label: "吐槽" },
      ];
      const tabNodes = {};
      let activeTab = "summary";
      const switchTab = (key) => {
        activeTab = key;
        for (const k of Object.keys(tabNodes)) {
          tabNodes[k].classList.toggle("is-active", k === key);
        }
        renderTabBody(key);
      };
      for (const t of tabs) {
        const node = el("div", { class: "tab" + (t.key === activeTab ? " is-active" : "") }, t.label);
        node.addEventListener("click", () => switchTab(t.key));
        tabNodes[t.key] = node;
        tabBar.append(node);
      }
      $app.append(tabBar);
      $app.append(tabBody);

      function renderTabBody(key) {
        tabBody.innerHTML = "";
        if (key === "summary") renderSummary();
        else if (key === "characters") renderCharacters();
        else if (key === "staff") renderStaff();
        else if (key === "comments") renderComments();
      }

      function renderSummary() {
        if (!bangumi.summary) {
          tabBody.append(el("div", { class: "status" }, "暂无简介"));
          return;
        }
        const card = el("div", { class: "summary-card collapsed" }, bangumi.summary);
        const toggle = el("button", { class: "summary-toggle" }, "展开");
        toggle.addEventListener("click", () => {
          const expanded = card.classList.toggle("collapsed");
          toggle.textContent = expanded ? "展开" : "收起";
        });
        tabBody.append(card, toggle);
        if (Array.isArray(bangumi.alias) && bangumi.alias.length) {
          tabBody.append(el("h2", {}, "别名"));
          const chips = el("div", { class: "chips" });
          for (const a of bangumi.alias) chips.append(el("span", { class: "chip" }, a));
          tabBody.append(chips);
        }
      }

      async function renderCharacters() {
        tabBody.append(el("div", { class: "status" }, "加载中…"));
        try {
          const data = await fetchJson("/api/bangumi/" + id + "/characters");
          tabBody.innerHTML = "";
          if (!data.characters || !data.characters.length) {
            tabBody.append(el("div", { class: "status" }, "暂无角色"));
            return;
          }
          const grid = el("div", { class: "char-grid" });
          for (const c of data.characters) {
            const img = el("img", { loading: "lazy", alt: "", referrerpolicy: "no-referrer" });
            if (c.image) img.src = c.image;
            const actors = (c.actors || []).map((a) => a.name).filter(Boolean).join(" / ");
            grid.append(
              el(
                "div",
                { class: "char-card" },
                img,
                el(
                  "div",
                  { class: "meta" },
                  el("div", { class: "name" }, c.name),
                  el("div", { class: "relation" }, c.relation || ""),
                  actors ? el("div", { class: "char-actors" }, "CV：" + actors) : null
                )
              )
            );
          }
          tabBody.append(grid);
        } catch (e) {
          tabBody.innerHTML = "";
          setStatus(tabBody, "加载失败：" + e.message, true);
        }
      }

      async function renderStaff() {
        tabBody.append(el("div", { class: "status" }, "加载中…"));
        try {
          const data = await fetchJson("/api/bangumi/" + id + "/staff");
          tabBody.innerHTML = "";
          if (!data.items || !data.items.length) {
            tabBody.append(el("div", { class: "status" }, "暂无制作信息"));
            return;
          }
          const grid = el("div", { class: "staff-grid" });
          for (const s of data.items) {
            const img = el("img", { loading: "lazy", alt: "", referrerpolicy: "no-referrer" });
            if (s.image) img.src = s.image;
            const positions = (s.positions || []).map((p) => p.type).filter(Boolean).join(" / ");
            grid.append(
              el(
                "div",
                { class: "staff-card" },
                img,
                el(
                  "div",
                  { class: "meta" },
                  el("div", { class: "name" }, s.nameCN || s.name),
                  el("div", { class: "position" }, positions)
                )
              )
            );
          }
          tabBody.append(grid);
        } catch (e) {
          tabBody.innerHTML = "";
          setStatus(tabBody, "加载失败：" + e.message, true);
        }
      }

      async function renderComments() {
        tabBody.append(el("div", { class: "status" }, "加载中…"));
        try {
          const data = await fetchJson("/api/bangumi/" + id + "/comments");
          tabBody.innerHTML = "";
          if (!data.items || !data.items.length) {
            tabBody.append(el("div", { class: "status" }, "暂无吐槽"));
            return;
          }
          for (const c of data.items) {
            const head = el("div", { class: "comment-head" });
            const avatar = el("img", { alt: "", referrerpolicy: "no-referrer" });
            if (c.user && c.user.avatar) avatar.src = c.user.avatar;
            head.append(avatar);
            head.append(el("span", { class: "username" }, (c.user && (c.user.nickname || c.user.username)) || "用户"));
            if (c.rate > 0) head.append(el("span", { class: "rate" }, "★ " + c.rate));
            tabBody.append(
              el(
                "div",
                { class: "comment-card" },
                head,
                el("div", { class: "comment-body" }, c.comment)
              )
            );
          }
        } catch (e) {
          tabBody.innerHTML = "";
          setStatus(tabBody, "加载失败：" + e.message, true);
        }
      }

      renderTabBody("summary");

      // FAB: 开始观看
      const fab = el("button", { class: "fab" }, "开始观看");
      fab.addEventListener("click", () => openSourcePicker(bangumi));
      $app.append(fab);
    }

    async function openSourcePicker(bangumi) {
      const close = openModal(async (sheet, _close) => {
        sheet.append(el("div", { class: "modal-title" }, "选择视频源"));

        let plugins = [];
        try {
          plugins = await fetchJson("/api/plugins");
        } catch (e) {
          sheet.append(el("div", { class: "status error" }, "加载规则失败：" + e.message));
          return;
        }
        if (!plugins.length) {
          sheet.append(el("div", { class: "status" }, "当前没有可用规则"));
          return;
        }

        const select = el("select", {});
        for (const p of plugins) select.append(el("option", { value: p.name }, p.name));
        const lastPlugin = localStorage.getItem("lastPlugin");
        if (lastPlugin && plugins.some((p) => p.name === lastPlugin)) select.value = lastPlugin;

        const keywordInput = el("input", {
          type: "search",
          placeholder: "搜索关键词",
          autocomplete: "off",
          autocorrect: "off",
          spellcheck: "false",
        });
        keywordInput.value = bangumi.nameCn || bangumi.name;

        const submit = el("button", { class: "submit", type: "submit", "aria-label": "搜索", html: "&#x2192;" });
        const form = el("form", { class: "search-bar" }, select, keywordInput, submit);
        sheet.append(form);

        const list = el("div", { class: "list" });
        sheet.append(list);

        const run = async () => {
          setStatus(list, "搜索中…");
          try {
            const items = await pluginSearchOnce(select.value, keywordInput.value.trim());
            list.innerHTML = "";
            if (!items.length) { setStatus(list, "没有结果"); return; }
            for (const item of items) {
              list.append(
                el(
                  "div",
                  {
                    class: "item",
                    onclick: () => {
                      localStorage.setItem("lastPlugin", select.value);
                      _close();
                      go("/episodes", {
                        plugin: select.value,
                        src: item.src,
                        title: bangumi.nameCn || bangumi.name,
                        bid: String(bangumi.id),
                      });
                    },
                  },
                  item.name
                )
              );
            }
          } catch (e) {
            setStatus(list, "搜索失败：" + e.message, true);
          }
        };
        form.addEventListener("submit", (ev) => { ev.preventDefault(); run(); });
        run();
      });
      return close;
    }

    async function renderEpisodes(params) {
      const { plugin, src, title, bid } = params;
      setBar(title || "选择集数", true);
      $app.innerHTML = "";
      $app.append(el("h2", {}, "规则 · " + plugin));

      const container = el("div", {});
      $app.append(container);
      setStatus(container, "加载中…");

      try {
        const data = await fetchJson(
          "/api/episodes?plugin=" + encodeURIComponent(plugin) + "&src=" + encodeURIComponent(src)
        );
        container.innerHTML = "";
        if (!data.roads || !data.roads.length) {
          setStatus(container, "没有可用的播放列表");
          return;
        }
        data.roads.forEach((road, roadIdx) => {
          container.append(el("h2", {}, road.name));
          const grid = el("div", { class: "ep-grid" });
          road.episodes.forEach((ep, epIdx) => {
            const params = {
              plugin,
              episodeUrl: ep.src,
              title: (title ? title + " · " : "") + ep.name,
              episode: String(epIdx + 1),
              road: String(roadIdx),
            };
            if (bid) params.bid = bid;
            const cell = el(
              "div",
              { class: "ep", onclick: () => go("/play", params) },
              ep.name
            );
            grid.append(cell);
          });
          container.append(grid);
        });
      } catch (e) {
        setStatus(container, "加载失败：" + e.message, true);
      }
    }

    // ====== Danmaku ======
    class DanmakuLayer {
      constructor(video, container) {
        this.video = video;
        this.canvas = document.createElement("canvas");
        this.canvas.className = "danmaku-canvas";
        container.append(this.canvas);
        this.ctx = this.canvas.getContext("2d");
        this.items = [];
        this.cursor = 0;
        this.activeRolling = [];
        this.activeFixed = [];
        this.lanes = { rolling: [], top: [], bottom: [] };
        this.lineH = 28;
        this.lastVideoTime = 0;
        this.lastTickAt = 0;
        this.rafId = null;
        this.config = this.loadConfig();
        this.applyVisibility();

        this.resizeObs = new ResizeObserver(() => this.resize());
        this.resizeObs.observe(container);
        this.resize();
        this.start();
      }

      loadConfig() {
        try {
          const stored = JSON.parse(localStorage.getItem("danmakuConfig") || "{}");
          return {
            enabled: stored.enabled !== false,
            fontSize: stored.fontSize || 22,
            opacity: typeof stored.opacity === "number" ? stored.opacity : 0.8,
            speed: stored.speed || 10,
          };
        } catch (_) {
          return { enabled: true, fontSize: 22, opacity: 0.8, speed: 10 };
        }
      }

      saveConfig() {
        try {
          localStorage.setItem("danmakuConfig", JSON.stringify(this.config));
        } catch (_) {}
      }

      setConfig(patch) {
        Object.assign(this.config, patch);
        this.saveConfig();
        this.applyVisibility();
        this.recomputeLanes();
      }

      applyVisibility() {
        this.canvas.classList.toggle("is-hidden", !this.config.enabled);
      }

      resize() {
        const rect = this.canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        this.canvas.width = Math.max(1, Math.round(rect.width * dpr));
        this.canvas.height = Math.max(1, Math.round(rect.height * dpr));
        this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        this.cssWidth = rect.width;
        this.cssHeight = rect.height;
        this.recomputeLanes();
      }

      recomputeLanes() {
        const lineH = this.config.fontSize + 6;
        this.lineH = lineH;
        const maxLanes = Math.max(1, Math.floor(this.cssHeight * 0.75 / lineH));
        const reset = (arr) => {
          const out = new Array(maxLanes).fill(0);
          for (let i = 0; i < Math.min(arr.length, maxLanes); i++) out[i] = arr[i];
          return out;
        };
        this.lanes.rolling = reset(this.lanes.rolling);
        this.lanes.top = reset(this.lanes.top);
        this.lanes.bottom = reset(this.lanes.bottom);
      }

      load(items) {
        this.items = (items || []).slice().sort((a, b) => a.time - b.time);
        this.cursor = 0;
        this.activeRolling = [];
        this.activeFixed = [];
        this.lanes.rolling = this.lanes.rolling.map(() => 0);
        this.lanes.top = this.lanes.top.map(() => 0);
        this.lanes.bottom = this.lanes.bottom.map(() => 0);
      }

      get count() { return this.items.length; }

      start() {
        if (this.rafId != null) return;
        const tick = (now) => {
          if (!this.lastTickAt) this.lastTickAt = now;
          const dt = Math.min(0.1, (now - this.lastTickAt) / 1000);
          this.lastTickAt = now;
          this.update(dt);
          this.render();
          this.rafId = requestAnimationFrame(tick);
        };
        this.rafId = requestAnimationFrame(tick);
      }

      stop() {
        if (this.rafId != null) cancelAnimationFrame(this.rafId);
        this.rafId = null;
      }

      dispose() {
        this.stop();
        try { this.resizeObs.disconnect(); } catch (_) {}
        this.canvas.remove();
      }

      update(dt) {
        if (!this.config.enabled || !this.items.length || !this.video) return;
        const now = this.video.currentTime;
        if (Math.abs(now - this.lastVideoTime) > 1) {
          // seek
          let lo = 0, hi = this.items.length;
          while (lo < hi) {
            const mid = (lo + hi) >> 1;
            if (this.items[mid].time < now) lo = mid + 1; else hi = mid;
          }
          this.cursor = lo;
          this.activeRolling = [];
          this.activeFixed = [];
        }
        this.lastVideoTime = now;
        if (this.video.paused) return;

        while (this.cursor < this.items.length && this.items[this.cursor].time <= now) {
          this.emit(this.items[this.cursor]);
          this.cursor++;
        }

        for (const d of this.activeRolling) d.x -= d.speed * dt;
        this.activeRolling = this.activeRolling.filter((d) => d.x + d.width > 0);
        this.activeFixed = this.activeFixed.filter((d) => now < d.endTime);
      }

      emit(item) {
        const W = this.cssWidth, H = this.cssHeight;
        this.ctx.font = this.config.fontSize + "px sans-serif";
        const width = this.ctx.measureText(item.message).width;
        const color = "#" + (item.color || 0xffffff).toString(16).padStart(6, "0");
        if (item.type === 1) {
          const duration = this.config.speed;
          const speed = (W + width) / duration;
          const now = this.video.currentTime;
          let laneIdx = -1;
          for (let i = 0; i < this.lanes.rolling.length; i++) {
            if (this.lanes.rolling[i] <= now) { laneIdx = i; break; }
          }
          if (laneIdx < 0) return;
          this.lanes.rolling[laneIdx] = now + width / speed + 0.3;
          this.activeRolling.push({
            message: item.message, x: W, y: laneIdx * this.lineH + this.config.fontSize,
            speed, width, color,
          });
        } else if (item.type === 4 || item.type === 5) {
          const top = item.type === 5;
          const lanes = top ? this.lanes.top : this.lanes.bottom;
          const now = this.video.currentTime;
          let laneIdx = -1;
          for (let i = 0; i < lanes.length; i++) {
            if (lanes[i] <= now) { laneIdx = i; break; }
          }
          if (laneIdx < 0) return;
          const duration = 4;
          lanes[laneIdx] = now + duration;
          const y = top
            ? laneIdx * this.lineH + this.config.fontSize + 4
            : H - laneIdx * this.lineH - 8;
          this.activeFixed.push({
            message: item.message, x: Math.max(4, (W - width) / 2), y,
            width, color, endTime: now + duration,
          });
        }
      }

      render() {
        if (!this.config.enabled) return;
        const ctx = this.ctx;
        ctx.clearRect(0, 0, this.cssWidth, this.cssHeight);
        ctx.globalAlpha = this.config.opacity;
        ctx.font = this.config.fontSize + "px sans-serif";
        ctx.textBaseline = "alphabetic";
        ctx.shadowColor = "rgba(0,0,0,0.85)";
        ctx.shadowBlur = 3;
        for (const d of this.activeRolling) {
          ctx.fillStyle = d.color;
          ctx.fillText(d.message, d.x, d.y);
        }
        for (const d of this.activeFixed) {
          ctx.fillStyle = d.color;
          ctx.fillText(d.message, d.x, d.y);
        }
      }
    }

    let activeDanmaku = null;
    function disposeDanmaku() {
      if (activeDanmaku) {
        try { activeDanmaku.dispose(); } catch (_) {}
        activeDanmaku = null;
      }
    }

    // ====== Progress reporting ======
    let activeProgressTimer = null;
    function disposeProgressReporter() {
      if (activeProgressTimer != null) {
        clearInterval(activeProgressTimer);
        activeProgressTimer = null;
      }
    }
    async function reportProgress(payload) {
      try {
        await fetch("/api/history/progress", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(payload),
        });
      } catch (_) {
        // 进度上报失败不打扰用户
      }
    }

    // 当前播放页持有的 hls.js 实例，跳出页面时销毁
    let activeHls = null;
    function disposeHls() {
      if (activeHls) {
        try { activeHls.destroy(); } catch (_) {}
        activeHls = null;
      }
    }

    // 懒加载 hls.js（只在需要时）
    let hlsLoaderPromise = null;
    function ensureHlsLoaded() {
      if (typeof Hls !== "undefined") return Promise.resolve();
      if (hlsLoaderPromise) return hlsLoaderPromise;
      hlsLoaderPromise = new Promise((resolve, reject) => {
        const s = document.createElement("script");
        s.src = "/assets/hls.min.js";
        s.async = true;
        s.onload = () => resolve();
        s.onerror = () => reject(new Error("hls.js 加载失败"));
        document.head.append(s);
      });
      return hlsLoaderPromise;
    }

    function nativeHlsSupported(video) {
      return !!(
        video.canPlayType("application/vnd.apple.mpegurl") ||
        video.canPlayType("application/x-mpegURL") ||
        video.canPlayType("audio/mpegurl")
      );
    }

    async function attachStream(video, data, onError) {
      const streamType = data.streamType || "unknown";
      const looksLikeHls = streamType === "hls" || /\.m3u8/i.test(data.originalUrl || "");

      if (looksLikeHls && !nativeHlsSupported(video)) {
        try {
          await ensureHlsLoaded();
        } catch (e) {
          onError("加载 hls.js 失败：" + e.message);
          return;
        }
        const hls = new Hls({
          enableWorker: true,
          lowLatencyMode: false,
        });
        activeHls = hls;
        hls.on(Hls.Events.ERROR, (_, info) => {
          if (info.fatal) {
            switch (info.type) {
              case Hls.ErrorTypes.NETWORK_ERROR:
                hls.startLoad();
                break;
              case Hls.ErrorTypes.MEDIA_ERROR:
                hls.recoverMediaError();
                break;
              default:
                onError("HLS 错误：" + (info.details || info.type));
                disposeHls();
            }
          }
        });
        hls.loadSource(data.playUrl);
        hls.attachMedia(video);
      } else {
        video.src = data.playUrl;
      }
    }

    async function renderPlayer(params) {
      disposeHls();
      disposeDanmaku();
      disposeProgressReporter();
      const { plugin, episodeUrl, title, bid, episode, road } = params;
      setBar(title || "播放", true);
      $app.innerHTML = "";

      const status = el("div", { class: "status" }, "正在解析视频源，可能需要几秒…");
      $app.append(status);

      try {
        const data = await fetchJson(
          "/api/resolve?plugin=" + encodeURIComponent(plugin) + "&episodeUrl=" + encodeURIComponent(episodeUrl)
        );
        status.remove();

        const video = el("video", {
          controls: true,
          playsinline: true,
          "webkit-playsinline": true,
          preload: "metadata",
        });
        const playerWrap = el("div", { class: "player-wrap" }, video);
        $app.append(playerWrap);

        const errorNode = el("div", { class: "status error" });
        errorNode.style.display = "none";
        $app.append(errorNode);
        const showError = (msg) => {
          errorNode.textContent = msg;
          errorNode.style.display = "block";
        };

        await attachStream(video, data, showError);

        const typeLabel =
          data.streamType === "hls"
            ? "HLS" + (nativeHlsSupported(video) ? "（原生）" : "（hls.js）")
            : data.streamType === "mp4"
              ? "MP4"
              : "直链";
        $app.append(
          el(
            "div",
            { class: "player-meta" },
            "规则：" + data.pluginName + " · 流：" + typeLabel + " · 源：" + data.originalUrl
          )
        );

        const reload = el("button", { class: "tonal" }, "重新解析");
        reload.addEventListener("click", () => renderPlayer(params));
        $app.append(el("div", { class: "player-actions" }, reload));

        video.addEventListener("error", () => {
          showError("播放器报告错误。可能是源失效或浏览器不支持该格式。");
        });

        // ====== 弹幕 ======
        const danmaku = new DanmakuLayer(video, playerWrap);
        activeDanmaku = danmaku;

        const danmakuPanel = el("details", { class: "danmaku-panel" });
        const summary = el("summary", {},
          "弹幕",
          el("span", { class: "count" }, "加载中…")
        );
        danmakuPanel.append(summary);
        const countNode = summary.querySelector(".count");

        // 开关
        const enabledRow = el("div", { class: "row" });
        const enabledCb = el("input", { type: "checkbox" });
        enabledCb.checked = danmaku.config.enabled;
        enabledCb.addEventListener("change", () => danmaku.setConfig({ enabled: enabledCb.checked }));
        enabledRow.append(el("span", {}, "开启弹幕"), enabledCb);
        danmakuPanel.append(enabledRow);

        // 字号
        const fontRow = el("div", { class: "row" });
        const fontInput = el("input", { type: "range", min: "14", max: "36", step: "1" });
        fontInput.value = String(danmaku.config.fontSize);
        const fontLabel = el("span", {}, "字号 " + fontInput.value);
        fontInput.addEventListener("input", () => {
          fontLabel.textContent = "字号 " + fontInput.value;
          danmaku.setConfig({ fontSize: parseInt(fontInput.value, 10) });
        });
        fontRow.append(fontLabel, fontInput);
        danmakuPanel.append(fontRow);

        // 透明度
        const opacityRow = el("div", { class: "row" });
        const opacityInput = el("input", { type: "range", min: "20", max: "100", step: "5" });
        opacityInput.value = String(Math.round(danmaku.config.opacity * 100));
        const opacityLabel = el("span", {}, "透明度 " + opacityInput.value + "%");
        opacityInput.addEventListener("input", () => {
          opacityLabel.textContent = "透明度 " + opacityInput.value + "%";
          danmaku.setConfig({ opacity: parseInt(opacityInput.value, 10) / 100 });
        });
        opacityRow.append(opacityLabel, opacityInput);
        danmakuPanel.append(opacityRow);

        // 滚动速度
        const speedRow = el("div", { class: "row" });
        const speedInput = el("input", { type: "range", min: "5", max: "20", step: "1" });
        speedInput.value = String(danmaku.config.speed);
        const speedLabel = el("span", {}, "滚动时长 " + speedInput.value + "s");
        speedInput.addEventListener("input", () => {
          speedLabel.textContent = "滚动时长 " + speedInput.value + "s";
          danmaku.setConfig({ speed: parseInt(speedInput.value, 10) });
        });
        speedRow.append(speedLabel, speedInput);
        danmakuPanel.append(speedRow);

        $app.append(danmakuPanel);

        // 拉弹幕（需要 bid + episode）
        if (bid && episode) {
          try {
            const dm = await fetchJson(
              "/api/danmaku?bangumiId=" + encodeURIComponent(bid) +
              "&episode=" + encodeURIComponent(episode)
            );
            danmaku.load(dm.items || []);
            countNode.textContent = "共 " + danmaku.count + " 条";
          } catch (e) {
            countNode.textContent = "加载失败";
          }
        } else {
          countNode.textContent = "需从番剧详情页打开才能加载弹幕";
        }

        // ====== 进度同步 ======
        if (bid && episode && plugin) {
          const epNum = parseInt(episode, 10);
          const roadNum = parseInt(road || "0", 10);
          // 取上次进度并 resume
          try {
            const data = await fetchJson(
              "/api/history?bangumiId=" + encodeURIComponent(bid) +
              "&pluginName=" + encodeURIComponent(plugin)
            );
            const history = data.history;
            const prog = history && history.progresses && history.progresses[String(epNum)];
            if (prog && prog.progressMs > 5000) {
              const seekTo = prog.progressMs / 1000;
              const doSeek = () => {
                if (Math.abs((video.currentTime || 0) - seekTo) > 2) {
                  try { video.currentTime = seekTo; } catch (_) {}
                }
              };
              if (video.readyState >= 1) doSeek();
              else video.addEventListener("loadedmetadata", doSeek, { once: true });
            }
          } catch (_) {}

          const epName = (title || "").split(" · ").pop() || "";
          const send = () => {
            const t = video.currentTime || 0;
            if (t < 5) return;
            reportProgress({
              bangumiId: parseInt(bid, 10),
              pluginName: plugin,
              episode: epNum,
              road: roadNum,
              progressMs: Math.floor(t * 1000),
              lastSrc: episodeUrl,
              episodeName: epName,
            });
          };
          activeProgressTimer = setInterval(send, 5000);
          // 暂停时立即上报一次
          video.addEventListener("pause", send);
          // 离开页面前再上报一次
          window.addEventListener("pagehide", send, { once: true });
        }
      } catch (e) {
        status.remove();
        $app.append(el("div", { class: "status error" }, "解析失败：" + e.message));
      }
    }

    // 离开播放页时销毁 hls.js + 弹幕 + 进度上报
    window.addEventListener("hashchange", () => {
      const { path } = parseRoute();
      if (path !== "/play") {
        disposeHls();
        disposeDanmaku();
        disposeProgressReporter();
      }
    });

    // ====== Dispatch ======
    function dispatch() {
      const { path, params } = parseRoute();
      if (path === "/home" || path === "/") return renderHome(params);
      if (path === "/bangumi") return renderBangumiDetail(params);
      if (path === "/episodes") return renderEpisodes(params);
      if (path === "/play") return renderPlayer(params);
      go("/home");
    }

    window.addEventListener("hashchange", dispatch);

    // 启动顺序：先拉主题（视觉不闪），再 dispatch
    loadTheme().finally(dispatch);
  </script>
</body>
</html>
''';
