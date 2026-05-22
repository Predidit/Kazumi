/// 播放器层 JS：DanmakuLayer 类、HLS 集成、进度上报、renderPlayer。
///
/// 拼接到 HTML 单一 `<script>` 标签的后段，与 `web_app_script.dart` 共享全局
/// 作用域。模块对外暴露的"接口"是 `renderPlayer(params)`——`dispatch()` 在
/// app_script 里调用它。
///
/// 关键 DOM 依赖（重写视觉时务必保留）：
/// - `DanmakuLayer` 构造时 append canvas 到 `.player-wrap` 容器，并对该
///   容器创建 ResizeObserver。canvas 必须是 `.player-wrap` 的子节点
///   （而不是 `<video>` 的兄弟），否则尺寸计算会错乱。
/// - `attachStream(video, ...)` 直接持有 `<video>` 引用；hls.js 通过
///   `hls.attachMedia(video)` 绑定，重建 video 元素需配套 disposeHls()。
/// - `reportProgress` 通过 `video.currentTime` / `pause` 事件 / `pagehide`
///   全部依赖 video 元素生命周期。
/// - hashchange listener 在路由离开 `/play` 时清理三套资源
///   （hls / 弹幕 / 进度 timer），任何替代实现都要等价。
const String lanWebPlayerJs = r'''
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
  const { plugin, episodeUrl, title, bid, episode, road, src } = params;
  const epNum = parseInt(episode || "1", 10);
  const roadNum = parseInt(road || "0", 10);
  $app.innerHTML = "";
  renderNavRail("");

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

    // 浮在 video 左上的返回按钮 —— 对齐详情页 hero overlay 风格
    const backBtn = el("button", { class: "icon-btn player-back", "aria-label": "返回" });
    backBtn.innerHTML = ICONS.arrow_back;
    backBtn.addEventListener("click", () => history.back());
    playerWrap.append(backBtn);

    $app.append(playerWrap);

    const errorNode = el("div", { class: "status error" });
    errorNode.style.display = "none";
    $app.append(errorNode);
    const showError = (msg) => {
      errorNode.textContent = msg;
      errorNode.style.display = "block";
    };

    await attachStream(video, data, showError);

    // ====== 控件行：上一集/下一集 + 倍速 + 视频比例 + 重新解析 ======
    const controls = el("div", { class: "player-controls" });

    const prevBtn = el("button", { class: "ctrl-btn", type: "button" }, "上一集");
    const nextBtn = el("button", { class: "ctrl-btn", type: "button" }, "下一集");
    prevBtn.disabled = true;
    nextBtn.disabled = true;

    // 倍速：HTML5 video.playbackRate（iOS 原生控件可能不暴露，所以自己加）
    const rateOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    const rateSelect = el("select", { class: "ctrl-select", "aria-label": "倍速" });
    for (const r of rateOptions) {
      const opt = el("option", { value: String(r) }, r === 1.0 ? "倍速 1x" : "倍速 " + r + "x");
      if (r === 1.0) opt.setAttribute("selected", "");
      rateSelect.append(opt);
    }
    rateSelect.addEventListener("change", () => {
      const r = parseFloat(rateSelect.value);
      if (!Number.isNaN(r)) video.playbackRate = r;
    });

    // 视频比例：object-fit contain / cover / fill
    const fitOptions = [
      { v: "contain", label: "比例 适应" },
      { v: "cover", label: "比例 填充" },
      { v: "fill", label: "比例 拉伸" },
    ];
    const fitSelect = el("select", { class: "ctrl-select", "aria-label": "视频比例" });
    for (const f of fitOptions) {
      const opt = el("option", { value: f.v }, f.label);
      if (f.v === "contain") opt.setAttribute("selected", "");
      fitSelect.append(opt);
    }
    fitSelect.addEventListener("change", () => {
      video.style.objectFit = fitSelect.value;
    });

    const reload = el("button", { class: "ctrl-btn", type: "button" }, "重新解析");
    reload.addEventListener("click", () => renderPlayer(params));

    controls.append(prevBtn, nextBtn, rateSelect, fitSelect, reload);
    $app.append(controls);

    // 上一集/下一集：需要 plugin + src 拉 episodes，从 roads[road] 取
    if (plugin && src) {
      fetchJson(
        "/api/episodes?plugin=" + encodeURIComponent(plugin) + "&src=" + encodeURIComponent(src)
      ).then((roadsData) => {
        const roads = roadsData.roads || [];
        const currentRoad = roads[roadNum];
        if (!currentRoad || !Array.isArray(currentRoad.episodes)) return;
        const eps = currentRoad.episodes;
        const idx = epNum - 1;
        const goEp = (newIdx) => {
          if (newIdx < 0 || newIdx >= eps.length) return;
          const next = eps[newIdx];
          const newTitle = (title || "").split(" · ").slice(0, -1).join(" · ");
          const pp = {
            plugin,
            episodeUrl: next.src,
            title: (newTitle ? newTitle + " · " : "") + next.name,
            episode: String(newIdx + 1),
            road: String(roadNum),
            src,
          };
          if (bid) pp.bid = bid;
          go("/play", pp);
        };
        if (idx > 0) {
          prevBtn.disabled = false;
          prevBtn.addEventListener("click", () => goEp(idx - 1));
        }
        if (idx < eps.length - 1) {
          nextBtn.disabled = false;
          nextBtn.addEventListener("click", () => goEp(idx + 1));
        }
      }).catch(() => {
        // 拉取失败保持 disabled
      });
    }

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
''';
