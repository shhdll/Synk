// Handles Supabase email links on synk.cc.
//
// The email templates point at synk.cc/<page>.html?token=<TokenHash>&type=...
//
// Sign-up, magic link and email change are confirmed right here, so the page
// can tell the user the real outcome. For sign-up the resulting session is
// handed to the app (io.supabase.synk://login-callback?refresh_token=...) so
// it signs straight in.
//
// Password reset shows a new password form, so the link also works on a
// phone without Synk. The token is only used when the form is submitted, so
// "Continue to Synk" can still pass it to the app unused.
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
    recovery: ["Password updated", "Log in to Synk with your new password."],
    // Signed up at synk.cc/admin, so there is no app account to open.
    dashboard: ["Email confirmed", "Sign in to the dashboard to ask for access."],
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
    if (kind === "dashboard") {
      el("open-app").href = "/admin/";
      el("open-app").querySelector("span").textContent = "Go to the dashboard";
      return;
    }
    openApp(
      appUrl("login-callback", appQuery || "", confirmedUrl(kind)),
      params
    );
  }

  function authRequest(method, path, body, accessToken) {
    var config = window.SYNK_SUPABASE;
    var headers = {
      apikey: config.anonKey,
      "Content-Type": "application/json",
    };
    if (accessToken) headers.Authorization = "Bearer " + accessToken;
    return fetch(config.url + "/auth/v1" + path, {
      method: method,
      headers: headers,
      body: body ? JSON.stringify(body) : undefined,
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

  function verifyOnPage(type, tokenHash) {
    return authRequest("POST", "/verify", { type: type, token_hash: tokenHash });
  }

  // Same rules as AuthConstants.validatePassword in the app.
  function passwordProblem(password, confirmation) {
    if (!password) return "Password is required";
    if (password.length < 8) return "Password must be at least 8 characters";
    if (!/[A-Z]/.test(password)) {
      return "Password must contain at least 1 uppercase letter";
    }
    if (!/[a-z]/.test(password)) {
      return "Password must contain at least 1 lowercase letter";
    }
    if (!/[0-9]/.test(password)) return "Password must contain at least 1 number";
    if (!/[^a-zA-Z0-9]/.test(password)) {
      return "Password must contain at least 1 special character (e.g., @$!%*?&)";
    }
    if (!confirmation) return "Please confirm your new password";
    if (password !== confirmation) return "Passwords do not match";
    return null;
  }

  function showPasswordForm(tokenHash, params) {
    var form = el("reset-form");
    var button = el("save-password");
    var error = el("form-error");
    // Kept after the token is used, so a rejected password can be retried.
    var session = null;

    el("message").textContent = "Choose a new password for your account.";
    el("message").hidden = false;
    form.hidden = false;
    el("app-note").hidden = false;
    el("open-app").classList.add("secondary");

    function showError(message) {
      error.textContent = message || "";
      error.hidden = !message;
    }

    function setSaving(saving) {
      button.disabled = saving;
      button.textContent = saving ? "Saving…" : "Update password";
    }

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      var password = el("new-password").value;
      var problem = passwordProblem(password, el("confirm-password").value);
      if (problem) return showError(problem);

      showError("");
      setSaving(true);

      var ready = session
        ? Promise.resolve(session)
        : verifyOnPage("recovery", tokenHash).then(function (result) {
            if (!result.ok) {
              throw { expired: result.status >= 400 && result.status < 500 };
            }
            session = result.body;
            return session;
          });

      ready
        .then(function (current) {
          return authRequest(
            "PUT",
            "/user",
            { password: password },
            current.access_token
          );
        })
        .then(function (result) {
          if (result.status === 401 || result.status === 403) {
            throw { expired: true };
          }
          if (!result.ok) {
            throw { message: result.body.msg || result.body.message };
          }

          // End the session the link opened on this page; the user logs in
          // on their own phone.
          authRequest("POST", "/logout?scope=local", null, session.access_token)
            .catch(function () {});

          window.history.replaceState(null, "", confirmedUrl("recovery"));
          form.hidden = true;
          el("app-note").hidden = true;
          el("open-app").classList.remove("secondary");
          showConfirmed("recovery", params);
        })
        .catch(function (failure) {
          setSaving(false);
          if (failure && failure.expired) return showExpired();
          // A thrown Error is a network failure, not a message from Supabase.
          showError(
            (failure && !(failure instanceof Error) && failure.message) ||
              "Couldn't update your password. Check your connection and try again."
          );
        });
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
      forwardToApp(options, params);
      if (options.passwordForm && window.SYNK_SUPABASE) {
        showPasswordForm(params.get("token"), params);
      }
      return;
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
        var meta = result.body && result.body.user && result.body.user.user_metadata;
        if (type === "signup" && meta && meta.dashboard_only) kind = "dashboard";

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
