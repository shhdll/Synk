import { assert, assertEquals } from "@std/assert";

import {
  IMAGE_CATEGORIES,
  imageBlockCategories,
  moderateImage,
  moderateText,
  MODERATION_MODEL,
  type ModerationOptions,
} from "./moderation.ts";

function categories(trueOnes: string[] = []) {
  const all = [
    "harassment",
    "harassment/threatening",
    "hate",
    "hate/threatening",
    "illicit",
    "illicit/violent",
    "self-harm",
    "self-harm/intent",
    "self-harm/instructions",
    "sexual",
    "sexual/minors",
    "violence",
    "violence/graphic",
  ];
  return Object.fromEntries(all.map((name) => [name, trueOnes.includes(name)]));
}

function reply(flagged: boolean, trueOnes: string[] = []) {
  return {
    id: "modr-1",
    model: MODERATION_MODEL,
    results: [{
      flagged,
      categories: categories(trueOnes),
      category_scores: Object.fromEntries(
        Object.keys(categories()).map((k) => [k, 0.01]),
      ),
    }],
  };
}

// Scripted fetch: each call takes the next answer.
function scripted(answers: (Response | Error | (() => Promise<Response>))[]) {
  const calls: { body: Record<string, unknown>; auth: string | null }[] = [];
  const fakeFetch = async (
    _url: string | URL | Request,
    init?: RequestInit,
  ) => {
    calls.push({
      body: JSON.parse(String(init?.body)),
      auth: new Headers(init?.headers).get("Authorization"),
    });
    const next = answers.shift();
    if (next === undefined) throw new Error("no more scripted answers");
    if (next instanceof Error) throw next;
    if (typeof next === "function") return await next();
    return next;
  };
  return { fetch: fakeFetch as typeof fetch, calls };
}

const ok = (body: unknown) =>
  new Response(JSON.stringify(body), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });

type Fetch = typeof globalThis.fetch;

function options(
  fetchFn: Fetch,
  extra: Partial<ModerationOptions> = {},
): ModerationOptions {
  let clock = 0;
  return {
    apiKey: "sk-test",
    fetch: fetchFn,
    timeoutMs: 50,
    now: () => clock,
    sleep: async (ms) => {
      clock += ms;
    },
    deadline: 25_000,
    ...extra,
  };
}

Deno.test("clean text is allowed (#11, #13)", async () => {
  const { fetch, calls } = scripted([ok(reply(false))]);
  assertEquals(await moderateText("Padel night", options(fetch)), {
    status: "allowed",
  });
  assertEquals(calls[0].body, {
    model: "omni-moderation-latest",
    input: "Padel night",
  });
  assertEquals(calls[0].auth, "Bearer sk-test");
});

Deno.test("flagged text is blocked, whatever the category (#12, #14)", async () => {
  for (const category of ["hate", "illicit", "sexual/minors", "harassment"]) {
    const { fetch } = scripted([ok(reply(true, [category]))]);
    assertEquals(await moderateText("x", options(fetch)), {
      status: "blocked",
    });
  }
});

Deno.test("the photo goes as a data URL; booleans decide (#26, #27)", async () => {
  const safe = scripted([ok(reply(false))]);
  assertEquals(
    await moderateImage("AAAA", [...IMAGE_CATEGORIES], options(safe.fetch)),
    { status: "allowed" },
  );
  assertEquals(safe.calls[0].body.input, [{
    type: "image_url",
    image_url: { url: "data:image/jpeg;base64,AAAA" },
  }]);

  for (const category of IMAGE_CATEGORIES) {
    const { fetch } = scripted([ok(reply(true, [category]))]);
    assertEquals(
      await moderateImage("AAAA", [...IMAGE_CATEGORIES], options(fetch)),
      { status: "blocked" },
    );
  }
});

Deno.test("photo categories outside the list don't block", async () => {
  const { fetch } = scripted([ok(reply(true, ["violence"]))]);
  const list = imageBlockCategories(
    "sexual,violence/graphic,self-harm,self-harm/intent,self-harm/instructions",
  );
  assertEquals(await moderateImage("AAAA", list, options(fetch)), {
    status: "allowed",
  });
});

Deno.test("the category list can't be switched off by mistake", () => {
  assertEquals(imageBlockCategories(undefined), [...IMAGE_CATEGORIES]);
  assertEquals(imageBlockCategories(""), [...IMAGE_CATEGORIES]);
  assertEquals(imageBlockCategories("sexual,typo"), [...IMAGE_CATEGORIES]);
  assertEquals(imageBlockCategories(" sexual , violence/graphic "), [
    "sexual",
    "violence/graphic",
  ]);
});

Deno.test("timeouts retry once, then fail closed (#41)", async () => {
  const slow = () =>
    new Promise<Response>((_, reject) =>
      setTimeout(() => reject(new DOMException("t", "AbortError")), 1)
    );
  const { fetch, calls } = scripted([slow, slow]);
  const verdict = await moderateText("x", options(fetch));
  assertEquals(verdict.status, "unavailable");
  assertEquals(calls.length, 2);
});

Deno.test("429 and 5xx retry once and can then succeed (#42, #44)", async () => {
  for (const status of [429, 500, 503]) {
    const { fetch, calls } = scripted([
      new Response("busy", { status, headers: { "retry-after": "1" } }),
      ok(reply(false)),
    ]);
    assertEquals(await moderateText("x", options(fetch)), {
      status: "allowed",
    });
    assertEquals(calls.length, 2);
  }
  const { fetch } = scripted([
    new Response("", { status: 503 }),
    new Response("", { status: 503 }),
  ]);
  assertEquals((await moderateText("x", options(fetch))).status, "unavailable");
});

Deno.test("401 or a missing key fails closed without retrying (#43)", async () => {
  const { fetch, calls } = scripted([new Response("no", { status: 401 })]);
  assertEquals(await moderateText("x", options(fetch)), {
    status: "unavailable",
    detail: "http_401",
  });
  assertEquals(calls.length, 1);

  const missing = scripted([]);
  assertEquals(
    await moderateText("x", options(missing.fetch, { apiKey: undefined })),
    { status: "unavailable", detail: "missing_key" },
  );
  assertEquals(missing.calls.length, 0);
});

Deno.test("malformed or empty answers fail closed (#45, #46)", async () => {
  const bad = [
    new Response("not json", { status: 200 }),
    ok({}),
    ok({ results: [] }),
    ok({ results: [{ flagged: "no", categories: {} }] }),
    ok({ results: [{ flagged: false, categories: { sexual: "false" } }] }),
    ok({ results: [{ flagged: false }] }),
  ];
  for (const response of bad) {
    const { fetch } = scripted([response]);
    assertEquals(
      (await moderateText("x", options(fetch))).status,
      "unavailable",
    );
  }
  // A configured image category missing from the answer.
  const { fetch } = scripted([
    ok({ results: [{ flagged: false, categories: { sexual: false } }] }),
  ]);
  assertEquals(
    (await moderateImage("AAAA", ["sexual", "violence"], options(fetch)))
      .status,
    "unavailable",
  );
});

Deno.test("OpenAI refusing the photo itself is an unreadable photo (#30)", async () => {
  const { fetch } = scripted([
    new Response('{"error":{"message":"invalid image"}}', { status: 400 }),
  ]);
  assertEquals(
    await moderateImage("AAAA", [...IMAGE_CATEGORIES], options(fetch)),
    { status: "unreadable_image" },
  );
});

Deno.test("no retry when the time is up (#47)", async () => {
  const { fetch, calls } = scripted([new Response("", { status: 503 })]);
  let clock = 24_500;
  const verdict = await moderateText("x", {
    apiKey: "sk-test",
    fetch,
    now: () => clock,
    sleep: async (ms) => {
      clock += ms;
    },
    deadline: 25_000,
  });
  assert(verdict.status === "unavailable");
  assertEquals(calls.length, 0);
});
