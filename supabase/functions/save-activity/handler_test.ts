import { assert, assertEquals } from "@std/assert";

import { LIMITS } from "./contract.ts";
import { createHandler, type Deps } from "./handler.ts";
import { encodeBase64 } from "./image.ts";
import { makeJpeg, validBody } from "./test_helpers.ts";
import type { Verdict } from "./moderation.ts";

const USER = "a1b2c3d4-0000-4000-8000-000000000001";

interface Fake {
  deps: Deps;
  calls: string[];
  rpcArgs: Record<string, Record<string, unknown>>;
  uploads: { path: string; bytes: Uint8Array }[];
  removed: string[][];
  logs: Record<string, unknown>[];
}

function fake(overrides: Partial<{
  user: string | null;
  authThrows: boolean;
  begin: Record<string, unknown>;
  finish: Record<string, unknown> | Error;
  failCleanup: string | null;
  text: (text: string) => Verdict;
  image: Verdict;
  uploadThrows: boolean;
  removeThrows: boolean;
}> = {}): Fake {
  const calls: string[] = [];
  const rpcArgs: Record<string, Record<string, unknown>> = {};
  const uploads: { path: string; bytes: Uint8Array }[] = [];
  const removed: string[][] = [];
  const logs: Record<string, unknown>[] = [];
  const deps: Deps = {
    authenticate: async () => {
      if (overrides.authThrows) throw new Error("auth down");
      return overrides.user === undefined ? USER : overrides.user;
    },
    rpc: async (name, args) => {
      calls.push(name);
      rpcArgs[name] = args;
      if (name === "begin_activity_save") {
        return overrides.begin ??
          { action: "proceed", attempt: 1, cleanup_paths: [] };
      }
      if (name === "fail_activity_save") {
        return {
          response: {
            result: args.p_result_code,
            ...(args.p_fields ? { fields: args.p_fields } : {}),
            ...(args.p_reason ? { reason: args.p_reason } : {}),
          },
          cleanup_path: overrides.failCleanup === undefined
            ? args.p_photo_path
            : overrides.failCleanup,
        };
      }
      if (name === "finish_activity_save") {
        if (overrides.finish instanceof Error) throw overrides.finish;
        return overrides.finish ?? {
          response: { result: "saved", activity: { id: "x", edit_version: 1 } },
          cleanup_path: null,
        };
      }
      throw new Error(`unexpected rpc ${name}`);
    },
    uploadPhoto: async (path, bytes) => {
      calls.push("upload");
      if (overrides.uploadThrows) throw new Error("storage down");
      uploads.push({ path, bytes });
    },
    removePhotos: async (paths) => {
      calls.push("remove");
      removed.push(paths);
      if (overrides.removeThrows) throw new Error("remove failed");
    },
    publicUrl: (path) =>
      `https://x.supabase.co/storage/v1/object/public/activity-photos/${path}`,
    moderateText: async (text) => {
      calls.push("moderate_text");
      return overrides.text?.(text) ?? { status: "allowed" };
    },
    moderateImage: async () => {
      calls.push("moderate_image");
      return overrides.image ?? { status: "allowed" };
    },
    now: () => 0,
    log: (entry) => logs.push(entry),
  };
  return { deps, calls, rpcArgs, uploads, removed, logs };
}

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("http://localhost/save-activity", {
    method: "POST",
    headers: {
      "Authorization": "Bearer token",
      "Content-Type": "application/json",
      ...headers,
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function send(f: Fake, request: Request) {
  const response = await createHandler(f.deps)(request);
  return { status: response.status, body: await response.json() };
}

const photoBody = () =>
  validBody({
    photo: { action: "replace", jpeg_base64: encodeBase64(makeJpeg(400, 200)) },
  });

Deno.test("no token or a bad token: 401, nothing else runs (#1, #2)", async () => {
  const noToken = fake();
  const request = new Request("http://localhost", {
    method: "POST",
    body: "{}",
  });
  assertEquals((await send(noToken, request)).status, 401);
  const bad = fake({ user: null });
  assertEquals((await send(bad, post(validBody()))).status, 401);
  assertEquals(bad.calls, []);
  const down = fake({ authThrows: true });
  assertEquals((await send(down, post(validBody()))).status, 503);
});

Deno.test("only POST", async () => {
  const f = fake();
  const response = await createHandler(f.deps)(
    new Request("http://localhost", { method: "GET" }),
  );
  assertEquals(response.status, 405);
});

Deno.test("too big: 413 from the header, or from reading past the cap (#47, A7)", async () => {
  const f = fake();
  assertEquals(
    (await send(
      f,
      post(validBody(), { "Content-Length": String(LIMITS.bodyBytes + 1) }),
    )).status,
    413,
  );
  // The header lies (or is missing): the read stops at the cap.
  const huge = "x".repeat(LIMITS.bodyBytes + 10);
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(huge));
      controller.close();
    },
  });
  const lying = new Request("http://localhost", {
    method: "POST",
    headers: { "Authorization": "Bearer token", "Content-Length": "10" },
    body: stream,
  });
  assertEquals((await send(fake(), lying)).status, 413);
  assertEquals(f.calls, []);
});

Deno.test("broken JSON or contract: 400, nothing runs (A6)", async () => {
  for (
    const body of [
      "{not json",
      JSON.stringify({ ...validBody(), host_id: USER }),
    ]
  ) {
    const f = fake();
    const { status, body: answer } = await send(f, post(body));
    assertEquals(status, 400);
    assertEquals(answer.result, "invalid_request");
    assertEquals(f.calls, []);
  }
});

Deno.test("fixable fields come back as invalid before begin (#18)", async () => {
  const f = fake();
  const body = validBody();
  (body.activity as Record<string, unknown>).title = "";
  const { status, body: answer } = await send(f, post(body));
  assertEquals([status, answer.result, answer.fields], [200, "invalid", [
    "title",
  ]]);
  assertEquals(f.calls, []);
});

Deno.test("a clean create: moderate, then finish; no upload without a photo (#11, #54)", async () => {
  const f = fake();
  const { status, body } = await send(f, post(validBody()));
  assertEquals([status, body.result], [200, "saved"]);
  assertEquals(body.request_id, validBody().request_id);
  assertEquals(f.calls.filter((c) => c !== "moderate_text"), [
    "begin_activity_save",
    "finish_activity_save",
  ]);
  assertEquals(f.calls.filter((c) => c === "moderate_text").length, 3);
  assertEquals(f.rpcArgs.begin_activity_save.p_photo_path, null);
  assertEquals(f.rpcArgs.finish_activity_save.p_photo_url, null);
  assertEquals(f.rpcArgs.begin_activity_save.p_user_id, USER);
});

Deno.test("a photo is re-encoded, checked, uploaded to its own path, then saved (#35)", async () => {
  const f = fake();
  const body = photoBody();
  const { body: answer } = await send(f, post(body));
  assertEquals(answer.result, "saved");
  const path = `${USER}/${body.activity_id}.${body.request_id}.jpg`;
  assertEquals(f.rpcArgs.begin_activity_save.p_photo_path, path);
  assertEquals(f.uploads[0].path, path);
  assertEquals(
    f.rpcArgs.finish_activity_save.p_photo_url,
    `https://x.supabase.co/storage/v1/object/public/activity-photos/${path}`,
  );
  assertEquals([...f.uploads[0].bytes.subarray(0, 2)], [0xff, 0xd8]);
  // Order: moderation before upload, upload before the write.
  assert(f.calls.indexOf("moderate_image") < f.calls.indexOf("upload"));
  assert(f.calls.indexOf("upload") < f.calls.indexOf("finish_activity_save"));
});

Deno.test("rejected text or photo: final, named fields, no upload (#12, #19-#21, #27, #36)", async () => {
  const f = fake({
    text: (text) =>
      text.startsWith("Padel") ? { status: "blocked" } : { status: "allowed" },
    image: { status: "blocked" },
  });
  const { body } = await send(f, post(photoBody()));
  assertEquals(body.result, "rejected");
  assertEquals(new Set(body.fields), new Set(["title", "photo"]));
  assertEquals(f.rpcArgs.fail_activity_save.p_retryable, false);
  assertEquals(f.uploads.length, 0);
  assert(!f.calls.includes("finish_activity_save"));
  assert(
    !("category_scores" in body) && !("categories" in body),
    "no scores to the app",
  );
});

Deno.test("location or description alone (#20, #21)", async () => {
  for (
    const [needle, field] of [["Kingdom", "location"], [
      "Friendly",
      "description",
    ]]
  ) {
    const f = fake({
      text: (text) =>
        text.startsWith(needle) ? { status: "blocked" } : { status: "allowed" },
    });
    const { body } = await send(f, post(validBody()));
    assertEquals([body.result, body.fields], ["rejected", [field]]);
  }
});

Deno.test("moderation unavailable: retryable, lease released via fail (#41-#46, #49)", async () => {
  const f = fake({
    text: () => ({ status: "unavailable", detail: "timeout" }),
  });
  const { body } = await send(f, post(photoBody()));
  assertEquals(body.result, "moderation_unavailable");
  assertEquals(f.rpcArgs.fail_activity_save.p_retryable, true);
  assertEquals(f.uploads.length, 0);
  assert(!f.calls.includes("finish_activity_save"));
});

Deno.test("a blocked field wins over an unavailable one", async () => {
  const f = fake({
    text: (text) =>
      text.startsWith("Padel")
        ? { status: "blocked" }
        : { status: "unavailable", detail: "http_503" },
  });
  const { body } = await send(f, post(validBody()));
  assertEquals([body.result, body.fields], ["rejected", ["title"]]);
});

Deno.test("a bad photo stops before moderation (#30, #32)", async () => {
  const f = fake();
  const body = validBody({
    photo: {
      action: "replace",
      jpeg_base64: encodeBase64(new TextEncoder().encode("not an image")),
    },
  });
  const { body: answer } = await send(f, post(body));
  assertEquals([answer.result, answer.reason], ["photo_invalid", "corrupt"]);
  assert(!f.calls.includes("moderate_text"));
  assertEquals(f.rpcArgs.fail_activity_save.p_retryable, false);
});

Deno.test("OpenAI can't read the photo: photo_invalid, not retryable", async () => {
  const f = fake({ image: { status: "unreadable_image" } });
  const { body } = await send(f, post(photoBody()));
  assertEquals([body.result, body.reason], ["photo_invalid", "corrupt"]);
});

Deno.test("upload fails: storage_failed, retryable, the path handed to fail and deleted (#53)", async () => {
  const f = fake({ uploadThrows: true });
  const body = photoBody();
  const { body: answer } = await send(f, post(body));
  assertEquals(answer.result, "storage_failed");
  assertEquals(f.rpcArgs.fail_activity_save.p_retryable, true);
  const path = `${USER}/${body.activity_id}.${body.request_id}.jpg`;
  assertEquals(f.rpcArgs.fail_activity_save.p_photo_path, path);
  assertEquals(f.removed, [[path]]);
});

Deno.test("finish throws: fail(save_failed) with the uploaded path (#37, #60)", async () => {
  const f = fake({ finish: new Error("network") });
  const { body } = await send(f, post(photoBody()));
  assertEquals(body.result, "save_failed");
  assertEquals(f.rpcArgs.fail_activity_save.p_result_code, "save_failed");
  assert(typeof f.rpcArgs.fail_activity_save.p_photo_path === "string");
});

Deno.test("finish committed but its answer was lost: nothing linked is deleted", async () => {
  // fail finds the row already saved and hands back no file.
  const f = fake({ finish: new Error("network"), failCleanup: null });
  await send(f, post(photoBody()));
  assertEquals(f.removed, []);
});

Deno.test("database codes pass through; the replaced photo is deleted (#50-#52, #35)", async () => {
  for (
    const code of [
      "schedule_conflict",
      "capacity_below_participants",
      "conflict",
      "not_host",
      "not_found",
    ]
  ) {
    const f = fake({
      finish: { response: { result: code }, cleanup_path: null },
    });
    const { body } = await send(f, post(validBody()));
    assertEquals(body.result, code);
  }
  const f = fake({
    finish: { response: { result: "saved" }, cleanup_path: "old/photo.jpg" },
  });
  await send(f, post(validBody()));
  assertEquals(f.removed, [["old/photo.jpg"]]);
});

Deno.test("begin answers directly: replay, busy, mismatch, rate limit, suspended (#61-#63, A1-A3, #3)", async () => {
  for (
    const response of [
      { result: "saved", replayed: true },
      { result: "busy", retry_after_seconds: 3 },
      { result: "request_mismatch" },
      { result: "rate_limited", retry_after_seconds: 120 },
      { result: "suspended" },
    ]
  ) {
    const f = fake({
      begin: { action: "respond", response, cleanup_paths: ["left/over.jpg"] },
    });
    const { body } = await send(f, post(photoBody()));
    assertEquals(body.result, response.result);
    assert(!f.calls.includes("moderate_text"), "nothing re-runs");
    assert(!f.calls.includes("upload"));
    assertEquals(
      f.removed,
      [["left/over.jpg"]],
      "leftover files are still cleaned",
    );
  }
});

Deno.test("a failed cleanup doesn't change the answer, and logs paths only (#38)", async () => {
  const f = fake({
    removeThrows: true,
    finish: { response: { result: "saved" }, cleanup_path: "old.jpg" },
  });
  const { body } = await send(f, post(validBody()));
  assertEquals(body.result, "saved");
  assertEquals(f.logs.at(-1)?.cleanup_failed, ["old.jpg"]);
});

Deno.test("logs never contain the text, the photo or the token (#74)", async () => {
  const f = fake({ text: () => ({ status: "blocked" }) });
  const body = photoBody();
  await send(f, post(body));
  const logged = JSON.stringify(f.logs);
  const activity = body.activity as Record<string, string>;
  for (
    const secret of [
      activity.title,
      activity.description,
      activity.location_name,
      "Bearer",
      "token",
    ]
  ) {
    assert(!logged.includes(secret), `log contains ${secret}`);
  }
  assert(
    !logged.includes(
      (body.photo as Record<string, string>).jpeg_base64.slice(0, 40),
    ),
  );
  assertEquals(f.logs.at(-1)?.result, "rejected");
});

function titled(title: string) {
  const body = validBody();
  return { ...body, activity: { ...(body.activity as object), title } };
}

// Moderation is faked here: these words stand in for what OpenAI flags.
const flagging = (words: string[]) => (text: string): Verdict =>
  words.some((word) => text.includes(word))
    ? { status: "blocked" }
    : { status: "allowed" };

Deno.test("English, Arabic and mixed titles are saved", async () => {
  for (const title of ["Padel night", "ليلة بادل", "بادل night مع Sara"]) {
    const f = fake({ text: flagging(["كلب", "idiot"]) });
    const { body } = await send(f, post(titled(title)));
    assertEquals(body.result, "saved", title);
    assertEquals(
      (f.rpcArgs.finish_activity_save.p_activity as Record<string, unknown>)
        .title,
      title,
    );
  }
});

Deno.test("an inappropriate Arabic title is rejected and nothing is saved", async () => {
  const f = fake({ text: flagging(["كلب"]) });
  const { body } = await send(f, post(titled("يا كلب")));
  assertEquals([body.result, body.fields], ["rejected", ["title"]]);
  assert(!f.calls.includes("finish_activity_save"));
});

Deno.test("an Arabic title with harakat is checked without them too", async () => {
  const seen: string[] = [];
  const f = fake({
    text: (text) => {
      seen.push(text);
      return flagging(["كلب"])(text);
    },
  });
  const { body } = await send(f, post(titled("يا كَلْب")));
  assertEquals([body.result, body.fields], ["rejected", ["title"]]);
  assert(seen.some((text) => text.includes("\nيا كلب")));
});

Deno.test("an inappropriate English title is rejected and nothing is saved", async () => {
  const f = fake({ text: flagging(["idiot"]) });
  const { body } = await send(f, post(titled("Padel for idiots")));
  assertEquals([body.result, body.fields], ["rejected", ["title"]]);
  assert(!f.calls.includes("finish_activity_save"));
});

Deno.test("a standalone 'sex' title is rejected before OpenAI is called", async () => {
  const f = fake();
  const { body } = await send(f, post(titled("sex")));
  assertEquals([body.result, body.fields], ["rejected", ["title"]]);
  assert(!f.calls.includes("moderate_text"));
  assert(!f.calls.includes("finish_activity_save"));
  assertEquals(f.rpcArgs.fail_activity_save.p_result_code, "rejected");
  assertEquals(f.rpcArgs.fail_activity_save.p_retryable, false);
  // The matched word goes nowhere: not to the app, not to the logs.
  assertEquals(Object.keys(body).sort(), ["fields", "request_id", "result"]);
  assert(!JSON.stringify(f.logs).toLowerCase().includes("sex"));
});

Deno.test("explicit description or location is rejected with its field", async () => {
  const description = validBody();
  (description.activity as Record<string, unknown>).description =
    "Come for s.e.x and drinks";
  let { body } = await send(fake(), post(description));
  assertEquals([body.result, body.fields], ["rejected", ["description"]]);

  const location = validBody();
  (location.activity as Record<string, unknown>).location_name = "بيت السكس";
  ({ body } = await send(fake(), post(location)));
  assertEquals([body.result, body.fields], ["rejected", ["location"]]);
});

Deno.test("Arabic and English explicit titles are rejected", async () => {
  for (const title of ["سكس", "ليلة سكسي", "s3x night", "Padel سكس"]) {
    const f = fake();
    const { body } = await send(f, post(titled(title)));
    assertEquals([body.result, body.fields], ["rejected", ["title"]], title);
    assert(!f.calls.includes("finish_activity_save"), title);
  }
});

Deno.test("innocent titles that contain the letters still go to OpenAI and save", async () => {
  for (const title of ["Sussex padel", "Essex football", "Unisex yoga"]) {
    const f = fake();
    const { body } = await send(f, post(titled(title)));
    assertEquals(body.result, "saved", title);
    assert(f.calls.includes("moderate_text"), title);
  }
});
