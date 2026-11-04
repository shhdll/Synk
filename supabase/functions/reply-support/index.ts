// Backs synk.cc/support-reply.html and the admin dashboard: loads a ticket
// and emails the user a styled reply that quotes their original message.
//
// Access is by the ticket's reply_token, which is only in the team's email,
// or by a signed-in admin's token when no reply_token is sent.
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

const LOGO_URL = "https://synk.cc/logo.png";
const SCREENSHOT_BUCKET = "support-screenshots";
const SCREENSHOT_LINK_SECONDS = 60 * 60;
const UUID = /^[0-9a-f-]{36}$/i;
const CATEGORY_LABELS: Record<string, string> = {
  problem: "Bug",
  feedback: "Idea",
  other: "Other",
  appeal: "Appeal",
};

// Asks the database whether the caller is in private.admins, using their own
// token so auth.uid() is them.
async function adminIdFromRequest(request: Request): Promise<string | null> {
  const authorization = request.headers.get("Authorization") ?? "";
  const jwt = authorization.replace(/^Bearer\s+/i, "");
  const apikey = request.headers.get("apikey") ?? "";
  if (!admin || !jwt || !apikey || jwt === apikey) return null;

  const { data } = await admin.auth.getUser(jwt);
  if (!data?.user) return null;

  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_is_admin`, {
    method: "POST",
    headers: {
      apikey,
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  }).catch(() => null);
  if (!response?.ok) return null;
  return (await response.json()) === true ? data.user.id : null;
}

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

function formatDate(value: string): string {
  return new Date(value).toLocaleDateString("en-GB", {
    timeZone: "Asia/Riyadh",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

// Email-safe layout: tables and inline styles only.
function replyEmailHtml(ticket: {
  firstName: string;
  reply: string;
  message: string;
  category: string;
  createdAt: string;
}): string {
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
        <h1 style="margin:0 0 16px;font-size:20px;line-height:1.3;color:#1E1C24">Hi ${escapeHtml(ticket.firstName)},</h1>
        <div style="font-size:15px;line-height:1.6;color:#1E1C24;white-space:pre-wrap">${escapeHtml(ticket.reply)}</div>
        <p style="margin:24px 0 0;font-size:15px;color:#1E1C24">Synk team</p>
        <div style="margin-top:28px;padding-top:20px;border-top:1px solid #EFE8DA">
          <p style="margin:0 0 10px;font-size:12px;font-weight:700;color:#6B7280">
            YOUR MESSAGE · ${escapeHtml(CATEGORY_LABELS[ticket.category] ?? "Other").toUpperCase()} · ${escapeHtml(formatDate(ticket.createdAt))}
          </p>
          <div style="background:#FFF5EF;border-left:4px solid #FF7A36;border-radius:12px;padding:14px 16px;font-size:14px;line-height:1.55;color:#5F6672;white-space:pre-wrap">${escapeHtml(ticket.message)}</div>
        </div>
      </td></tr>
      <tr><td style="padding:16px 4px 0;font-size:12px;color:#6B7280">Need anything else? Just reply to this email.</td></tr>
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
    console.error("reply-support is missing server configuration.");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  let action: string;
  let ticketId: string;
  let token: string;
  let reply: string;
  try {
    const body = await request.json();
    action = body.action === "send" ? "send" : "get";
    ticketId = typeof body.ticket === "string" ? body.ticket : "";
    token = typeof body.token === "string" ? body.token : "";
    reply = typeof body.reply === "string" ? body.reply.trim() : "";
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!UUID.test(ticketId)) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  let adminId: string | null = null;
  if (!token) {
    adminId = await adminIdFromRequest(request);
    if (!adminId) return jsonResponse({ error: "not_allowed" }, 403);
  } else if (!UUID.test(token)) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  let query = admin.from("support_tickets")
    .select("id, user_id, email, category, message, created_at, reply, replied_at, screenshot_paths")
    .eq("id", ticketId);
  if (!adminId) query = query.eq("reply_token", token);
  const { data: ticket } = await query.maybeSingle();
  if (!ticket) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  const { data: profile } = ticket.user_id
    ? await admin.from("users")
      .select("full_name, username")
      .eq("id", ticket.user_id)
      .maybeSingle()
    : { data: null };
  const name = profile?.full_name?.trim() || profile?.username?.trim() ||
    (ticket.email as string).split("@")[0];

  if (action === "get") {
    // The bucket is private, so the page gets short-lived links.
    const paths = (ticket.screenshot_paths as string[] | null) ?? [];
    let screenshots: string[] = [];
    if (paths.length > 0) {
      const { data: signed } = await admin.storage.from(SCREENSHOT_BUCKET)
        .createSignedUrls(paths, SCREENSHOT_LINK_SECONDS);
      screenshots = (signed ?? [])
        .map((item) => item.signedUrl)
        .filter((link): link is string => !!link);
    }
    return jsonResponse({
      screenshots,
      name,
      email: ticket.email,
      category: ticket.category,
      message: ticket.message,
      created_at: ticket.created_at,
      reply: ticket.reply,
      replied_at: ticket.replied_at,
    });
  }

  if (reply.length < 1 || reply.length > 5000) {
    return jsonResponse({ error: "invalid_reply" }, 400);
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: SUPPORT_FROM_EMAIL,
      to: [ticket.email],
      // If they answer back, it lands in the team inbox.
      reply_to: SUPPORT_INBOX_EMAIL,
      subject: `Re: your message to Synk (#${(ticket.id as string).slice(0, 8)})`,
      text: `Hi ${name.split(" ")[0]},\n\n${reply}\n\nSynk team\n\n---\nYour message:\n${ticket.message}`,
      html: replyEmailHtml({
        firstName: name.split(" ")[0],
        reply,
        message: ticket.message as string,
        category: ticket.category as string,
        createdAt: ticket.created_at as string,
      }),
    }),
  }).catch(() => null);

  if (!response?.ok) {
    const detail = response
      ? `Resend ${response.status}: ${(await response.text()).slice(0, 300)}`
      : "Could not reach Resend";
    console.error("Resend failed:", detail);
    await admin.rpc("record_support_reply", {
      p_ticket_id: ticket.id,
      p_admin_id: adminId,
      p_body: reply,
      p_sent: false,
      p_error: detail,
    });
    return jsonResponse({ error: "send_failed", detail }, 502);
  }

  const { error: recordError } = await admin.rpc("record_support_reply", {
    p_ticket_id: ticket.id,
    p_admin_id: adminId,
    p_body: reply,
    p_sent: true,
  });
  if (recordError) console.error("Could not record reply:", recordError.message);

  return jsonResponse({ ok: true, name });
});
