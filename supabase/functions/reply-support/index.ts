// Backs synk.cc/support-reply.html: loads a ticket and emails the user a
// styled reply that quotes their original message.
//
// Access is by the ticket's reply_token, which is only in the team's email.
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

const UUID = /^[0-9a-f-]{36}$/i;
const CATEGORY_LABELS: Record<string, string> = {
  problem: "Bug",
  feedback: "Idea",
  other: "Other",
};

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
      <tr><td style="padding:0 4px 16px;font-size:22px;font-weight:800;letter-spacing:-0.5px;color:#FF7A36">synk</td></tr>
      <tr><td style="background:#FFFFFF;border-radius:20px;padding:28px">
        <h1 style="margin:0 0 16px;font-size:20px;line-height:1.3;color:#1E1C24">Hi ${escapeHtml(ticket.firstName)},</h1>
        <div style="font-size:15px;line-height:1.6;color:#1E1C24;white-space:pre-wrap">${escapeHtml(ticket.reply)}</div>
        <p style="margin:24px 0 0;font-size:15px;color:#1E1C24">The Synk team</p>
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
  if (!UUID.test(ticketId) || !UUID.test(token)) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  const { data: ticket } = await admin.from("support_tickets")
    .select("id, user_id, email, category, message, created_at, reply, replied_at")
    .eq("id", ticketId)
    .eq("reply_token", token)
    .maybeSingle();
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
    return jsonResponse({
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
      text: `Hi ${name.split(" ")[0]},\n\n${reply}\n\nThe Synk team\n\n---\nYour message:\n${ticket.message}`,
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
    console.error("Resend failed:", response?.status);
    return jsonResponse({ error: "send_failed" }, 502);
  }

  await admin.from("support_tickets")
    .update({
      status: "replied",
      reply,
      replied_at: new Date().toISOString(),
    })
    .eq("id", ticket.id);

  return jsonResponse({ ok: true, name });
});
