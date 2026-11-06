// Receives updates from the Synk Telegram bot. "/start <code>" links the
// chat to the Synk account that made the code (telegram_link_code) and
// turns ntfy off for it. "/stop" or blocking the bot removes the link.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEYS = Deno.env.get("SUPABASE_SECRET_KEYS");
const SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SECRET_KEYS
  ? (JSON.parse(SUPABASE_SECRET_KEYS) as Record<string, string>).default
  : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN");
const TELEGRAM_WEBHOOK_SECRET = Deno.env.get("TELEGRAM_WEBHOOK_SECRET");

const admin = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  : null;

type Language = "en" | "ar";

const replies: Record<string, Record<Language, string>> = {
  linked: {
    en: "Connected. Your Synk notifications will show up here.",
    ar: "تم الربط. ستصلك إشعارات Synk هنا.",
  },
  expired: {
    en: "This link has expired. Open Synk and tap Connect Telegram again.",
    ar: "انتهت صلاحية الرابط. افتح Synk واضغط ربط تيليجرام مرة أخرى.",
  },
  howTo: {
    en: "To connect, open Synk, go to Settings > Notifications > iPhone notifications and tap Connect Telegram.",
    ar: "للربط، افتح Synk ثم الإعدادات > الإشعارات > إشعارات الآيفون واضغط ربط تيليجرام.",
  },
  stopped: {
    en: "Disconnected. You won't get Synk notifications here anymore.",
    ar: "تم إلغاء الربط. لن تصلك إشعارات Synk هنا بعد الآن.",
  },
};

function secureEquals(actual: string | null, expected: string): boolean {
  if (actual === null || actual.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < actual.length; index++) {
    difference |= actual.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

function languageOf(code: unknown): Language {
  return typeof code === "string" && code.startsWith("ar") ? "ar" : "en";
}

async function reply(chatId: number, text: string): Promise<void> {
  try {
    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
  } catch {
    console.error("Could not reply on Telegram");
  }
}

async function link(chatId: number, code: string, fallback: Language): Promise<void> {
  const { data: row } = await admin!.from("telegram_links")
    .select("user_id, language, link_code_expires_at")
    .eq("link_code", code)
    .maybeSingle();
  if (!row || new Date(row.link_code_expires_at as string) < new Date()) {
    await reply(chatId, replies.expired[fallback]);
    return;
  }

  // One Telegram chat belongs to one Synk account at a time.
  await admin!.from("telegram_links")
    .update({ chat_id: null, linked_at: null, updated_at: new Date().toISOString() })
    .eq("chat_id", chatId)
    .neq("user_id", row.user_id);

  const { error } = await admin!.from("telegram_links")
    .update({
      chat_id: chatId,
      link_code: null,
      link_code_expires_at: null,
      linked_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", row.user_id);
  if (error) {
    console.error("Could not save Telegram link:", error.message);
    return;
  }

  // Telegram replaces ntfy, or every notification would come twice.
  await admin!.from("notification_preferences")
    .update({ ntfy_topic: null, updated_at: new Date().toISOString() })
    .eq("user_id", row.user_id);

  await reply(chatId, replies.linked[languageOf(row.language)]);
}

async function unlink(chatId: number): Promise<void> {
  await admin!.from("telegram_links").delete().eq("chat_id", chatId);
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return new Response("method_not_allowed", { status: 405 });
  }
  if (!admin || !TELEGRAM_BOT_TOKEN || !TELEGRAM_WEBHOOK_SECRET) {
    console.error("Telegram webhook is missing server configuration.");
    return new Response("server_misconfigured", { status: 500 });
  }
  if (!secureEquals(
    request.headers.get("x-telegram-bot-api-secret-token"),
    TELEGRAM_WEBHOOK_SECRET,
  )) {
    return new Response("unauthorized", { status: 401 });
  }

  let update: Record<string, any>;
  try {
    update = await request.json();
  } catch {
    return new Response("ok");
  }

  // The user blocked the bot.
  const member = update.my_chat_member;
  if (member?.chat?.type === "private" && member.new_chat_member?.status === "kicked") {
    await unlink(member.chat.id);
    return new Response("ok");
  }

  const message = update.message;
  if (message?.chat?.type !== "private" || typeof message.text !== "string") {
    return new Response("ok");
  }
  const chatId = message.chat.id as number;
  const language = languageOf(message.from?.language_code);
  const [command, argument] = message.text.trim().split(/\s+/, 2);

  if (command === "/start" && argument && /^[0-9a-f]{32}$/.test(argument)) {
    await link(chatId, argument, language);
  } else if (command === "/stop") {
    await unlink(chatId);
    await reply(chatId, replies.stopped[language]);
  } else {
    await reply(chatId, replies.howTo[language]);
  }

  // Always 200, or Telegram keeps sending the same update.
  return new Response("ok");
});
