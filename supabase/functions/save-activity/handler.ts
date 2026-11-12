// The save-activity request flow. Everything outside (auth, database,
// storage, OpenAI, the clock, logs) comes in as `Deps`, so handler_test.ts
// can run every path without a network.
//
//  1. Token → user id                                       401 unauthorized
//  2. Body ≤ 2.9 MiB, read with a hard cap                  413 payload_too_large
//  3. JSON + strict contract (before the photo is decoded)  400 invalid_request / invalid
//  4. begin_activity_save: suspension, idempotency, leases,
//     one-at-a-time, rate limit                             stored result / busy / …
//  5. Photo checks + re-encode (JPEG only)                  photo_invalid
//  6. Synk's own term check of the text fields, then OpenAI
//     moderation of title, description, location and photo rejected / moderation_unavailable
//  7. Upload the re-encoded photo to its final path         storage_failed
//  8. finish_activity_save: the one transaction that writes saved / conflict / codes …
//  9. Delete the files the database said to delete (best effort)
//
// Every exit after step 4 either reaches finish or calls
// fail_activity_save, so the lease is always given back at once.
import {
  type Field,
  LIMITS,
  moderationInput,
  parseSaveRequest,
  payloadHash,
  type SaveRequest,
} from "./contract.ts";
import { encodeBase64, processPhoto } from "./image.ts";
import type { Verdict } from "./moderation.ts";
import { violatesTextPolicy } from "./text_policy.ts";

export interface Deps {
  // The user id for a valid token, null for an invalid one. Throws when
  // Auth itself can't be reached.
  authenticate(jwt: string): Promise<string | null>;
  // Calls a database function as service_role; throws on any error.
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
  uploadPhoto(path: string, jpeg: Uint8Array): Promise<void>;
  removePhotos(paths: string[]): Promise<void>;
  publicUrl(path: string): string;
  moderateText(text: string, deadline: number): Promise<Verdict>;
  moderateImage(jpegBase64: string, deadline: number): Promise<Verdict>;
  now(): number;
  // Never receives text, photos, keys or tokens: ids, codes and timings only.
  log(entry: Record<string, unknown>): void;
}

// The whole save has 30 seconds; moderation gets up to 25 of them.
const MODERATION_BUDGET_MS = 25_000;

type Body = Record<string, unknown>;

function json(body: Body, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

// Reads at most `limit` bytes; null when the body is bigger.
async function readCapped(
  request: Request,
  limit: number,
): Promise<Uint8Array | null> {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > limit) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return bytes;
}

interface Outcome {
  response: Body;
  cleanup: string[];
}

export function createHandler(deps: Deps) {
  return async function handle(request: Request): Promise<Response> {
    const started = deps.now();
    const entry: Record<string, unknown> = { event: "save_activity" };
    const finish = (response: Response, result: string) => {
      deps.log({
        ...entry,
        result,
        status: response.status,
        ms: deps.now() - started,
      });
      return response;
    };

    if (request.method !== "POST") {
      return finish(
        json({ result: "method_not_allowed" }, 405),
        "method_not_allowed",
      );
    }

    // 1. Who is calling.
    const jwt = request.headers.get("Authorization")?.match(/^Bearer\s+(\S+)$/i)
      ?.[1];
    if (!jwt) {
      return finish(json({ result: "unauthorized" }, 401), "unauthorized");
    }
    let userId: string | null;
    try {
      userId = await deps.authenticate(jwt);
    } catch {
      return finish(json({ result: "save_failed" }, 503), "auth_unreachable");
    }
    if (!userId) {
      return finish(json({ result: "unauthorized" }, 401), "unauthorized");
    }
    entry.user_id = userId;

    // 2. Size, before reading anything.
    const declared = Number(request.headers.get("Content-Length"));
    if (Number.isFinite(declared) && declared > LIMITS.bodyBytes) {
      return finish(
        json({ result: "payload_too_large" }, 413),
        "payload_too_large",
      );
    }
    const raw = await readCapped(request, LIMITS.bodyBytes);
    if (raw === null) {
      return finish(
        json({ result: "payload_too_large" }, 413),
        "payload_too_large",
      );
    }

    // 3. The contract.
    let body: unknown;
    try {
      body = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(raw));
    } catch {
      return finish(
        json({ result: "invalid_request" }, 400),
        "invalid_request",
      );
    }
    const parsed = parseSaveRequest(body);
    if (!parsed.ok) {
      if (parsed.kind === "contract") {
        entry.detail = parsed.detail;
        return finish(
          json({ result: "invalid_request" }, 400),
          "invalid_request",
        );
      }
      entry.fields = parsed.fields;
      if (parsed.fields.length === 1 && parsed.fields[0] === "photo") {
        return finish(
          json({ result: "photo_invalid", reason: "too_large" }),
          "photo_invalid",
        );
      }
      return finish(
        json({ result: "invalid", fields: parsed.fields }),
        "invalid",
      );
    }
    const save = parsed.request;
    entry.request_id = save.requestId;
    entry.activity_id = save.activityId;
    entry.operation = save.operation;

    const outcome = await run(save, userId, started, entry);
    await removeFiles(outcome.cleanup, entry);
    const result = String(outcome.response.result ?? "save_failed");
    return finish(
      json({ ...outcome.response, request_id: save.requestId }),
      result,
    );
  };

  async function run(
    save: SaveRequest,
    userId: string,
    started: number,
    entry: Record<string, unknown>,
  ): Promise<Outcome> {
    const photoPath = save.photoAction === "replace"
      ? `${userId}/${save.activityId}.${save.requestId}.jpg`
      : null;

    // 4. begin.
    let begin: {
      action: string;
      attempt?: number;
      response?: Body;
      cleanup_paths?: string[];
    };
    try {
      begin = await deps.rpc("begin_activity_save", {
        p_user_id: userId,
        p_request_id: save.requestId,
        p_activity_id: save.activityId,
        p_operation: save.operation,
        p_payload_hash: await payloadHash(save),
        p_photo_path: photoPath,
      }) as typeof begin;
    } catch {
      entry.detail = "begin_failed";
      return { response: { result: "save_failed" }, cleanup: [] };
    }
    const cleanup = [...(begin.cleanup_paths ?? [])];
    if (begin.action !== "proceed" || typeof begin.attempt !== "number") {
      if (begin.response?.result === "request_mismatch") {
        entry.detail = "request_mismatch";
      }
      return { response: begin.response ?? { result: "save_failed" }, cleanup };
    }
    const attempt = begin.attempt;
    entry.attempt = attempt;

    // Ends the request without saving and gives the lease back.
    const fail = async (
      code: string,
      retryable: boolean,
      extra: { fields?: Field[]; reason?: string; path?: string | null } = {},
    ): Promise<Outcome> => {
      if (extra.fields) entry.fields = extra.fields;
      try {
        const failed = await deps.rpc("fail_activity_save", {
          p_user_id: userId,
          p_request_id: save.requestId,
          p_attempt: attempt,
          p_result_code: code,
          p_retryable: retryable,
          p_fields: extra.fields ?? null,
          p_reason: extra.reason ?? null,
          p_photo_path: extra.path ?? null,
        }) as { response: Body; cleanup_path: string | null };
        if (failed.cleanup_path) cleanup.push(failed.cleanup_path);
        return { response: failed.response, cleanup };
      } catch {
        // The lease runs out on its own; a crashed attempt's file is
        // cleaned up on this user's next save.
        entry.detail = "fail_rpc_failed";
        return {
          response: { result: retryable ? code : "save_failed" },
          cleanup,
        };
      }
    };

    let uploaded = false;
    try {
      // 5. The photo.
      let jpeg: Uint8Array | null = null;
      if (save.jpegBase64 !== null) {
        const photo = processPhoto(save.jpegBase64);
        if (!photo.ok) {
          return await fail("photo_invalid", false, { reason: photo.reason });
        }
        jpeg = photo.jpeg;
        entry.photo_px = photo.width * photo.height;
      }

      // 6a. Synk's own rule first: obvious sexual or explicit terms are
      // rejected even when the model would let a lone word through. Same
      // answer as a moderation rejection; the matched word isn't logged.
      const policyBlocked = ([
        ["title", save.activity.title],
        ["location", save.activity.location_name],
        ["description", save.activity.description],
      ] as [Field, string | null][])
        .filter(([, value]) => violatesTextPolicy(value))
        .map(([field]) => field);
      if (policyBlocked.length > 0) {
        entry.detail = "text_policy";
        return await fail("rejected", false, { fields: policyBlocked });
      }

      // 6b. OpenAI moderation, all fields at once.
      const deadline = started + MODERATION_BUDGET_MS;
      const checks: { field: Field; verdict: Promise<Verdict> }[] = [
        {
          field: "title",
          verdict: deps.moderateText(
            moderationInput(save.activity.title),
            deadline,
          ),
        },
        {
          field: "location",
          verdict: deps.moderateText(
            moderationInput(save.activity.location_name),
            deadline,
          ),
        },
      ];
      if (save.activity.description !== null) {
        checks.push({
          field: "description",
          verdict: deps.moderateText(
            moderationInput(save.activity.description),
            deadline,
          ),
        });
      }
      if (jpeg !== null) {
        checks.push({
          field: "photo",
          verdict: deps.moderateImage(encodeBase64(jpeg), deadline),
        });
      }
      const verdicts = await Promise.all(checks.map((check) => check.verdict));

      const blocked = checks
        .filter((_, i) => verdicts[i].status === "blocked")
        .map((check) => check.field);
      if (blocked.length > 0) {
        return await fail("rejected", false, { fields: blocked });
      }
      if (verdicts.some((verdict) => verdict.status === "unreadable_image")) {
        return await fail("photo_invalid", false, { reason: "corrupt" });
      }
      const unavailable = verdicts.find((verdict) =>
        verdict.status === "unavailable"
      );
      if (unavailable && unavailable.status === "unavailable") {
        entry.detail = unavailable.detail;
        return await fail("moderation_unavailable", true);
      }

      // 7. Upload the checked photo.
      if (jpeg !== null && photoPath !== null) {
        try {
          await deps.uploadPhoto(photoPath, jpeg);
          uploaded = true;
        } catch {
          return await fail("storage_failed", true, { path: photoPath });
        }
      }

      // 8. The one write.
      const finished = await deps.rpc("finish_activity_save", {
        p_user_id: userId,
        p_request_id: save.requestId,
        p_attempt: attempt,
        p_activity: save.activity,
        p_expected_version: save.expectedVersion,
        p_photo_action: save.photoAction,
        p_photo_url: photoPath === null ? null : deps.publicUrl(photoPath),
      }) as {
        response: Body;
        cleanup_path: string | null;
        sqlstate?: string | null;
      };
      if (finished.sqlstate) entry.sqlstate = finished.sqlstate;
      if (finished.cleanup_path) cleanup.push(finished.cleanup_path);
      return { response: finished.response, cleanup };
    } catch {
      // Anything unexpected, including finish failing to answer. If finish
      // did commit, fail changes nothing and returns the saved result.
      entry.detail = "unexpected";
      return await fail("save_failed", true, {
        path: uploaded ? photoPath : null,
      });
    }
  }

  async function removeFiles(paths: string[], entry: Record<string, unknown>) {
    const unique = [...new Set(paths.filter((path) => path.length > 0))];
    if (unique.length === 0) return;
    try {
      await deps.removePhotos(unique);
    } catch {
      // The files are unlinked; they just stay in storage. Paths only.
      entry.cleanup_failed = unique;
    }
  }
}
