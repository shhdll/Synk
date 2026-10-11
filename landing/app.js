// Handles Supabase email links on synk.cc.
//
// The email templates point at synk.cc/<page>.html?token=<TokenHash>&type=...
//
// Sign-up, magic link and email change are confirmed right here, so the page
// can tell the user the real outcome. For sign-up the resulting session is
// handed to the app (io.supabase.synk://login-callback?refresh_token=...) so
// it signs straight in. Password reset is not confirmed here: the app needs
// the token itself to let the user set a new password.
//
// Opening the app, per device:
// - Android: automatically, through an intent:// link. Android offers Synk
//   when it is installed and simply stays on this page when it is not.
// - iPhone/iPad and desktop: only from "Continue to Synk" (an automatic jump
//   shows an error when the app is missing).
(function () {
  "use strict";

  var SCHEME = "io.supabase.synk";
  // Token hashes are hex, PKCE ones are prefixed with "pkce_".
  var TOKEN_PATTERN = /^[A-Za-z0-9_-]{8,256}$/;
  // Marks a page reached after Android could not open the app.
  var FALLBACK_PARAM = "app_missing";
  // Marks an already confirmed link, so reloading shows the result again
  // instead of re-using the spent token.
  var CONFIRMED_PARAM = "confirmed";

  var IS_ANDROID = /Android/i.test(navigator.userAgent);

  // What the user sees after a successful confirmation, by link type.
  var SUCCESS = {
    signup: ["Email confirmed", "Your Synk account is ready."],
    invite: ["Email confirmed", "Your Synk account is ready."],
    magiclink: ["Link confirmed", "Continue to Synk to sign in."],
    email: ["Link confirmed", "Continue to Synk to sign in."],
    email_change: ["Email updated", "Your Synk account now uses your new email."],
    email_change_partial: [
      "One more step",
      "Open the link we sent to your other email to finish the change.",
    ],
  };

  function el(id) {
    return document.getElementById(id);
  }

  function show(title, message, success) {
    el("title").textContent = title;
    el("message").textContent = message || "";
    el("message").hidden = !message;
    el("badge").hidden = !success;
    el("open-app").hidden = false;
  }

  // The link "Continue to Synk" uses on this device. On Android it is an
  // intent:// link that falls back to [fallbackUrl] when Synk is missing.
  function appUrl(host, query, fallbackUrl) {
    if (!IS_ANDROID) return SCHEME + "://" + host + query;

    var fallback = new URL(fallbackUrl || window.location.href);
    fallback.searchParams.set(FALLBACK_PARAM, "1");
    return (
      "intent://" +
      host +
      query +
      "#Intent;scheme=" +
      SCHEME +
      ";S.browser_fallback_url=" +
      encodeURIComponent(fallback.toString()) +
      ";end"
    );
  }

  function openApp(url, params) {
    el("open-app").href = url;
    if (IS_ANDROID && !params.get(FALLBACK_PARAM)) window.location.href = url;
  }

  function linkType(options, params) {
    return params.get("type") || options.defaultType;
  }

  function validate(options, params) {
    var token = params.get("token");
    if (!token) return !options.requireToken;
    if (!TOKEN_PATTERN.test(token)) return false;
    var type = linkType(options, params);
    return !options.allowedTypes || options.allowedTypes.indexOf(type) !== -1;
  }

  // Supabase reports rejected links in the query or the fragment.
  function hasAuthError() {
    var query = new URLSearchParams(window.location.search);
    var fragment = new URLSearchParams(window.location.hash.replace(/^#/, ""));
    return ["error", "error_code"].some(function (key) {
      return query.has(key) || fragment.has(key);
    });
  }

  function showExpired() {
    window.location.replace("expired.html");
  }

  // Page URL for a confirmed result, without the spent token.
  function confirmedUrl(kind) {
    var url = new URL(window.location.pathname, window.location.origin);
    url.searchParams.set(CONFIRMED_PARAM, kind);
    return url.toString();
  }

  function showConfirmed(kind, params, appQuery) {
    var text = SUCCESS[kind] || SUCCESS.signup;
    show(text[0], text[1], kind !== "email_change_partial");
    openApp(
      appUrl("login-callback", appQuery || "", confirmedUrl(kind)),
      params
    );
  }

  function verifyOnPage(type, tokenHash) {
    var config = window.SYNK_SUPABASE;
    return fetch(config.url + "/auth/v1/verify", {
      method: "POST",
      headers: {
        apikey: config.anonKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ type: type, token_hash: tokenHash }),
    }).then(function (response) {
      return response.json().then(
        function (body) {
          return { ok: response.ok, status: response.status, body: body };
        },
        function () {
          return { ok: response.ok, status: response.status, body: {} };
        }
      );
    });
  }

  // Sends the token on to the app, which confirms it there.
  function forwardToApp(options, params) {
    var query = "?token=" + encodeURIComponent(params.get("token"));
    if (options.includeType) {
      query += "&type=" + encodeURIComponent(linkType(options, params));
    }
    el("message").hidden = !IS_ANDROID || !!params.get(FALLBACK_PARAM);
    openApp(appUrl(options.host, query), params);
  }

  window.synkRedirect = function (options) {
    if (hasAuthError()) return showExpired();

    var params = new URLSearchParams(window.location.search);

    // Plain https://synk.cc with nothing to forward: show the brand only.
    if (options.homeWhenEmpty && !window.location.search && !window.location.hash) {
      el("title").textContent = "Find your missing piece.";
      el("message").hidden = true;
      el("open-app").hidden = true;
      return;
    }

    // Reloaded, or back from Android without the app: show the result.
    var confirmed = params.get(CONFIRMED_PARAM);
    if (confirmed && SUCCESS[confirmed]) {
      return showConfirmed(confirmed, params);
    }

    if (!validate(options, params)) {
      show("This link looks broken", "Request a new email from the Synk app.");
      el("open-app").href = appUrl("login-callback", "");
      return;
    }

    // Nothing to confirm (allowed only where requireToken is false).
    if (!params.get("token")) {
      el("message").hidden = true;
      el("open-app").href = appUrl(options.host, "");
      return;
    }

    if (!options.verifyOnPage || !window.SYNK_SUPABASE) {
      return forwardToApp(options, params);
    }

    var type = linkType(options, params);
    var heading = el("title").textContent;
    el("title").textContent = "Confirming…";
    el("message").hidden = true;
    el("open-app").hidden = true;

    verifyOnPage(type, params.get("token")).then(
      function (result) {
        if (!result.ok) {
          // 4xx: expired, already used, or otherwise rejected.
          if (result.status >= 400 && result.status < 500) return showExpired();
          el("title").textContent = heading;
          el("open-app").hidden = false;
          return forwardToApp(options, params);
        }

        var session = result.body && result.body.refresh_token ? result.body : null;
        var kind = type;
        if (type === "email_change" && !session) kind = "email_change_partial";

        // A reload now shows this result instead of re-using the token.
        window.history.replaceState(null, "", confirmedUrl(kind));

        // Sign-up and magic link: hand the session to the app.
        var appQuery =
          session && type !== "email_change"
            ? "?refresh_token=" +
              encodeURIComponent(session.refresh_token) +
              "&type=" +
              encodeURIComponent(type)
            : "";
        showConfirmed(kind, params, appQuery);
      },
      function () {
        // Network trouble: let the app confirm it instead.
        el("title").textContent = heading;
        el("open-app").hidden = false;
        forwardToApp(options, params);
      }
    );
  };

  // expired.html: the button just opens the app to request a new link.
  window.synkExpired = function () {
    el("open-app").href = appUrl("login-callback", "");
  };
})();
