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

// SSE 通道：桌面端 themeMode / themeColor / oledEnhance / useDynamicColor
// 任何变更都会通过 /api/theme/stream 推送过来。
let themeEventSource = null;
function connectThemeStream() {
  if (themeEventSource) {
    try { themeEventSource.close(); } catch (_) {}
    themeEventSource = null;
  }
  try {
    const es = new EventSource("/api/theme/stream");
    themeEventSource = es;
    es.onmessage = (ev) => {
      try { applyTheme(JSON.parse(ev.data)); } catch (_) {}
    };
    es.onerror = () => {
      // iOS Safari 后台标签 / 网络抖动 / 服务端重启都会进这里，5s 重连。
      try { es.close(); } catch (_) {}
      if (themeEventSource === es) themeEventSource = null;
      setTimeout(connectThemeStream, 5000);
    };
  } catch (_) {
    setTimeout(connectThemeStream, 5000);
  }
}

async function loadTheme() {
  try {
    const t = await fetchJson("/api/theme");
    applyTheme(t);
  } catch (_) {
    // 静默：默认 :root 配色仍可用
  }
  connectThemeStream();
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

// ====== Page header (replaces the old sticky app bar) ======
function pageHeader(title, opts) {
  opts = opts || {};
  const header = el("div", { class: "page-header" });
  if (opts.back) {
    const back = el("button", { class: "icon-btn", "aria-label": "返回" }, "←");
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
const NAV_TABS = [
  { key: "popular",  icon: "⌂", label: "推荐" },
  { key: "timeline", icon: "◫", label: "时间表" },
  { key: "collect",  icon: "♥", label: "追番" },
  { key: "my",       icon: "☰", label: "我的" },
];
function renderNavRail(activeTab) {
  $navRail.innerHTML = "";

  const search = el("button", {
    class: "nav-search",
    "aria-label": "搜索",
    onclick: () => go("/search"),
  });
  // 放大镜
  search.innerHTML = "\u{1F50D}";
  $navRail.append(search);

  const main = el("div", { class: "nav-main" });
  for (const t of NAV_TABS) {
    main.append(
      el(
        "button",
        {
          class: "nav-item" + (t.key === activeTab ? " is-active" : ""),
          onclick: () => go("/home", { tab: t.key }),
        },
        el("span", { class: "icon" }, t.icon),
        el("span", { class: "label" }, t.label)
      )
    );
  }
  $navRail.append(main);

  const bottom = el("div", { class: "nav-bottom" });
  bottom.append(
    el(
      "button",
      {
        class: "nav-item",
        "aria-label": "设置",
        onclick: () => go("/home", { tab: "my" }),
      },
      el("span", { class: "icon" }, "⚙"),
      el("span", { class: "label" }, "设置")
    )
  );
  $navRail.append(bottom);
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

async function renderTabPopular(container) {
  container.append(pageHeader("热门番组", { chev: true }));
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
}

async function renderTabTimeline(container) {
  container.append(pageHeader("时间表"));
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
  container.append(pageHeader("追番"));
  const body = el("div", {});
  container.append(body);
  setStatus(body, "加载中…");
  try {
    const data = await fetchJson("/api/collect/list");
    body.innerHTML = "";
    const items = data.items || [];
    if (!items.length) {
      setStatus(body, "还没有收藏哦，去推荐页找一部番剧收藏看看吧");
      return;
    }
    const labels = { 1: "在看", 2: "想看", 3: "搁置", 4: "看过", 5: "抛弃" };
    const groups = { 1: [], 2: [], 3: [], 4: [], 5: [] };
    for (const it of items) {
      if (groups[it.type]) groups[it.type].push(it);
    }
    for (const type of [1, 2, 3, 4, 5]) {
      if (!groups[type].length) continue;
      body.append(el("h2", {}, labels[type] + " · " + groups[type].length));
      const grid = el("div", { class: "poster-grid" });
      for (const c of groups[type]) grid.append(buildPosterCard(c.bangumi));
      body.append(grid);
    }
  } catch (e) {
    setStatus(body, "加载失败：" + e.message, true);
  }
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

async function renderSearch(params) {
  $app.innerHTML = "";
  renderNavRail("");
  $app.append(pageHeader("搜索", { back: true }));

  const input = el("input", {
    type: "search",
    placeholder: "搜索番剧（Bangumi）",
    autocomplete: "off",
    autocorrect: "off",
    spellcheck: "false",
  });
  input.value = (params && params.q) || localStorage.getItem("lastBangumiKeyword") || "";
  const submit = el("button", { class: "submit", "aria-label": "搜索", type: "submit", html: "&#x2192;" });
  const form = el("form", { class: "search-bar" }, input, submit);
  form.addEventListener("submit", (ev) => {
    ev.preventDefault();
    const keyword = input.value.trim();
    if (!keyword) return;
    localStorage.setItem("lastBangumiKeyword", keyword);
    runBangumiSearch(keyword);
  });
  $app.append(form);

  const results = el("div", { class: "list", id: "bangumi-results" });
  $app.append(results);

  // 自动聚焦输入
  setTimeout(() => { try { input.focus(); } catch (_) {} }, 50);
  if (input.value) runBangumiSearch(input.value);
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
  $app.innerHTML = "";
  renderNavRail("");
  // 内联返回按钮（覆盖在 hero 区左上）
  const backRow = el("div", { class: "page-header", style: "padding: 4px 0 0;" },
    (() => {
      const back = el("button", { class: "icon-btn", "aria-label": "返回" }, "←");
      back.addEventListener("click", () => history.back());
      return back;
    })()
  );
  $app.append(backRow);

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
  $app.innerHTML = "";
  renderNavRail("");
  $app.append(pageHeader(title || "选择集数", { back: true }));
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
