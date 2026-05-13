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

    // ====== Views ======
    async function renderHome() {
      setBar("Kazumi", false);
      $app.innerHTML = "";

      let plugins;
      try {
        plugins = await fetchJson("/api/plugins");
      } catch (e) {
        setStatus($app, "加载规则失败：" + e.message, true);
        return;
      }
      if (!plugins.length) {
        setStatus($app, "当前没有可用规则，请先在桌面端的「规则管理」里安装", true);
        return;
      }

      const lastPlugin = localStorage.getItem("lastPlugin");
      const select = el("select", { "aria-label": "规则" });
      for (const p of plugins) {
        select.append(el("option", { value: p.name }, p.name));
      }
      if (lastPlugin && plugins.some((p) => p.name === lastPlugin)) {
        select.value = lastPlugin;
      }

      const input = el("input", {
        type: "search",
        placeholder: "搜索番剧",
        autocomplete: "off",
        autocorrect: "off",
        spellcheck: "false",
      });
      input.value = localStorage.getItem("lastKeyword") || "";

      const submit = el("button", { class: "submit", "aria-label": "搜索", type: "submit", html: "&#x2192;" });

      const form = el("form", { class: "search-bar" }, select, input, submit);
      form.addEventListener("submit", (ev) => {
        ev.preventDefault();
        const keyword = input.value.trim();
        if (!keyword) return;
        localStorage.setItem("lastPlugin", select.value);
        localStorage.setItem("lastKeyword", keyword);
        runSearch(select.value, keyword);
      });
      $app.append(form);

      const results = el("div", { class: "list", id: "search-results" });
      $app.append(results);

      $app.append(el("div", { class: "footer" }, "Kazumi · Web 预览 · 实验性"));

      if (input.value) runSearch(select.value, input.value);
    }

    async function runSearch(pluginName, keyword) {
      const results = document.getElementById("search-results");
      if (!results) return;
      setStatus(results, "搜索中…");
      try {
        const data = await fetchJson(
          "/api/search?plugin=" + encodeURIComponent(pluginName) + "&keyword=" + encodeURIComponent(keyword)
        );
        results.innerHTML = "";
        if (!data.items || !data.items.length) {
          setStatus(results, "没有结果");
          return;
        }
        for (const item of data.items) {
          results.append(
            el(
              "div",
              {
                class: "item",
                onclick: () =>
                  go("/episodes", {
                    plugin: pluginName,
                    src: item.src,
                    title: item.name,
                  }),
              },
              item.name
            )
          );
        }
      } catch (e) {
        setStatus(results, "搜索失败：" + e.message, true);
      }
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
