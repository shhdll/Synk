// Saves a support message and emails it to the team through Resend.
// The email's reply-to is the user, so the team can answer straight away.
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

const DAILY_LIMIT = 5;
const CATEGORIES = ["problem", "feedback", "other"];

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

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!admin || !RESEND_API_KEY || !SUPPORT_INBOX_EMAIL) {
    console.error("submit-support is missing server configuration.");
    return jsonResponse({ error: "server_misconfigured" }, 500);
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
  try {
    const body = await request.json();
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
  if (message.length < 10 || message.length > 2000) {
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
    })
    .select("id")
    .single();
  if (insertError || !ticket) {
    console.error("Could not save support ticket:", insertError?.message);
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
      reply_to: user.email,
      subject: `[${category}] ${name} (#${shortId})`,
      text: `${message}\n\n---\nFrom: ${name} <${user.email}>\nUser ID: ${user.id}\nApp: ${appVersion ?? "unknown"}\nTicket: ${ticket.id}`,
      html: `<p style="white-space:pre-wrap">${escapeHtml(message)}</p>
<hr>
<p style="color:#6B7280;font-size:13px">
From: ${escapeHtml(name)} &lt;${escapeHtml(user.email)}&gt;<br>
User ID: ${user.id}<br>
App: ${escapeHtml(appVersion ?? "unknown")}<br>
Ticket: ${ticket.id}
</p>`,
    }),
  }).catch(() => null);

  if (!response?.ok) {
    // The ticket is saved, so the team can still find it in the dashboard.
    console.error("Resend failed:", response?.status);
  }

  return jsonResponse({ ok: true, ticket_id: ticket.id });
});
