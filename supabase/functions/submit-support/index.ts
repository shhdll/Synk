// Saves a support message and emails it to the team through Resend.
// The email's reply-to is the user, so the team can answer straight away.
//
// A suspended user can't sign in, so the login screen sends
// { action: "appeal", email, message } without a token. It's only saved when
// the email belongs to a suspended account, and the answer is the same
// either way so it doesn't tell anyone who is suspended.
//
// Secrets: RESEND_API_KEY, SUPPORT_INBOX_EMAIL, SUPPORT_FROM_EMAIL.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEYS = Deno.env.get("SUPABASE_SECRET_KEYS");
const SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SECRET_KEYS
  ? (JSON.parse(SUPABASE_SECRET_KEYS) as Record<string, string>).default
  : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPPORT_INBOX_EMAIL = Deno.env.get("SUPPORT_INBOX_EMAIL");
const SUPPORT_FROM_EMAIL = Deno.env.get("SUPPORT_FROM_EMAIL") ??
  "Synk Support <onboarding@resend.dev>";

const SUPPORT_REPLY_URL = Deno.env.get("SUPPORT_REPLY_URL") ??
  "https://synk.cc/support-reply.html";

const LOGO_URL = "https://synk.cc/logo.png";
const DAILY_LIMIT = 5;
const APPEAL_DAILY_LIMIT = 2;
const CATEGORIES = ["problem", "feedback", "other"];
const SCREENSHOT_BUCKET = "support-screenshots";
const MAX_SCREENSHOTS = 3;
// Links in the email work for 30 days.
const SCREENSHOT_LINK_SECONDS = 60 * 60 * 24 * 30;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const admin = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  : null;

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

const CATEGORY_LABELS: Record<string, { label: string; color: string; tint: string }> = {
  problem: { label: "Bug", color: "#CA602F", tint: "#FCE3D4" },
  feedback: { label: "Idea", color: "#2A6F65", tint: "#DCEFEC" },
  other: { label: "Other", color: "#5F6672", tint: "#ECEDEF" },
  appeal: { label: "Appeal", color: "#B42318", tint: "#FDECEA" },
};

// Email-safe layout: tables and inline styles only.
function supportEmailHtml(ticket: {
  category: string;
  name: string;
  email: string;
  userId: string;
  appVersion: string | null;
  ticketId: string;
  shortId: string;
  replyToken: string;
  message: string;
  screenshots: string[];
}): string {
  const tag = CATEGORY_LABELS[ticket.category] ?? CATEGORY_LABELS.other;
  const name = escapeHtml(ticket.name);
  const email = escapeHtml(ticket.email);
  const replyLink = `${SUPPORT_REPLY_URL}?ticket=${ticket.ticketId}&token=${ticket.replyToken}`;
  const row = (label: string, value: string) =>
    `<tr>
      <td style="padding:6px 0;color:#6B7280;font-size:13px;width:90px;vertical-align:top">${label}</td>
      <td style="padding:6px 0;color:#1E1C24;font-size:13px">${value}</td>
    </tr>`;

  return `<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F6F1E6">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F6F1E6;padding:32px 12px">
  <tr><td align="center">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
      <tr><td style="padding:0 4px 16px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td style="vertical-align:middle;padding-right:10px"><img src="${LOGO_URL}" alt="Synk" width="36" height="36" style="display:block;width:36px;height:36px"></td>
          <td style="vertical-align:middle;font-size:22px;font-weight:800;letter-spacing:-0.5px;color:#2D2A32">Synk</td>
        </tr></table>
      </td></tr>
      <tr><td style="background:#FFFFFF;border-radius:20px;padding:28px">
        <span style="display:inline-block;padding:4px 12px;border-radius:999px;background:${tag.tint};color:${tag.color};font-size:12px;font-weight:700">${tag.label}</span>
        <h1 style="margin:14px 0 4px;font-size:20px;line-height:1.3;color:#1E1C24">New message from ${name}</h1>
        <p style="margin:0 0 20px;font-size:14px;color:#6B7280">${email}</p>
        <div style="background:#FFF5EF;border-left:4px solid #FF7A36;border-radius:12px;padding:16px 18px;font-size:15px;line-height:1.55;color:#1E1C24;white-space:pre-wrap">${escapeHtml(ticket.message)}</div>
        ${screenshotsHtml(ticket.screenshots)}
        <table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px 0 0">
          <tr><td style="border-radius:12px;background:#FF7A36">
            <a href="${replyLink}" style="display:inline-block;padding:12px 22px;font-size:14px;font-weight:700;color:#FFFFFF;text-decoration:none">Reply to ${name}</a>
          </td></tr>
        </table>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:24px;border-top:1px solid #EFE8DA;padding-top:12px">
          ${row("User ID", escapeHtml(ticket.userId))}
          ${row("App", escapeHtml(ticket.appVersion ?? "unknown"))}
          ${row("Ticket", escapeHtml(ticket.ticketId))}
        </table>
      </td></tr>
      <tr><td style="padding:16px 4px 0;font-size:12px;color:#6B7280">Sent from Settings › Contact support. The button sends a styled reply that quotes their message. Replying to this email also reaches the user.</td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

// Small linked thumbnails, one per screenshot.
function screenshotsHtml(links: string[]): string {
  if (links.length === 0) return "";
  const cells = links.map((link) =>
    `<td style="padding:0 8px 0 0"><a href="${escapeHtml(link)}"><img src="${escapeHtml(link)}" width="120" alt="Screenshot" style="display:block;width:120px;border-radius:10px;border:1px solid #EFE8DA"></a></td>`
  ).join("");
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:16px 0 0"><tr>${cells}</tr></table>`;
}

async function handleAppeal(body: Record<string, unknown>): Promise<Response> {
  const email = typeof body.email === "string" ? body.email.trim() : "";
  const message = typeof body.message === "string" ? body.message.trim() : "";
  const appVersion = typeof body.app_version === "string"
    ? body.app_version.slice(0, 40)
    : null;
  if (email.length > 254 || !EMAIL_PATTERN.test(email)) {
    return jsonResponse({ error: "invalid_email" }, 400);
  }
  if (message.length < 1 || message.length > 2000) {
    return jsonResponse({ error: "invalid_message" }, 400);
  }

  const { data: userId } = await admin!.rpc("suspended_user_for_email", {
    p_email: email,
  });
  if (typeof userId !== "string") {
    return jsonResponse({ ok: true });
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count } = await admin!.from("support_tickets")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("category", "appeal")
    .gte("created_at", since);
  if ((count ?? 0) >= APPEAL_DAILY_LIMIT) {
    return jsonResponse({ ok: true });
  }

  const { data: profile } = await admin!.from("users")
    .select("full_name, username, email")
    .eq("id", userId)
    .maybeSingle();
  // Replies go to the account's own email, not whatever was typed.
  const accountEmail = (profile?.email as string | undefined) ?? email;
  const name = profile?.full_name?.trim() || profile?.username?.trim() ||
    accountEmail;

  const { data: ticket, error: insertError } = await admin!
    .from("support_tickets")
    .insert({
      user_id: userId,
      email: accountEmail,
      category: "appeal",
      message,
      app_version: appVersion,
      screenshot_paths: [],
    })
    .select("id, reply_token")
    .single();
  if (insertError || !ticket) {
    console.error("Could not save appeal:", insertError?.message);
    return jsonResponse({ error: "save_failed" }, 500);
  }

  const shortId = (ticket.id as string).slice(0, 8);
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: SUPPORT_FROM_EMAIL,
      to: [SUPPORT_INBOX_EMAIL],
      reply_to: accountEmail,
      subject: `[Appeal] ${name} (#${shortId})`,
      text: `${message}\n\n---\nFrom: ${name} <${accountEmail}>\nUser ID: ${userId}\nApp: ${appVersion ?? "unknown"}\nTicket: ${ticket.id}`,
      html: supportEmailHtml({
        category: "appeal",
        name,
        email: accountEmail,
        userId,
        appVersion,
        ticketId: ticket.id as string,
        shortId,
        replyToken: ticket.reply_token as string,
        message,
        screenshots: [],
      }),
    }),
  }).catch(() => null);
  if (!response?.ok) {
    console.error("Resend failed:", response?.status);
  }

  return jsonResponse({ ok: true });
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!admin || !RESEND_API_KEY || !SUPPORT_INBOX_EMAIL) {
    console.error("submit-support is missing server configuration.");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const peek = await request.clone().json().catch(() => null);
  if (peek?.action === "appeal") {
    return await handleAppeal(peek);
  }

  const jwt = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const { data: auth } = jwt
    ? await admin.auth.getUser(jwt)
    : { data: { user: null } };
  const user = auth.user;
  if (!user?.email) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let category: string;
  let message: string;
  let appVersion: string | null;
  let screenshotPaths: string[];
  let replyTo: string;
  try {
    const body = await request.json();
    // Only files in the user's own folder.
    screenshotPaths = Array.isArray(body.screenshots)
      ? body.screenshots
        .filter((path: unknown): path is string =>
          typeof path === "string" && path.startsWith(`${user.id}/`) &&
          !path.includes("..")
        )
        .slice(0, MAX_SCREENSHOTS)
      : [];
    const wanted = typeof body.reply_to === "string"
      ? body.reply_to.trim()
      : "";
    replyTo = wanted.length <= 254 && EMAIL_PATTERN.test(wanted)
      ? wanted
      : user.email;
    category = typeof body.category === "string" ? body.category : "";
    message = typeof body.message === "string" ? body.message.trim() : "";
    appVersion = typeof body.app_version === "string"
      ? body.app_version.slice(0, 40)
      : null;
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!CATEGORIES.includes(category)) {
    return jsonResponse({ error: "invalid_category" }, 400);
  }
  if (message.length < 1 || message.length > 2000) {
    return jsonResponse({ error: "invalid_message" }, 400);
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count } = await admin.from("support_tickets")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .gte("created_at", since);
  if ((count ?? 0) >= DAILY_LIMIT) {
    return jsonResponse({ error: "rate_limited" }, 429);
  }

  const { data: profile } = await admin.from("users")
    .select("full_name, username")
    .eq("id", user.id)
    .maybeSingle();
  const name = profile?.full_name?.trim() || profile?.username?.trim() ||
    user.email;

  const { data: ticket, error: insertError } = await admin
    .from("support_tickets")
    .insert({
      user_id: user.id,
      email: user.email,
      category,
      message,
      app_version: appVersion,
      screenshot_paths: screenshotPaths,
      reply_to: replyTo === user.email ? null : replyTo,
    })
    .select("id, reply_token")
    .single();
  if (insertError || !ticket) {
    console.error("Could not save support ticket:", insertError?.message);
    return jsonResponse({ error: "save_failed" }, 500);
  }

  let screenshotLinks: string[] = [];
  if (screenshotPaths.length > 0) {
    const { data: signed } = await admin.storage.from(SCREENSHOT_BUCKET)
      .createSignedUrls(screenshotPaths, SCREENSHOT_LINK_SECONDS);
    screenshotLinks = (signed ?? [])
      .map((item) => item.signedUrl)
      .filter((link): link is string => !!link);
  }

  const shortId = (ticket.id as string).slice(0, 8);
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: SUPPORT_FROM_EMAIL,
      to: [SUPPORT_INBOX_EMAIL],
      reply_to: replyTo,
      subject: `[${(CATEGORY_LABELS[category] ?? CATEGORY_LABELS.other).label}] ${name} (#${shortId})`,
      text: `${message}\n\n${screenshotLinks.map((link, i) => `Screenshot ${i + 1}: ${link}\n`).join("")}---\nFrom: ${name} <${replyTo}>\nUser ID: ${user.id}\nApp: ${appVersion ?? "unknown"}\nTicket: ${ticket.id}`,
      html: supportEmailHtml({
        category,
        name,
        email: replyTo,
        userId: user.id,
        appVersion,
        ticketId: ticket.id as string,
        shortId,
        replyToken: ticket.reply_token as string,
        message,
        screenshots: screenshotLinks,
      }),
    }),
  }).catch(() => null);

  if (!response?.ok) {
    // The ticket is saved, so the team can still find it in the dashboard.
    console.error("Resend failed:", response?.status);
  }

  return jsonResponse({ ok: true, ticket_id: ticket.id });
});
