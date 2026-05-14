/// CSS 字符串：嵌入到 `lib/lan/web_index_html.dart` 的 `<style>` 块中。
///
/// v5b 起，**所有颜色与 typography 都通过 CSS 变量驱动**，变量值由
/// `applyTheme()`（web_app_script.dart）在运行时根据 `/api/theme` 返回的
/// schemes + typography 注入。这里只定义：
///   1. 兜底 :root 变量（接入失败时也能勉强显示）
///   2. 布局（layout / nav-rail / content）
///   3. 组件视觉规则（圆角 / 间距 / state layer）
///
/// 配色对齐桌面端 `lib/pages/menu/menu.dart`：
///   - body / .nav-rail = surfaceContainer
///   - .content       = primaryContainer + 左侧 16dp 圆角（M3 NavigationRail
///                       与内容区分离的视觉语言）
///
/// State layer 走 M3 spec：`on-surface` @ 8% (hover) / 12% (focus, pressed)
/// 用 `::before` 伪元素叠加，避免破坏底色语义。
const String lanWebCss = r'''
@font-face {
  font-family: "MiSans";
  src: url("/assets/MiSans-Regular.ttf") format("truetype");
  font-display: swap;
  font-weight: 400;
}

/* 兜底 token：/api/theme 接入失败时还能凑合看 */
:root {
  --primary: #4CAF50;
  --on-primary: #FFFFFF;
  --primary-container: #B7F0B9;
  --on-primary-container: #00390C;
  --secondary: #52634F;
  --secondary-container: #D5E8CF;
  --on-secondary-container: #101F0E;
  --tertiary: #38656A;
  --error: #BA1A1A;
  --on-error: #FFFFFF;
  --surface: #F7FBF1;
  --on-surface: #181D17;
  --on-surface-variant: #424940;
  --surface-container-lowest: #FFFFFF;
  --surface-container-low: #F1F5EB;
  --surface-container: #EBEFE5;
  --surface-container-high: #E6E9DF;
  --surface-container-highest: #E0E4DA;
  --outline: #72796F;
  --outline-variant: #C2C9BD;
  --scaffold-background: #F7FBF1;

  /* Typography 兜底（M3 type scale） */
  --display-large-size: 57px;       --display-large-weight: 400;   --display-large-letter-spacing: -0.25px;  --display-large-height: 1.12;
  --display-medium-size: 45px;      --display-medium-weight: 400;  --display-medium-letter-spacing: 0px;     --display-medium-height: 1.16;
  --display-small-size: 36px;       --display-small-weight: 400;   --display-small-letter-spacing: 0px;      --display-small-height: 1.22;
  --headline-large-size: 32px;      --headline-large-weight: 400;  --headline-large-letter-spacing: 0px;     --headline-large-height: 1.25;
  --headline-medium-size: 28px;     --headline-medium-weight: 400; --headline-medium-letter-spacing: 0px;    --headline-medium-height: 1.29;
  --headline-small-size: 24px;      --headline-small-weight: 400;  --headline-small-letter-spacing: 0px;     --headline-small-height: 1.33;
  --title-large-size: 22px;         --title-large-weight: 400;     --title-large-letter-spacing: 0px;        --title-large-height: 1.27;
  --title-medium-size: 16px;        --title-medium-weight: 500;    --title-medium-letter-spacing: 0.15px;    --title-medium-height: 1.5;
  --title-small-size: 14px;         --title-small-weight: 500;     --title-small-letter-spacing: 0.1px;      --title-small-height: 1.43;
  --label-large-size: 14px;         --label-large-weight: 500;     --label-large-letter-spacing: 0.1px;      --label-large-height: 1.43;
  --label-medium-size: 12px;        --label-medium-weight: 500;    --label-medium-letter-spacing: 0.5px;     --label-medium-height: 1.33;
  --label-small-size: 11px;         --label-small-weight: 500;     --label-small-letter-spacing: 0.5px;      --label-small-height: 1.45;
  --body-large-size: 16px;          --body-large-weight: 400;      --body-large-letter-spacing: 0.5px;       --body-large-height: 1.5;
  --body-medium-size: 14px;         --body-medium-weight: 400;     --body-medium-letter-spacing: 0.25px;     --body-medium-height: 1.43;
  --body-small-size: 12px;          --body-small-weight: 400;      --body-small-letter-spacing: 0.4px;       --body-small-height: 1.33;

  /* StyleString 常量（lib/utils/constants.dart） */
  --card-space: 8px;
  --safe-space: 12px;
  --md-radius: 10px;
  --img-radius: 12px;

  /* M3 NavigationRail 与内容区的分隔圆角 */
  --content-corner: 16px;

  /* State layer 不透明度（M3 spec） */
  --state-hover-opacity: 0.08;
  --state-focus-opacity: 0.12;
  --state-pressed-opacity: 0.12;
  --state-dragged-opacity: 0.16;

  /* Navigation rail 尺寸（M3 spec） */
  --nav-rail-width: 80px;
  --nav-bottom-height: 80px;
}

/* ========== Reset ========== */
* { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
html, body { margin: 0; padding: 0; }
body {
  font-family: "MiSans", "MI_Sans_Regular", -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", Roboto, sans-serif;
  background: var(--surface-container);
  color: var(--on-surface);
  min-height: 100vh;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  font-size: var(--body-medium-size);
  line-height: var(--body-medium-height);
  letter-spacing: var(--body-medium-letter-spacing);
}

/* ========== Layout ========== */
.layout {
  display: flex;
  min-height: 100vh;
  align-items: stretch;
}
.content {
  flex: 1;
  min-width: 0;
  /* 桌面端 menu.dart 的 Container(primaryContainer) 实际被内层
   * PopularPage.Scaffold 默认的 colorScheme.surface 完全覆盖；
   * primaryContainer 仅在 ClipRRect 的圆角边角短暂露出。所以
   * 真实可见的"内容区背景"是 surface，对齐它。 */
  background: var(--surface);
  color: var(--on-surface);
  padding: 20px 28px calc(env(safe-area-inset-bottom) + 32px);
  padding-right: max(28px, env(safe-area-inset-right));
}

/* ========== NavigationRail (desktop / landscape) ========== */
.nav-rail {
  width: var(--nav-rail-width);
  flex-shrink: 0;
  background: var(--surface-container);
  color: var(--on-surface-variant);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 0 12px;
  padding-top: calc(env(safe-area-inset-top) + 24px);
  padding-left: env(safe-area-inset-left);
  gap: 12px;
  position: sticky;
  top: 0;
  max-height: 100vh;
  z-index: 9;
}
.nav-search {
  /* M3 FAB: 56x56 圆形（不是圆角方形），primaryContainer 底色 */
  width: 56px;
  height: 56px;
  border-radius: 16px;
  background: var(--primary-container);
  color: var(--on-primary-container);
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  position: relative;
  overflow: hidden;
  isolation: isolate;
  transition: filter 0.15s;
}
.nav-search svg { width: 24px; height: 24px; fill: currentColor; }
/* state layer */
.nav-search::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-primary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.nav-search:hover::before { opacity: var(--state-hover-opacity); }
.nav-search:active::before { opacity: var(--state-pressed-opacity); }

.nav-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;   /* 对齐 menu.dart groupAlignment: 1.0 */
  gap: 4px;
  width: 100%;
  align-items: center;
}
.nav-bottom { display: none; }   /* desktop 模式下设置入口与 groupAlignment 冲突，先隐藏 */

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  gap: 4px;
  width: 56px;
  padding: 0;
  border: none;
  background: transparent;
  cursor: pointer;
  color: var(--on-surface-variant);
  font-family: inherit;
  font-size: var(--label-medium-size);
  font-weight: var(--label-medium-weight);
  letter-spacing: var(--label-medium-letter-spacing);
  line-height: var(--label-medium-height);
  transition: color 0.15s;
}
.nav-item .nav-indicator {
  /* M3 NavigationRail indicator: 56x32 pill */
  width: 56px;
  height: 32px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  position: relative;
  overflow: hidden;
  isolation: isolate;
  transition: background 0.15s;
}
.nav-item .nav-indicator::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-surface);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.nav-item:hover .nav-indicator::before { opacity: var(--state-hover-opacity); }
.nav-item:active .nav-indicator::before { opacity: var(--state-pressed-opacity); }
.nav-item .icon { width: 24px; height: 24px; display: inline-block; }
.nav-item .icon svg { width: 24px; height: 24px; fill: currentColor; }
.nav-item .label { display: none; }
.nav-item.is-active { color: var(--on-secondary-container); }
.nav-item.is-active .nav-indicator { background: var(--secondary-container); }
.nav-item.is-active .label { display: block; }

/* ========== Bottom NavigationBar (portrait / mobile) ========== */
@media (max-width: 599px) {
  .layout { flex-direction: column; }
  .content {
    order: 1;
    border-radius: 0;
    padding: 14px 16px calc(env(safe-area-inset-bottom) + 14px);
  }
  .nav-rail {
    order: 2;
    width: 100%;
    height: var(--nav-bottom-height);
    max-height: var(--nav-bottom-height);
    flex-direction: row;
    padding: 12px 8px;
    padding-bottom: calc(env(safe-area-inset-bottom) + 12px);
    padding-left: max(8px, env(safe-area-inset-left));
    gap: 0;
    position: sticky;
    top: auto;
    bottom: 0;
    align-items: center;
    justify-content: space-around;
    background: var(--surface-container);
    border-top: 1px solid var(--outline-variant);
  }
  /* 窄屏：搜索不在底部 NavigationBar 里（对齐 menu.dart bottomMenuWidget） */
  .nav-search { display: none; }
  .nav-main {
    flex: 1;
    flex-direction: row;
    gap: 0;
    justify-content: space-around;
    align-items: center;
  }
  .nav-item {
    flex: 1;
    width: auto;
    height: 100%;
    justify-content: center;
  }
  .nav-item .label { display: block; }   /* M3 NavigationBar 默认所有 label 都显示 */
}

/* ========== IconButton (page header / inline) ========== */
.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: transparent;
  border: none;
  color: var(--on-primary-container);
  cursor: pointer;
  position: relative;
  overflow: hidden;
  isolation: isolate;
  flex-shrink: 0;
}
.icon-btn svg { width: 24px; height: 24px; fill: currentColor; }
.icon-btn::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-primary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.icon-btn:hover::before { opacity: var(--state-hover-opacity); }
.icon-btn:active::before { opacity: var(--state-pressed-opacity); }

/* ========== Page header (replaces sticky app bar) ========== */
.page-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 0 16px;
  min-height: 56px;
}
.page-title {
  font-size: var(--headline-medium-size);
  font-weight: 700;
  letter-spacing: var(--headline-medium-letter-spacing);
  line-height: var(--headline-medium-height);
  color: var(--on-primary-container);
  display: flex;
  align-items: center;
  gap: 4px;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.page-title .chev { font-size: 24px; opacity: 0.85; line-height: 1; }

h2 {
  font-size: var(--title-medium-size);
  font-weight: var(--title-medium-weight);
  letter-spacing: var(--title-medium-letter-spacing);
  line-height: var(--title-medium-height);
  color: var(--on-primary-container);
  opacity: 0.78;
  margin: 22px 0 12px;
}
h2:first-child { margin-top: 4px; }

/* ========== Search bar ========== */
.search-bar {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--surface-container-high);
  color: var(--on-surface);
  border-radius: 28px;
  padding: 4px 4px 4px 16px;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
.search-bar select, .search-bar input {
  font: inherit;
  font-size: var(--body-large-size);
  color: inherit;
  background: transparent;
  border: none;
  outline: none;
}
.search-bar input {
  flex: 1;
  min-width: 0;
  padding: 12px 4px;
}
.search-bar input::placeholder { color: var(--on-surface-variant); }
.search-bar select {
  padding: 10px 22px 10px 8px;
  -webkit-appearance: none;
  appearance: none;
  max-width: 38%;
  cursor: pointer;
  border-radius: 18px;
}
.search-bar .submit {
  flex-shrink: 0;
  background: var(--primary);
  color: var(--on-primary);
  border: none;
  border-radius: 22px;
  width: 44px;
  height: 44px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
.search-bar .submit svg { width: 20px; height: 20px; fill: currentColor; }
.search-bar .submit::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-primary);
  opacity: 0;
  transition: opacity 0.12s;
}
.search-bar .submit:hover::before { opacity: var(--state-hover-opacity); }
.search-bar .submit:active::before { opacity: var(--state-pressed-opacity); }
.search-bar .submit:disabled { opacity: 0.4; }

/* ========== Lists & items ========== */
.list { display: flex; flex-direction: column; gap: 4px; margin-top: 8px; }
.item {
  background: transparent;
  border-radius: var(--md-radius);
  padding: 14px 16px;
  cursor: pointer;
  border: none;
  position: relative;
  overflow: hidden;
  isolation: isolate;
  line-height: var(--body-large-height);
  font-size: var(--body-large-size);
  color: var(--on-primary-container);
}
.item::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-primary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.item:hover::before { opacity: var(--state-hover-opacity); }
.item:active::before { opacity: var(--state-pressed-opacity); }

/* ========== Episode grid ========== */
.ep-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(92px, 1fr));
  gap: var(--card-space);
}
.ep {
  text-align: center;
  padding: 12px 6px;
  background: var(--surface-container);
  color: var(--on-surface);
  border: none;
  border-radius: var(--md-radius);
  cursor: pointer;
  font-size: var(--label-large-size);
  font-weight: var(--label-large-weight);
  letter-spacing: var(--label-large-letter-spacing);
  line-height: var(--label-large-height);
  word-break: break-all;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
.ep::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-surface);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.ep:hover::before { opacity: var(--state-hover-opacity); }
.ep:active::before { opacity: var(--state-pressed-opacity); }
.ep.is-active { background: var(--secondary-container); color: var(--on-secondary-container); }

/* ========== Status / error ========== */
.status {
  padding: 28px 0;
  font-size: var(--body-medium-size);
  color: var(--on-primary-container);
  opacity: 0.7;
  text-align: center;
}
.error { color: var(--error); opacity: 1; }

/* ========== Player ========== */
video {
  width: 100%;
  max-height: 78vh;
  background: #000;
  border-radius: var(--md-radius);
  display: block;
}
.player-meta {
  font-size: var(--body-small-size);
  color: var(--on-primary-container);
  opacity: 0.7;
  margin-top: 10px;
  word-break: break-all;
  line-height: 1.5;
}
.player-actions { display: flex; gap: 8px; margin-top: 14px; }
button.tonal {
  flex: 1;
  background: var(--secondary-container);
  color: var(--on-secondary-container);
  border: none;
  font: inherit;
  font-size: var(--label-large-size);
  font-weight: var(--label-large-weight);
  padding: 10px 22px;
  border-radius: 100px;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
button.tonal::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-secondary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
button.tonal:hover::before { opacity: var(--state-hover-opacity); }
button.tonal:active::before { opacity: var(--state-pressed-opacity); }

/* ========== Bangumi list row (search results) ========== */
.bangumi-card {
  display: flex;
  gap: 12px;
  background: transparent;
  border: none;
  border-radius: var(--md-radius);
  padding: 10px 8px;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
.bangumi-card::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-primary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.bangumi-card:hover::before { opacity: var(--state-hover-opacity); }
.bangumi-card .cover {
  width: 78px;
  height: 110px;
  flex-shrink: 0;
  background: var(--surface-container);
  border-radius: var(--img-radius);
  object-fit: cover;
}
.bangumi-card .info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
.bangumi-card .name {
  font-size: var(--title-medium-size);
  font-weight: 600;
  letter-spacing: 0.3px;
  line-height: 1.35;
  color: var(--on-primary-container);
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.bangumi-card .alt { font-size: var(--body-small-size); color: var(--on-primary-container); opacity: 0.65; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.bangumi-card .summary {
  font-size: var(--body-small-size);
  color: var(--on-primary-container);
  opacity: 0.7;
  line-height: 1.45;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.bangumi-card .meta { display: flex; gap: 8px; align-items: center; font-size: var(--body-small-size); color: var(--on-primary-container); opacity: 0.7; margin-top: auto; }
.bangumi-card .score { color: var(--primary); font-weight: 600; opacity: 1; }

/* ========== Detail hero ========== */
.hero {
  position: relative;
  margin: -20px -28px 16px;
  padding: calc(env(safe-area-inset-top) + 20px) 28px 18px;
  overflow: hidden;
  isolation: isolate;
  border-top-left-radius: var(--content-corner);
}
@media (max-width: 599px) {
  .hero { margin: -14px -16px 16px; padding: calc(env(safe-area-inset-top) + 14px) 16px 18px; border-radius: 0; }
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
  background: linear-gradient(180deg, transparent 0%, var(--primary-container) 100%);
  z-index: -1;
}
.hero-row { display: flex; gap: 16px; align-items: flex-start; }
.hero-cover {
  width: 108px;
  aspect-ratio: 0.65;
  border-radius: var(--img-radius);
  object-fit: cover;
  background: var(--surface-container);
  flex-shrink: 0;
}
.hero-meta { display: flex; flex-direction: column; gap: 6px; min-width: 0; flex: 1; }
.hero-title {
  font-size: var(--title-large-size);
  font-weight: 700;
  letter-spacing: 0.2px;
  line-height: 1.25;
  color: var(--on-primary-container);
  word-break: break-word;
}
.hero-alt { font-size: var(--body-small-size); color: var(--on-primary-container); opacity: 0.7; word-break: break-word; }
.hero-stat { display: flex; align-items: baseline; flex-wrap: wrap; gap: 6px 10px; margin-top: 4px; }
.hero-score { font-size: var(--headline-small-size); font-weight: 700; color: var(--primary); line-height: 1; }
.hero-stars { font-size: var(--label-large-size); color: var(--primary); }
.hero-votes { font-size: var(--body-small-size); color: var(--on-primary-container); opacity: 0.65; }
.hero-rank { font-size: var(--body-small-size); color: var(--on-primary-container); opacity: 0.65; }

.chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.chip {
  font-size: var(--label-small-size);
  font-weight: var(--label-small-weight);
  padding: 4px 12px;
  border-radius: 8px;
  background: var(--surface-container);
  color: var(--on-surface-variant);
  border: none;
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
  padding: 12px 18px;
  cursor: pointer;
  font-size: var(--title-small-size);
  font-weight: var(--title-small-weight);
  letter-spacing: var(--title-small-letter-spacing);
  color: var(--on-primary-container);
  opacity: 0.7;
  border-bottom: 2px solid transparent;
  white-space: nowrap;
  transition: color 0.15s, border-color 0.15s, opacity 0.15s;
}
.tab.is-active { color: var(--primary); border-bottom-color: var(--primary); opacity: 1; }

/* ========== Summary ========== */
.summary-card {
  background: transparent;
  border-radius: 0;
  padding: 4px 0;
  border: none;
  font-size: var(--body-medium-size);
  line-height: 1.75;
  color: var(--on-primary-container);
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
  font-size: var(--label-large-size);
  font-weight: var(--label-large-weight);
  cursor: pointer;
  padding: 6px 12px;
}

/* ========== Character / staff / comment cards ========== */
.char-grid, .staff-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: var(--card-space);
}
.char-card, .staff-card {
  display: flex;
  gap: 10px;
  background: var(--surface-container);
  color: var(--on-surface);
  border: none;
  border-radius: var(--md-radius);
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
.char-card .meta, .staff-card .meta { min-width: 0; line-height: 1.35; flex: 1; }
.char-card .name, .staff-card .name { font-size: var(--label-large-size); font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.char-card .relation, .staff-card .position { font-size: var(--label-small-size); color: var(--on-surface-variant); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.char-actors { font-size: var(--label-small-size); color: var(--on-surface-variant); margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.comment-card {
  background: var(--surface-container);
  color: var(--on-surface);
  border: none;
  border-radius: var(--md-radius);
  padding: 14px 16px;
  margin-bottom: 8px;
}
.comment-head { display: flex; align-items: center; gap: 10px; font-size: var(--body-medium-size); margin-bottom: 8px; }
.comment-head img { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; background: var(--surface-container-high); }
.comment-head .username { font-weight: 500; }
.comment-head .rate { margin-left: auto; font-size: var(--label-medium-size); color: var(--primary); }
.comment-body { font-size: var(--body-medium-size); line-height: 1.6; color: var(--on-surface); white-space: pre-wrap; word-break: break-word; }

/* ========== FAB (M3 standard) ========== */
.fab {
  position: fixed;
  right: 24px;
  bottom: calc(env(safe-area-inset-bottom) + 24px);
  background: var(--primary-container);
  color: var(--on-primary-container);
  border: none;
  border-radius: 16px;
  width: 56px;
  height: 56px;
  cursor: pointer;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: center;
  position: fixed;
  isolation: isolate;
  overflow: hidden;
  box-shadow: 0 3px 6px rgba(0,0,0,0.15), 0 1px 2px rgba(0,0,0,0.10);
}
.fab svg { width: 24px; height: 24px; fill: currentColor; }
.fab::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-primary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.fab:hover::before { opacity: var(--state-hover-opacity); }
.fab:active::before { opacity: var(--state-pressed-opacity); }
.fab.fab-extended {
  width: auto;
  padding: 0 20px;
  gap: 8px;
  font: inherit;
  font-size: var(--label-large-size);
  font-weight: var(--label-large-weight);
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
  background: var(--surface-container-low);
  color: var(--on-surface);
  width: 100%;
  max-width: 560px;
  max-height: 80vh;
  overflow-y: auto;
  border-radius: 28px 28px 0 0;
  padding: 14px 16px calc(env(safe-area-inset-bottom) + 18px);
  box-shadow: 0 -6px 22px rgba(0,0,0,0.25);
}
@media (min-width: 600px) {
  .modal-mask { align-items: center; }
  .modal-sheet { border-radius: 28px; max-height: 86vh; }
}
.modal-handle { width: 32px; height: 4px; background: var(--on-surface-variant); border-radius: 2px; margin: 0 auto 12px; opacity: 0.4; }
.modal-title { font-size: var(--title-large-size); font-weight: 500; margin-bottom: 10px; color: var(--on-surface); }

/* ========== Poster grid (响应 M3 BangumiCardV) ========== */
.poster-grid {
  display: grid;
  gap: 8px 8px;
}
@media (max-width: 599px) {
  .poster-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (min-width: 600px) and (max-width: 839px) {
  .poster-grid { grid-template-columns: repeat(5, minmax(0, 1fr)); }
}
@media (min-width: 840px) {
  .poster-grid { grid-template-columns: repeat(6, minmax(0, 1fr)); }
}
.poster-card {
  cursor: pointer;
  background: var(--surface-container);
  color: var(--on-surface);
  border: none;
  padding: 0;
  border-radius: var(--md-radius);
  overflow: hidden;
  position: relative;
  isolation: isolate;
  display: flex;
  flex-direction: column;
}
.poster-card::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-surface);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
  z-index: 1;
}
.poster-card:hover::before { opacity: var(--state-hover-opacity); }
.poster-card:active::before { opacity: var(--state-pressed-opacity); }
.poster-card img {
  width: 100%;
  aspect-ratio: 0.65;        /* 对齐 bangumi_card.dart */
  border-radius: 0;          /* card 已经 overflow: hidden */
  object-fit: cover;
  background: var(--surface-container-high);
  display: block;
}
.poster-card .name {
  font-size: var(--title-small-size);
  font-weight: 500;
  letter-spacing: 0.3px;
  line-height: 1.35;
  color: var(--on-surface);
  padding: 5px 5px 1px 5px;  /* 对齐 BangumiContent fromLTRB(5,3,5,1) */
  margin: 0;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  flex: 1;
  min-height: 3em;
}
@media (max-width: 599px) {
  .poster-card .name { -webkit-line-clamp: 2; min-height: 2em; }
}
.poster-card .score { display: none; }

/* ========== Day chips ========== */
.day-chips {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  scrollbar-width: none;
  margin-bottom: 18px;
  padding-bottom: 2px;
}
.day-chips::-webkit-scrollbar { display: none; }
.day-chip {
  flex-shrink: 0;
  padding: 8px 16px;
  border-radius: 8px;
  background: var(--surface-container);
  color: var(--on-surface);
  border: none;
  font-size: var(--label-large-size);
  font-weight: var(--label-large-weight);
  cursor: pointer;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
.day-chip::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-surface);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.day-chip:hover::before { opacity: var(--state-hover-opacity); }
.day-chip:active::before { opacity: var(--state-pressed-opacity); }
.day-chip.is-active {
  background: var(--secondary-container);
  color: var(--on-secondary-container);
}

/* ========== History row ========== */
.history-row {
  display: flex;
  gap: 12px;
  background: transparent;
  border: none;
  border-radius: var(--md-radius);
  padding: 10px 8px;
  margin-bottom: 6px;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
.history-row::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-primary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.history-row:hover::before { opacity: var(--state-hover-opacity); }
.history-row img {
  width: 54px;
  aspect-ratio: 0.65;
  border-radius: var(--img-radius);
  object-fit: cover;
  flex-shrink: 0;
  background: var(--surface-container);
}
.history-row .meta { min-width: 0; flex: 1; display: flex; flex-direction: column; gap: 4px; justify-content: center; }
.history-row .name { font-size: var(--title-small-size); font-weight: 500; line-height: 1.35; color: var(--on-primary-container); overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
.history-row .sub { font-size: var(--body-small-size); color: var(--on-primary-container); opacity: 0.7; }

/* ========== Collect button (filled tonal) ========== */
.collect-row { display: flex; gap: 8px; align-items: center; margin: 12px 0 4px; flex-wrap: wrap; }
.collect-btn {
  background: var(--secondary-container);
  color: var(--on-secondary-container);
  border: none;
  padding: 10px 22px;
  border-radius: 100px;
  font: inherit;
  font-size: var(--label-large-size);
  font-weight: var(--label-large-weight);
  letter-spacing: var(--label-large-letter-spacing);
  cursor: pointer;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}
.collect-btn::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: var(--on-secondary-container);
  opacity: 0;
  transition: opacity 0.12s;
  border-radius: inherit;
}
.collect-btn:hover::before { opacity: var(--state-hover-opacity); }
.collect-btn:active::before { opacity: var(--state-pressed-opacity); }
.collect-btn.is-collected { background: var(--primary); color: var(--on-primary); }
.collect-btn.is-collected::before { background: var(--on-primary); }
.collect-row .hint { font-size: var(--body-small-size); color: var(--on-primary-container); opacity: 0.7; }

/* ========== Player wrap + danmaku ========== */
.player-wrap {
  position: relative;
  border-radius: var(--md-radius);
  overflow: hidden;
  background: #000;
}
.player-wrap video { border-radius: 0; display: block; }
.danmaku-canvas { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; }
.danmaku-canvas.is-hidden { display: none; }

.danmaku-panel {
  background: var(--surface-container);
  color: var(--on-surface);
  border: none;
  border-radius: var(--md-radius);
  padding: 4px 14px;
  margin-top: 12px;
}
.danmaku-panel summary {
  cursor: pointer;
  padding: 12px 0;
  font-size: var(--title-small-size);
  font-weight: var(--title-small-weight);
  color: var(--on-surface);
  list-style: none;
  display: flex;
  align-items: center;
  gap: 8px;
}
.danmaku-panel summary::-webkit-details-marker { display: none; }
.danmaku-panel summary::after { content: "▾"; margin-left: auto; opacity: 0.6; }
.danmaku-panel[open] summary::after { content: "▴"; }
.danmaku-panel summary .count { font-weight: 400; opacity: 0.7; font-size: var(--body-small-size); }
.danmaku-panel .row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 0;
  font-size: var(--body-medium-size);
  gap: 12px;
}
.danmaku-panel input[type="range"] { flex: 1; max-width: 60%; accent-color: var(--primary); }
.danmaku-panel input[type="checkbox"] { accent-color: var(--primary); width: 20px; height: 20px; }

/* ========== Footer / legacy ========== */
.footer { margin-top: 32px; font-size: var(--label-small-size); color: var(--on-primary-container); opacity: 0.5; text-align: center; letter-spacing: 0.5px; }

.tab-bar { display: none; }
.bottom-spacer { height: 0; }

/* iOS Safari focus outline */
select:focus-visible, input:focus-visible, button:focus-visible {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
}
''';
