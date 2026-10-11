// Forwards Supabase email links on synk.cc into the Synk app.
//
// The email templates point at synk.cc/<page>.html?token=<TokenHash>&type=...
// This page rebuilds the link as io.supabase.synk://<host>?token=...&type=...
// and the app verifies the token with supabase.auth.verifyOTP.
//
// The token is never verified here: verifying consumes it, and the app needs
// it to create its own session.
(function () {
  "use strict";

  var SCHEME = "io.supabase.synk";
  // Token hashes are hex, PKCE ones are prefixed with "pkce_".
  var TOKEN_PATTERN = /^[A-Za-z0-9_-]{8,256}$/;
  // How long to wait before assuming the app did not open.
  var APP_OPEN_TIMEOUT_MS = 2500;

  function buildAppUrl(options, params) {
    var query = [];
    var token = params.get("token");
    var type = params.get("type") || options.defaultType;

    if (token) query.push("token=" + encodeURIComponent(token));
    if (token && type && options.includeType) {
      query.push("type=" + encodeURIComponent(type));
    }

    return (
      SCHEME + "://" + options.host + (query.length ? "?" + query.join("&") : "")
    );
  }

  function validate(options, params) {
    var token = params.get("token");
    var type = params.get("type") || options.defaultType;

    if (!token) return !options.requireToken;
    if (!TOKEN_PATTERN.test(token)) return false;
    if (options.allowedTypes && options.allowedTypes.indexOf(type) === -1) {
      return false;
    }
    return true;
  }

  function showError() {
    var card = document.querySelector(".card");
    card.classList.add("error");
    document.getElementById("title").textContent = "This link looks broken";
    document.getElementById("message").textContent =
      "Open Synk and request a new email, or copy the full link from your inbox.";
    var button = document.getElementById("open-app");
    button.href = SCHEME + "://login-callback";
    button.textContent = "Open Synk App";
  }

  window.synkRedirect = function (options) {
    var params = new URLSearchParams(window.location.search);

    // Plain https://synk.cc with nothing to forward: show the brand only.
    if (options.homeWhenEmpty && !window.location.search && !window.location.hash) {
      document.body.classList.add("home");
      document.getElementById("tagline").hidden = false;
      return;
    }

    var button = document.getElementById("open-app");
    var hint = document.getElementById("hint");

    if (!validate(options, params)) {
      showError();
      return;
    }

    var appUrl = buildAppUrl(options, params);
    button.href = appUrl;

    // If the app opens, the page is hidden and the hint never shows.
    var hintTimer = window.setTimeout(function () {
      if (document.visibilityState === "visible") hint.hidden = false;
    }, APP_OPEN_TIMEOUT_MS);

    document.addEventListener("visibilitychange", function () {
      if (document.visibilityState === "hidden") window.clearTimeout(hintTimer);
    });

    // Short delay so the confirmation is visible before the app takes over.
    window.setTimeout(function () {
      window.location.href = appUrl;
    }, 400);
  };
})();
