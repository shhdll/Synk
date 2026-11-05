// Synk admin dashboard. Everything goes through the admin_* database
// functions, which check admin access on the server.
(function () {
  "use strict";

  var cfg = window.SYNK_SUPABASE;
  var sb = window.supabase.createClient(cfg.url, cfg.anonKey);
  var app = document.getElementById("app");
  var PAGE_SIZE = 50;
  var TZ = "Asia/Riyadh";

  var me = null;
  var shell = null;
  var current = { section: null, listKey: null, reload: null, rows: {} };

  var SECTIONS = [
    { key: "overview", label: "Overview" },
    { key: "support", label: "Support" },
    { key: "reports", label: "Reports" },
    { key: "users", label: "Users" },
    { key: "activities", label: "Activities" },
    { key: "audit", label: "Audit log" },
    { key: "admins", label: "Admins" },
  ];

  var REASONS = {
    harassment: "Harassment",
    spam: "Spam",
    fake_profile: "Fake profile",
    inappropriate_content: "Inappropriate content",
    other: "Other",
  };

  var CATEGORIES = { problem: "Bug", feedback: "Idea", other: "Other", appeal: "Appeal" };

  var STATUS_LABELS = {
    open: "Open",
    reviewing: "In review",
    resolved: "Resolved",
    dismissed: "Dismissed",
    replied: "Replied",
    closed: "Closed",
    joined: "Joined",
    pending: "Pending",
    waitlisted: "Waitlisted",
    rejected: "Rejected",
    sent: "Sent",
    failed: "Failed",
  };

  var ACTIONS = {
    "user.suspend": "Suspended user",
    "user.restore": "Restored user",
    "activity.delete": "Deleted activity",
    "report.start_review": "Started review",
    "report.dismiss": "Dismissed report",
    "report.remove": "Acted on report",
    "support.reply": "Replied to ticket",
    "support.reply_failed": "Reply not sent",
    "support.close": "Closed ticket",
    "support.reopen": "Reopened ticket",
    "admin.add": "Added admin",
    "admin.approve": "Approved admin request",
    "admin.decline": "Declined admin request",
    "admin.remove": "Removed admin",
  };

  var TAKEN = {
    none: "No action",
    suspended_user: "User suspended",
    deleted_activity: "Activity deleted",
  };

  // ---- Helpers ------------------------------------------------------------------

  function h(tag, attrs) {
    var el = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (key) {
        var value = attrs[key];
        if (value === null || value === undefined || value === false) return;
        if (key.slice(0, 2) === "on") el.addEventListener(key.slice(2), value);
        else if (key === "class") el.className = value;
        else if (key === "value") el.value = value;
        else el.setAttribute(key, value === true ? "" : value);
      });
    }
    for (var i = 2; i < arguments.length; i++) append(el, arguments[i]);
    return el;
  }

  function append(el, child) {
    if (child === null || child === undefined || child === false) return;
    if (Array.isArray(child)) return child.forEach(function (c) { append(el, c); });
    el.appendChild(child instanceof Node ? child : document.createTextNode(String(child)));
  }

  function clear(el) {
    while (el.firstChild) el.removeChild(el.firstChild);
    return el;
  }

  function fmtDate(value) {
    if (!value) return "";
    return new Date(value).toLocaleDateString("en-GB", {
      timeZone: TZ, day: "numeric", month: "short", year: "numeric",
    });
  }

  function fmtDateTime(value) {
    if (!value) return "";
    return new Date(value).toLocaleString("en-GB", {
      timeZone: TZ, day: "numeric", month: "short", year: "numeric",
      hour: "2-digit", minute: "2-digit",
    });
  }

  function fmtDay(value) {
    return new Date(value + "T12:00:00").toLocaleDateString("en-GB", {
      day: "numeric", month: "short",
    });
  }

  function num(n) {
    return Number(n || 0).toLocaleString("en-US");
  }

  function pill(status, label) {
    return h("span", { class: "pill " + status }, label || STATUS_LABELS[status] || status);
  }

  function personName(card) {
    if (!card) return "Deleted account";
    return card.full_name || (card.username ? "@" + card.username : "No name");
  }

  // Small round profile photo, or the first letter when there is none.
  function avatar(card, size) {
    var px = (size || 24) + "px";
    var letter = h("span", {
      class: "av av-empty",
      style: "width:" + px + ";height:" + px + ";font-size:" + Math.round((size || 24) * 0.45) + "px",
    }, ((card && (card.full_name || card.username)) || "?").trim().charAt(0).toUpperCase());
    if (!card || !card.avatar_url) return letter;
    return h("img", {
      class: "av", src: card.avatar_url, alt: "", loading: "lazy",
      style: "width:" + px + ";height:" + px,
      onerror: function (e) { e.target.replaceWith(letter); },
    });
  }

  function thumb(url, size) {
    var px = (size || 32) + "px";
    // Activities without a photo get the app logo on a soft tile.
    var empty = h("span", { class: "thumb thumb-empty", style: "width:" + px + ";height:" + px },
      h("img", { src: "/logo.png", alt: "" }));
    if (!url) return empty;
    return h("img", {
      class: "thumb", src: url, alt: "", loading: "lazy",
      style: "width:" + px + ";height:" + px,
      onerror: function (e) { e.target.replaceWith(empty); },
    });
  }

  function withMedia(media, content) {
    return h("div", { class: "media" }, media, h("div", { class: "media-text" }, content));
  }

  function personLink(card) {
    if (!card) return h("span", { class: "sub" }, "Deleted account");
    return h("span", { class: "person" },
      avatar(card, 20),
      h("a", { href: "#/users?id=" + card.id }, personName(card)),
      card.suspended ? [" ", pill("suspended", "Suspended")] : null);
  }

  function friendly(error) {
    if (!error) return "Something went wrong.";
    if (error.code === "42501") return "You don't have access to this.";
    return error.message || "Something went wrong.";
  }

  async function rpc(name, args) {
    var result = await sb.rpc(name, args || {});
    if (result.error) throw new Error(friendly(result.error));
    return result.data;
  }

  async function replySupport(body) {
    var result = await sb.functions.invoke("reply-support", { body: body });
    if (result.error) {
      var detail = null;
      try { detail = await result.error.context.json(); } catch (e) { /* not json */ }
      var err = new Error((detail && detail.error) || "request_failed");
      err.detail = detail;
      throw err;
    }
    return result.data;
  }

  // ---- Toasts and dialogs -----------------------------------------------------------

  var toastBox = null;

  function toast(message, kind) {
    if (!toastBox) {
      toastBox = h("div", { class: "toasts", role: "status", "aria-live": "polite" });
      document.body.appendChild(toastBox);
    }
    var el = h("div", { class: "toast" + (kind === "error" ? " error" : "") }, message);
    toastBox.appendChild(el);
    setTimeout(function () { el.remove(); }, kind === "error" ? 7000 : 3500);
  }

  // Resolves with { ok, note }.
  function confirmDialog(options) {
    return new Promise(function (resolve) {
      var note = null;
      var error = h("p", { class: "form-error", hidden: true });
      if (options.note && options.note.type) {
        note = h("input", {
          class: "input", type: options.note.type,
          placeholder: options.note.placeholder || "",
        });
      } else if (options.note) {
        note = h("textarea", {
          class: "textarea", rows: 3, maxlength: 500,
          placeholder: options.note.placeholder || "",
        });
      }
      var confirmBtn = h("button", {
        class: "btn " + (options.danger ? "danger solid" : "primary"), type: "submit",
      }, options.confirm);
      var dialog = h("dialog", null,
        h("form", { method: "dialog" },
          h("h2", null, options.title),
          options.body ? h("p", null, options.body) : null,
          note ? h("label", { class: "field" }, h("span", null, options.note.label), note) : null,
          error,
          h("div", { class: "actions" },
            h("button", { class: "btn", type: "button", value: "cancel", onclick: function () { done(false); } }, "Cancel"),
            confirmBtn)));

      dialog.querySelector("form").addEventListener("submit", function (event) {
        event.preventDefault();
        var text = note ? note.value.trim() : "";
        if (note && options.note.required && !text) {
          error.textContent = options.note.missing || "Add a reason first.";
          error.hidden = false;
          note.focus();
          return;
        }
        done(true, text);
      });
      dialog.addEventListener("cancel", function (event) { event.preventDefault(); done(false); });

      function done(ok, text) {
        dialog.close();
        dialog.remove();
        resolve({ ok: ok, note: text || "" });
      }

      document.body.appendChild(dialog);
      dialog.showModal();
      (note || confirmBtn).focus();
    });
  }

  // ---- Routing ----------------------------------------------------------------------

  function parseHash() {
    var raw = location.hash.replace(/^#\/?/, "");
    var parts = raw.split("?");
    var section = parts[0] || "overview";
    if (!SECTIONS.some(function (s) { return s.key === section; })) section = "overview";
    var params = {};
    new URLSearchParams(parts[1] || "").forEach(function (value, key) { params[key] = value; });
    return { section: section, params: params };
  }

  function go(section, params) {
    var query = new URLSearchParams();
    Object.keys(params || {}).forEach(function (key) {
      if (params[key] !== null && params[key] !== undefined && params[key] !== "") {
        query.set(key, params[key]);
      }
    });
    var text = query.toString();
    location.hash = "#/" + section + (text ? "?" + text : "");
  }

  function setParams(patch) {
    var route = parseHash();
    go(route.section, Object.assign({}, route.params, patch));
  }

  window.addEventListener("hashchange", function () {
    if (shell) route();
  });

  // ---- Sign in ----------------------------------------------------------------------

  // Brand panel on the left, the form or message on the right.
  function signinLayout(content) {
    shell = null;
    clear(app).appendChild(h("div", { class: "signin" },
      h("section", { class: "signin-brand" },
        // The app's drifting blobs, stronger here.
        h("div", { class: "signin-blobs", "aria-hidden": "true" }, h("span"), h("span"), h("span"), h("span")),
        h("div", { class: "signin-logo" }, h("img", { src: "/logo.png", alt: "" }), "Synk"),
        h("div", null,
          h("p", { class: "signin-tagline" }, "Welcome backstage"),
          h("p", { class: "signin-lead" }, "Where Synk's people and plans get looked after.")),
        h("div", { class: "signin-foot" },
          h("div", { class: "stripe", "aria-hidden": "true" }, h("span"), h("span"), h("span")),
          "Team dashboard")),
      h("section", { class: "signin-main" },
        h("div", { class: "signin-mobile-logo" }, h("img", { src: "/logo.png", alt: "" }), "Synk"),
        h("div", { class: "signin-card" }, content))));
  }

  function renderSignIn(message, requesting) {
    var email = h("input", { class: "input", type: "email", autocomplete: "username", required: true });
    var password = h("input", { class: "input", type: "password", autocomplete: "current-password", required: true });
    var error = h("p", { class: "form-error", hidden: !message }, message || "");
    var button = h("button", { class: "btn primary block big", type: "submit" }, requesting ? "Continue" : "Sign in");

    var form = h("form", null,
      h("h1", null, requesting ? "Request admin access" : "Sign in"),
      h("p", { class: "signin-sub" }, requesting
        ? "Sign in with your Synk account, then send your request."
        : "Use your Synk account."),
      h("label", { class: "field" }, h("span", null, "Email"), email),
      h("label", { class: "field" }, h("span", null, "Password"), password),
      error,
      button,
      h("div", { class: "signin-switch" },
        requesting ? "Already an admin? " : "Not an admin yet? ",
        h("button", {
          type: "button", class: "link-btn",
          onclick: function () { renderSignIn(null, !requesting); },
        }, requesting ? "Sign in" : "Request access")));

    form.addEventListener("submit", async function (event) {
      event.preventDefault();
      error.hidden = true;
      button.disabled = true;
      button.textContent = "Signing in";
      var result = await sb.auth.signInWithPassword({
        email: email.value.trim(), password: password.value,
      });
      button.disabled = false;
      button.textContent = requesting ? "Continue" : "Sign in";
      if (result.error) {
        var msg = result.error.message || "";
        error.textContent = /banned/i.test(msg) || result.error.code === "user_banned"
          ? "This account is suspended."
          : /confirm/i.test(msg) ? "Confirm your email first."
          : /invalid/i.test(msg) ? "Wrong email or password."
          : msg || "Could not sign in.";
        error.hidden = false;
        return;
      }
      await enter(result.data.session);
    });

    signinLayout(form);
    email.focus();
  }

  // Signed in but not an admin: ask for access, or wait for an answer.
  function renderAccessRequest(session, request) {
    var signOut = h("button", {
      type: "button", class: "btn block big",
      onclick: async function () { await sb.auth.signOut(); renderSignIn(); },
    }, "Sign out");
    var who = h("p", { class: "signin-who" }, "Signed in as ", h("b", null, session.user.email));

    if (request && request.status === "pending") {
      var check = h("button", { type: "button", class: "btn primary block big" }, "Check again");
      check.addEventListener("click", async function () {
        check.disabled = true;
        check.textContent = "Checking";
        await enter(session);
      });
      signinLayout([
        h("h1", null, "Request sent"),
        h("p", { class: "signin-sub" },
          "Sent " + fmtDate(request.created_at) + ". You'll get access once an admin approves it."),
        who,
        h("div", { class: "signin-actions" }, check, signOut),
      ]);
      return;
    }

    var note = h("textarea", {
      class: "textarea", rows: 3, maxlength: 500,
      placeholder: "Your role in the team, for example",
    });
    var error = h("p", { class: "form-error", hidden: true });
    var send = h("button", { type: "submit", class: "btn primary block big" }, "Send request");
    var form = h("form", null,
      h("h1", null, request && request.status === "declined" ? "Request declined" : "Request admin access"),
      h("p", { class: "signin-sub" }, request && request.status === "declined"
        ? "An admin declined your last request. You can send a new one."
        : "This account isn't an admin yet. An admin will review your request."),
      who,
      h("label", { class: "field" }, h("span", null, "Why do you need access? (optional)"), note),
      error,
      h("div", { class: "signin-actions" }, send, signOut));

    form.addEventListener("submit", async function (event) {
      event.preventDefault();
      send.disabled = true;
      send.textContent = "Sending";
      try {
        var result = await sb.functions.invoke("request-admin", { body: { note: note.value.trim() || null } });
        if (result.error) {
          var detail = null;
          try { detail = await result.error.context.json(); } catch (e) { /* not json */ }
          throw new Error((detail && detail.error) || "Could not send the request.");
        }
        await enter(session);
      } catch (e) {
        send.disabled = false;
        send.textContent = "Send request";
        error.textContent = e.message;
        error.hidden = false;
      }
    });
    signinLayout(form);
  }

  async function enter(session) {
    var status = null;
    try {
      status = await rpc("admin_access_status");
    } catch (e) {
      await sb.auth.signOut();
      renderSignIn(e.message);
      return;
    }
    if (!status.is_admin) {
      renderAccessRequest(session, status.request);
      return;
    }
    me = session.user;
    me.name = "";
    try {
      var profile = await sb.from("users").select("full_name, username, avatar_url").eq("id", me.id).maybeSingle();
      if (profile.data) {
        me.name = profile.data.full_name || profile.data.username || "";
        me.avatar_url = profile.data.avatar_url;
      }
    } catch (e) {
      // The email is shown instead.
    }
    renderShell();
    route();
  }

  sb.auth.onAuthStateChange(function (event) {
    if (event === "SIGNED_OUT" && shell) renderSignIn();
  });

  // ---- Shell ------------------------------------------------------------------------

  function renderShell() {
    var nav = h("nav", { class: "nav" });
    var counts = {};
    SECTIONS.forEach(function (s) {
      counts[s.key] = h("span", { class: "count" });
      nav.appendChild(h("a", { href: "#/" + s.key, "data-key": s.key }, s.label, counts[s.key]));
    });

    var page = h("main", { class: "page" });
    var drawerRoot = h("div");
    var root = h("div", { class: "shell" });

    var side = h("aside", { class: "side" },
      h("div", { class: "side-logo" }, h("img", { src: "/logo.png", alt: "" }), "Synk"),
      h("div", { class: "side-me" },
        avatar({ full_name: me.name || me.email, avatar_url: me.avatar_url }, 32),
        h("div", { class: "media-text" },
          h("div", { class: "who-name" }, me.name || me.email),
          h("div", { class: "who-role" }, "Admin"))),
      nav,
      h("div", { class: "side-foot" },
        h("div", { class: "who", title: me.email }, me.email),
        h("button", { class: "link-btn", onclick: function () { sb.auth.signOut(); } }, "Sign out")));

    nav.addEventListener("click", function () { root.classList.remove("nav-open"); });
    // Tapping outside the open menu closes it.
    var closeMenu = h("div", { class: "menu-back", onclick: function () { root.classList.remove("nav-open"); } });

    var topbar = h("div", { class: "topbar" },
      h("div", { class: "side-logo" }, h("img", { src: "/logo.png", alt: "" }), "Synk"),
      h("button", {
        class: "burger", type: "button", "aria-label": "Menu",
        onclick: function () { root.classList.toggle("nav-open"); },
      }, h("span"), h("span"), h("span")));

    append(root, [side, closeMenu, h("div", { class: "main" }, topbar, page), drawerRoot]);
    clear(app).appendChild(root);

    shell = { nav: nav, counts: counts, page: page, drawer: drawerRoot };
    current = { section: null, listKey: null, reload: null, rows: {} };
    refreshCounts();
  }

  async function refreshCounts() {
    if (!shell) return;
    try {
      var results = await Promise.all([
        rpc("admin_list_tickets", { p_status: "open", p_limit: 1 }),
        rpc("admin_list_reports", { p_kind: "all", p_status: "open", p_limit: 1 }),
        rpc("admin_list_admins"),
      ]);
      shell.counts.support.textContent = results[0].total ? num(results[0].total) : "";
      shell.counts.reports.textContent = results[1].total ? num(results[1].total) : "";
      shell.counts.admins.textContent = results[2].requests.length ? num(results[2].requests.length) : "";
    } catch (e) {
      // Counts are a nice extra; the pages show their own errors.
    }
  }

  function route() {
    var r = parseHash();
    Array.prototype.forEach.call(shell.nav.children, function (a) {
      a.classList.toggle("active", a.getAttribute("data-key") === r.section);
    });

    var listParams = Object.assign({}, r.params);
    delete listParams.id;
    var listKey = r.section + "|" + JSON.stringify(listParams);
    if (listKey !== current.listKey) {
      current.section = r.section;
      current.listKey = listKey;
      current.rows = {};
      PAGES[r.section](r.params);
    } else {
      markSelected(r.params.id);
    }
    renderDrawer(r.section, r.params.id);
  }

  function markSelected(id) {
    shell.page.querySelectorAll("tr.row").forEach(function (tr) {
      tr.classList.toggle("selected", tr.getAttribute("data-id") === id);
    });
  }

  // ---- Generic list page ------------------------------------------------------------

  function stateBox(title, text, retry) {
    return h("div", { class: "state" },
      h("strong", null, title),
      text ? h("div", null, text) : null,
      retry ? h("button", { class: "btn", onclick: retry }, "Try again") : null);
  }

  function tabs(param, options, value) {
    return h("div", { class: "tabs", role: "group" }, options.map(function (o) {
      var patch = { page: null, id: null };
      patch[param] = o.value;
      return h("button", {
        type: "button",
        class: o.value === value ? "on" : "",
        "aria-pressed": o.value === value ? "true" : "false",
        onclick: function () { setParams(patch); },
      }, o.label);
    }));
  }

  function searchBox(value, placeholder) {
    var input = h("input", {
      class: "input", type: "search", placeholder: placeholder, value: value || "",
      "aria-label": placeholder,
    });
    var timer = null;
    input.addEventListener("input", function () {
      clearTimeout(timer);
      timer = setTimeout(function () {
        setParams({ q: input.value.trim() || null, page: null, id: null });
      }, 350);
    });
    return input;
  }

  // options: title, filters (nodes), fetch(offset, sort) -> {total, rows}, columns,
  // rowKey(row), emptyText, sectionKey, sort ({key, dir} default).
  // A column with a sort key can be clicked to sort; first is its first direction.
  function listPage(options) {
    var page = clear(shell.page);
    var countEl = h("span", { class: "sub" });
    page.appendChild(h("div", { class: "page-head" }, h("h1", null, options.title), countEl));
    page.appendChild(h("div", { class: "toolbar" }, options.filters));
    var body = h("div", { class: "table-wrap" });
    var pager = h("div", { class: "pager" });
    append(page, [body, pager]);

    var pageNo = Math.max(parseInt(parseHash().params.page || "1", 10) || 1, 1);
    var sort = currentSort(options);

    async function load() {
      clear(body).appendChild(stateBox("Loading"));
      clear(pager);
      current.loaded = false;
      var data;
      try {
        data = await options.fetch((pageNo - 1) * PAGE_SIZE, sort);
      } catch (e) {
        clear(body).appendChild(stateBox("Couldn't load this list", e.message, load));
        return;
      }
      current.loaded = true;
      countEl.textContent = num(data.total) + (data.total === 1 ? " result" : " results");
      current.rows = {};
      var waiting = parseHash().params.id && options.needsRows;
      if (!data.rows.length) {
        clear(body).appendChild(stateBox(options.emptyText, null));
        if (waiting) renderDrawer(current.section, parseHash().params.id);
        return;
      }

      var thead = h("thead", null, h("tr", null, options.columns.map(function (c) {
        return h("th", { class: c.cls || "", "aria-sort": sortState(c, sort) }, c.sort ? sortButton(c, sort) : c.label);
      })));
      var tbody = h("tbody");
      var selected = parseHash().params.id;
      data.rows.forEach(function (row) {
        var key = options.rowKey(row);
        current.rows[key] = row;
        var opens = !!DETAILS[current.section];
        tbody.appendChild(h("tr", {
          class: opens ? "row" + (key === selected ? " selected" : "") : null,
          "data-id": key,
          tabindex: opens ? 0 : null,
          onclick: opens ? function () { setParams({ id: key }); } : null,
          onkeydown: opens ? function (e) { if (e.key === "Enter") setParams({ id: key }); } : null,
        }, options.columns.map(function (c) {
          return h("td", { class: c.cls || "", "data-label": c.label }, c.render(row));
        })));
      });
      clear(body).appendChild(h("table", { class: "list-table" }, thead, tbody));

      var from = (pageNo - 1) * PAGE_SIZE + 1;
      var to = Math.min(pageNo * PAGE_SIZE, data.total);
      if (data.total > PAGE_SIZE) {
        append(pager, [
          h("span", null, num(from) + "–" + num(to) + " of " + num(data.total)),
          h("button", { class: "btn small", disabled: pageNo === 1, onclick: function () { setParams({ page: pageNo - 1, id: null }); } }, "Previous"),
          h("button", { class: "btn small", disabled: to >= data.total, onclick: function () { setParams({ page: pageNo + 1, id: null }); } }, "Next"),
        ]);
      }
      // A drawer opened from a link may be waiting on these rows.
      if (waiting) renderDrawer(current.section, parseHash().params.id);
    }

    current.reload = load;
    load();
  }

  function currentSort(options) {
    var params = parseHash().params;
    var fallback = options.sort || { key: null, dir: "desc" };
    var known = options.columns.some(function (c) { return c.sort && c.sort === params.sort; });
    if (!known) return fallback;
    return { key: params.sort, dir: params.dir === "asc" ? "asc" : "desc" };
  }

  function sortState(column, sort) {
    if (!column.sort) return null;
    if (column.sort !== sort.key) return "none";
    return sort.dir === "asc" ? "ascending" : "descending";
  }

  function sortButton(column, sort) {
    var on = column.sort === sort.key;
    var dir = on ? (sort.dir === "asc" ? "desc" : "asc") : (column.first || "desc");
    return h("button", {
      type: "button", class: "sort" + (on ? " on" : ""),
      onclick: function () { setParams({ sort: column.sort, dir: dir, page: null }); },
    }, column.label, h("span", { class: "arrow", "aria-hidden": "true" }, on ? (sort.dir === "asc" ? "\u2191" : "\u2193") : ""));
  }

  // ---- Drawer -----------------------------------------------------------------------

  var drawerToken = 0;

  function closeDrawer() {
    setParams({ id: null });
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && shell && parseHash().params.id && !document.querySelector("dialog[open]")) {
      closeDrawer();
    }
  });

  function renderDrawer(section, id) {
    var root = shell.drawer;
    if (!id || !DETAILS[section]) {
      clear(root);
      return;
    }
    var token = ++drawerToken;
    var title = h("h2", null, "");
    var sub = h("div", { class: "sub" });
    var media = h("div", { class: "drawer-media" });
    var badge = h("div");
    var body = h("div", { class: "drawer-body" }, h("div", { class: "empty-line" }, "Loading"));
    clear(root);
    append(root, [
      h("div", { class: "drawer-back", onclick: closeDrawer }),
      h("aside", { class: "drawer", role: "dialog", "aria-label": "Details" },
        h("div", { class: "drawer-head" },
          h("div", { class: "media" }, media, h("div", { class: "media-text" }, title, sub)),
          h("div", { class: "actions" }, badge,
            h("button", { class: "close", "aria-label": "Close", onclick: closeDrawer }, "×"))),
        body),
    ]);

    var view = {
      title: function (text) { title.textContent = text; },
      sub: function (text) { clear(sub); append(sub, text); },
      media: function (node) { clear(media); append(media, node); },
      badge: function (node) { clear(badge); append(badge, node); },
      body: function (nodes) { clear(body); append(body, nodes); },
      stale: function () { return token !== drawerToken; },
      refresh: function () {
        if (current.reload) current.reload();
        refreshCounts();
        renderDrawer(section, id);
      },
    };

    DETAILS[section](id, view).catch(function (e) {
      if (view.stale()) return;
      view.title("Couldn't load");
      view.body(stateBox("Couldn't load this", e.message, function () { renderDrawer(section, id); }));
    });
  }

  function section(titleText, content) {
    return h("div", { class: "section" }, h("h3", null, titleText), content);
  }

  // Closed until the title is clicked.
  function foldSection(titleText, content) {
    return h("details", { class: "section fold" }, h("summary", null, titleText), content);
  }

  function kv(pairs) {
    var dl = h("dl", { class: "kv" });
    pairs.forEach(function (p) {
      if (!p || p[1] === null || p[1] === undefined || p[1] === "") return;
      append(dl, [h("dt", null, p[0]), h("dd", null, p[1])]);
    });
    return dl;
  }

  function list(items, empty, render) {
    if (!items || !items.length) return h("div", { class: "empty-line" }, empty);
    return h("div", { class: "list" }, items.map(function (item) {
      return h("div", { class: "list-item" }, render(item));
    }));
  }

  async function runAction(button, label, work) {
    var text = button.textContent;
    button.disabled = true;
    button.textContent = label;
    try {
      return await work();
    } catch (e) {
      toast(e.message, "error");
      return null;
    } finally {
      button.disabled = false;
      button.textContent = text;
    }
  }

  // ---- Overview ---------------------------------------------------------------------

  function renderOverview(params) {
    var choice = params.days === "90" || params.days === "all" ? params.days : "30";
    var days = choice === "all" ? null : Number(choice);
    var page = clear(shell.page);
    page.appendChild(h("div", { class: "page-head" },
      h("h1", null, greeting()),
      tabs("days", [
        { value: "30", label: "30 days" },
        { value: "90", label: "90 days" },
        { value: "all", label: "All time" },
      ], choice)));
    var body = h("div");
    page.appendChild(body);

    async function load() {
      clear(body).appendChild(stateBox("Loading"));
      var s;
      try {
        s = await rpc("admin_stats", { p_days: days });
      } catch (e) {
        clear(body).appendChild(stateBox("Couldn't load the numbers", e.message, load));
        return;
      }
      var period = days ? "in the last " + days + " days" : "all time";
      var weekly = s.bucket === "week";
      clear(body);
      body.appendChild(h("div", { class: "stats" },
        stat("Users", s.users, days ? "+" + num(s.users_in_period) + " " + period : "all time"),
        stat("Activities", s.activities, days ? "+" + num(s.activities_in_period) + " " + period : "all time"),
        stat("Upcoming activities", s.upcoming_activities, "starting after now"),
        stat("Joins", s.joins_in_period, period),
        stat("Sign-ins", s.signed_in_in_period, days ? "logged in " + period : "people who ever logged in"),
        stat("Open tickets", s.open_tickets, "waiting for a reply", "#/support"),
        stat("Open reports", s.open_reports, "not reviewed yet", "#/reports"),
        stat("Suspended", s.suspended, "accounts", "#/users?filter=suspended")));

      body.appendChild(h("div", { class: "charts" },
        chartPanel("New users", s.daily, "users", period, weekly),
        chartPanel("Activities created", s.daily, "activities", period, weekly)));

      var maxCat = Math.max.apply(null, s.categories.map(function (c) { return c.count; }).concat([1]));
      body.appendChild(h("div", { class: "panel" },
        h("div", { class: "panel-head" }, h("h2", null, "Activities by category"), h("span", { class: "total" }, period)),
        s.categories.length
          ? h("div", { class: "cat-list" }, s.categories.map(function (c) {
            return h("div", { class: "cat-row" },
              h("div", { class: "clip" }, c.label),
              h("div", { class: "track" }, h("div", { class: "fill", style: "width:" + Math.max(2, (c.count / maxCat) * 100) + "%" })),
              h("div", { class: "n" }, num(c.count)));
          }))
          : h("div", { class: "empty-line" }, "No activities yet.")));
    }

    current.reload = load;
    load();
  }

  function greeting() {
    var hour = Number(new Date().toLocaleString("en-GB", { timeZone: TZ, hour: "2-digit", hour12: false }));
    var part = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";
    var first = (me.name || "").split(" ")[0];
    return first ? part + ", " + first : part;
  }

  function stat(label, value, note, href) {
    return h("div", { class: "stat" },
      h("div", { class: "label" }, label),
      href ? h("a", { class: "value", href: href }, num(value)) : h("div", { class: "value" }, num(value)),
      h("div", { class: "note" }, note));
  }

  function chartPanel(titleText, daily, key, period, weekly) {
    var total = daily.reduce(function (sum, d) { return sum + d[key]; }, 0);
    var holder = h("div", { class: "chart" });
    var showingTable = false;
    var toggle = h("button", { class: "link-btn", type: "button" }, "Table");
    toggle.addEventListener("click", function () {
      showingTable = !showingTable;
      toggle.textContent = showingTable ? "Chart" : "Table";
      draw();
    });

    var observer = new ResizeObserver(function () { if (!showingTable) draw(); });
    observer.observe(holder);

    function draw() {
      clear(holder);
      if (showingTable) {
        holder.appendChild(h("div", { class: "table-wrap", style: "max-height:220px;overflow-y:auto" },
          h("table", null,
            h("thead", null, h("tr", null, h("th", null, weekly ? "Week of" : "Day"), h("th", { class: "num" }, titleText))),
            h("tbody", null, daily.slice().reverse().map(function (d) {
              return h("tr", null, h("td", null, fmtDay(d.day)), h("td", { class: "num" }, num(d[key])));
            })))));
        return;
      }
      columnChart(holder, daily, key, titleText, weekly);
    }

    var panel = h("div", { class: "panel" },
      h("div", { class: "panel-head" },
        h("h2", null, titleText),
        h("span", { class: "total" }, num(total) + " " + period + " · ", toggle)),
      holder);
    requestAnimationFrame(draw);
    return panel;
  }

  function niceMax(value) {
    if (value <= 4) return 4;
    var step = Math.pow(10, Math.floor(Math.log10(value)));
    var options = [1, 2, 2.5, 5, 10];
    for (var i = 0; i < options.length; i++) {
      if (options[i] * step >= value) return options[i] * step;
    }
    return 10 * step;
  }

  function columnChart(holder, daily, key, label, weekly) {
    var NS = "http://www.w3.org/2000/svg";
    var width = holder.clientWidth || 500;
    var height = 180;
    var left = 30, bottom = 22, top = 8;
    var innerW = width - left;
    var innerH = height - top - bottom;
    var max = niceMax(Math.max.apply(null, daily.map(function (d) { return d[key]; })));
    var band = innerW / daily.length;
    var barW = Math.max(1, Math.min(24, band - 2));

    function el(tag, attrs) {
      var node = document.createElementNS(NS, tag);
      Object.keys(attrs).forEach(function (k) { node.setAttribute(k, attrs[k]); });
      return node;
    }

    var svg = el("svg", { width: width, height: height, role: "img", "aria-label": label + " per day" });
    [0, max / 2, max].forEach(function (v) {
      var y = top + innerH - (v / max) * innerH;
      svg.appendChild(el("line", { class: "grid", x1: left, x2: width, y1: y, y2: y }));
      var t = el("text", { class: "axis-text", x: left - 6, y: y + 4, "text-anchor": "end" });
      t.textContent = num(v);
      svg.appendChild(t);
    });

    var tip = h("div", { class: "tip", hidden: true });

    daily.forEach(function (d, i) {
      var value = d[key];
      var x = left + i * band + (band - barW) / 2;
      var barH = (value / max) * innerH;
      var baseY = top + innerH;
      var g = el("g", {});
      var hit = el("rect", { class: "hit", x: left + i * band, y: top, width: band, height: innerH });
      g.appendChild(hit);
      if (value > 0) {
        var r = Math.min(4, barW / 2, barH);
        var y = baseY - barH;
        // Rounded at the top, square at the baseline.
        g.appendChild(el("path", {
          class: "col",
          d: "M" + x + "," + baseY + "V" + (y + r) + "Q" + x + "," + y + " " + (x + r) + "," + y +
            "H" + (x + barW - r) + "Q" + (x + barW) + "," + y + " " + (x + barW) + "," + (y + r) +
            "V" + baseY + "Z",
        }));
      }
      g.addEventListener("mouseenter", function () {
        clear(tip);
        append(tip, [(weekly ? "Week of " : "") + fmtDay(d.day) + "  ", h("b", null, num(value))]);
        tip.style.left = (x + barW / 2) + "px";
        tip.style.top = (top + innerH - barH) + "px";
        tip.hidden = false;
        g.classList.add("on");
      });
      g.addEventListener("mouseleave", function () {
        tip.hidden = true;
        g.classList.remove("on");
      });
      svg.appendChild(g);
    });

    [0, Math.floor(daily.length / 2), daily.length - 1].forEach(function (i, n) {
      var t = el("text", {
        class: "axis-text",
        x: left + i * band + band / 2,
        y: height - 6,
        "text-anchor": n === 0 ? "start" : n === 2 ? "end" : "middle",
      });
      t.textContent = fmtDay(daily[i].day);
      svg.appendChild(t);
    });

    append(holder, [svg, tip]);
  }

  // ---- Support ----------------------------------------------------------------------

  function renderSupport(params) {
    var status = params.status || "open";
    listPage({
      title: "Support",
      filters: [
        tabs("status", [
          { value: "open", label: "Open" },
          { value: "replied", label: "Replied" },
          { value: "closed", label: "Closed" },
          { value: "all", label: "All" },
        ], status),
        searchBox(params.q, "Search email or message"),
      ],
      fetch: function (offset) {
        return rpc("admin_list_tickets", {
          p_status: status, p_search: params.q || null, p_limit: PAGE_SIZE, p_offset: offset,
        });
      },
      rowKey: function (row) { return row.id; },
      emptyText: params.q ? "No tickets match \"" + params.q + "\"" : status === "open" ? "No open tickets" : "No tickets here",
      columns: [
        { label: "From", render: function (r) {
          return withMedia(avatar(r.user || { full_name: r.email }, 24),
            [h("div", null, r.user ? personName(r.user) : r.email), r.user ? h("div", { class: "sub" }, r.email) : null]);
        } },
        { label: "Type", render: function (r) {
          return pill("type-" + r.category, CATEGORIES[r.category] || r.category);
        } },
        { label: "Message", render: function (r) { return h("div", { class: "clip" }, r.message); } },
        { label: "Received", cls: "nowrap", render: function (r) { return fmtDate(r.created_at); } },
        { label: "Status", cls: "nowrap", render: function (r) {
          return [pill(r.status), r.last_send_failed ? [" ", pill("failed", "Not sent")] : null];
        } },
      ],
    });
  }

  async function ticketDetail(id, view) {
    var results = await Promise.all([
      rpc("admin_get_ticket", { p_ticket_id: id }),
      replySupport({ action: "get", ticket: id }).catch(function () { return null; }),
    ]);
    if (view.stale()) return;
    var data = results[0];
    var extra = results[1];
    var t = data.ticket;

    view.media(avatar(data.user || { full_name: t.email }, 36));
    view.title(data.user ? personName(data.user) : t.email);
    view.sub(t.email);
    view.badge(pill(t.status));

    var draft = h("textarea", { class: "textarea", rows: 6, maxlength: 5000, "aria-label": "Reply" });
    var lastFailed = data.replies.length && data.replies[data.replies.length - 1].email_status === "failed"
      ? data.replies[data.replies.length - 1] : null;
    if (lastFailed) draft.value = lastFailed.body;
    var counter = h("div", { class: "char-count" }, draft.value.length + " / 5000");
    draft.addEventListener("input", function () { counter.textContent = draft.value.length + " / 5000"; });

    var send = h("button", { class: "btn primary" }, lastFailed ? "Try sending again" : "Send reply");
    send.addEventListener("click", function () {
      var text = draft.value.trim();
      if (!text) {
        toast("Write a reply first.", "error");
        draft.focus();
        return;
      }
      runAction(send, "Sending", async function () {
        try {
          await replySupport({ action: "send", ticket: id, reply: text });
          toast("Reply sent to " + t.email);
        } catch (e) {
          var why = e.detail && e.detail.detail ? " (" + e.detail.detail + ")" : "";
          toast(e.message === "send_failed"
            ? "The email wasn't sent" + why + ". It's saved in the history so you can retry."
            : "Couldn't send: " + e.message, "error");
        }
        view.refresh();
      });
    });

    var closed = t.status === "closed";
    var toggle = h("button", { class: "btn" }, closed ? "Reopen" : "Mark as closed");
    toggle.addEventListener("click", function () {
      runAction(toggle, "Saving", async function () {
        await rpc("admin_set_ticket_status", { p_ticket_id: id, p_status: closed ? "open" : "closed" });
        toast(closed ? "Ticket reopened" : "Ticket closed");
        view.refresh();
      });
    });

    var shots = extra && extra.screenshots && extra.screenshots.length
      ? section("Screenshots", h("div", { class: "shots" }, extra.screenshots.map(function (src) {
        return h("a", { href: src, target: "_blank", rel: "noopener" }, h("img", { src: src, alt: "Screenshot" }));
      })))
      : (t.screenshot_paths && t.screenshot_paths.length && !extra
        ? section("Screenshots", h("div", { class: "empty-line" }, "Couldn't load the screenshots."))
        : null);

    view.body([
      section((CATEGORIES[t.category] || "Other") + " · " + fmtDateTime(t.created_at), h("div", { class: "message" }, t.message)),
      shots,
      section("Sender", kv([
        ["Account", data.user ? personLink(data.user) : "No account"],
        ["Email", t.email],
        ["App version", t.app_version],
        ["Other tickets", data.other_tickets ? num(data.other_tickets) : null],
      ])),
      section("Replies", data.replies.length
        ? data.replies.map(function (r) {
          return h("div", { class: "reply" },
            h("div", { class: "reply-meta" },
              h("span", null, r.admin ? personName(r.admin) : "Reply link in email"),
              h("span", null, fmtDateTime(r.created_at), " ", pill(r.email_status))),
            h("div", { class: "reply-body" }, r.body),
            r.error ? h("div", { class: "reply-error" }, r.error) : null);
        })
        : h("div", { class: "empty-line" }, "No replies yet.")),
      section("Reply by email", [draft, counter, h("div", { class: "actions" }, send, toggle)]),
    ]);
  }

  // ---- Reports ----------------------------------------------------------------------

  function renderReports(params) {
    var status = params.status || "open";
    var kind = params.kind || "all";
    listPage({
      title: "Reports",
      needsRows: true,
      filters: [
        tabs("status", [
          { value: "open", label: "Open" },
          { value: "closed", label: "Closed" },
          { value: "all", label: "All" },
        ], status),
        tabs("kind", [
          { value: "all", label: "All types" },
          { value: "user", label: "Users" },
          { value: "activity", label: "Activities" },
        ], kind),
      ],
      fetch: function (offset) {
        return rpc("admin_list_reports", {
          p_kind: kind, p_status: status, p_limit: PAGE_SIZE, p_offset: offset,
        });
      },
      rowKey: function (row) { return row.kind + ":" + row.id; },
      emptyText: status === "open" ? "No open reports" : "No reports here",
      columns: [
        { label: "Type", render: function (r) { return r.kind === "user" ? "User" : "Activity"; } },
        { label: "Reported", render: function (r) {
          if (r.kind === "user") {
            return withMedia(avatar(r.target_user, 22),
              [personName(r.target_user), r.target_user && r.target_user.suspended ? [" ", pill("suspended", "Suspended")] : null]);
          }
          return [h("div", { class: "clip" }, r.target_activity.title), r.target_activity.deleted ? pill("removed", "Deleted") : null];
        } },
        { label: "Reason", render: function (r) { return REASONS[r.reason] || r.reason; } },
        { label: "Reporter", cls: "hide-sm", render: function (r) { return personName(r.reporter); } },
        { label: "Received", cls: "nowrap", render: function (r) { return fmtDate(r.created_at); } },
        { label: "Status", render: function (r) { return pill(r.status); } },
      ],
    });
  }

  async function reportDetail(key, view) {
    var r = current.rows[key];
    if (!r) {
      view.title("Report");
      view.body(current.loaded
        ? stateBox("Not in this list", "It may have been handled already. Try the All tab.")
        : stateBox("Loading", null));
      return;
    }
    var isUser = r.kind === "user";
    var target = isUser ? r.target_user : r.target_activity;
    view.title(isUser ? "Report on " + personName(target) : "Report on " + target.title);
    view.sub((isUser ? "User report" : "Activity report") + " · " + fmtDateTime(r.created_at));
    view.badge(pill(r.status));

    var isOpen = r.status === "open" || r.status === "reviewing";
    var buttons = [];
    if (isOpen) {
      if (r.status === "open") {
        var claim = h("button", { class: "btn" }, "Start review");
        claim.addEventListener("click", function () {
          runAction(claim, "Saving", async function () {
            var res = await rpc("admin_start_review", { p_kind: r.kind, p_report_id: r.id });
            toast(res.result === "reviewing" ? "Marked as in review" : "Someone else already picked this up");
            view.refresh();
          });
        });
        buttons.push(claim);
      }

      var dismiss = h("button", { class: "btn" }, "Dismiss");
      dismiss.addEventListener("click", async function () {
        var answer = await confirmDialog({
          title: "Dismiss this report?",
          body: "Nothing happens to the reported " + (isUser ? "user" : "activity") + ".",
          confirm: "Dismiss",
          note: { label: "Note (optional)", placeholder: "Why it's fine" },
        });
        if (!answer.ok) return;
        review(dismiss, "dismiss", answer.note);
      });
      buttons.push(dismiss);

      if (isUser ? target && !target.suspended : !target.deleted) {
        var remove = h("button", { class: "btn danger" }, isUser ? "Suspend user" : "Delete activity");
        remove.addEventListener("click", async function () {
          var answer = await confirmDialog(isUser ? {
            title: "Suspend " + personName(target) + "?",
            body: "They're signed out and can't sign in. Their profile and activities are hidden from everyone. Nothing is deleted, and you can restore the account later. Other open reports on them are closed too.",
            confirm: "Suspend",
            danger: true,
            note: { label: "Reason", required: true, placeholder: "What they did" },
          } : {
            title: "Delete " + target.title + "?",
            body: "Participants get the usual \"activity deleted\" notification. The activity, its chat and its join list are removed for good. Other open reports on it are closed too.",
            confirm: "Delete activity",
            danger: true,
            note: { label: "Reason", required: true, placeholder: "What was wrong with it" },
          });
          if (!answer.ok) return;
          review(remove, "remove", answer.note);
        });
        buttons.push(remove);
      } else {
        // Already suspended or deleted elsewhere: closing it is enough.
        var close = h("button", { class: "btn" }, "Mark as resolved");
        close.addEventListener("click", function () { review(close, "remove", isUser ? "Already suspended" : "Already deleted"); });
        buttons.push(close);
      }
    }

    function review(button, decision, note) {
      runAction(button, "Saving", async function () {
        var res = await rpc("admin_review_report", {
          p_kind: r.kind, p_report_id: r.id, p_decision: decision, p_note: note || null,
        });
        if (res.result === "already_closed") {
          toast("Already handled by " + personName(res.reviewed_by) + " on " + fmtDate(res.reviewed_at), "error");
        } else if (res.result === "not_found") {
          toast("This report no longer exists", "error");
        } else {
          toast(decision === "dismiss" ? "Report dismissed" : TAKEN[res.action] || "Done");
        }
        closeDrawer();
        if (current.reload) current.reload();
        refreshCounts();
      });
    }

    var targetInfo = isUser
      ? kv([["User", personLink(target)], ["Open reports on them", num(r.open_on_target)]])
      : kv([
        ["Activity", target.deleted ? [target.title, " ", pill("removed", "Deleted")] : h("a", { href: "#/activities?id=" + target.id }, target.title)],
        ["Starts", fmtDateTime(target.starts_at)],
        ["Host", personLink(r.target_user)],
        ["Open reports on it", target.deleted ? null : num(r.open_on_target)],
      ]);

    view.body([
      section("Reported", targetInfo),
      section("Report", [
        kv([
          ["Reason", REASONS[r.reason] || r.reason],
          ["Reporter", personLink(r.reporter)],
          ["Received", fmtDateTime(r.created_at)],
        ]),
        r.details ? h("div", { class: "message", style: "margin-top:10px" }, r.details) : null,
      ]),
      r.status !== "open" ? section("Review", kv([
        ["Status", pill(r.status)],
        ["By", r.reviewed_by ? personName(r.reviewed_by) : null],
        ["On", fmtDateTime(r.reviewed_at)],
        ["Action", r.action_taken ? TAKEN[r.action_taken] || r.action_taken : null],
        ["Note", r.admin_note],
      ])) : null,
      buttons.length ? h("div", { class: "actions" }, buttons) : null,
    ]);
  }

  // ---- Users ------------------------------------------------------------------------

  function renderUsers(params) {
    var filter = params.filter || "all";
    listPage({
      title: "Users",
      filters: [
        tabs("filter", [
          { value: "all", label: "All" },
          { value: "reported", label: "Reported" },
          { value: "suspended", label: "Suspended" },
        ], filter),
        searchBox(params.q, "Search name, username or email"),
      ],
      sort: { key: "joined", dir: "desc" },
      fetch: function (offset, sort) {
        return rpc("admin_list_users", {
          p_search: params.q || null, p_filter: filter, p_limit: PAGE_SIZE, p_offset: offset,
          p_sort: sort.key, p_dir: sort.dir,
        });
      },
      rowKey: function (row) { return row.id; },
      emptyText: params.q ? "No users match \"" + params.q + "\"" : "No users here",
      columns: [
        { label: "Name", sort: "name", first: "asc", render: function (r) {
          return withMedia(avatar(r, 28),
            [h("div", null, r.full_name || "No name"), r.username ? h("div", { class: "sub" }, "@" + r.username) : null]);
        } },
        { label: "Email", cls: "hide-sm", sort: "email", first: "asc", render: function (r) { return r.email; } },
        { label: "Signed up", cls: "nowrap", sort: "joined", render: function (r) { return fmtDate(r.created_at); } },
        { label: "Last sign-in", cls: "nowrap hide-sm", sort: "last_sign_in", render: function (r) { return fmtDate(r.last_sign_in_at); } },
        { label: "Hosted", cls: "center", sort: "hosted", render: function (r) { return num(r.hosted_count); } },
        { label: "Joined", cls: "center hide-sm", sort: "joins", render: function (r) { return num(r.joined_count); } },
        { label: "Status", cls: "status-col", sort: "status", render: function (r) {
          if (r.suspended_at) return pill("suspended", "Suspended");
          if (r.open_reports) return pill("open", r.open_reports + (r.open_reports === 1 ? " report" : " reports"));
          return pill("active", "Active");
        } },
      ],
    });
  }

  async function userDetail(id, view) {
    var d = await rpc("admin_get_user", { p_user_id: id });
    if (view.stale()) return;
    var p = d.profile;
    view.media(p.avatar_url
      ? h("a", { href: p.avatar_url, target: "_blank", rel: "noopener" }, avatar(p, 40))
      : avatar(p, 40));
    view.title(p.full_name || "No name");
    view.sub([p.username ? "@" + p.username + " · " : "", p.email]);
    view.badge(d.suspension ? pill("suspended", "Suspended") : d.is_admin ? pill("ok", "Admin") : null);

    var actions = null;
    if (!d.is_admin && p.id !== me.id) {
      if (d.suspension) {
        var restore = h("button", { class: "btn" }, "Restore account");
        restore.addEventListener("click", async function () {
          var answer = await confirmDialog({
            title: "Restore " + (p.full_name || "this account") + "?",
            body: "They can sign in again, and their profile and activities show again.",
            confirm: "Restore",
          });
          if (!answer.ok) return;
          runAction(restore, "Saving", async function () {
            await rpc("admin_restore_user", { p_user_id: id });
            toast("Account restored");
            view.refresh();
          });
        });
        actions = restore;
      } else {
        var suspend = h("button", { class: "btn danger" }, "Suspend account");
        suspend.addEventListener("click", async function () {
          var answer = await confirmDialog({
            title: "Suspend " + (p.full_name || "this account") + "?",
            body: "They're signed out and can't sign in. Their profile and activities are hidden from everyone, and nobody can join their activities. Nothing is deleted, and you can restore the account later.",
            confirm: "Suspend",
            danger: true,
            note: { label: "Reason", required: true, placeholder: "What they did" },
          });
          if (!answer.ok) return;
          runAction(suspend, "Saving", async function () {
            var res = await rpc("admin_suspend_user", { p_user_id: id, p_reason: answer.note });
            toast(res.result === "suspended" ? "Account suspended" : "Already suspended");
            view.refresh();
          });
        });
        actions = suspend;
      }
    }

    view.body([
      d.suspension ? h("div", { class: "notice" },
        "Suspended " + fmtDateTime(d.suspension.suspended_at) +
        (d.suspension.suspended_by ? " by " + personName(d.suspension.suspended_by) : "") +
        ": " + d.suspension.reason) : null,
      section("Profile", kv([
        ["Email", p.email],
        ["Gender", p.gender],
        ["Age", p.age],
        ["Signed up", fmtDateTime(p.created_at)],
        ["Email confirmed", d.auth.email_confirmed_at ? fmtDate(d.auth.email_confirmed_at) : "No"],
        ["Last sign-in", fmtDateTime(d.auth.last_sign_in_at)],
        ["Rating", p.rating_count ? p.rating + " from " + p.rating_count : null],
        ["Interests", p.interests && p.interests.length ? p.interests.join(", ") : null],
        ["Reports made", d.reports_made ? num(d.reports_made) : null],
        ["User ID", h("span", { class: "sub" }, p.id)],
      ])),
      actions ? h("div", { class: "section actions" }, actions) : null,
      foldSection("Reports about them (" + d.reports_against.length + ")", list(d.reports_against, "None.", function (r) {
        return [
          h("div", { class: "grow" },
            h("div", null, REASONS[r.reason] || r.reason, h("span", { class: "sub" }, " by " + personName(r.reporter))),
            r.details ? h("div", { class: "sub clip" }, r.details) : null),
          h("div", { class: "nowrap" }, pill(r.status)),
        ];
      })),
      foldSection("Hosted (" + d.hosted.length + ")", list(d.hosted, "No activities.", function (a) {
        return [
          h("a", { class: "grow clip", href: "#/activities?id=" + a.id }, a.title),
          h("span", { class: "sub nowrap" }, fmtDate(a.starts_at)),
        ];
      })),
      foldSection("Joined (" + d.joined.length + ")", list(d.joined, "None.", function (a) {
        return [
          h("a", { class: "grow clip", href: "#/activities?id=" + a.id }, a.title),
          h("span", { class: "sub nowrap" }, fmtDate(a.starts_at), " ", pill(a.status)),
        ];
      })),
      foldSection("Support tickets (" + d.tickets.length + ")", list(d.tickets, "None.", function (t) {
        return [
          h("a", { class: "grow clip", href: "#/support?status=all&id=" + t.id }, t.message),
          h("span", { class: "sub nowrap" }, fmtDate(t.created_at), " ", pill(t.status)),
        ];
      })),
    ]);
  }

  // ---- Activities -------------------------------------------------------------------

  function renderActivities(params) {
    var filter = params.filter || "all";
    var visibility = params.visibility || "all";
    listPage({
      title: "Activities",
      filters: [
        tabs("filter", [
          { value: "all", label: "All" },
          { value: "upcoming", label: "Upcoming" },
          { value: "past", label: "Past" },
          { value: "reported", label: "Reported" },
        ], filter),
        tabs("visibility", [
          { value: "all", label: "Any visibility" },
          { value: "public", label: "Public" },
          { value: "private", label: "Private" },
        ], visibility),
        searchBox(params.q, "Search title, place, host or code"),
      ],
      sort: { key: "starts", dir: "desc" },
      fetch: function (offset, sort) {
        return rpc("admin_list_activities", {
          p_search: params.q || null, p_filter: filter, p_limit: PAGE_SIZE, p_offset: offset,
          p_sort: sort.key, p_dir: sort.dir, p_visibility: visibility,
        });
      },
      rowKey: function (row) { return row.id; },
      emptyText: params.q ? "No activities match \"" + params.q + "\"" : "No activities here",
      columns: [
        { label: "Title", sort: "title", first: "asc", render: function (r) {
          return withMedia(thumb(r.photo_url, 32),
            [h("div", { class: "clip" }, r.title), r.category_label ? h("div", { class: "sub" }, r.category_label) : null]);
        } },
        { label: "Host", sort: "host", first: "asc", render: function (r) { return personName(r.host); } },
        { label: "Starts", cls: "nowrap", sort: "starts", render: function (r) { return fmtDateTime(r.starts_at); } },
        { label: "Place", cls: "hide-sm", sort: "place", first: "asc", render: function (r) { return h("div", { class: "clip" }, r.location_name || ""); } },
        { label: "People", cls: "num", sort: "people", render: function (r) { return num(r.participants_count) + (r.max_participants ? " / " + num(r.max_participants) : ""); } },
        { label: "Visibility", cls: "hide-sm", sort: "visibility", render: function (r) { return r.is_public ? "Public" : "Private"; } },
        { label: "Reports", sort: "reports", render: function (r) { return r.open_reports ? pill("open", String(r.open_reports)) : ""; } },
      ],
    });
  }

  async function activityDetail(id, view) {
    var d = await rpc("admin_get_activity", { p_activity_id: id });
    if (view.stale()) return;
    var a = d.activity;
    view.media(a.photo_url
      ? h("a", { href: a.photo_url, target: "_blank", rel: "noopener" }, thumb(a.photo_url, 48))
      : thumb(null, 48));
    view.title(a.title);
    view.sub([a.category_label || "", a.category_label ? " · " : "", a.is_public ? "Public" : "Private"]);
    view.badge(new Date(a.starts_at) < new Date() ? pill("closed", "Past") : pill("ok", "Upcoming"));

    var joined = d.participants.filter(function (p) { return p.status === "joined"; }).length + 1;

    var del = h("button", { class: "btn danger" }, "Delete activity");
    del.addEventListener("click", async function () {
      var answer = await confirmDialog({
        title: "Delete " + a.title + "?",
        body: "Participants get the usual \"activity deleted\" notification. The activity, its chat and its join list are removed for good. Reports on it are kept.",
        confirm: "Delete activity",
        danger: true,
        note: { label: "Reason", required: true, placeholder: "What was wrong with it" },
      });
      if (!answer.ok) return;
      runAction(del, "Deleting", async function () {
        var res = await rpc("admin_delete_activity", { p_activity_id: id, p_reason: answer.note });
        toast(res.result === "deleted" ? "Activity deleted" : "It was already deleted");
        closeDrawer();
        if (current.reload) current.reload();
        refreshCounts();
      });
    });

    view.body([
      section("Details", kv([
        ["Starts", fmtDateTime(a.starts_at)],
        ["Ends", fmtDateTime(a.ends_at)],
        ["Place", [a.location_name || "", a.location_address ? h("div", { class: "sub" }, a.location_address) : null]],
        ["Host", personLink(d.host)],
        ["People", num(joined) + (a.max_participants ? " of " + num(a.max_participants) : "")],
        ["Code", a.activity_code],
        ["Created", fmtDateTime(a.created_at)],
        ["Activity ID", h("span", { class: "sub" }, a.id)],
      ])),
      a.description ? section("Description", h("div", { class: "message" }, a.description)) : null,
      section("Participants (" + d.participants.length + ")", list(d.participants, "Nobody else yet.", function (p) {
        return [h("div", { class: "grow" }, personLink(p)), h("span", { class: "sub nowrap" }, fmtDate(p.joined_at), " ", pill(p.status))];
      })),
      section("Reports (" + d.reports.length + ")", list(d.reports, "None.", function (r) {
        return [
          h("div", { class: "grow" },
            h("div", null, REASONS[r.reason] || r.reason, h("span", { class: "sub" }, " by " + personName(r.reporter))),
            r.details ? h("div", { class: "sub clip" }, r.details) : null),
          h("div", { class: "nowrap" }, pill(r.status)),
        ];
      })),
      h("div", { class: "actions" }, del),
    ]);
  }

  // ---- Audit log --------------------------------------------------------------------

  function auditTarget(row) {
    var id = row.target_id;
    var d = row.details || {};
    if (!id) return "";
    if (row.target_type === "user") return h("a", { href: "#/users?id=" + id }, "User");
    if (row.target_type === "activity") {
      return row.action === "activity.delete" ? d.title || "Activity" : h("a", { href: "#/activities?id=" + id }, "Activity");
    }
    if (row.target_type === "ticket") return h("a", { href: "#/support?status=all&id=" + id }, "Ticket");
    if (row.target_type === "user_report" || row.target_type === "activity_report") {
      var kind = row.target_type === "user_report" ? "user" : "activity";
      return h("a", { href: "#/reports?status=all&kind=" + kind + "&id=" + kind + ":" + id }, "Report");
    }
    return row.target_type;
  }

  function renderAudit(params) {
    var kind = params.kind || "all";
    var filtered = kind !== "all" || params.q;
    listPage({
      title: "Audit log",
      filters: [
        tabs("kind", [
          { value: "all", label: "All" },
          { value: "user", label: "Users" },
          { value: "activity", label: "Activities" },
          { value: "report", label: "Reports" },
          { value: "support", label: "Support" },
          { value: "admin", label: "Admins" },
        ], kind),
        searchBox(params.q, "Search admin, reason or ID"),
      ],
      sort: { key: "when", dir: "desc" },
      fetch: function (offset, sort) {
        return rpc("admin_audit_log", {
          p_limit: PAGE_SIZE, p_offset: offset, p_kind: kind, p_search: params.q || null,
          p_sort: sort.key, p_dir: sort.dir,
        });
      },
      rowKey: function (row) { return String(row.id); },
      emptyText: filtered ? "No admin actions match" : "No admin actions yet",
      columns: [
        { label: "When", cls: "nowrap", sort: "when", render: function (r) { return fmtDateTime(r.created_at); } },
        { label: "Admin", sort: "admin", first: "asc", render: function (r) { return r.admin ? personName(r.admin) : "Email reply link"; } },
        { label: "Action", sort: "action", first: "asc", render: function (r) { return ACTIONS[r.action] || r.action; } },
        { label: "Target", sort: "target", first: "asc", render: auditTarget },
        { label: "Details", render: function (r) {
          var d = r.details || {};
          var text = d.reason || d.note || (d.action ? TAKEN[d.action] : "") || (d.via === "email_link" ? "From the email link" : "");
          return h("div", { class: "clip sub" }, text || "");
        } },
      ],
    });
  }

  // ---- Admins -----------------------------------------------------------------------

  function renderAdmins() {
    var page = clear(shell.page);
    var add = h("button", { class: "btn small primary" }, "Add admin");
    page.appendChild(h("div", { class: "page-head" }, h("h1", null, "Admins"), add));
    var body = h("div");
    page.appendChild(body);

    add.addEventListener("click", async function () {
      var answer = await confirmDialog({
        title: "Add an admin",
        body: "They need a Synk account. They'll see all users, tickets and reports, and can suspend accounts and delete activities.",
        note: { type: "email", label: "Their account email", required: true, missing: "Add an email first." },
        confirm: "Add",
      });
      if (!answer.ok) return;
      runAction(add, "Adding", async function () {
        var res = await rpc("admin_add_admin", { p_email: answer.note });
        if (res.result === "not_found") throw new Error("No Synk account uses that email.");
        toast(res.result === "added" ? "Admin added" : "Already an admin");
        load();
        refreshCounts();
      });
    });

    async function load() {
      clear(body).appendChild(stateBox("Loading"));
      var d;
      try {
        d = await rpc("admin_list_admins");
      } catch (e) {
        clear(body).appendChild(stateBox("Couldn't load admins", e.message, load));
        return;
      }
      clear(body);

      body.appendChild(h("h2", { class: "block-title" }, "Access requests", h("span", { class: "sub" }, " " + d.requests.length)));
      body.appendChild(h("div", { class: "table-wrap block" }, d.requests.length
        ? h("table", null,
          h("thead", null, h("tr", null, ["Name", "Note", "Requested", ""].map(function (t) { return h("th", null, t); }))),
          h("tbody", null, d.requests.map(function (r) {
            var approve = h("button", { class: "btn small primary" }, "Approve");
            var decline = h("button", { class: "btn small" }, "Decline");
            approve.addEventListener("click", async function () {
              var answer = await confirmDialog({
                title: "Make " + personName(r) + " an admin?",
                body: "They'll see all users, tickets and reports, and can suspend accounts and delete activities.",
                confirm: "Approve",
              });
              if (!answer.ok) return;
              runAction(approve, "Saving", async function () {
                await rpc("admin_review_access_request", { p_user_id: r.id, p_approve: true });
                toast(personName(r) + " is now an admin");
                load();
                refreshCounts();
              });
            });
            decline.addEventListener("click", async function () {
              var answer = await confirmDialog({ title: "Decline this request?", confirm: "Decline", danger: true });
              if (!answer.ok) return;
              runAction(decline, "Saving", async function () {
                await rpc("admin_review_access_request", { p_user_id: r.id, p_approve: false });
                toast("Request declined");
                load();
                refreshCounts();
              });
            });
            return h("tr", null,
              h("td", null, h("div", null, personLink(r)), h("div", { class: "sub" }, r.email)),
              h("td", null, r.note ? h("div", { class: "clip" }, r.note) : h("span", { class: "sub" }, "No note")),
              h("td", { class: "nowrap" }, fmtDateTime(r.created_at)),
              h("td", { class: "nowrap right" }, h("div", { class: "actions end" }, decline, approve)));
          })))
        : stateBox("No requests waiting")));

      body.appendChild(h("h2", { class: "block-title" }, "Admins", h("span", { class: "sub" }, " " + d.admins.length)));
      body.appendChild(h("div", { class: "table-wrap block" }, h("table", null,
        h("thead", null, h("tr", null, ["Name", "Email", "Added", "Added by", ""].map(function (t, i) {
          return h("th", { class: i === 1 || i === 3 ? "hide-sm" : "" }, t);
        }))),
        h("tbody", null, d.admins.map(function (a) {
          var self = a.id === me.id;
          var remove = null;
          if (!self) {
            remove = h("button", { class: "btn small danger" }, "Remove");
            remove.addEventListener("click", async function () {
              var answer = await confirmDialog({
                title: "Remove " + personName(a) + " as admin?",
                body: "Their Synk account stays as it is. They just lose access to this dashboard.",
                confirm: "Remove",
                danger: true,
              });
              if (!answer.ok) return;
              runAction(remove, "Removing", async function () {
                await rpc("admin_remove_admin", { p_user_id: a.id });
                toast(personName(a) + " is no longer an admin");
                load();
              });
            });
          }
          return h("tr", null,
            h("td", null, personLink(a), self ? h("span", { class: "sub" }, " (you)") : null),
            h("td", { class: "hide-sm" }, a.email),
            h("td", { class: "nowrap" }, fmtDate(a.added_at)),
            h("td", { class: "hide-sm" }, a.added_by ? personName(a.added_by) : h("span", { class: "sub" }, "SQL editor")),
            h("td", { class: "right" }, remove));
        })))));
    }

    current.reload = load;
    load();
  }

  var PAGES = {
    overview: renderOverview,
    support: renderSupport,
    reports: renderReports,
    users: renderUsers,
    activities: renderActivities,
    audit: renderAudit,
    admins: renderAdmins,
  };

  var DETAILS = {
    support: ticketDetail,
    reports: reportDetail,
    users: userDetail,
    activities: activityDetail,
  };

  // ---- Start ------------------------------------------------------------------------

  sb.auth.getSession().then(function (result) {
    var session = result.data.session;
    if (session) enter(session);
    else renderSignIn();
  });
})();
