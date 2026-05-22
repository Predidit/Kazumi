/// 应用层 JS：路由、视图渲染、主题应用、导航栏、模态框。
///
/// 不含播放器、弹幕、HLS、进度上报——那些在 `web_player_script.dart`。
/// 拼接到 HTML 单一 `<script>` 标签的前段；运行时与 player script 共享同一
/// 全局作用域，函数 / `let` / `const` 都可互相引用。
///
/// 启动顺序：脚本末尾 `loadTheme().finally(dispatch)` 触发首次路由分发；这是
/// 一个 microtask，会在 player script 中所有 `let` 声明完成初始化之后才执行，
/// 因此 dispatch → renderPlayer → 引用 activeHls 等是安全的。
const String lanWebAppJs = r'''
"use strict";

const $app = document.getElementById("app");
const $navRail = document.getElementById("nav-rail");

// ====== Theme ======
// 把 ColorScheme + textTheme 写到一个独立 <style id="theme-tokens">，每次
// applyTheme 重写整段。这样可以同时为 light/dark/auto 三种 data-theme 状态
// 都准备好 CSS 变量，切换模式时浏览器无须再发请求。
function applyTheme(theme) {
  const root = document.documentElement;
  const mode = theme.themeMode || "system";
  root.dataset.theme = mode === "system" ? "auto" : mode;

  let style = document.getElementById("theme-tokens");
  if (!style) {
    style = document.createElement("style");
    style.id = "theme-tokens";
    document.head.append(style);
  }

  const lines = [];

  if (theme.schemes) {
    const lightVars = schemeToCssVars(theme.schemes.light);
    const darkVars = schemeToCssVars(theme.schemes.dark);
    if (lightVars) {
      lines.push(':root[data-theme="light"] {', lightVars, '}');
      // auto 在浅色系统下与 light 一致
      lines.push(':root[data-theme="auto"] {', lightVars, '}');
    }
    if (darkVars) {
      lines.push(':root[data-theme="dark"] {', darkVars, '}');
      lines.push('@media (prefers-color-scheme: dark) {');
      lines.push('  :root[data-theme="auto"] {', darkVars, '  }');
      lines.push('}');
    }
  } else if (theme.primaryColor) {
    // v1 兼容回退
    root.style.setProperty("--primary", theme.primaryColor);
    root.style.setProperty(
      "--primary-container",
      hexToRgba(theme.primaryColor, 0.16)
    );
  }

  if (theme.typography) {
    const typoLines = [':root {'];
    for (const [role, geom] of Object.entries(theme.typography)) {
      if (!geom) continue;
      const kebab = camelToKebab(role);
      if (geom.size != null) typoLines.push('  --' + kebab + '-size: ' + geom.size + 'px;');
      if (geom.weight != null) typoLines.push('  --' + kebab + '-weight: ' + geom.weight + ';');
      if (geom.letterSpacing != null) typoLines.push('  --' + kebab + '-letter-spacing: ' + geom.letterSpacing + 'px;');
      if (geom.height != null) typoLines.push('  --' + kebab + '-height: ' + geom.height + ';');
    }
    typoLines.push('}');
    lines.push(typoLines.join('\n'));
  }

  style.textContent = lines.join('\n');
}

function schemeToCssVars(scheme) {
  if (!scheme) return null;
  const out = [];
  for (const [k, v] of Object.entries(scheme)) {
    out.push('  --' + camelToKebab(k) + ': ' + v + ';');
  }
  return out.join('\n');
}

function camelToKebab(s) {
  return s.replace(/([A-Z])/g, '-$1').toLowerCase();
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

// 主题同步走"惰性刷新"：不再开 SSE 长连接（之前的 /api/theme/stream 在
// Windows + dart:io HttpServer 上会让后续短请求 ERR_EMPTY_RESPONSE）。
// 时机：首次加载 + 页面回到可见 (visibilitychange → visible) 时拉一次。
// 桌面端用户切主题的场景频率低，惰性刷新的体验代价可忽略。
async function loadTheme() {
  try {
    const t = await fetchJson("/api/theme");
    applyTheme(t);
  } catch (_) {
    // 静默：默认 :root 配色仍可用
  }
}

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") {
    loadTheme();
  }
});

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

// ====== Material Symbols (path 取自 Google Fonts material-symbols) ======
const ICONS = {
  home: '<svg viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>',
  home_outlined: '<svg viewBox="0 0 24 24"><path d="M12 5.69l5 4.5V18h-2v-6H9v6H7v-7.81l5-4.5M12 3L2 12h3v8h6v-6h2v6h6v-8h3L12 3z"/></svg>',
  timeline: '<svg viewBox="0 0 24 24"><path d="M23 8c0 1.1-.9 2-2 2-.18 0-.35-.02-.51-.07l-3.56 3.55c.05.16.07.34.07.52 0 1.1-.9 2-2 2s-2-.9-2-2c0-.18.02-.36.07-.52l-2.55-2.55c-.16.05-.34.07-.52.07s-.36-.02-.52-.07l-4.55 4.56c.05.16.07.33.07.51 0 1.1-.9 2-2 2s-2-.9-2-2 .9-2 2-2c.18 0 .35.02.51.07l4.56-4.55C6.02 9.36 6 9.18 6 9c0-1.1.9-2 2-2s2 .9 2 2c0 .18-.02.36-.07.52l2.55 2.55c.16-.05.34-.07.52-.07s.36.02.52.07l3.55-3.56C17.02 8.35 17 8.18 17 8c0-1.1.9-2 2-2s2 .9 2 2z"/></svg>',
  favorite: '<svg viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>',
  favorite_border: '<svg viewBox="0 0 24 24"><path d="M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55l-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z"/></svg>',
  settings: '<svg viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>',
  search: '<svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>',
  arrow_back: '<svg viewBox="0 0 24 24"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>',
  arrow_forward: '<svg viewBox="0 0 24 24"><path d="M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8z"/></svg>',
  play_arrow: '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>',
  tune: '<svg viewBox="0 0 24 24"><path d="M3 17v2h6v-2H3zM3 5v2h10V5H3zm10 16v-2h8v-2h-8v-2h-2v6h2zM7 9v2H3v2h4v2h2V9H7zm14 4v-2H11v2h10zm-6-4h2V7h4V5h-4V3h-2v6z"/></svg>',
  schedule: '<svg viewBox="0 0 24 24"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>',
  star: '<svg viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>',
  fire: '<svg viewBox="0 0 24 24"><path d="M13.5.67s.74 2.65.74 4.8c0 2.06-1.35 3.73-3.41 3.73-2.07 0-3.63-1.67-3.63-3.73l.03-.36C5.21 7.51 4 10.62 4 14c0 4.42 3.58 8 8 8s8-3.58 8-8C20 8.61 17.41 3.8 13.5.67zM11.71 19c-1.78 0-3.22-1.4-3.22-3.14 0-1.62 1.05-2.76 2.81-3.12 1.77-.36 3.6-1.21 4.62-2.58.39 1.29.59 2.65.59 4.04 0 2.65-2.15 4.8-4.8 4.8z"/></svg>',
  heart_broken: '<svg viewBox="0 0 24 24"><path d="M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-3.97 12.4l-1.13 1.05-1.05-1.05L6.7 11.7l3-1.5-1.7-3.7 3.96 1.13.53-2.13L14 8l-1.65 1.65 2.36 2.36-2.18 3.39z"/></svg>',
  task_alt: '<svg viewBox="0 0 24 24"><path d="M22 5.18 10.59 16.6l-4.24-4.24 1.41-1.41 2.83 2.83 10-10L22 5.18zm-2.21 5.04c.13.57.21 1.17.21 1.78 0 4.42-3.58 8-8 8s-8-3.58-8-8 3.58-8 8-8c1.58 0 3.04.46 4.28 1.25l1.44-1.44C16.1 2.67 14.13 2 12 2 6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10c0-1.19-.22-2.33-.6-3.39l-1.61 1.61z"/></svg>',
  live_tv: '<svg viewBox="0 0 24 24"><path d="M21 6h-7.59l3.29-3.29L16 2l-4 4-4-4-.71.71L10.59 6H3c-1.1 0-2 .89-2 2v12c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.11-.9-2-2-2zm0 14H3V8h18v12zM9 10v8l7-4z"/></svg>',
  check_circle: '<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>',
  radio_unchecked: '<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/></svg>',
  leaderboard: '<svg viewBox="0 0 24 24"><path d="M7 14H5v7h2v-7zm12-6h-2v13h2V8zM11 3h2v18h-2V3z"/></svg>',
  how_to_vote: '<svg viewBox="0 0 24 24"><path d="M13.05 11.36l5.59-5.59 1.41 1.41-7 7L8.81 9.94l1.41-1.41 2.83 2.83zM19 19H5V5h9V3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-7h-2v7z"/></svg>',
  open_in_browser: '<svg viewBox="0 0 24 24"><path d="M5 4h14c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2h-4v-2h4V8H5v10h4v2H5c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2zm7 6l-4 4h3v6h2v-6h3l-4-4z"/></svg>',
  // 对齐桌面端 CollectButton.getIconByInt：
  // 0 favorite_border / 1 favorite / 2 star / 3 pending_actions / 4 done / 5 heart_broken
  pending_actions: '<svg viewBox="0 0 24 24"><path d="M17 12c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zm1.65 7.35L16.5 17.2V14h1v2.79l1.85 1.85-.7.71zM18 3h-3.18C14.4 1.84 13.3 1 12 1c-1.3 0-2.4.84-2.82 2H6c-1.1 0-2 .9-2 2v15c0 1.1.9 2 2 2h6.11c-.59-.57-1.07-1.25-1.42-2H6V5h2v3h8V5h2v5.08c.71.1 1.38.31 2 .6V5c0-1.1-.9-2-2-2zm-6 2c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1z"/></svg>',
  done: '<svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>',
};

// 收藏状态枚举（对齐 lib/bean/widget/collect_button.dart）
// index=0 表示"未追"，调 PUT /api/collect?type=0 = 后端 deleteCollectible
const COLLECT_TYPES = [
  { value: 0, label: "未追", icon: "favorite_border" },
  { value: 1, label: "在看", icon: "favorite" },
  { value: 2, label: "想看", icon: "star" },
  { value: 3, label: "搁置", icon: "pending_actions" },
  { value: 4, label: "看过", icon: "done" },
  { value: 5, label: "抛弃", icon: "heart_broken" },
];
function collectTypeOf(value) {
  return COLLECT_TYPES.find((t) => t.value === value) || COLLECT_TYPES[0];
}

// ====== Timeline state (module-level so tab switching preserves) ======
// 对齐 lib/pages/timeline/timeline_controller.dart：seasonString / sortType /
// 三个 filter 持续保留，切换 tab 不丢；切换季节才重拉数据。
const TIMELINE_STATE = {
  selectedDate: new Date(),
  seasonString: "",
  days: [[], [], [], [], [], [], []],
  activeWeekday: ((new Date().getDay() + 6) % 7) + 1, // 1..7 (一..日)
  sortType: parseInt(localStorage.getItem("timelineSortType") || "3", 10),
  filterAbandoned: localStorage.getItem("timelineFilterAbandoned") === "1",
  filterWatched: localStorage.getItem("timelineFilterWatched") === "1",
  filterOnlyWatching: localStorage.getItem("timelineFilterWatching") === "1",
  isLoading: false,
  isError: false,
  // 收藏 id 集合（type:1 在看 / 4 看过 / 5 抛弃 — 对齐 collect_type.dart）
  collectIds: {
    watching: new Set(),
    watched: new Set(),
    abandoned: new Set(),
  },
};

function seasonOf(date) {
  const month = date.getMonth() + 1;
  const labels = ["冬季", "春季", "夏季", "秋季"];
  const idx = month <= 3 ? 0 : month <= 6 ? 1 : month <= 9 ? 2 : 3;
  return date.getFullYear() + "年" + labels[idx] + "新番";
}
function seasonQuarter(date) {
  const m = date.getMonth() + 1;
  return m <= 3 ? 1 : m <= 6 ? 2 : m <= 9 ? 3 : 4;
}
function seasonKey(date) {
  return date.getFullYear() + "-" + seasonQuarter(date);
}
function isSameSeasonDate(d1, d2) {
  return seasonKey(d1) === seasonKey(d2);
}
function sortTypeLabel(t) {
  if (t === 1) return "时间优先";
  if (t === 2) return "评分优先";
  return "热度优先";
}
function sortDayList(list, sortType) {
  const arr = list.slice();
  if (sortType === 1) arr.sort((a, b) => a.id - b.id);
  else if (sortType === 2)
    arr.sort((a, b) => (b.ratingScore || 0) - (a.ratingScore || 0));
  else arr.sort((a, b) => (b.votes || 0) - (a.votes || 0));
  return arr;
}
function filterTimelineDay(list) {
  const s = TIMELINE_STATE;
  let arr = list;
  if (s.filterAbandoned)
    arr = arr.filter((it) => !s.collectIds.abandoned.has(it.id));
  if (s.filterWatched)
    arr = arr.filter((it) => !s.collectIds.watched.has(it.id));
  if (s.filterOnlyWatching)
    arr = arr.filter((it) => s.collectIds.watching.has(it.id));
  return arr;
}
async function loadCollectIdsForTimeline() {
  try {
    const data = await fetchJson("/api/collect/list");
    const items = data.items || [];
    const watching = new Set();
    const watched = new Set();
    const abandoned = new Set();
    for (const it of items) {
      if (it.type === 1) watching.add(it.bangumiId);
      else if (it.type === 4) watched.add(it.bangumiId);
      else if (it.type === 5) abandoned.add(it.bangumiId);
    }
    TIMELINE_STATE.collectIds = { watching, watched, abandoned };
  } catch (_) {
    // 静默：收藏数据不可用不应阻塞时间表渲染
  }
}
async function fetchTimelineData(seasonParam) {
  TIMELINE_STATE.isLoading = true;
  TIMELINE_STATE.isError = false;
  try {
    const url = seasonParam
      ? "/api/timeline?season=" + encodeURIComponent(seasonParam)
      : "/api/timeline";
    const data = await fetchJson(url);
    const days = data.days || [];
    TIMELINE_STATE.days =
      days.length === 7 ? days : [[], [], [], [], [], [], []];
    TIMELINE_STATE.isError = TIMELINE_STATE.days.every((d) => !d.length);
  } catch (_) {
    TIMELINE_STATE.days = [[], [], [], [], [], [], []];
    TIMELINE_STATE.isError = true;
  } finally {
    TIMELINE_STATE.isLoading = false;
  }
}
function iconNode(name) {
  const span = el("span", { class: "icon", "aria-hidden": "true" });
  span.innerHTML = ICONS[name] || "";
  return span;
}

// ====== Page header (replaces the old sticky app bar) ======
function pageHeader(title, opts) {
  opts = opts || {};
  const header = el("div", { class: "page-header" });
  if (opts.back) {
    const back = el("button", { class: "icon-btn", "aria-label": "返回" });
    back.innerHTML = ICONS.arrow_back;
    back.addEventListener("click", () => history.back());
    header.append(back);
  }
  const titleNode = el("div", { class: "page-title" });
  titleNode.append(typeof title === "string" ? document.createTextNode(title) : title);
  if (opts.chev) {
    titleNode.append(el("span", { class: "chev" }, "▾"));
  }
  if (opts.onTitleClick) titleNode.addEventListener("click", opts.onTitleClick);
  header.append(titleNode);
  if (opts.trailing) header.append(opts.trailing);
  return header;
}

// ====== NavigationRail ======
// 对齐 lib/pages/menu/menu.dart：4 个 destinations，filled/outlined 图标对，
// active 项有 secondaryContainer 椭圆 indicator + label，未选中只显示 icon。
const NAV_TABS = [
  { key: "popular",  icon: "home",     iconOutlined: "home_outlined",     label: "推荐" },
  { key: "timeline", icon: "timeline", iconOutlined: "timeline",          label: "时间表" },
  { key: "collect",  icon: "favorite", iconOutlined: "favorite_border",   label: "追番" },
  { key: "my",       icon: "settings", iconOutlined: "settings",          label: "我的" },
];
function renderNavRail(activeTab) {
  $navRail.innerHTML = "";

  const search = el("button", {
    class: "nav-search",
    "aria-label": "搜索",
    onclick: () => go("/search"),
  });
  search.innerHTML = ICONS.search;
  $navRail.append(search);

  const main = el("div", { class: "nav-main" });
  for (const t of NAV_TABS) {
    const isActive = t.key === activeTab;
    const indicator = el("span", { class: "nav-indicator" },
      iconNode(isActive ? t.icon : t.iconOutlined));
    const btn = el(
      "button",
      {
        class: "nav-item" + (isActive ? " is-active" : ""),
        onclick: () => go("/home", { tab: t.key }),
      },
      indicator,
      el("span", { class: "label" }, t.label)
    );
    main.append(btn);
  }
  $navRail.append(main);
}
// 初始渲染
renderNavRail("popular");

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
  $app.innerHTML = "";
  renderNavRail(tab);

  if (tab === "popular") renderTabPopular($app);
  else if (tab === "timeline") renderTabTimeline($app);
  else if (tab === "collect") renderTabCollect($app);
  else if (tab === "my") renderTabMy($app);
  else renderTabPopular($app);
}

function buildTabBar() { return el("div", { class: "tab-bar" }); }

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

// 推荐页：对齐桌面端 PopularPage —— 标题旁 chevron 弹 tag 选择器；
// 滚到底自动加载更多（仅趋势模式分页，tag 模式后端是 random rank 一次性结果）；
// 右下角"返回顶部" FAB。
// 对齐桌面端 defaultAnimeTags（lib/utils/constants.dart）
const POPULAR_TAGS = [
  "日常", "原创", "校园", "搞笑", "奇幻", "百合",
  "恋爱", "悬疑", "热血", "后宫", "机战",
];
const POPULAR_STATE = {
  tag: "",        // "" = 趋势模式
  items: [],
  loading: false,
  exhausted: false,
};

async function renderTabPopular(container) {
  const headerTitle = POPULAR_STATE.tag || "热门番组";
  container.append(
    pageHeader(headerTitle, {
      chev: true,
      onTitleClick: () => openTagPicker(container),
    })
  );

  const grid = el("div", { class: "poster-grid" });
  container.append(grid);

  // 返回顶部 FAB
  const topFab = el("button", { class: "fab popular-top-fab", "aria-label": "返回顶部" });
  topFab.innerHTML = ICONS.arrow_back;
  topFab.style.transform = "rotate(90deg)";
  topFab.addEventListener("click", () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  });
  container.append(topFab);

  function renderItems() {
    grid.innerHTML = "";
    if (POPULAR_STATE.loading && !POPULAR_STATE.items.length) {
      setStatus(grid, "加载中…");
      return;
    }
    if (!POPULAR_STATE.items.length) {
      setStatus(grid, POPULAR_STATE.tag
        ? "没有这个标签的内容"
        : "暂无趋势数据");
      return;
    }
    for (const item of POPULAR_STATE.items) grid.append(buildPosterCard(item));
  }

  async function loadMore(reset) {
    if (POPULAR_STATE.loading) return;
    if (reset) {
      POPULAR_STATE.items = [];
      POPULAR_STATE.exhausted = false;
    }
    if (POPULAR_STATE.exhausted) return;
    POPULAR_STATE.loading = true;
    renderItems();
    try {
      const url = POPULAR_STATE.tag
        ? "/api/popular?tag=" + encodeURIComponent(POPULAR_STATE.tag)
        : "/api/popular?offset=" + POPULAR_STATE.items.length;
      const data = await fetchJson(url);
      const items = data.items || [];
      POPULAR_STATE.items = POPULAR_STATE.items.concat(items);
      // tag 模式后端是一次性返回（rank 随机），不再续翻
      if (POPULAR_STATE.tag || !items.length) {
        POPULAR_STATE.exhausted = true;
      }
    } catch (e) {
      if (!POPULAR_STATE.items.length) {
        grid.innerHTML = "";
        setStatus(grid, "加载失败：" + e.message, true);
      }
    } finally {
      POPULAR_STATE.loading = false;
    }
    renderItems();
  }

  // 滚到底自动加载更多
  const onScroll = () => {
    const doc = document.documentElement;
    if (window.innerHeight + window.scrollY >= doc.scrollHeight - 240) {
      loadMore(false);
    }
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  // 切 tab 时移除监听
  const observer = new MutationObserver(() => {
    if (!grid.isConnected) {
      window.removeEventListener("scroll", onScroll);
      observer.disconnect();
    }
  });
  observer.observe(container, { childList: true, subtree: true });

  // 首次进入或切换 tag：reset 数据
  await loadMore(true);
}

// 推荐页的 tag 选择 bottom sheet
function openTagPicker(container) {
  openModal((sheet, close) => {
    sheet.append(el("div", { class: "modal-title" }, "选择标签"));
    const list = el("div", { class: "list" });
    sheet.append(list);

    const all = [{ key: "", label: "热门番组" }].concat(
      POPULAR_TAGS.map((t) => ({ key: t, label: t }))
    );
    for (const t of all) {
      const isCurrent = t.key === POPULAR_STATE.tag;
      const item = el(
        "div",
        { class: "item" + (isCurrent ? " is-current" : "") },
        t.label
      );
      item.addEventListener("click", () => {
        close();
        if (t.key === POPULAR_STATE.tag) return;
        POPULAR_STATE.tag = t.key;
        // 重新渲染整个 popular tab
        container.innerHTML = "";
        renderTabPopular(container);
      });
      list.append(item);
    }
  });
}

async function renderTabTimeline(container) {
  // 首次进入：把当前日期当作选中季节
  if (!TIMELINE_STATE.seasonString) {
    TIMELINE_STATE.selectedDate = new Date();
    TIMELINE_STATE.seasonString = seasonOf(TIMELINE_STATE.selectedDate);
    TIMELINE_STATE.activeWeekday = ((new Date().getDay() + 6) % 7) + 1;
  }

  // 元素骨架（一次性创建，redraw 只更新内容）
  const header = pageHeader(TIMELINE_STATE.seasonString, {
    chev: true,
    onTitleClick: () => openSeasonPicker(redraw),
  });
  const tabs = el("div", { class: "week-tabs" });
  const grid = el("div", { class: "timeline-grid" });
  const fab = el("button", { class: "fab", "aria-label": "排序与过滤" });
  fab.innerHTML = ICONS.tune;
  fab.addEventListener("click", () => openTimelineOptions(redraw));

  container.append(header, tabs, grid, fab);

  const dayLabels = ["", "一", "二", "三", "四", "五", "六", "日"];

  function buildTabs() {
    tabs.innerHTML = "";
    for (let i = 1; i <= 7; i++) {
      const tab = el(
        "button",
        {
          class:
            "week-tab" +
            (i === TIMELINE_STATE.activeWeekday ? " is-active" : ""),
          onclick: () => {
            TIMELINE_STATE.activeWeekday = i;
            redraw();
          },
        },
        dayLabels[i]
      );
      tabs.append(tab);
    }
  }

  function redrawGrid() {
    grid.innerHTML = "";
    if (TIMELINE_STATE.isLoading) {
      setStatus(grid, "加载中…");
      return;
    }
    if (TIMELINE_STATE.isError) {
      setStatus(grid, "什么都没有找到 (´;ω;`)", true);
      return;
    }
    const day = TIMELINE_STATE.days[TIMELINE_STATE.activeWeekday - 1] || [];
    let list = sortDayList(day, TIMELINE_STATE.sortType);
    list = filterTimelineDay(list);
    if (!list.length) {
      setStatus(grid, "当前条件下没有番剧");
      return;
    }
    for (const item of list) grid.append(buildTimelineCard(item));
  }

  function redraw() {
    // 更新标题（切季后季节字符串可能变了）
    const titleNode = header.querySelector(".page-title");
    if (titleNode && titleNode.firstChild) {
      titleNode.firstChild.nodeValue = TIMELINE_STATE.seasonString;
    }
    buildTabs();
    redrawGrid();
  }

  buildTabs();

  // 仅当数据为空且未标记错误时拉取，避免重复请求
  const allEmpty = TIMELINE_STATE.days.every((d) => !d.length);
  if (allEmpty && !TIMELINE_STATE.isError) {
    TIMELINE_STATE.isLoading = true;
    redrawGrid();
    const isCurrent = isSameSeasonDate(
      TIMELINE_STATE.selectedDate,
      new Date()
    );
    await Promise.all([
      fetchTimelineData(isCurrent ? null : seasonKey(TIMELINE_STATE.selectedDate)),
      loadCollectIdsForTimeline(),
    ]);
  }
  redrawGrid();
}

function buildTimelineCard(item) {
  const img = el("img", {
    class: "cover",
    loading: "lazy",
    referrerpolicy: "no-referrer",
    alt: "",
  });
  const src = bestBangumiImage(item.images);
  if (src) img.src = src;
  const title = el("div", { class: "title" }, item.nameCn || item.name);
  const supportingText =
    (item.info && item.info.trim && item.info.trim()) ||
    (item.summary && item.summary.trim()) ||
    "";
  const supporting = supportingText
    ? el("div", { class: "supporting" }, supportingText)
    : null;
  const metrics = el("div", { class: "metrics" });
  if (item.ratingScore > 0) {
    const m = el("span", { class: "metric score" });
    m.innerHTML = ICONS.star + "<span>" + item.ratingScore.toFixed(1) + "</span>";
    metrics.append(m);
  }
  if (item.rank > 0) {
    const m = el("span", { class: "metric rank" });
    m.innerHTML = ICONS.leaderboard + "<span>#" + item.rank + "</span>";
    metrics.append(m);
  }
  if (item.votes > 0) {
    const m = el("span", { class: "metric votes" });
    m.innerHTML = ICONS.how_to_vote + "<span>" + item.votes + "</span>";
    metrics.append(m);
  }
  const body = el("div", { class: "body" }, title, supporting, metrics);
  const card = el(
    "div",
    {
      class: "timeline-card",
      onclick: () => go("/bangumi", { id: String(item.id) }),
    },
    img,
    body
  );
  return card;
}

// 对齐 timeline_page.dart 的"时间机器" bottom sheet：按年分组，列出已开播的季。
function openSeasonPicker(onChange) {
  openModal((sheet, close) => {
    sheet.append(
      el(
        "div",
        { class: "options-summary" },
        el("div", { class: "title" }, "时间机器"),
        el("div", { class: "desc" }, "按季度回到任意放送季，时间线会立即切换。"),
        el(
          "div",
          { class: "chips" },
          el(
            "span",
            { class: "summary-chip highlighted" },
            "当前查看 " + TIMELINE_STATE.seasonString
          )
        )
      )
    );

    const list = el("div", {});
    sheet.append(list);

    const seasonNames = ["冬", "春", "夏", "秋"];
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentQuarter = seasonQuarter(now);
    const selectedYear = TIMELINE_STATE.selectedDate.getFullYear();
    const selectedQuarter = seasonQuarter(TIMELINE_STATE.selectedDate);

    for (let offset = 0; offset < 20; offset++) {
      const year = currentYear - offset;
      const available = [];
      for (let q = 1; q <= 4; q++) {
        if (year < currentYear || (year === currentYear && q <= currentQuarter)) {
          available.push(q);
        }
      }
      if (!available.length) continue;

      const hasSelected =
        year === selectedYear && available.includes(selectedQuarter);
      const card = el("div", {
        class: "season-year-card" + (hasSelected ? " has-selected" : ""),
      });
      card.append(el("div", { class: "year" }, year + "年"));
      if (!hasSelected) {
        card.append(
          el("div", { class: "year-hint" }, "共 " + available.length + " 个季度可选")
        );
      }
      const chips = el("div", { class: "season-chips" });
      for (const q of available) {
        const isSel = year === selectedYear && q === selectedQuarter;
        const chip = el(
          "button",
          {
            class: "season-chip" + (isSel ? " is-selected" : ""),
            onclick: async () => {
              close();
              if (isSel) return;
              const newDate = new Date(year, (q - 1) * 3, 1);
              TIMELINE_STATE.selectedDate = newDate;
              TIMELINE_STATE.seasonString = seasonOf(newDate);
              TIMELINE_STATE.days = [[], [], [], [], [], [], []];
              TIMELINE_STATE.isLoading = true;
              TIMELINE_STATE.isError = false;
              if (onChange) onChange();
              const isCurrent = isSameSeasonDate(newDate, new Date());
              await fetchTimelineData(isCurrent ? null : seasonKey(newDate));
              if (onChange) onChange();
            },
          },
          seasonNames[q - 1]
        );
        chips.append(chip);
      }
      card.append(chips);
      list.append(card);
    }
  });
}

// 对齐 timeline_page.dart 的"时间线选项" sheet：排序 3 项 + 过滤 3 项。
function openTimelineOptions(onChange) {
  openModal((sheet, close) => {
    const renderSummary = () => {
      const enabledFilters = [
        TIMELINE_STATE.filterAbandoned,
        TIMELINE_STATE.filterWatched,
        TIMELINE_STATE.filterOnlyWatching,
      ].filter(Boolean).length;
      summaryNode.innerHTML = "";
      summaryNode.append(
        el("div", { class: "title" }, "时间线选项"),
        el(
          "div",
          { class: "desc" },
          "调整排序和过滤条件，结果会立即应用到当前时间线。"
        ),
        el(
          "div",
          { class: "chips" },
          el(
            "span",
            { class: "summary-chip highlighted" },
            "当前排序 " + sortTypeLabel(TIMELINE_STATE.sortType)
          ),
          el(
            "span",
            { class: "summary-chip" },
            enabledFilters === 0
              ? "未启用过滤条件"
              : "已启用 " + enabledFilters + " 个过滤条件"
          )
        )
      );
    };
    const summaryNode = el("div", { class: "options-summary" });
    sheet.append(summaryNode);

    // Sort section
    const sortSection = el(
      "div",
      { class: "options-section" },
      el("h3", {}, "排序方式"),
      el("div", { class: "desc" }, "选择每一天内番剧卡片的排列方式。")
    );
    const sortOptions = [
      { type: 3, icon: "fire", title: "按热度排序", desc: "优先展示讨论度和关注度更高的条目。" },
      { type: 2, icon: "star", title: "按评分排序", desc: "优先展示评分更高的条目。" },
      { type: 1, icon: "schedule", title: "按时间排序", desc: "恢复默认时间顺序，方便按播出节奏查看。" },
    ];
    for (const opt of sortOptions) {
      const tile = el("div", { class: "option-tile" });
      const leading = el("span", { class: "leading" });
      leading.innerHTML = ICONS[opt.icon];
      const trailing = el("span", { class: "trailing" });
      const refreshTile = () => {
        const selected = TIMELINE_STATE.sortType === opt.type;
        tile.classList.toggle("is-selected", selected);
        trailing.innerHTML = selected ? ICONS.check_circle : ICONS.radio_unchecked;
      };
      tile.append(
        leading,
        el(
          "div",
          { class: "text" },
          el("div", { class: "row-title" }, opt.title),
          el("div", { class: "row-desc" }, opt.desc)
        ),
        trailing
      );
      refreshTile();
      tile.addEventListener("click", () => {
        TIMELINE_STATE.sortType = opt.type;
        localStorage.setItem("timelineSortType", String(opt.type));
        // 仅刷新本 section（保持 sheet 打开）
        for (const sib of sortSection.querySelectorAll(".option-tile")) {
          sib.classList.remove("is-selected");
          const tr = sib.querySelector(".trailing");
          if (tr) tr.innerHTML = ICONS.radio_unchecked;
        }
        refreshTile();
        renderSummary();
        if (onChange) onChange();
      });
      sortSection.append(tile);
    }
    sheet.append(sortSection);

    // Filter section
    const filterSection = el(
      "div",
      { class: "options-section" },
      el("h3", {}, "过滤器"),
      el("div", { class: "desc" }, "按收藏状态收起不需要显示的条目，支持连续调整。")
    );
    const filterOptions = [
      {
        key: "filterAbandoned",
        icon: "heart_broken",
        title: "不显示已抛弃的番剧",
        desc: "隐藏已经标记为抛弃的条目。",
        storeKey: "timelineFilterAbandoned",
      },
      {
        key: "filterWatched",
        icon: "task_alt",
        title: "不显示已看过的番剧",
        desc: "把已经看完的条目从时间线中移除。",
        storeKey: "timelineFilterWatched",
      },
      {
        key: "filterOnlyWatching",
        icon: "live_tv",
        title: "只显示在看的番剧",
        desc: "聚焦当前正在追更的条目。",
        storeKey: "timelineFilterWatching",
      },
    ];
    for (const opt of filterOptions) {
      const tile = el("div", { class: "option-tile" });
      const leading = el("span", { class: "leading" });
      leading.innerHTML = ICONS[opt.icon];
      const toggle = el("span", { class: "option-toggle" });
      tile.append(
        leading,
        el(
          "div",
          { class: "text" },
          el("div", { class: "row-title" }, opt.title),
          el("div", { class: "row-desc" }, opt.desc)
        ),
        toggle
      );
      const refresh = () => {
        tile.classList.toggle("is-selected", TIMELINE_STATE[opt.key]);
      };
      refresh();
      tile.addEventListener("click", () => {
        TIMELINE_STATE[opt.key] = !TIMELINE_STATE[opt.key];
        localStorage.setItem(opt.storeKey, TIMELINE_STATE[opt.key] ? "1" : "0");
        refresh();
        renderSummary();
        if (onChange) onChange();
      });
      filterSection.append(tile);
    }
    sheet.append(filterSection);

    renderSummary();
  });
}

// 收藏页：对齐桌面端 CollectPage（5 Tab 分组）
const COLLECT_LABELS = { 1: "在看", 2: "想看", 3: "搁置", 4: "看过", 5: "抛弃" };
const COLLECT_TAB_ORDER = [1, 2, 3, 4, 5];

async function renderTabCollect(container) {
  container.append(pageHeader("追番"));

  // 5 个 Tab
  const tabBar = el("div", { class: "tabs" });
  const tabBody = el("div", {});
  container.append(tabBar, tabBody);
  let activeType = parseInt(localStorage.getItem("collectActiveType") || "1", 10);
  if (!COLLECT_TAB_ORDER.includes(activeType)) activeType = 1;

  const tabNodes = {};
  for (const t of COLLECT_TAB_ORDER) {
    const node = el(
      "div",
      { class: "tab" + (t === activeType ? " is-active" : "") },
      COLLECT_LABELS[t]
    );
    node.addEventListener("click", () => switchTab(t));
    tabNodes[t] = node;
    tabBar.append(node);
  }

  function switchTab(t) {
    activeType = t;
    localStorage.setItem("collectActiveType", String(t));
    for (const k of COLLECT_TAB_ORDER) {
      tabNodes[k].classList.toggle("is-active", k === t);
    }
    renderGroup();
  }

  // 数据：一次性拉全量，前端分组
  let groups = null;
  setStatus(tabBody, "加载中…");
  try {
    const data = await fetchJson("/api/collect/list");
    const items = data.items || [];
    groups = { 1: [], 2: [], 3: [], 4: [], 5: [] };
    for (const it of items) {
      if (groups[it.type]) groups[it.type].push(it);
    }
    // 更新 tab 显示带计数
    for (const t of COLLECT_TAB_ORDER) {
      tabNodes[t].textContent =
        COLLECT_LABELS[t] + (groups[t].length ? " · " + groups[t].length : "");
      tabNodes[t].classList.toggle("is-active", t === activeType);
    }
  } catch (e) {
    setStatus(tabBody, "加载失败：" + e.message, true);
    return;
  }

  function renderGroup() {
    tabBody.innerHTML = "";
    const list = groups[activeType] || [];
    if (!list.length) {
      setStatus(tabBody, "这里还没有内容，去推荐页找一部番剧吧");
      return;
    }
    const grid = el("div", { class: "poster-grid" });
    for (const c of list) grid.append(buildPosterCard(c.bangumi));
    tabBody.append(grid);
  }
  renderGroup();
}

async function renderTabMy(container) {
  container.append(pageHeader("我的"));
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

// 搜索状态：对齐桌面端 SearchPage 的 3 种排序 + 2 个过滤 + 历史记录（10 条）
const SEARCH_STATE = {
  raw: [],          // 原始结果（按服务端默认顺序）
  sortType: parseInt(localStorage.getItem("searchSortType") || "1", 10),
  hideWatched: localStorage.getItem("searchHideWatched") === "1",
  hideAbandoned: localStorage.getItem("searchHideAbandoned") === "1",
  watchedIds: new Set(),
  abandonedIds: new Set(),
};

// 排序：1=匹配度（默认/不动）/ 2=评分 / 3=热度
function sortSearchResults(items) {
  const arr = items.slice();
  if (SEARCH_STATE.sortType === 2) {
    arr.sort((a, b) => (b.ratingScore || 0) - (a.ratingScore || 0));
  } else if (SEARCH_STATE.sortType === 3) {
    arr.sort((a, b) => (b.votes || 0) - (a.votes || 0));
  }
  return arr;
}
function filterSearchResults(items) {
  let arr = items;
  if (SEARCH_STATE.hideWatched) {
    arr = arr.filter((it) => !SEARCH_STATE.watchedIds.has(it.id));
  }
  if (SEARCH_STATE.hideAbandoned) {
    arr = arr.filter((it) => !SEARCH_STATE.abandonedIds.has(it.id));
  }
  return arr;
}

function loadSearchHistory() {
  try {
    const arr = JSON.parse(localStorage.getItem("searchHistory") || "[]");
    return Array.isArray(arr) ? arr : [];
  } catch (_) {
    return [];
  }
}
function pushSearchHistory(keyword) {
  const kw = (keyword || "").trim();
  if (!kw) return;
  let arr = loadSearchHistory();
  arr = arr.filter((x) => x !== kw);
  arr.unshift(kw);
  if (arr.length > 10) arr.length = 10;
  try { localStorage.setItem("searchHistory", JSON.stringify(arr)); } catch (_) {}
}
function clearSearchHistory() {
  try { localStorage.removeItem("searchHistory"); } catch (_) {}
}

async function loadCollectIdsForSearch() {
  try {
    const data = await fetchJson("/api/collect/list");
    const items = data.items || [];
    const watched = new Set();
    const abandoned = new Set();
    for (const it of items) {
      if (it.type === 4) watched.add(it.bangumiId);
      else if (it.type === 5) abandoned.add(it.bangumiId);
    }
    SEARCH_STATE.watchedIds = watched;
    SEARCH_STATE.abandonedIds = abandoned;
  } catch (_) {}
}

function renderSearchResults() {
  const results = document.getElementById("bangumi-results");
  if (!results) return;
  results.innerHTML = "";
  let arr = sortSearchResults(SEARCH_STATE.raw);
  arr = filterSearchResults(arr);
  if (!arr.length) {
    setStatus(results, SEARCH_STATE.raw.length ? "过滤后没有内容" : "没有结果");
    return;
  }
  for (const item of arr) results.append(buildBangumiCard(item));
}

async function runBangumiSearch(keyword) {
  const results = document.getElementById("bangumi-results");
  if (!results) return;
  setStatus(results, "搜索中…");
  try {
    const data = await fetchJson("/api/bangumi/search?keyword=" + encodeURIComponent(keyword));
    SEARCH_STATE.raw = data.items || [];
    renderSearchResults();
  } catch (e) {
    SEARCH_STATE.raw = [];
    setStatus(results, "搜索失败：" + e.message, true);
  }
}

async function renderSearch(params) {
  $app.innerHTML = "";
  renderNavRail("");

  // 标题旁加排序/过滤按钮 + 历史按钮
  const optionsBtn = el("button", { class: "icon-btn", "aria-label": "排序与过滤" });
  optionsBtn.innerHTML = ICONS.tune;
  optionsBtn.addEventListener("click", () => openSearchOptions());
  $app.append(pageHeader("搜索", { back: true, trailing: optionsBtn }));

  const input = el("input", {
    type: "search",
    placeholder: "搜索番剧（Bangumi）",
    autocomplete: "off",
    autocorrect: "off",
    spellcheck: "false",
  });
  input.value = (params && params.q) || localStorage.getItem("lastBangumiKeyword") || "";
  const submit = el("button", { class: "submit", "aria-label": "搜索", type: "submit", html: ICONS.arrow_forward });
  const form = el("form", { class: "search-bar" }, input, submit);
  form.addEventListener("submit", (ev) => {
    ev.preventDefault();
    const keyword = input.value.trim();
    if (!keyword) return;
    localStorage.setItem("lastBangumiKeyword", keyword);
    pushSearchHistory(keyword);
    renderHistoryRow();
    runBangumiSearch(keyword);
  });
  $app.append(form);

  // 历史记录行（最近 10 条 chip）
  const historyRow = el("div", { class: "search-history" });
  $app.append(historyRow);
  function renderHistoryRow() {
    historyRow.innerHTML = "";
    const arr = loadSearchHistory();
    if (!arr.length) return;
    historyRow.append(el("span", { class: "search-history-label" }, "最近："));
    for (const kw of arr) {
      const chip = el("button", { class: "search-history-chip", type: "button" }, kw);
      chip.addEventListener("click", () => {
        input.value = kw;
        localStorage.setItem("lastBangumiKeyword", kw);
        pushSearchHistory(kw);
        renderHistoryRow();
        runBangumiSearch(kw);
      });
      historyRow.append(chip);
    }
    const clearBtn = el("button", { class: "search-history-chip is-clear", type: "button" }, "清空");
    clearBtn.addEventListener("click", () => {
      clearSearchHistory();
      renderHistoryRow();
    });
    historyRow.append(clearBtn);
  }
  renderHistoryRow();

  const results = el("div", { class: "list", id: "bangumi-results" });
  $app.append(results);

  // 拉收藏数据让过滤生效（异步，不阻塞首搜）
  loadCollectIdsForSearch();

  setTimeout(() => { try { input.focus(); } catch (_) {} }, 50);
  if (input.value) runBangumiSearch(input.value);
}

function openSearchOptions() {
  openModal((sheet, _close) => {
    sheet.append(el("div", { class: "modal-title" }, "排序与过滤"));

    // 排序 section
    const sortSection = el("div", { class: "options-section" },
      el("h3", {}, "排序方式"),
      el("div", { class: "desc" }, "Bangumi 默认按匹配度返回")
    );
    const sortOptions = [
      { type: 1, icon: "search", title: "按匹配度", desc: "保留 Bangumi 默认顺序" },
      { type: 2, icon: "star", title: "按评分", desc: "评分高的优先" },
      { type: 3, icon: "fire", title: "按热度", desc: "评分人数多的优先" },
    ];
    for (const opt of sortOptions) {
      const tile = el("div", { class: "option-tile" });
      const leading = el("span", { class: "leading" });
      leading.innerHTML = ICONS[opt.icon];
      const trailing = el("span", { class: "trailing" });
      const refresh = () => {
        const sel = SEARCH_STATE.sortType === opt.type;
        tile.classList.toggle("is-selected", sel);
        trailing.innerHTML = sel ? ICONS.check_circle : ICONS.radio_unchecked;
      };
      tile.append(
        leading,
        el("div", { class: "text" },
          el("div", { class: "row-title" }, opt.title),
          el("div", { class: "row-desc" }, opt.desc)),
        trailing
      );
      refresh();
      tile.addEventListener("click", () => {
        SEARCH_STATE.sortType = opt.type;
        localStorage.setItem("searchSortType", String(opt.type));
        for (const sib of sortSection.querySelectorAll(".option-tile")) {
          sib.classList.remove("is-selected");
          const tr = sib.querySelector(".trailing");
          if (tr) tr.innerHTML = ICONS.radio_unchecked;
        }
        refresh();
        renderSearchResults();
      });
      sortSection.append(tile);
    }
    sheet.append(sortSection);

    // 过滤 section
    const filterSection = el("div", { class: "options-section" },
      el("h3", {}, "过滤器")
    );
    const filterOpts = [
      { key: "hideWatched", icon: "task_alt", title: "不显示已看过的番剧",
        desc: "已收藏为「看过」的结果会被隐藏", storeKey: "searchHideWatched" },
      { key: "hideAbandoned", icon: "heart_broken", title: "不显示已抛弃的番剧",
        desc: "已收藏为「抛弃」的结果会被隐藏", storeKey: "searchHideAbandoned" },
    ];
    for (const opt of filterOpts) {
      const tile = el("div", { class: "option-tile" });
      const leading = el("span", { class: "leading" });
      leading.innerHTML = ICONS[opt.icon];
      const toggle = el("span", { class: "option-toggle" });
      tile.append(
        leading,
        el("div", { class: "text" },
          el("div", { class: "row-title" }, opt.title),
          el("div", { class: "row-desc" }, opt.desc)),
        toggle
      );
      const refresh = () => tile.classList.toggle("is-selected", SEARCH_STATE[opt.key]);
      refresh();
      tile.addEventListener("click", () => {
        SEARCH_STATE[opt.key] = !SEARCH_STATE[opt.key];
        localStorage.setItem(opt.storeKey, SEARCH_STATE[opt.key] ? "1" : "0");
        refresh();
        renderSearchResults();
      });
      filterSection.append(tile);
    }
    sheet.append(filterSection);
  });
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

// plugin 搜索（单插件，单关键词）。后端 423=captcha，502=search_failed
// （这两个用 status code 区分，对齐桌面端 QueryManager 的 captcha/error/noResult/success 状态机）
async function pluginSearchSingle(pluginName, keyword) {
  const res = await fetch(
    "/api/search?plugin=" + encodeURIComponent(pluginName) + "&keyword=" + encodeURIComponent(keyword)
  );
  if (res.status === 423) {
    const err = new Error("captcha required");
    err.code = "captcha";
    throw err;
  }
  if (!res.ok) {
    let detail = res.statusText;
    try { const body = await res.json(); if (body && body.message) detail = body.message; } catch (_) {}
    const err = new Error(detail);
    err.code = "error";
    throw err;
  }
  const data = await res.json();
  return data.items || [];
}

async function renderBangumiDetail(params) {
  const id = parseInt(params.id, 10);
  if (!id) { go("/home"); return; }
  $app.innerHTML = "";
  renderNavRail("");

  // 返回按钮 + bangumi.tv 外链按钮 —— 不再用独立 pageHeader（会留出黑色空带），
  // 改成浮在 hero 内部 absolute 定位（对齐桌面端 SliverAppBar.medium 的 leading/actions
  // 直接叠在 flexibleSpace 背景上）。两个按钮稍后插到 hero 顶部。
  const backBtn = el("button", { class: "icon-btn", "aria-label": "返回" });
  backBtn.innerHTML = ICONS.arrow_back;
  backBtn.addEventListener("click", () => history.back());
  const headerOpenBtn = el("button", { class: "icon-btn", "aria-label": "在 Bangumi 打开" });
  headerOpenBtn.innerHTML = ICONS.open_in_browser;
  headerOpenBtn.addEventListener("click", () => {
    window.open("https://bangumi.tv/subject/" + id, "_blank", "noopener");
  });

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

  // Hero。结构对齐桌面端 BangumiInfoCardV：
  //   - 标题在 hero 顶部全宽
  //   - 下方横排：cover (左) + meta column (右)
  //   - meta column 用 space-between 把 CollectButton 推到底
  //   - 每组信息（放送/评分/Rank）是 label + value 上下两行（桌面端就是这样）
  // 背景图必须用 <img referrerpolicy="no-referrer">：bangumi.tv 拒绝带 Referer
  // 的图片请求，CSS background-image 没法控制 referrer。
  const cover = bestBangumiImage(bangumi.images);
  const hero = el("div", { class: "hero" });
  if (cover) {
    const bgImg = el("img", {
      class: "hero-bg",
      "aria-hidden": "true",
      alt: "",
      referrerpolicy: "no-referrer",
      loading: "eager",
    });
    bgImg.src = cover;
    hero.append(bgImg);
  }

  // 返回 / 外链 按钮浮在 hero 内（absolute），让 banner 撑到顶端
  backBtn.classList.add("hero-leading");
  headerOpenBtn.classList.add("hero-trailing");
  hero.append(backBtn);
  hero.append(headerOpenBtn);

  hero.append(
    el("div", { class: "hero-title" }, bangumi.nameCn || bangumi.name)
  );

  const coverImg = el("img", {
    class: "hero-cover",
    loading: "lazy",
    alt: "",
    referrerpolicy: "no-referrer",
  });
  if (cover) coverImg.src = cover;

  const heroMeta = el("div", { class: "hero-meta" });
  const heroInfoCol = el("div", { class: "hero-info" });

  // 放送开始
  if (bangumi.airDate) {
    heroInfoCol.append(
      el(
        "div",
        { class: "hero-info-group" },
        el("div", { class: "hero-info-label" }, "放送开始:"),
        el("div", { class: "hero-info-value" }, bangumi.airDate)
      )
    );
  }

  // 评分（人数+分数+星）
  if (bangumi.ratingScore > 0) {
    const ratingValue = el("div", { class: "hero-info-value hero-info-rating" });
    ratingValue.append(
      el("span", { class: "score" }, bangumi.ratingScore.toFixed(1))
    );
    const stars = renderStars(bangumi.ratingScore);
    if (stars) ratingValue.append(el("span", { class: "stars" }, stars));
    heroInfoCol.append(
      el(
        "div",
        { class: "hero-info-group" },
        el(
          "div",
          { class: "hero-info-label" },
          (bangumi.votes > 0 ? bangumi.votes : 0) + " 人评分:"
        ),
        ratingValue
      )
    );
  }

  // Bangumi Ranked
  if (bangumi.rank > 0) {
    heroInfoCol.append(
      el(
        "div",
        { class: "hero-info-group" },
        el("div", { class: "hero-info-label" }, "Bangumi Ranked:"),
        el("div", { class: "hero-info-value" }, "#" + bangumi.rank)
      )
    );
  }

  // 收藏按钮（meta 底部，对齐 BangumiInfoCardV 的 spaceBetween）
  const collectBtn = el("button", {
    class: "collect-btn",
    "aria-label": "收藏状态",
  });
  const collectIcon = el("span", { class: "icon", "aria-hidden": "true" });
  const collectLabel = el("span", { class: "label" }, "未追");
  collectBtn.append(collectIcon, collectLabel);

  heroMeta.append(heroInfoCol, collectBtn);
  hero.append(el("div", { class: "hero-row" }, coverImg, heroMeta));
  $app.append(hero);

  const collectHint = el("span", { class: "hint" });
  $app.append(collectHint);

  let currentCollectType = 0;
  function refreshCollectBtn(type) {
    const def = collectTypeOf(type);
    collectIcon.innerHTML = ICONS[def.icon] || "";
    collectLabel.textContent = def.label;
  }
  refreshCollectBtn(0);
  fetchJson("/api/collect?bangumiId=" + id)
    .then((data) => {
      currentCollectType = data.type || 0;
      refreshCollectBtn(currentCollectType);
    })
    .catch(() => {});

  collectBtn.addEventListener("click", () => {
    openModal((sheet, _close) => {
      sheet.append(el("div", { class: "modal-title" }, "选择收藏状态"));
      const list = el("div", { class: "collect-menu" });
      for (const t of COLLECT_TYPES) {
        const isCurrent = t.value === currentCollectType;
        const iconNode = el("span", { class: "icon", "aria-hidden": "true" });
        iconNode.innerHTML = ICONS[t.icon] || "";
        const labelNode = el("span", { class: "label" }, t.label);
        const item = el(
          "div",
          { class: "collect-menu-item" + (isCurrent ? " is-current" : "") },
          iconNode,
          labelNode
        );
        item.addEventListener("click", async () => {
          if (t.value === currentCollectType) {
            _close();
            return;
          }
          try {
            const res = await fetch("/api/collect", {
              method: "PUT",
              headers: { "content-type": "application/json" },
              body: JSON.stringify({ bangumiId: id, type: t.value }),
            });
            if (!res.ok) throw new Error("HTTP " + res.status);
            const body = await res.json();
            currentCollectType = body.type || 0;
            refreshCollectBtn(currentCollectType);
            _close();
          } catch (e) {
            collectHint.textContent = "保存失败：" + e.message;
          }
        });
        list.append(item);
      }
      sheet.append(list);
    });
  });

  // Tabs（对齐 info_page.dart：概览/吐槽/角色/评论/制作人员）
  const tabBar = el("div", { class: "tabs" });
  const tabBody = el("div", {});
  const tabs = [
    { key: "summary", label: "概览" },
    { key: "tucao", label: "吐槽" },
    { key: "characters", label: "角色" },
    { key: "comments", label: "评论" },
    { key: "staff", label: "制作人员" },
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
    else if (key === "tucao") renderTucao();
    else if (key === "characters") renderCharacters();
    else if (key === "comments") renderComments();
    else if (key === "staff") renderStaff();
  }

  // ====== 概览：简介 + 标签 ======
  function renderSummary() {
    if (bangumi.summary) {
      tabBody.append(el("h2", {}, "简介"));
      const card = el("div", { class: "summary-card collapsed" }, bangumi.summary);
      const toggle = el("button", { class: "summary-toggle" }, "展开");
      toggle.addEventListener("click", () => {
        const expanded = card.classList.toggle("collapsed");
        toggle.textContent = expanded ? "展开" : "收起";
      });
      tabBody.append(card, toggle);
    } else {
      tabBody.append(el("div", { class: "status" }, "暂无简介"));
    }

    // 标签：每个 chip 显示 name + count（primary 色），点击进搜索
    if (Array.isArray(bangumi.tags) && bangumi.tags.length) {
      tabBody.append(el("h2", {}, "标签"));
      const chips = el("div", { class: "chips" });
      // 桌面端默认展示前 12 个，点"更多+"展开
      let fullTag = false;
      const renderChips = () => {
        chips.innerHTML = "";
        const showAll = fullTag || bangumi.tags.length < 13;
        const total = showAll ? bangumi.tags.length : 12;
        for (let i = 0; i < total; i++) {
          const t = bangumi.tags[i];
          const chip = el(
            "div",
            {
              class: "tag-chip",
              onclick: () => go("/search", { q: t.name }),
            },
            el("span", {}, t.name + " "),
            el("span", { class: "count" }, String(t.count))
          );
          chips.append(chip);
        }
        if (!showAll) {
          const more = el(
            "div",
            {
              class: "tag-chip",
              onclick: () => { fullTag = true; renderChips(); },
            },
            el("span", { class: "count" }, "更多 +")
          );
          chips.append(more);
        }
      };
      renderChips();
      tabBody.append(chips);
    }

    if (Array.isArray(bangumi.alias) && bangumi.alias.length) {
      tabBody.append(el("h2", {}, "别名"));
      const chips = el("div", { class: "chips" });
      for (const a of bangumi.alias) chips.append(el("span", { class: "chip" }, a));
      tabBody.append(chips);
    }
  }

  // ====== 吐槽：分页加载（对齐桌面端 info_tabview.commentsListBody 滚到底加载） ======
  function renderTucao() {
    const list = el("div", {});
    tabBody.append(list);
    const status = el("div", { class: "status" }, "加载中…");
    list.append(status);

    let offset = 0;
    let total = -1; // 未知
    let exhausted = false;
    let loading = false;
    let hadAny = false;

    const loadMore = async () => {
      if (loading || exhausted) return;
      loading = true;
      try {
        const data = await fetchJson(
          "/api/bangumi/" + id + "/comments?offset=" + offset
        );
        // 首次请求清掉 status
        if (status.parentNode) status.remove();
        const items = data.items || [];
        if (!hadAny && !items.length) {
          list.append(el("div", { class: "status" }, "暂无吐槽"));
          exhausted = true;
          return;
        }
        if (items.length) hadAny = true;
        for (const c of items) {
          const head = el("div", { class: "comment-head" });
          const avatar = el("img", { alt: "", referrerpolicy: "no-referrer" });
          if (c.user && c.user.avatar) avatar.src = c.user.avatar;
          head.append(avatar);
          head.append(
            el(
              "span",
              { class: "username" },
              (c.user && (c.user.nickname || c.user.username)) || "用户"
            )
          );
          if (c.rate > 0) head.append(el("span", { class: "rate" }, "★ " + c.rate));
          list.append(
            el(
              "div",
              { class: "comment-card" },
              head,
              el("div", { class: "comment-body" }, c.comment)
            )
          );
        }
        offset += items.length;
        if (typeof data.total === "number") total = data.total;
        if (!items.length || (total >= 0 && offset >= total)) {
          exhausted = true;
        }
      } catch (e) {
        if (status.parentNode) status.remove();
        if (!hadAny) {
          list.append(el("div", { class: "status error" }, "加载失败：" + e.message));
          exhausted = true; // 失败不再自动重试
        }
      } finally {
        loading = false;
      }
    };

    // 监听滚动到底（容器在 .content 内，滚动监听放在 window）
    const onScroll = () => {
      if (activeTab !== "tucao") return; // 切走后不再触发
      const doc = document.documentElement;
      if (window.innerHeight + window.scrollY >= doc.scrollHeight - 240) {
        loadMore();
      }
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    // tabBody 切换时移除监听
    const observer = new MutationObserver(() => {
      if (!list.isConnected) {
        window.removeEventListener("scroll", onScroll);
        observer.disconnect();
      }
    });
    observer.observe(tabBody, { childList: true });

    loadMore();
  }

  // ====== 角色：行布局（对齐桌面端 CharacterCard ListTile） ======
  async function renderCharacters() {
    tabBody.append(el("div", { class: "status" }, "加载中…"));
    try {
      const data = await fetchJson("/api/bangumi/" + id + "/characters");
      tabBody.innerHTML = "";
      if (!data.characters || !data.characters.length) {
        tabBody.append(el("div", { class: "status" }, "暂无角色"));
        return;
      }
      const wrap = el("div", {});
      for (const c of data.characters) {
        const avatar = el("img", { class: "avatar", loading: "lazy", alt: "", referrerpolicy: "no-referrer" });
        if (c.image) avatar.src = c.image;
        const firstActor =
          c.actors && c.actors.length ? c.actors[0].name : "";
        const row = el(
          "div",
          { class: "info-row" },
          avatar,
          el(
            "div",
            { class: "body" },
            el("div", { class: "name" }, c.name),
            firstActor ? el("div", { class: "sub" }, firstActor) : null
          ),
          c.relation ? el("div", { class: "trailing" }, c.relation) : null
        );
        wrap.append(row);
      }
      tabBody.append(wrap);
    } catch (e) {
      tabBody.innerHTML = "";
      setStatus(tabBody, "加载失败：" + e.message, true);
    }
  }

  // ====== 评论：施工中占位（与桌面端 info_tabview "施工中" 一致） ======
  function renderComments() {
    tabBody.append(el("div", { class: "status" }, "施工中"));
  }

  // ====== 制作人员：行布局 ======
  async function renderStaff() {
    tabBody.append(el("div", { class: "status" }, "加载中…"));
    try {
      const data = await fetchJson("/api/bangumi/" + id + "/staff");
      tabBody.innerHTML = "";
      if (!data.items || !data.items.length) {
        tabBody.append(el("div", { class: "status" }, "暂无制作信息"));
        return;
      }
      const wrap = el("div", {});
      for (const s of data.items) {
        const avatar = el("img", { class: "avatar", loading: "lazy", alt: "", referrerpolicy: "no-referrer" });
        if (s.image) avatar.src = s.image;
        const positions = (s.positions || []).map((p) => p.type).filter(Boolean).join(" / ");
        const row = el(
          "div",
          { class: "info-row" },
          avatar,
          el(
            "div",
            { class: "body" },
            el("div", { class: "name" }, s.nameCN || s.name),
            positions ? el("div", { class: "sub" }, positions) : null
          )
        );
        wrap.append(row);
      }
      tabBody.append(wrap);
    } catch (e) {
      tabBody.innerHTML = "";
      setStatus(tabBody, "加载失败：" + e.message, true);
    }
  }

  renderTabBody("summary");

  // FAB: 开始观看 (M3 Extended FAB with leading play icon)
  const fab = el("button", { class: "fab fab-extended", "aria-label": "开始观看" });
  const fabIcon = el("span", { class: "icon", "aria-hidden": "true" });
  fabIcon.innerHTML = ICONS.play_arrow;
  fab.append(fabIcon, document.createTextNode("开始观看"));
  fab.addEventListener("click", () => openSourcePicker(bangumi));
  $app.append(fab);
}

// 选源 Sheet：对齐桌面端 SourceSheet（Plugin TabBar + 并发查询 + 状态点
// + 别名/手动检索补充入口）。
async function openSourcePicker(bangumi) {
  openModal(async (sheet, _close) => {
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

    // pluginState[name] = { status: 'pending'|'success'|'noResult'|'captcha'|'error', items, error }
    const pluginState = {};
    for (const p of plugins) pluginState[p.name] = { status: "pending", items: null };

    // 默认 active：上次用过的 plugin，否则第一个
    let activePluginName = plugins[0].name;
    const lastPlugin = localStorage.getItem("lastPlugin");
    if (lastPlugin && plugins.some((p) => p.name === lastPlugin)) {
      activePluginName = lastPlugin;
    }

    // 关键词输入（提交触发对所有 plugin 重新查询）
    const keywordInput = el("input", {
      type: "search",
      placeholder: "搜索关键词",
      autocomplete: "off",
      autocorrect: "off",
      spellcheck: "false",
    });
    keywordInput.value = bangumi.nameCn || bangumi.name;
    const submit = el("button", {
      class: "submit", type: "submit", "aria-label": "搜索",
      html: ICONS.arrow_forward,
    });
    const form = el("form", { class: "search-bar" }, keywordInput, submit);
    sheet.append(form);

    // Plugin TabBar（含状态色点）
    const tabs = el("div", { class: "source-tabs" });
    sheet.append(tabs);
    const body = el("div", { class: "source-body" });
    sheet.append(body);

    function renderTabs() {
      tabs.innerHTML = "";
      for (const p of plugins) {
        const state = pluginState[p.name];
        const dot = el("span", { class: "source-tab-dot status-" + state.status });
        const tab = el(
          "button",
          {
            class: "source-tab" + (p.name === activePluginName ? " is-active" : ""),
            type: "button",
            onclick: () => {
              activePluginName = p.name;
              renderTabs();
              renderBody();
            },
          },
          el("span", { class: "label" }, p.name),
          dot
        );
        tabs.append(tab);
      }
    }

    function renderBody() {
      body.innerHTML = "";
      const state = pluginState[activePluginName];
      if (state.status === "pending") {
        setStatus(body, "搜索中…");
        return;
      }
      if (state.status === "captcha") {
        body.append(
          el("div", { class: "status error" },
            activePluginName + " 需要验证码 — Web 端无法处理。请回到桌面 Kazumi 客户端完成验证后再来")
        );
        appendHelpers();
        return;
      }
      if (state.status === "error") {
        body.append(
          el("div", { class: "status error" },
            activePluginName + " 检索失败 — " + (state.error || "未知错误"))
        );
        appendHelpers();
        return;
      }
      if (state.status === "noResult" || !state.items || !state.items.length) {
        body.append(
          el("div", { class: "status" },
            activePluginName + " 无结果 — 用别名或手动检索试试")
        );
        appendHelpers();
        return;
      }
      const list = el("div", { class: "list" });
      for (const item of state.items) {
        list.append(
          el(
            "div",
            {
              class: "item",
              onclick: () => {
                localStorage.setItem("lastPlugin", activePluginName);
                _close();
                go("/episodes", {
                  plugin: activePluginName,
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
      body.append(list);
      appendHelpers();
    }

    function appendHelpers() {
      const helpers = el("div", { class: "source-helpers" });
      helpers.append(el("span", { class: "helper-text" }, "结果不准确？"));
      const aliasBtn = el("button", { class: "helper-btn", type: "button" }, "别名检索");
      aliasBtn.addEventListener("click", () => {
        openAliasPicker(bangumi, (alias) => {
          keywordInput.value = alias;
          runOne(activePluginName, alias);
        });
      });
      const manualBtn = el("button", { class: "helper-btn", type: "button" }, "手动检索");
      manualBtn.addEventListener("click", () => {
        openManualSearch((term) => {
          keywordInput.value = term;
          runOne(activePluginName, term);
        });
      });
      helpers.append(aliasBtn, manualBtn);
      body.append(helpers);
    }

    async function runOne(pluginName, kw) {
      pluginState[pluginName] = { status: "pending", items: null };
      renderTabs();
      if (pluginName === activePluginName) renderBody();
      try {
        const items = await pluginSearchSingle(pluginName, kw);
        pluginState[pluginName] = {
          status: items.length ? "success" : "noResult",
          items,
        };
      } catch (e) {
        pluginState[pluginName] = {
          status: e.code === "captcha" ? "captcha" : "error",
          items: null,
          error: e.message,
        };
      }
      renderTabs();
      if (pluginName === activePluginName) renderBody();
    }

    function runAll(kw) {
      // 并发查询所有 plugin（对齐 QueryManager.queryAllSource）
      for (const p of plugins) runOne(p.name, kw);
    }

    form.addEventListener("submit", (ev) => {
      ev.preventDefault();
      runAll(keywordInput.value.trim());
    });

    renderTabs();
    renderBody();
    runAll(keywordInput.value.trim());
  });
}

// 别名检索：在嵌套 modal 中列出 bangumi.alias，点击其中一个 → 用该别名重查当前 plugin
function openAliasPicker(bangumi, onPick) {
  const aliases = Array.isArray(bangumi.alias) ? bangumi.alias : [];
  if (!aliases.length) {
    openModal((sheet, close) => {
      sheet.append(el("div", { class: "modal-title" }, "无可用别名"));
      sheet.append(el("div", { class: "status" }, "试试手动检索"));
      const ok = el("button", { class: "tonal" }, "知道了");
      ok.style.marginTop = "8px";
      ok.addEventListener("click", close);
      sheet.append(ok);
    });
    return;
  }
  openModal((sheet, close) => {
    sheet.append(el("div", { class: "modal-title" }, "别名检索"));
    const list = el("div", { class: "list" });
    for (const a of aliases) {
      list.append(
        el(
          "div",
          {
            class: "item",
            onclick: () => { close(); onPick(a); },
          },
          a
        )
      );
    }
    sheet.append(list);
  });
}

// 手动检索：用户输入任意关键词
function openManualSearch(onPick) {
  openModal((sheet, close) => {
    sheet.append(el("div", { class: "modal-title" }, "手动检索"));
    const input = el("input", {
      type: "search",
      placeholder: "输入关键词",
      autocomplete: "off",
      autocorrect: "off",
      spellcheck: "false",
    });
    const submit = el("button", {
      class: "submit", type: "submit", "aria-label": "搜索",
      html: ICONS.arrow_forward,
    });
    const form = el("form", { class: "search-bar" }, input, submit);
    sheet.append(form);
    form.addEventListener("submit", (ev) => {
      ev.preventDefault();
      const v = input.value.trim();
      if (!v) return;
      close();
      onPick(v);
    });
    setTimeout(() => { try { input.focus(); } catch (_) {} }, 30);
  });
}

// 选集页：对齐桌面端 VideoPage 的 2 Tab 结构（选集 / 评论）
//   - 选集 Tab：多 road 时显示「播放列表 N」切换器（对齐 MenuAnchor）
//   - 评论 Tab：默认第 1 集；点「手动切换」改集数；可倒/正序
async function renderEpisodes(params) {
  const { plugin, src, title, bid } = params;
  $app.innerHTML = "";
  renderNavRail("");
  $app.append(pageHeader(title || "选择集数", { back: true }));
  $app.append(el("div", { class: "ep-plugin-line" }, "规则 · " + plugin));

  const tabBar = el("div", { class: "tabs" });
  const tabBody = el("div", {});
  const tabsConfig = [
    { key: "episodes", label: "选集" },
    { key: "comments", label: "评论" },
  ];
  const tabNodes = {};
  let activeTab = "episodes";
  let activeEpisode = 1;
  let activeRoadIdx = 0;
  let roads = null;
  let roadsLoading = true;
  let roadsError = null;

  for (const t of tabsConfig) {
    const node = el(
      "div",
      { class: "tab" + (t.key === activeTab ? " is-active" : "") },
      t.label
    );
    node.addEventListener("click", () => switchTab(t.key));
    tabNodes[t.key] = node;
    tabBar.append(node);
  }
  $app.append(tabBar, tabBody);

  function switchTab(key) {
    activeTab = key;
    for (const k of Object.keys(tabNodes)) {
      tabNodes[k].classList.toggle("is-active", k === key);
    }
    renderTabBody();
  }

  function renderTabBody() {
    tabBody.innerHTML = "";
    if (activeTab === "episodes") renderEpisodesTab();
    else renderCommentsTab();
  }

  function renderEpisodesTab() {
    if (roadsLoading) {
      setStatus(tabBody, "加载中…");
      return;
    }
    if (roadsError) {
      setStatus(tabBody, "加载失败：" + roadsError, true);
      return;
    }
    if (!roads || !roads.length) {
      setStatus(tabBody, "没有可用的播放列表");
      return;
    }

    // 多 road 时显示「播放列表 N」切换；单 road 直接显示名字
    if (roads.length > 1) {
      const select = el("select", { class: "road-select" });
      roads.forEach((r, i) => {
        const opt = el(
          "option",
          { value: String(i) },
          (r.name || "播放列表 " + (i + 1)) +
            "（" + (r.episodes ? r.episodes.length : 0) + " 集）"
        );
        if (i === activeRoadIdx) opt.setAttribute("selected", "");
        select.append(opt);
      });
      select.addEventListener("change", (ev) => {
        activeRoadIdx = parseInt(ev.target.value, 10);
        renderEpisodesTab();
      });
      const row = el(
        "div",
        { class: "road-row" },
        el("span", { class: "road-label" }, "播放列表"),
        select
      );
      tabBody.append(row);
    } else if (roads[0].name) {
      tabBody.append(el("h2", {}, roads[0].name));
    }

    const road = roads[activeRoadIdx];
    const grid = el("div", { class: "ep-grid" });
    road.episodes.forEach((ep, epIdx) => {
      const cell = el(
        "div",
        {
          class: "ep",
          onclick: () => {
            const pp = {
              plugin,
              episodeUrl: ep.src,
              title: (title ? title + " · " : "") + ep.name,
              episode: String(epIdx + 1),
              road: String(activeRoadIdx),
              // 把 source src（不是 episode src）带到 /play，让播放页能拉一次
              // /api/episodes 拿到 roads，渲染上一集/下一集
              src,
            };
            if (bid) pp.bid = bid;
            go("/play", pp);
          },
        },
        ep.name
      );
      grid.append(cell);
    });
    tabBody.append(grid);
  }

  function renderCommentsTab() {
    if (!bid) {
      setStatus(tabBody, "缺少番剧 ID，无法加载评论");
      return;
    }

    let ascending = false;
    let cachedList = [];

    const epInfo = el("div", { class: "ep-comments-current" });
    const epInfoTop = el("div", { class: "ep-comments-current-top" },
      "第 " + activeEpisode + " 集");
    const epInfoSub = el("div", { class: "ep-comments-current-sub" });
    epInfo.append(epInfoTop, epInfoSub);

    const switchBtn = el("button", { class: "text-btn", type: "button" }, "手动切换");
    switchBtn.addEventListener("click", () => openEpisodePicker());
    const sortBtn = el("button", { class: "text-btn", type: "button" }, "倒序");
    sortBtn.addEventListener("click", () => {
      ascending = !ascending;
      sortBtn.textContent = ascending ? "正序" : "倒序";
      renderList();
    });

    const header = el(
      "div",
      { class: "ep-comments-header" },
      epInfo,
      switchBtn,
      sortBtn
    );
    tabBody.append(header);

    const list = el("div", { class: "ep-comments-list" });
    tabBody.append(list);

    function renderList() {
      list.innerHTML = "";
      if (!cachedList.length) {
        setStatus(list, "什么都没有找到 (´;ω;`)");
        return;
      }
      const sorted = cachedList.slice();
      sorted.sort((a, b) =>
        ascending ? (a.createdAt || 0) - (b.createdAt || 0)
                  : (b.createdAt || 0) - (a.createdAt || 0)
      );
      for (const c of sorted) list.append(buildEpisodeCommentCard(c));
    }

    setStatus(list, "加载中…");
    fetchJson(
      "/api/bangumi/" + bid + "/episode-comments?episode=" + activeEpisode
    ).then((data) => {
      cachedList = data.items || [];
      if (data.episode) {
        epInfoSub.textContent =
          data.episode.readType + "." + data.episode.episode + " " +
          (data.episode.nameCn || data.episode.name || "");
      }
      renderList();
    }).catch((e) => {
      list.innerHTML = "";
      setStatus(list, "评论获取失败：" + e.message, true);
    });

    function openEpisodePicker() {
      openModal((sheet, close) => {
        sheet.append(el("div", { class: "modal-title" }, "选择集数"));
        const innerList = el("div", { class: "list" });
        sheet.append(innerList);
        setStatus(innerList, "加载中…");
        fetchJson("/api/bangumi/" + bid + "/episodes").then((data) => {
          innerList.innerHTML = "";
          const items = data.items || [];
          if (!items.length) {
            setStatus(innerList, "未找到分集列表");
            return;
          }
          items.forEach((it, idx) => {
            const label =
              it.readType + "." + it.episode + " " +
              (it.nameCn || it.name || "");
            const isCurrent = idx + 1 === activeEpisode;
            const item = el(
              "div",
              { class: "item" + (isCurrent ? " is-current" : "") },
              label
            );
            item.addEventListener("click", () => {
              activeEpisode = idx + 1;
              close();
              renderTabBody();
            });
            innerList.append(item);
          });
        }).catch((e) => {
          innerList.innerHTML = "";
          setStatus(innerList, "加载失败：" + e.message, true);
        });
      });
    }
  }

  renderTabBody();

  // 拉取选集（roads）
  try {
    const data = await fetchJson(
      "/api/episodes?plugin=" + encodeURIComponent(plugin) +
      "&src=" + encodeURIComponent(src)
    );
    roads = data.roads || [];
    roadsLoading = false;
  } catch (e) {
    roadsError = e.message;
    roadsLoading = false;
  }
  if (activeTab === "episodes") renderTabBody();
}

function buildEpisodeCommentCard(c) {
  const head = el("div", { class: "comment-head" });
  const avatar = el("img", { alt: "", referrerpolicy: "no-referrer" });
  if (c.user && c.user.avatar) avatar.src = c.user.avatar;
  head.append(avatar);
  head.append(
    el(
      "span",
      { class: "username" },
      (c.user && (c.user.nickname || c.user.username)) || "用户"
    )
  );
  if (c.createdAt) {
    const dt = new Date(c.createdAt * 1000);
    head.append(el("span", { class: "comment-time" }, dt.toLocaleString()));
  }
  return el(
    "div",
    { class: "comment-card" },
    head,
    el("div", { class: "comment-body" }, c.content || "")
  );
}

// ====== Dispatch ======
function dispatch() {
  const { path, params } = parseRoute();
  if (path === "/home" || path === "/") return renderHome(params);
  if (path === "/search") return renderSearch(params);
  if (path === "/bangumi") return renderBangumiDetail(params);
  if (path === "/episodes") return renderEpisodes(params);
  if (path === "/play") return renderPlayer(params);
  go("/home");
}

window.addEventListener("hashchange", dispatch);

// 启动顺序：先拉主题（视觉不闪），再 dispatch
loadTheme().finally(dispatch);
''';
