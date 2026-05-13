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
    async function renderHome() {
      setBar("Kazumi", false);
      $app.innerHTML = "";

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
      $app.append(form);

      const results = el("div", { class: "list", id: "bangumi-results" });
      $app.append(results);

      $app.append(el("div", { class: "footer" }, "Kazumi · Web 预览 · 实验性"));

      if (input.value) runBangumiSearch(input.value);
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
      const { plugin, src, title } = params;
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
        for (const road of data.roads) {
          container.append(el("h2", {}, road.name));
          const grid = el("div", { class: "ep-grid" });
          for (const ep of road.episodes) {
            const cell = el(
              "div",
              {
                class: "ep",
                onclick: () =>
                  go("/play", {
                    plugin,
                    episodeUrl: ep.src,
                    title: (title ? title + " · " : "") + ep.name,
                  }),
              },
              ep.name
            );
            grid.append(cell);
          }
          container.append(grid);
        }
      } catch (e) {
        setStatus(container, "加载失败：" + e.message, true);
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
      const { plugin, episodeUrl, title } = params;
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
        $app.append(video);

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
      } catch (e) {
        status.remove();
        $app.append(el("div", { class: "status error" }, "解析失败：" + e.message));
      }
    }

    // 离开播放页时销毁 hls.js
    window.addEventListener("hashchange", () => {
      const { path } = parseRoute();
      if (path !== "/play") disposeHls();
    });

    // ====== Dispatch ======
    function dispatch() {
      const { path, params } = parseRoute();
      if (path === "/home" || path === "/") return renderHome();
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
