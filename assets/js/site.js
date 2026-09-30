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

// The hero's clip player. Nothing plays until a visitor asks: the first
// clip's poster shows, and a tap on Play, on the reel, or on a clip in the
// filmstrip plays that clip with sound; a tap on Pause, or the reel again,
// pauses it. The slate shows the picked clip's stats.
(function () {
  var player = document.getElementById("reel-player");
  var slate = document.getElementById("reel-slate");
  var playBtn = document.getElementById("reel-play");
  var reel = player && player.closest(".ep-hero__reel");
  var clips = Array.prototype.slice.call(document.querySelectorAll(".ep-clip"));
  if (!player || !clips.length) return;

  var activeEl = null;
  var playingNow = false;

  // --- YouTube IFrame Player API --------------------------------------
  // iOS plays sound only when play is called inside the tap itself, on a
  // player that's already there: a player loaded in answer to the tap
  // starts after the tap's gone, and just shows YouTube's poster. So the
  // first clip's player is loaded ahead, paused (its iframe in the page's
  // <template>, with enablejsapi=1, adopted by the API), and one player is
  // kept after that: a tap calls playVideo() or loadVideoById() on it at
  // once.
  var ytPlayer = null;
  var ytPlayerReady = false;
  var ytVideo = null; // the id the player has loaded
  var ytPending = false; // a tap came before the player was ready
  var ytReady = false;
  var ytApiLoading = false;
  var ytQueue = [];

  var YT_VARS = {
    autoplay: 1, mute: 0, loop: 1, controls: 0, modestbranding: 1,
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

  var ytEvents = {
    onReady: function (e) {
      ytPlayerReady = true;
      if (ytPending) {
        ytPending = false;
        e.target.unMute();
        e.target.playVideo();
      }
    },
    onStateChange: function (e) {
      var S = window.YT.PlayerState;
      if (e.data === S.PLAYING) setPlaying(true);
      if (e.data === S.PAUSED) setPlaying(false);
      // Belt-and-suspenders looping (loop+playlist is unreliable via the API).
      if (e.data === S.ENDED) {
        e.target.seekTo(0, true);
        e.target.playVideo();
      }
    }
  };

  // playYouTube plays id, inside the tap when there's a player ready.
  function playYouTube(id) {
    if (ytPlayer && ytPlayerReady) {
      if (ytVideo === id) {
        ytPlayer.unMute();
        ytPlayer.playVideo();
      } else {
        ytPlayer.loadVideoById({ videoId: id });
        ytPlayer.unMute();
        ytVideo = id;
      }
      return;
    }
    if (ytPlayer && ytVideo === id) {
      ytPending = true; // adopted, not ready yet: it plays when it is
      return;
    }
    // No player for it: build one, playing (sound may wait for a second
    // tap on iOS, as it's no longer inside this one).
    clearPlayer();
    var host = document.createElement("div");
    host.id = "reel-yt";
    player.appendChild(host);
    ytVideo = id;
    ytPlayerReady = false;
    whenYT(function () {
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
    }
    ytPlayer = null;
    ytPlayerReady = false;
    ytVideo = null;
    ytPending = false;
  }

  // --- Vimeo, and video files ------------------------------------------
  // A Vimeo clip plays from its embed (autoplay, with sound), and pauses and
  // plays again by message (its player's postMessage API). A file is a
  // <video>, played inside the tap.
  function vimeo(method) {
    var f = player.querySelector("iframe");
    if (f && f.contentWindow) {
      f.contentWindow.postMessage(JSON.stringify({ method: method }), "https://player.vimeo.com");
    }
  }

  function playVimeo(src) {
    clearPlayer();
    var f = document.createElement("iframe");
    f.src = src;
    f.title = "Clip";
    f.setAttribute("allow", "autoplay; encrypted-media; picture-in-picture");
    // Vimeo's player says nothing without its API: it's playing a moment
    // after it loads.
    f.addEventListener("load", function () { setTimeout(function () { setPlaying(true); }, 1000); }, { once: true });
    player.appendChild(f);
  }

  function videoEl() {
    return player.querySelector("video");
  }

  function playFile(src) {
    var v = videoEl();
    if (!v || v.getAttribute("src") !== src) {
      clearPlayer();
      v = document.createElement("video");
      v.className = "ep-reel__media";
      v.src = src;
      v.loop = true;
      v.playsInline = true;
      player.appendChild(v);
    }
    watchVideo(v);
    v.muted = false;
    var p = v.play();
    if (p && p.catch) p.catch(function () { setPlaying(false); });
  }

  function watchVideo(v) {
    if (v.dataset.watched) return;
    v.dataset.watched = "1";
    v.addEventListener("playing", function () { setPlaying(true); });
    v.addEventListener("pause", function () { setPlaying(false); });
  }

  // clearPlayer removes the player, keeping the poster.
  function clearPlayer() {
    Array.prototype.slice.call(player.children).forEach(function (el) {
      if (!el.querySelector(".ep-reel__poster") && !el.classList.contains("ep-reel__poster")) el.remove();
    });
  }

  // --- Playing and pausing -----------------------------------------------
  function play(clip) {
    var kind = clip.dataset.kind;
    if (kind === "youtube") {
      playYouTube(clip.dataset.ytId);
      return;
    }
    destroyYouTube();
    if (kind === "vimeo") playVimeo(clip.dataset.src);
    if (kind === "file") playFile(clip.dataset.src);
  }

  function pause() {
    var kind = activeEl && activeEl.dataset.kind;
    if (kind === "youtube" && ytPlayer && ytPlayerReady) ytPlayer.pauseVideo();
    if (kind === "vimeo") {
      vimeo("pause");
      setPlaying(false);
    }
    if (kind === "file" && videoEl()) videoEl().pause();
  }

  function resume() {
    if (activeEl.dataset.kind === "vimeo" && player.querySelector("iframe")) {
      vimeo("play");
      setPlaying(true);
      return;
    }
    play(activeEl);
  }

  // setPlaying says whether the video is playing: the poster fades for good
  // the first time it is (a paused video keeps its frame), and the button
  // says what a tap does next.
  function setPlaying(on) {
    playingNow = on;
    if (on) player.classList.add("is-playing");
    syncButton();
  }

  function syncButton() {
    if (!playBtn) return;
    playBtn.hidden = !activeEl || activeEl.dataset.kind === "none";
    playBtn.setAttribute("aria-pressed", String(playingNow));
    playBtn.classList.toggle("is-on", playingNow);
    var label = playBtn.querySelector(".ep-reel__play-label");
    if (label) label.textContent = playingNow ? "PAUSE" : "PLAY";
  }

  function toggle() {
    if (!activeEl || activeEl.dataset.kind === "none") return;
    if (playingNow) {
      pause();
    } else {
      resume();
    }
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

  function activate(clip) {
    if (activeEl) {
      activeEl.classList.remove("is-active");
      activeEl.setAttribute("aria-pressed", "false");
    }
    activeEl = clip;
    clip.classList.add("is-active");
    clip.setAttribute("aria-pressed", "true");
    updateSlate(clip);
    syncButton();
  }

  clips.forEach(function (clip) {
    clip.addEventListener("click", function () {
      if (clip === activeEl) {
        toggle();
        return;
      }
      if (playingNow) pause();
      playingNow = false;
      activate(clip);
      if (clip.dataset.kind === "none") {
        destroyYouTube();
        clearPlayer();
        player.classList.remove("is-playing");
        return;
      }
      play(clip);
    });
  });

  if (playBtn) playBtn.addEventListener("click", toggle);
  if (reel) {
    reel.addEventListener("click", function (e) {
      if (e.target.closest("#reel-play")) return;
      toggle();
    });
  }

  // The first clip is active. Its player (in the page's <template>) goes in,
  // paused, once the page has loaded and painted, and a while after, so
  // YouTube's megabytes wait for the page, not the other way round; a
  // YouTube player is adopted into its API, ready for the first tap.
  activate(clips[0]);
  var embed = document.getElementById("reel-embed");

  function loadFirst() {
    if (!embed || !embed.isConnected) return;
    player.appendChild(embed.content.cloneNode(true));
    embed.remove();
    var v = videoEl();
    if (v) watchVideo(v);
    if (clips[0].dataset.kind === "youtube") {
      ytVideo = clips[0].dataset.ytId;
      whenYT(function () {
        if (!ytPlayer && document.getElementById("reel-yt")) {
          ytPlayer = new window.YT.Player("reel-yt", { events: ytEvents });
        }
      });
    }
  }

  var LOAD_DELAY = 3000;

  // A frame's callback runs before that frame paints; a task queued from it
  // runs after. On a slow phone the first paint can come well after load.
  function afterPaint() {
    requestAnimationFrame(function () {
      setTimeout(function () {
        if ("requestIdleCallback" in window) {
          requestIdleCallback(loadFirst, { timeout: 2000 });
        } else {
          loadFirst();
        }
      }, LOAD_DELAY);
    });
  }

  if (document.readyState === "complete") {
    afterPaint();
  } else {
    window.addEventListener("load", afterPaint);
  }
})();
