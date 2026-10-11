// Port of the onboarding background (lib/views/onboarding_view.dart,
// _blobLayoutForStep step 0). The app drives it with a 6s AnimationController
// that repeats in reverse; wave = sin(t * pi), reverseWave = cos(t * pi).
(function () {
  "use strict";

  var DURATION_MS = 6000;

  function layout(width, height, wave, reverseWave) {
    return {
      pink: { top: -70 + wave * 35, left: -55 + reverseWave * 30 },
      orange: { bottom: -90 - wave * 30, right: -60 - reverseWave * 25 },
      small: { top: height * 0.45 + wave * 25, right: 35 - reverseWave * 30 },
      teal: { bottom: height * 0.2 - wave * 25, left: 70 + reverseWave * 35 },
    };
  }

  function mount() {
    var container = document.createElement("div");
    container.className = "blobs";
    container.setAttribute("aria-hidden", "true");

    var blobs = {};
    ["pink", "orange", "small", "teal"].forEach(function (name) {
      var el = document.createElement("div");
      el.className = "blob " + name;
      container.appendChild(el);
      blobs[name] = el;
    });
    document.body.insertBefore(container, document.body.firstChild);
    return blobs;
  }

  function apply(blobs, t) {
    var positions = layout(
      window.innerWidth,
      window.innerHeight,
      Math.sin(t * Math.PI),
      Math.cos(t * Math.PI)
    );
    Object.keys(positions).forEach(function (name) {
      var style = blobs[name].style;
      var pos = positions[name];
      Object.keys(pos).forEach(function (side) {
        style[side] = pos[side] + "px";
      });
    });
  }

  var blobs = mount();
  var reduceMotion =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (reduceMotion) {
    apply(blobs, 0);
    window.addEventListener("resize", function () {
      apply(blobs, 0);
    });
    return;
  }

  function frame(now) {
    // Forward then reverse, like AnimationController.repeat(reverse: true).
    var phase = (now % (DURATION_MS * 2)) / DURATION_MS;
    apply(blobs, phase <= 1 ? phase : 2 - phase);
    window.requestAnimationFrame(frame);
  }
  window.requestAnimationFrame(frame);
})();
