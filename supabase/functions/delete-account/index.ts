// Deletes the signed-in user's account and everything tied to it.
// Rows that reference the user cascade from auth.users; files and the
// rows that don't cascade are removed here first.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEYS = Deno.env.get("SUPABASE_SECRET_KEYS");
const SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SECRET_KEYS
  ? (JSON.parse(SUPABASE_SECRET_KEYS) as Record<string, string>).default
  : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

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

// Removes every file under <folder>/ in a bucket.
async function removeFolder(bucket: string, folder: string): Promise<void> {
  const storage = admin!.storage.from(bucket);
  while (true) {
    const { data, error } = await storage.list(folder, { limit: 100 });
    if (error || !data?.length) return;
    const paths = data.map((file) => `${folder}/${file.name}`);
    const { error: removeError } = await storage.remove(paths);
    if (removeError) throw removeError;
    if (data.length < 100) return;
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!admin) {
    console.error("delete-account is missing server configuration.");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const jwt = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const { data: auth } = jwt
    ? await admin.auth.getUser(jwt)
    : { data: { user: null } };
  const userId = auth.user?.id;
  if (!userId) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  try {
    // Profile photo, header and hosted activity photos are all in <uid>/.
    await removeFolder("avatars", userId);
    await removeFolder("activity-photos", userId);

    const { data: photos } = await admin.from("chat_messages")
      .select("image_path")
      .eq("sender_id", userId)
      .not("image_path", "is", null);
    const photoPaths = (photos ?? [])
      .map((row) => row.image_path as string)
      .filter((path) => path.length > 0);
    for (let i = 0; i < photoPaths.length; i += 100) {
      await admin.storage.from("chat-photos")
        .remove(photoPaths.slice(i, i + 100));
    }

    // Messages keep a null sender on user delete, so remove them here.
    const { error: messagesError } = await admin.from("chat_messages")
      .delete()
      .eq("sender_id", userId);
    if (messagesError) throw messagesError;

    // Participants get the usual "activity canceled" notification.
    const { error: activitiesError } = await admin.from("activities")
      .delete()
      .eq("host_id", userId);
    if (activitiesError) throw activitiesError;

    const { error: ticketsError } = await admin.from("support_tickets")
      .delete()
      .eq("user_id", userId);
    if (ticketsError) throw ticketsError;

    // Friends, blocks, ratings and the rest cascade from public.users.
    const { error: profileError } = await admin.from("users")
      .delete()
      .eq("id", userId);
    if (profileError) throw profileError;

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;
  } catch (error) {
    console.error(
      "Could not delete account:",
      error instanceof Error ? error.message : error,
    );
    return jsonResponse({ error: "delete_failed" }, 500);
  }

  return jsonResponse({ ok: true });
});
