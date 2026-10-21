import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEYS = Deno.env.get("SUPABASE_SECRET_KEYS");
const SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SECRET_KEYS
  ? (JSON.parse(SUPABASE_SECRET_KEYS) as Record<string, string>).default
  : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const PROMOTION_WEBHOOK_SECRET = Deno.env.get("PROMOTION_WEBHOOK_SECRET");
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

type PromotionEvent = {
  id: string;
  user_id: string;
  activity_id: string;
  activity_title: string;
  status: string;
  event_type?: "waitlist_promotion" | "activity_updated" | "activity_deleted" | "join_request_accepted" | "join_request_rejected" | "join_request_received";
};

type FcmCredentials = {
  project_id: string;
  client_email: string;
  private_key: string;
};

let cachedAccessToken: string | null = null;
let accessTokenExpiresAt = 0;

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

function secureEquals(actual: string | null, expected: string): boolean {
  if (actual === null || actual.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < actual.length; index++) {
    difference |= actual.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function pemBytes(pem: string): Uint8Array {
  const base64 = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
}

async function getFcmAccessToken(credentials: FcmCredentials): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && accessTokenExpiresAt > now + 60) {
    return cachedAccessToken;
  }

  const header = base64Url(new TextEncoder().encode(JSON.stringify({
    alg: "RS256",
    typ: "JWT",
  })));
  const claims = base64Url(new TextEncoder().encode(JSON.stringify({
    iss: credentials.client_email,
    scope: FCM_SCOPE,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })));
  const unsignedJwt = `${header}.${claims}`;
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(credentials.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      privateKey,
      new TextEncoder().encode(unsignedJwt),
    ),
  );
  const assertion = `${unsignedJwt}.${base64Url(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    throw new Error("Could not authorize with Firebase Cloud Messaging.");
  }

  cachedAccessToken = result.access_token;
  accessTokenExpiresAt = now + Number(result.expires_in ?? 3600);
  return cachedAccessToken!;
}

function isUnregisteredToken(error: Record<string, unknown>): boolean {
  const details = error.details;
  return Array.isArray(details) && details.some((detail) =>
    detail && typeof detail === "object" &&
    (detail as Record<string, unknown>).errorCode === "UNREGISTERED"
  );
}

async function sendToToken(
  token: string,
  event: PromotionEvent,
  credentials: FcmCredentials,
  accessToken: string,
): Promise<{
  sent: boolean;
  unregistered: boolean;
  httpStatus?: number;
  failureCode?: string;
}> {
  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: event.event_type === "join_request_accepted"
              ? {
                title: "Request accepted",
                body: `Your request to join ${event.activity_title} was accepted. You're in!`,
              }
              : event.event_type === "join_request_rejected"
              ? {
                title: "Request declined",
                body: `Your request to join ${event.activity_title} was declined by the host.`,
              }
              : event.event_type === "join_request_received"
              ? {
                title: "New join request",
                body: `Someone requested to join ${event.activity_title}. Review their request.`,
              }
              : event.event_type === "activity_deleted"
              ? {
                title: "Activity canceled",
                body: `${event.activity_title} was deleted by the host.`,
              }
              : event.event_type === "activity_updated"
              ? {
                title: "Activity updated",
                body: `${event.activity_title} has new details. Tap to review the changes.`,
              }
              : {
                title: "You're In! \u{1F389}",
                body: `A spot opened up! You've been moved from the waiting list and successfully joined ${event.activity_title}.`,
              },
            data: {
              type: event.event_type ?? "waitlist_promotion",
              event_id: event.id,
              activity_id: event.activity_id,
            },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: event.event_type === "activity_updated" ||
                    event.event_type === "activity_deleted" ||
                    event.event_type === "join_request_accepted" ||
                    event.event_type === "join_request_rejected" ||
                    event.event_type === "join_request_received"
                  ? "activity_updates"
                  : "waitlist_promotions",
                tag: `${event.event_type ?? "waitlist_promotion"}_${event.id}`,
                sound: "default",
              },
            },
          },
        }),
      },
    );

    if (response.ok) return { sent: true, unregistered: false };

    const failure = await response.json().catch(() => ({}));
    const error = failure && typeof failure === "object"
      ? (failure as Record<string, unknown>).error as
        | Record<string, unknown>
        | undefined
      : undefined;
    return {
      sent: false,
      unregistered: response.status === 404 ||
        (error !== undefined && isUnregisteredToken(error)),
      httpStatus: response.status,
      failureCode: typeof error?.status === "string" ? error.status : undefined,
    };
  } catch {
    // Avoid logging request details, which include the device token.
    return { sent: false, unregistered: false, failureCode: "network_error" };
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!admin || !PROMOTION_WEBHOOK_SECRET || !FCM_SERVICE_ACCOUNT_JSON) {
    console.error("Waitlist notification function is missing server configuration.");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }
  if (!secureEquals(
    request.headers.get("x-waitlist-push-secret"),
    PROMOTION_WEBHOOK_SECRET,
  )) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let eventId: string;
  let eventType: "waitlist_promotion" | "activity_updated" | "activity_deleted" | "join_request_accepted" | "join_request_rejected" | "join_request_received";
  try {
    const body = await request.json();
    eventId = typeof body.event_id === "string" ? body.event_id : "";
    eventType = body.event_type === "activity_updated" ||
        body.event_type === "activity_deleted" ||
        body.event_type === "join_request_accepted" ||
        body.event_type === "join_request_rejected" ||
        body.event_type === "join_request_received"
      ? body.event_type
      : "waitlist_promotion";
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!/^[0-9a-f-]{36}$/i.test(eventId)) {
    return jsonResponse({ error: "invalid_event_id" }, 400);
  }

  const outboxTable = eventType === "activity_updated"
    ? "activity_update_notification_outbox"
    : eventType === "activity_deleted"
    ? "activity_deleted_notification_outbox"
    : eventType === "join_request_accepted"
    ? "join_request_accepted_notification_outbox"
    : eventType === "join_request_rejected"
    ? "join_request_rejected_notification_outbox"
    : eventType === "join_request_received"
    ? "join_request_received_notification_outbox"
    : "waitlist_promotion_notification_outbox";
  const { data: event, error: claimError } = await admin
    .from(outboxTable)
    .update({ status: "processing" })
    .eq("id", eventId)
    .eq("status", "pending")
    .select("id, user_id, activity_id, activity_title, status")
    .maybeSingle();

  if (claimError) {
    console.error("Could not claim promotion event:", eventId, claimError.message);
    return jsonResponse({ error: "event_claim_failed" }, 500);
  }
  if (!event) {
    // A repeated webhook sees a non-pending event and never sends it twice.
    return jsonResponse({ ok: true, duplicate: true });
  }

  const typedEvent = { ...(event as PromotionEvent), event_type: eventType };
  const { data: tokens, error: tokenError } = await admin
    .from("push_device_tokens")
    .select("fcm_token")
    .eq("user_id", typedEvent.user_id);

  if (tokenError) {
    console.error("Could not load promotion recipient tokens:", tokenError.message);
    await admin.from(outboxTable)
      .update({ status: "failed", processed_at: new Date().toISOString() })
      .eq("id", eventId);
    return jsonResponse({ error: "recipient_lookup_failed" }, 500);
  }

  if (!tokens?.length) {
    await admin.from(outboxTable)
      .update({ status: "no_tokens", processed_at: new Date().toISOString() })
      .eq("id", eventId);
    return jsonResponse({ ok: true, sent: 0 });
  }

  let credentials: FcmCredentials;
  try {
    credentials = JSON.parse(FCM_SERVICE_ACCOUNT_JSON) as FcmCredentials;
    if (!credentials.project_id || !credentials.client_email || !credentials.private_key) {
      throw new Error("Incomplete Firebase service account.");
    }
  } catch {
    await admin.from(outboxTable)
      .update({ status: "failed", processed_at: new Date().toISOString() })
      .eq("id", eventId);
    console.error("Firebase service account configuration is invalid.");
    return jsonResponse({ error: "firebase_configuration_invalid" }, 500);
  }

  try {
    const accessToken = await getFcmAccessToken(credentials);
    const outcomes = await Promise.all(tokens.map(({ fcm_token }) =>
      sendToToken(fcm_token, typedEvent, credentials, accessToken)
    ));
    outcomes.forEach((outcome) => {
      if (!outcome.sent) {
        console.error("FCM rejected notification delivery", {
          eventId,
          httpStatus: outcome.httpStatus,
          code: outcome.failureCode ?? "unknown_fcm_error",
        });
      }
    });
    const invalidTokens = tokens
      .filter((_, index) => outcomes[index].unregistered)
      .map(({ fcm_token }) => fcm_token);

    if (invalidTokens.length) {
      await admin.from("push_device_tokens")
        .delete()
        .in("fcm_token", invalidTokens);
    }

    const sent = outcomes.filter((outcome) => outcome.sent).length;
    await admin.from(outboxTable)
      .update({
        status: sent > 0 ? "sent" : "failed",
        processed_at: new Date().toISOString(),
      })
      .eq("id", eventId);

    return jsonResponse({ ok: true, sent });
  } catch (error) {
    // Do not include FCM tokens or credential material in logs or responses.
    console.error("FCM delivery failed for promotion event:", eventId, error);
    await admin.from(outboxTable)
      .update({ status: "failed", processed_at: new Date().toISOString() })
      .eq("id", eventId);
    return jsonResponse({ error: "notification_delivery_failed" }, 500);
  }
});
