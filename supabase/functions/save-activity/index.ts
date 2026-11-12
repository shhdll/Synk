// save-activity: the only way the app creates or edits an activity.
// Checks the title, description, location and photo with OpenAI's
// moderation model before anything is saved. See
// supabase/ACTIVITY_MODERATION.md for the flow, configuration and rollout.
//
// Secrets:
//   OPENAI_API_KEY          required; without it every save fails closed
//   IMAGE_BLOCK_CATEGORIES  optional, comma-separated subset of the six
//                           image categories (default: all six)
// SUPABASE_URL and the service key are provided by Supabase.
//
// JWT verification stays ON in config.toml, and the handler also checks
// the token with Supabase Auth to get the user id.
import { createClient } from "@supabase/supabase-js";

import { createHandler } from "./handler.ts";
import {
  imageBlockCategories,
  moderateImage,
  moderateText,
} from "./moderation.ts";

const BUCKET = "activity-photos";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEYS = Deno.env.get("SUPABASE_SECRET_KEYS");
const SERVICE_KEY = SUPABASE_SECRET_KEYS
  ? (JSON.parse(SUPABASE_SECRET_KEYS) as Record<string, string>).default
  : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const BLOCK_CATEGORIES = imageBlockCategories(
  Deno.env.get("IMAGE_BLOCK_CATEGORIES"),
);

const admin = SUPABASE_URL && SERVICE_KEY
  ? createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  : null;

if (!OPENAI_API_KEY) {
  // Logged without the value. Saves still answer, as moderation_unavailable.
  console.error(
    JSON.stringify({
      event: "save_activity_config",
      problem: "missing_openai_key",
    }),
  );
}

const handler = admin
  ? createHandler({
    async authenticate(jwt) {
      const { data, error } = await admin.auth.getUser(jwt);
      if (error) {
        // 4xx: a bad or expired token. Anything else: Auth is unreachable.
        if (
          error.status !== undefined && error.status >= 400 &&
          error.status < 500
        ) return null;
        throw error;
      }
      return data.user?.id ?? null;
    },
    async rpc(name, args) {
      const { data, error } = await admin.rpc(name, args);
      if (error) {
        throw new Error(`rpc ${name} failed: ${error.code ?? "unknown"}`);
      }
      return data;
    },
    async uploadPhoto(path, jpeg) {
      const { error } = await admin.storage.from(BUCKET).upload(path, jpeg, {
        contentType: "image/jpeg",
        cacheControl: "31536000",
        upsert: true,
      });
      if (error) throw new Error("upload failed");
    },
    async removePhotos(paths) {
      const { error } = await admin.storage.from(BUCKET).remove(paths);
      if (error) throw new Error("remove failed");
    },
    publicUrl(path) {
      return admin.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;
    },
    moderateText(text, deadline) {
      return moderateText(text, { apiKey: OPENAI_API_KEY, deadline });
    },
    moderateImage(jpegBase64, deadline) {
      return moderateImage(jpegBase64, BLOCK_CATEGORIES, {
        apiKey: OPENAI_API_KEY,
        deadline,
      });
    },
    now: () => Date.now(),
    log: (entry) => console.log(JSON.stringify(entry)),
  })
  : null;

Deno.serve((request: Request) => {
  if (!handler) {
    console.error(
      JSON.stringify({
        event: "save_activity_config",
        problem: "missing_supabase_env",
      }),
    );
    return new Response(JSON.stringify({ result: "save_failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  return handler(request);
});
