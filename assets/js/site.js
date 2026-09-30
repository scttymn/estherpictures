// The home page: the mobile nav, the cast accordion, and the clip player.
// A module, so it runs once the page is parsed.

// Mobile nav: chevron toggles the menu; tapping an item collapses it.
(function () {
  var nav = document.getElementById("site-nav");
  var toggle = document.getElementById("site-nav-toggle");
  if (!nav || !toggle) return;

  function setOpen(open) {
    nav.classList.toggle("is-open", open);
    toggle.setAttribute("aria-expanded", String(open));
  }

  toggle.addEventListener("click", function () {
    setOpen(!nav.classList.contains("is-open"));
  });

  nav.querySelectorAll(".ep-nav__links a").forEach(function (link) {
    link.addEventListener("click", function () {
      setOpen(false);
    });
  });
})();

// Cast: only one bio accordion open at a time.
(function () {
  var members = document.querySelectorAll(".ep-ensemble details.ep-member");
  if (!members.length) return;

  members.forEach(function (panel) {
    panel.addEventListener("toggle", function () {
      if (!panel.open) return;
      members.forEach(function (other) {
        if (other !== panel) other.open = false;
      });
    });
  });
})();

(function () {
  var player = document.getElementById("reel-player");
  var slate = document.getElementById("reel-slate");
  var soundBtn = document.getElementById("reel-sound");
  var clips = Array.prototype.slice.call(document.querySelectorAll(".ep-clip"));
  if (!player || !clips.length) return;

  var activeEl = null;
  var muted = true;

  // --- YouTube IFrame Player API --------------------------------------
  // iOS forbids autoplaying unmuted media, and swapping in a fresh iframe on
  // unmute loses the tap gesture (the embed loads async, after the gesture
  // expires) — so the video just shows YouTube's poster. Instead we keep one
  // persistent player and call unMute()/playVideo() synchronously inside the
  // tap, which iOS accepts. The first clip's server-rendered iframe carries
  // enablejsapi=1 so the API can adopt it without a reload.
  var ytPlayer = null;
  var ytReady = false;
  var ytApiLoading = false;
  var ytQueue = [];

  var YT_VARS = {
    autoplay: 1, mute: 1, loop: 1, controls: 0, modestbranding: 1,
    rel: 0, playsinline: 1, iv_load_policy: 3, disablekb: 1, fs: 0
  };

  window.onYouTubeIframeAPIReady = function () {
    ytReady = true;
    var q = ytQueue;
    ytQueue = [];
    q.forEach(function (cb) { cb(); });
  };

  function whenYT(cb) {
    if (ytReady) return cb();
    ytQueue.push(cb);
    if (!ytApiLoading) {
      ytApiLoading = true;
      var tag = document.createElement("script");
      tag.src = "https://www.youtube.com/iframe_api";
      document.head.appendChild(tag);
    }
  }

  // Apply the current mute state to a player, in-gesture on the sound tap.
  function ytApply(p) {
    if (muted) { p.mute(); } else { p.unMute(); }
    p.playVideo();
  }

  var ytEvents = {
    onReady: function (e) { ytApply(e.target); },
    onStateChange: function (e) {
      // Belt-and-suspenders looping (loop+playlist is unreliable via the API).
      if (e.data === window.YT.PlayerState.ENDED) {
        e.target.seekTo(0, true);
        e.target.playVideo();
      }
    }
  };

  function showYouTube(id) {
    whenYT(function () {
      if (ytPlayer) {
        ytPlayer.loadVideoById({ videoId: id });
        if (muted) { ytPlayer.mute(); } else { ytPlayer.unMute(); }
        return;
      }
      // No player yet (initial clip was not YouTube): build one, keeping the
      // youtube-nocookie host to match the server-rendered privacy choice.
      player.innerHTML = "";
      var host = document.createElement("div");
      host.id = "reel-yt";
      player.appendChild(host);
      ytPlayer = new window.YT.Player(host, {
        host: "https://www.youtube-nocookie.com",
        videoId: id,
        playerVars: Object.assign({ playlist: id }, YT_VARS),
        events: ytEvents
      });
    });
  }

  function destroyYouTube() {
    if (ytPlayer) {
      try { ytPlayer.destroy(); } catch (e) {}
      ytPlayer = null;
    }
  }

  // --- Vimeo / uploaded-file players (unchanged iframe/element swap) ----
  function buildMedia(kind, src) {
    if (!src) return null;
    if (kind === "file") {
      var v = document.createElement("video");
      v.className = "ep-reel__media";
      v.src = src;
      v.autoplay = true;
      v.loop = true;
      v.playsInline = true;
      v.muted = muted;
      return v;
    }
    if (kind === "vimeo") {
      var f = document.createElement("iframe");
      f.src = src;
      f.title = "Clip";
      f.setAttribute("allow", "autoplay; encrypted-media; picture-in-picture");
      return f;
    }
    return null;
  }

  function render(clip) {
    var kind = clip.dataset.kind;
    if (kind === "youtube") {
      showYouTube(clip.dataset.ytId);
      return;
    }
    destroyYouTube();
    var src = muted ? clip.dataset.srcMuted : clip.dataset.srcUnmuted;
    player.innerHTML = "";
    var el = buildMedia(kind, src);
    if (el) player.appendChild(el);
  }

  function updateSlate(clip) {
    function set(slot, val, dot) {
      var el = slate && slate.querySelector('[data-slot="' + slot + '"]');
      if (!el) return;
      el.textContent = val ? (dot ? "● " + val : val) : "";
    }
    set("title", clip.dataset.title, false);
    set("runtime", clip.dataset.runtime, false);
    set("format", clip.dataset.format, false);
    set("years", clip.dataset.years, false);
    set("status", clip.dataset.status, true);
  }

  function syncSound() {
    if (!soundBtn) return;
    var hasVideo = activeEl && activeEl.dataset.kind !== "none";
    soundBtn.hidden = !hasVideo;
    soundBtn.setAttribute("aria-pressed", String(!muted));
    var label = soundBtn.querySelector(".ep-reel__sound-label");
    if (label) label.textContent = muted ? "SOUND OFF" : "SOUND ON";
    soundBtn.classList.toggle("is-on", !muted);
  }

  function activate(clip, opts) {
    opts = opts || {};
    if (opts.resetMute) muted = true;
    if (activeEl) {
      activeEl.classList.remove("is-active");
      activeEl.setAttribute("aria-pressed", "false");
    }
    activeEl = clip;
    clip.classList.add("is-active");
    clip.setAttribute("aria-pressed", "true");
    updateSlate(clip);
    if (opts.render) render(clip);
    syncSound();
  }

  clips.forEach(function (clip) {
    clip.addEventListener("click", function () {
      activate(clip, { render: true, resetMute: true });
    });
  });

  if (soundBtn) {
    soundBtn.addEventListener("click", function () {
      muted = !muted;
      if (activeEl) {
        // For YouTube, drive the live player in-gesture (iOS needs the
        // unmute/play call to happen synchronously inside the tap). Other
        // kinds rebuild their element as before.
        if (activeEl.dataset.kind === "youtube" && ytPlayer) {
          ytApply(ytPlayer);
        } else {
          render(activeEl);
        }
      }
      syncSound();
    });
  }

  // First clip is active and already server-rendered muted. If it's a
  // YouTube clip, adopt that iframe into the Player API now so the first
  // unmute tap can drive it synchronously.
  activate(clips[0], { render: false, resetMute: true });
  if (clips[0].dataset.kind === "youtube") {
    whenYT(function () {
      if (!ytPlayer) {
        ytPlayer = new window.YT.Player("reel-yt", { events: ytEvents });
      }
    });
  }
})();
