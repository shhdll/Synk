// Backs "Request access" on synk.cc/admin: saves the request with the
// caller's own token, then emails the team. A request that was already
// pending isn't emailed again.
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

const ADMINS_URL = "https://synk.cc/admin/#/admins";
const LOGO_URL = "https://synk.cc/logo.png";

const admin = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  : null;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function requestEmailHtml(name: string, email: string, note: string | null): string {
  const noteHtml = note
    ? `<div style="background:#FFF5EF;border-left:4px solid #FF7A36;border-radius:12px;padding:16px 18px;font-size:15px;line-height:1.55;color:#1E1C24;white-space:pre-wrap">${escapeHtml(note)}</div>`
    : `<p style="margin:0;font-size:14px;color:#6B7280">No note.</p>`;
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
        <h1 style="margin:0 0 4px;font-size:20px;line-height:1.3;color:#1E1C24">${escapeHtml(name)} wants admin access</h1>
        <p style="margin:0 0 20px;font-size:14px;color:#6B7280">${escapeHtml(email)}</p>
        ${noteHtml}
        <table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px 0 0">
          <tr><td style="border-radius:12px;background:#FF7A36">
            <a href="${ADMINS_URL}" style="display:inline-block;padding:12px 22px;font-size:14px;font-weight:700;color:#FFFFFF;text-decoration:none">Review request</a>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!admin || !RESEND_API_KEY || !SUPPORT_INBOX_EMAIL) {
    console.error("request-admin is missing server configuration.");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const jwt = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const apikey = request.headers.get("apikey") ?? "";
  if (!jwt || !apikey || jwt === apikey) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  const { data: auth } = await admin.auth.getUser(jwt);
  const user = auth?.user;
  if (!user?.email) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const body = await request.json().catch(() => ({}));
  const note = typeof body.note === "string" && body.note.trim()
    ? body.note.trim().slice(0, 500)
    : null;

  // As the caller, so auth.uid() is them.
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/request_admin_access`, {
    method: "POST",
    headers: {
      apikey,
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ p_note: note }),
  }).catch(() => null);
  if (!response?.ok) {
    const detail = await response?.json().catch(() => null);
    return jsonResponse({ error: detail?.message ?? "request_failed" }, 400);
  }
  const result = (await response.json())?.result as string | undefined;
  if (result !== "requested") {
    return jsonResponse({ result: result ?? "unknown" });
  }

  const { data: profile } = await admin.from("users")
    .select("full_name, username")
    .eq("id", user.id)
    .maybeSingle();
  const name = profile?.full_name?.trim() || profile?.username?.trim() ||
    user.email;

  const sent = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: SUPPORT_FROM_EMAIL,
      to: [SUPPORT_INBOX_EMAIL],
      reply_to: user.email,
      subject: `[Admin request] ${name}`,
      text: `${name} <${user.email}> wants admin access.\n\n${note ?? "No note."}\n\nReview it: ${ADMINS_URL}`,
      html: requestEmailHtml(name, user.email, note),
    }),
  }).catch(() => null);
  if (!sent?.ok) {
    // The request is saved, so it still shows on the Admins page.
    console.error("Resend failed:", sent?.status);
  }

  return jsonResponse({ result });
});
