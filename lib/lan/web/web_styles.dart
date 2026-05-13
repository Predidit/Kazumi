/// CSS 字符串：嵌入到 `lib/lan/web_index_html.dart` 的 `<style>` 块中。
///
/// 拆分前所有 CSS 都直接放在 web_index_html.dart 里；按职责拆出来后维护性
/// 与 diff 可读性显著提升。颜色/字号/形状的真值由 `lib/lan/theme_export.dart`
/// 生成、`/api/theme` 下发，前端 `applyTheme()` 注入到 `:root` 的 CSS 变量。
/// 这里的 `:root` 块只是兜底默认值，避免接入失败时页面完全无色。
const String lanWebCss = r'''
@font-face {
  font-family: "MiSans";
  src: url("/assets/MiSans-Regular.ttf") format("truetype");
  font-display: swap;
  font-weight: 400;
}

:root {
  --primary: #4CAF50;
  --on-primary: #ffffff;
  --primary-container: rgba(76, 175, 80, 0.16);
  --on-primary-container: #1d5224;

  --surface: #ffffff;
  --surface-container-lowest: #ffffff;
  --surface-container: #f5f5f7;
  --surface-container-high: #ebebef;
  --surface-container-highest: #e2e2e6;
  --on-surface: #181a1c;
  --on-surface-variant: #4a4d52;
  --outline: #b8b8be;
  --outline-variant: #e3e3e8;
  --error: #b3261e;

  --shadow-1: 0 1px 2px rgba(0,0,0,0.06), 0 1px 1px rgba(0,0,0,0.04);
  --shadow-2: 0 2px 8px rgba(0,0,0,0.10), 0 1px 3px rgba(0,0,0,0.04);

  --radius-sm: 10px;
  --radius-md: 12px;
  --radius-lg: 20px;
  --radius-xl: 28px;

  --nav-rail-width: 84px;
  --nav-bottom-height: 64px;
}

:root[data-theme="dark"] {
  --on-primary-container: #b4f4bb;
  --primary-container: rgba(76, 175, 80, 0.24);

  --surface: #060708;
  --surface-container-lowest: #000000;
  --surface-container: #0d0e10;
  --surface-container-high: #1c1d20;
  --surface-container-highest: #2a2b2e;
  --on-surface: #f1f1f4;
  --on-surface-variant: #a6a7ad;
  --outline: #5a5b62;
  --outline-variant: #1a1b1d;
  --error: #f2b8b5;

  --shadow-1: 0 1px 2px rgba(0,0,0,0.55);
  --shadow-2: 0 6px 18px rgba(0,0,0,0.65);
}

@media (prefers-color-scheme: dark) {
  :root[data-theme="auto"] {
    --on-primary-container: #b4f4bb;
    --primary-container: rgba(76, 175, 80, 0.24);

    --surface: #060708;
    --surface-container-lowest: #000000;
    --surface-container: #0d0e10;
    --surface-container-high: #1c1d20;
    --surface-container-highest: #2a2b2e;
    --on-surface: #f1f1f4;
    --on-surface-variant: #a6a7ad;
    --outline: #5a5b62;
    --outline-variant: #1a1b1d;
    --error: #f2b8b5;

    --shadow-1: 0 1px 2px rgba(0,0,0,0.55);
    --shadow-2: 0 6px 18px rgba(0,0,0,0.65);
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

/* ========== Layout: NavigationRail (desktop) / NavigationBar (mobile) ========== */
.layout {
  display: flex;
  min-height: 100vh;
  align-items: stretch;
}
.nav-rail {
  width: var(--nav-rail-width);
  flex-shrink: 0;
  background: var(--surface);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 14px 0 14px;
  padding-top: calc(env(safe-area-inset-top) + 14px);
  padding-left: env(safe-area-inset-left);
  gap: 8px;
  position: sticky;
  top: 0;
  max-height: 100vh;
  z-index: 9;
}
.nav-search {
  width: 56px;
  height: 56px;
  border-radius: 18px;
  background: var(--primary);
  color: var(--on-primary);
  border: none;
  font-size: 22px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 6px;
  box-shadow: var(--shadow-1);
  transition: filter 0.15s, transform 0.1s;
  flex-shrink: 0;
}
.nav-search:hover { filter: brightness(1.08); }
.nav-search:active { transform: scale(0.96); }
.nav-main { flex: 1; display: flex; flex-direction: column; gap: 6px; width: 100%; align-items: center; }
.nav-bottom { display: flex; flex-direction: column; gap: 6px; width: 100%; align-items: center; }
.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  width: 64px;
  padding: 10px 4px;
  border: none;
  background: transparent;
  cursor: pointer;
  color: var(--on-surface-variant);
  font-family: inherit;
  font-size: 11px;
  font-weight: 500;
  border-radius: 16px;
  transition: background 0.15s, color 0.15s;
}
.nav-item .icon { font-size: 22px; line-height: 1.1; }
.nav-item:hover { background: var(--surface-container); color: var(--on-surface); }
.nav-item.is-active { background: var(--surface-container-high); color: var(--on-surface); }

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

/* ========== Content area ========== */
.content {
  flex: 1;
  min-width: 0;
  padding: 20px 28px calc(env(safe-area-inset-bottom) + 32px);
  padding-right: max(28px, env(safe-area-inset-right));
}
h2 {
  font-size: 15px;
  font-weight: 500;
  color: var(--on-surface-variant);
  margin: 22px 0 12px;
  letter-spacing: 0.3px;
}
h2:first-child { margin-top: 4px; }
.page-header {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 0 18px;
  min-height: 56px;
}
.page-title {
  font-size: 28px;
  font-weight: 700;
  letter-spacing: 0.3px;
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.page-title .chev { font-size: 22px; opacity: 0.75; line-height: 1; }

/* 窄屏：rail 切换为底部 NavigationBar */
@media (max-width: 599px) {
  .layout { flex-direction: column; }
  .nav-rail {
    order: 2;
    width: 100%;
    max-height: none;
    flex-direction: row;
    padding: 4px 8px;
    padding-bottom: calc(env(safe-area-inset-bottom) + 4px);
    padding-left: max(8px, env(safe-area-inset-left));
    gap: 0;
    position: sticky;
    top: auto;
    bottom: 0;
    background: color-mix(in srgb, var(--surface) 92%, transparent);
    backdrop-filter: blur(14px);
    -webkit-backdrop-filter: blur(14px);
    border-top: 1px solid var(--outline-variant);
  }
  .nav-search {
    width: 44px;
    height: 44px;
    border-radius: 14px;
    font-size: 18px;
    margin-bottom: 0;
    margin-right: 4px;
  }
  .nav-main {
    flex: 1;
    flex-direction: row;
    gap: 0;
    justify-content: space-around;
  }
  .nav-bottom { display: none; }
  .nav-item { flex: 1; width: auto; padding: 6px 4px; border-radius: 14px; }
  .nav-item .icon { font-size: 20px; }
  .content {
    order: 1;
    padding: 14px 16px calc(env(safe-area-inset-bottom) + 14px);
  }
  .page-header { padding: 4px 0 14px; }
  .page-title { font-size: 24px; }
}

/* ========== Search bar ========== */
.search-bar {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--surface-container);
  border-radius: var(--radius-xl);
  padding: 4px 4px 4px 14px;
  transition: background 0.15s;
}
.search-bar:focus-within { background: var(--surface-container-high); }
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
.search-bar select:hover { background: var(--surface-container-high); }
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
}
.search-bar .submit:active { transform: scale(0.96); }
.search-bar .submit:disabled { opacity: 0.5; }

/* ========== List items ========== */
.list { display: flex; flex-direction: column; gap: 6px; margin-top: 14px; }
.item {
  background: transparent;
  border-radius: var(--radius-md);
  padding: 14px 16px;
  cursor: pointer;
  border: none;
  transition: background 0.15s, transform 0.1s;
  line-height: 1.5;
  font-size: 15px;
}
.item:hover { background: var(--surface-container); }
.item:active { transform: scale(0.99); background: var(--surface-container-high); }

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
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 13px;
  line-height: 1.35;
  word-break: break-all;
  transition: background 0.15s, color 0.15s;
  color: var(--on-surface);
}
.ep:hover { background: var(--surface-container-high); }
.ep:active, .ep.is-active {
  background: var(--primary-container);
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
  background: var(--surface-container);
  border: none;
  color: var(--on-surface);
  font: inherit;
  padding: 12px 18px;
  border-radius: 22px;
  cursor: pointer;
  transition: background 0.15s;
}
button.tonal:hover { background: var(--surface-container-high); }

/* ========== Bangumi card (search result list row) ========== */
.bangumi-card {
  display: flex;
  gap: 12px;
  background: transparent;
  border: none;
  border-radius: var(--radius-md);
  padding: 10px 8px;
  cursor: pointer;
  transition: background 0.15s;
}
.bangumi-card:hover { background: var(--surface-container); }
.bangumi-card .cover {
  width: 78px;
  height: 110px;
  flex-shrink: 0;
  background: var(--surface-container);
  border-radius: var(--radius-md);
  object-fit: cover;
}
.bangumi-card .info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
.bangumi-card .name { font-size: 15px; font-weight: 600; line-height: 1.35; overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
.bangumi-card .alt { font-size: 12px; color: var(--on-surface-variant); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.bangumi-card .summary { font-size: 12px; color: var(--on-surface-variant); line-height: 1.45; overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
.bangumi-card .meta { display: flex; gap: 8px; align-items: center; font-size: 12px; color: var(--on-surface-variant); margin-top: auto; }
.bangumi-card .score { color: var(--primary); font-weight: 600; }

/* ========== Detail hero ========== */
.hero {
  position: relative;
  margin: -20px -28px 16px;
  padding: calc(env(safe-area-inset-top) + 20px) 28px 18px;
  overflow: hidden;
  isolation: isolate;
}
@media (max-width: 599px) {
  .hero { margin: -14px -16px 16px; padding: calc(env(safe-area-inset-top) + 14px) 16px 18px; }
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
  background: var(--surface-container);
  border: none;
  color: var(--on-surface-variant);
}

/* ========== Tabs ========== */
.tabs {
  display: flex;
  gap: 4px;
  border-bottom: 1px solid var(--outline-variant);
  margin: 22px 0 14px;
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
  background: transparent;
  border-radius: 0;
  padding: 4px 0;
  border: none;
  font-size: 14px;
  line-height: 1.75;
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
  border: none;
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
  border: none;
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
  right: 24px;
  bottom: calc(env(safe-area-inset-bottom) + 24px);
  background: var(--primary);
  color: var(--on-primary);
  border: none;
  border-radius: 18px;
  width: 56px;
  height: 56px;
  font: inherit;
  font-size: 22px;
  cursor: pointer;
  box-shadow: var(--shadow-2);
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: filter 0.15s, transform 0.1s;
}
.fab:hover { filter: brightness(1.08); }
.fab:active { transform: scale(0.96); }
.fab.fab-extended {
  width: auto;
  padding: 0 22px;
  gap: 8px;
  font-size: 15px;
  font-weight: 500;
}
@media (max-width: 599px) {
  .fab { bottom: calc(var(--nav-bottom-height) + env(safe-area-inset-bottom) + 16px); right: 16px; }
}

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

/* ========== Legacy bottom tab bar (kept hidden; v4 uses .nav-rail) ========== */
.tab-bar { display: none; }
.bottom-spacer { height: 0; }

/* ========== Poster grid ========== */
.poster-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(128px, 1fr));
  gap: 18px 14px;
}
@media (max-width: 599px) {
  .poster-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px 10px; }
}
.poster-card { cursor: pointer; background: transparent; border: none; padding: 0; }
.poster-card img {
  width: 100%;
  aspect-ratio: 7 / 10;
  border-radius: var(--radius-md);
  object-fit: cover;
  background: var(--surface-container);
  display: block;
  transition: transform 0.15s;
}
.poster-card:hover img { transform: translateY(-2px); }
.poster-card .name {
  font-size: 14px;
  margin-top: 10px;
  line-height: 1.4;
  font-weight: 500;
  letter-spacing: 0.2px;
  color: var(--on-surface);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
/* 评分挪到详情页，不在卡片显示 */
.poster-card .score { display: none; }

/* ========== Day chips ========== */
.day-chips {
  display: flex;
  gap: 6px;
  overflow-x: auto;
  scrollbar-width: none;
  margin-bottom: 18px;
  padding-bottom: 2px;
}
.day-chips::-webkit-scrollbar { display: none; }
.day-chip {
  flex-shrink: 0;
  padding: 8px 14px;
  border-radius: 18px;
  background: var(--surface-container);
  border: none;
  font-size: 13px;
  cursor: pointer;
  color: var(--on-surface);
  transition: background 0.15s;
}
.day-chip.is-active {
  background: var(--primary);
  color: var(--on-primary);
}

/* ========== History row ========== */
.history-row {
  display: flex;
  gap: 12px;
  background: transparent;
  border: none;
  border-radius: var(--radius-md);
  padding: 10px 8px;
  margin-bottom: 6px;
  cursor: pointer;
  transition: background 0.15s;
}
.history-row:hover { background: var(--surface-container); }
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
  border: none;
  border-radius: var(--radius-md);
  padding: 4px 14px;
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
''';
