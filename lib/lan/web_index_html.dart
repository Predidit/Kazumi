/// 嵌入式 HTML 页面，由 LAN HTTP 服务在 `/` 路径返回。
///
/// 设计目标是 iOS Safari 上原生 HLS 播放。所有 CSS/JS 内联，单文件，
/// 不依赖任何外部 CDN，避免局域网环境无外网时打不开。
const String lanWebIndexHtml = r'''
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="format-detection" content="telephone=no">
  <title>Kazumi</title>
  <style>
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    html, body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif; background: #0f1115; color: #e4e7eb; min-height: 100vh; }
    .container { max-width: 720px; margin: 0 auto; padding: 14px 16px; padding-top: calc(env(safe-area-inset-top) + 14px); padding-bottom: calc(env(safe-area-inset-bottom) + 24px); }
    h1 { font-size: 17px; margin: 0 0 12px; font-weight: 600; letter-spacing: 0.3px; opacity: 0.92; }
    .row { display: flex; gap: 8px; align-items: stretch; }
    select, input[type="search"], button { font: inherit; color: inherit; background: #1c1f26; border: 1px solid #2c303a; border-radius: 10px; padding: 11px 12px; -webkit-appearance: none; appearance: none; }
    input[type="search"] { flex: 1; min-width: 0; }
    select { background-image: linear-gradient(45deg, transparent 50%, #888 50%), linear-gradient(135deg, #888 50%, transparent 50%); background-position: calc(100% - 18px) 50%, calc(100% - 13px) 50%; background-size: 5px 5px, 5px 5px; background-repeat: no-repeat; padding-right: 32px; max-width: 40%; }
    button { cursor: pointer; background: #2a6df4; border-color: #2a6df4; color: #fff; font-weight: 500; }
    button:active { opacity: 0.85; }
    button:disabled { opacity: 0.55; }
    .list { margin-top: 16px; display: flex; flex-direction: column; gap: 8px; }
    .item { background: #1c1f26; border: 1px solid #2c303a; border-radius: 12px; padding: 14px 16px; cursor: pointer; transition: background 0.15s; line-height: 1.45; }
    .item:active { background: #232732; }
    .breadcrumb { font-size: 13px; opacity: 0.65; margin: 0 0 10px; }
    .ep-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(90px, 1fr)); gap: 8px; }
    .ep { text-align: center; padding: 12px 4px; background: #1c1f26; border: 1px solid #2c303a; border-radius: 10px; cursor: pointer; font-size: 14px; line-height: 1.3; word-break: break-all; }
    .ep:active { background: #232732; }
    .road-title { margin: 18px 0 10px; font-size: 13px; opacity: 0.7; font-weight: 500; }
    .status { padding: 16px 0; font-size: 13px; opacity: 0.7; text-align: center; }
    .error { color: #ff7a7a; }
    .back { background: transparent; border: none; padding: 6px 0 12px; color: #4aa6ff; cursor: pointer; font-size: 14px; -webkit-appearance: none; appearance: none; }
    video { width: 100%; max-height: 78vh; background: #000; border-radius: 8px; display: block; }
    .player-meta { font-size: 13px; opacity: 0.65; margin: 10px 0 6px; word-break: break-all; }
    .player-actions { display: flex; gap: 8px; margin-top: 8px; }
    .player-actions button { flex: 1; background: #1c1f26; border-color: #2c303a; color: #e4e7eb; font-weight: 400; }
    .footer { margin-top: 24px; font-size: 12px; opacity: 0.45; text-align: center; }
  </style>
</head>
<body>
  <div class="container" id="app"></div>
  <script>
    "use strict";

    const $app = document.getElementById("app");

    // 极简 hash router：#/home, #/episodes?..., #/play?...
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

    function el(tag, attrs, ...children) {
      const node = document.createElement(tag);
      for (const [k, v] of Object.entries(attrs || {})) {
        if (k === "onclick") node.addEventListener("click", v);
        else if (k === "class") node.className = v;
        else if (k === "html") node.innerHTML = v;
        else node.setAttribute(k, v);
      }
      for (const c of children) {
        if (c == null) continue;
        node.append(typeof c === "string" ? document.createTextNode(c) : c);
      }
      return node;
    }

    function setStatus(msg, isError) {
      $app.innerHTML = "";
      $app.append(el("div", { class: "status" + (isError ? " error" : "") }, msg));
    }

    async function fetchJson(url) {
      const res = await fetch(url);
      if (!res.ok) {
        let detail = res.statusText;
        try {
          const body = await res.json();
          if (body.message) detail = body.message;
        } catch (_) {}
        throw new Error("HTTP " + res.status + ": " + detail);
      }
      return res.json();
    }

    // ====== 视图 ======
    async function renderHome() {
      $app.innerHTML = "";
      $app.append(el("h1", {}, "搜索番剧"));

      let plugins;
      try {
        plugins = await fetchJson("/api/plugins");
      } catch (e) {
        setStatus("加载规则失败：" + e.message, true);
        return;
      }
      if (!plugins.length) {
        setStatus("当前没有可用规则，请先在桌面端的「规则管理」里安装", true);
        return;
      }

      const lastPlugin = localStorage.getItem("lastPlugin");
      const select = el("select", {});
      for (const p of plugins) {
        const opt = el("option", { value: p.name }, p.name + " · v" + p.version);
        select.append(opt);
      }
      if (lastPlugin && plugins.some(p => p.name === lastPlugin)) {
        select.value = lastPlugin;
      }

      const input = el("input", { type: "search", placeholder: "番剧名称", autocomplete: "off", autocorrect: "off", spellcheck: "false" });
      input.value = localStorage.getItem("lastKeyword") || "";

      const btn = el("button", {}, "搜索");

      const form = el("form", {}, el("div", { class: "row" }, select, input, btn));
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

      $app.append(el("div", { class: "footer" }, "Kazumi LAN · 实验性"));

      // 如果有上次的搜索词，自动搜
      if (input.value) runSearch(select.value, input.value);
    }

    async function runSearch(pluginName, keyword) {
      const results = document.getElementById("search-results");
      if (!results) return;
      results.innerHTML = "";
      results.append(el("div", { class: "status" }, "搜索中…"));
      try {
        const data = await fetchJson("/api/search?plugin=" + encodeURIComponent(pluginName) + "&keyword=" + encodeURIComponent(keyword));
        results.innerHTML = "";
        if (!data.items || !data.items.length) {
          results.append(el("div", { class: "status" }, "没有结果"));
          return;
        }
        for (const item of data.items) {
          const node = el("div", { class: "item" }, item.name);
          node.addEventListener("click", () => {
            go("/episodes", { plugin: pluginName, src: item.src, title: item.name });
          });
          results.append(node);
        }
      } catch (e) {
        results.innerHTML = "";
        results.append(el("div", { class: "status error" }, "搜索失败：" + e.message));
      }
    }

    async function renderEpisodes(params) {
      const { plugin, src, title } = params;
      $app.innerHTML = "";
      $app.append(el("button", { class: "back", onclick: () => history.back() }, "← 返回搜索"));
      $app.append(el("h1", {}, title || "选择集数"));
      $app.append(el("div", { class: "breadcrumb" }, "规则：" + plugin));

      const container = el("div", {});
      $app.append(container);
      container.append(el("div", { class: "status" }, "加载中…"));

      try {
        const data = await fetchJson("/api/episodes?plugin=" + encodeURIComponent(plugin) + "&src=" + encodeURIComponent(src));
        container.innerHTML = "";
        if (!data.roads || !data.roads.length) {
          container.append(el("div", { class: "status" }, "没有可用的播放列表"));
          return;
        }
        for (const road of data.roads) {
          container.append(el("div", { class: "road-title" }, road.name));
          const grid = el("div", { class: "ep-grid" });
          for (const ep of road.episodes) {
            const cell = el("div", { class: "ep" }, ep.name);
            cell.addEventListener("click", () => {
              go("/play", {
                plugin,
                episodeUrl: ep.src,
                title: (title ? title + " · " : "") + ep.name,
              });
            });
            grid.append(cell);
          }
          container.append(grid);
        }
      } catch (e) {
        container.innerHTML = "";
        container.append(el("div", { class: "status error" }, "加载失败：" + e.message));
      }
    }

    async function renderPlayer(params) {
      const { plugin, episodeUrl, title } = params;
      $app.innerHTML = "";
      $app.append(el("button", { class: "back", onclick: () => history.back() }, "← 返回选集"));
      $app.append(el("h1", {}, title || "播放"));

      const status = el("div", { class: "status" }, "正在解析视频源，可能需要几秒…");
      $app.append(status);

      try {
        const data = await fetchJson("/api/resolve?plugin=" + encodeURIComponent(plugin) + "&episodeUrl=" + encodeURIComponent(episodeUrl));
        status.remove();

        const video = el("video", {
          controls: "",
          playsinline: "",
          "webkit-playsinline": "",
          preload: "metadata",
          src: data.playUrl,
        });
        // iOS Safari 自动播放策略要 muted 才行；这里不强制 autoplay，让用户主动点
        $app.append(video);
        $app.append(el("div", { class: "player-meta" }, "规则：" + data.pluginName));
        $app.append(el("div", { class: "player-meta" }, "源：" + data.originalUrl));

        const reloadBtn = el("button", {}, "重新解析");
        reloadBtn.addEventListener("click", () => renderPlayer(params));
        $app.append(el("div", { class: "player-actions" }, reloadBtn));

        video.addEventListener("error", () => {
          const errNode = el("div", { class: "status error" }, "播放器报告错误，可能是源失效或浏览器不支持该格式");
          $app.append(errNode);
        });
      } catch (e) {
        status.remove();
        $app.append(el("div", { class: "status error" }, "解析失败：" + e.message));
      }
    }

    // ====== 路由分发 ======
    function dispatch() {
      const { path, params } = parseRoute();
      if (path === "/home" || path === "/") return renderHome();
      if (path === "/episodes") return renderEpisodes(params);
      if (path === "/play") return renderPlayer(params);
      go("/home");
    }

    window.addEventListener("hashchange", dispatch);
    dispatch();
  </script>
</body>
</html>
''';
