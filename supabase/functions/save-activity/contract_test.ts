import { assert, assertEquals, assertNotEquals } from "@std/assert";

import {
  characterCount,
  cleanText,
  LIMITS,
  moderationInput,
  moderationVariant,
  parseSaveRequest,
  payloadHash,
} from "./contract.ts";
import { validBody } from "./test_helpers.ts";

function withActivity(changes: Record<string, unknown>) {
  const body = validBody();
  return { ...body, activity: { ...(body.activity as object), ...changes } };
}

Deno.test("a valid create passes and is cleaned up", () => {
  const result = parseSaveRequest(
    withActivity({ title: "  Padel\u200B night  " }),
  );
  assert(result.ok);
  assertEquals(result.request.activity.title, "Padel night");
  assertEquals(result.request.expectedVersion, null);
});

Deno.test("unknown or missing keys are contract errors (#7, A6, #76)", () => {
  for (
    const body of [
      { ...validBody(), host_id: "x" },
      { ...validBody(), photo_url: "https://evil.example/x.jpg" },
      withActivity({ activity_code: "123456" }),
      withActivity({ participants_count: 99 }),
      {
        ...validBody(),
        photo: { action: "replace", url: "https://evil.example/x.jpg" },
      },
      (() => {
        const body = validBody();
        delete (body.activity as Record<string, unknown>).title;
        return body;
      })(),
    ]
  ) {
    const result = parseSaveRequest(body);
    assert(!result.ok && result.kind === "contract", JSON.stringify(body));
  }
});

Deno.test("ids must be UUIDs; request ids must be v4", () => {
  for (
    const body of [
      validBody({ request_id: "not-a-uuid" }),
      validBody({ request_id: "6f1c8a52-3b8e-1a8f-9d6e-1c2b3a4d5e6f" }),
      validBody({ activity_id: "'; drop table activities; --" }),
    ]
  ) {
    const result = parseSaveRequest(body);
    assert(!result.ok && result.kind === "contract");
  }
});

Deno.test("create and update have different required parts", () => {
  assert(!parseSaveRequest(validBody({ expected_version: 3 })).ok);
  assert(!parseSaveRequest(validBody({ operation: "update" })).ok);
  assert(
    !parseSaveRequest(validBody({ operation: "update", expected_version: 0 }))
      .ok,
  );
  assert(!parseSaveRequest(validBody({ photo: { action: "keep" } })).ok);
  assert(
    !parseSaveRequest(
      validBody({
        operation: "update",
        expected_version: 2,
        photo: { action: "none" },
      }),
    ).ok,
  );
  const update = parseSaveRequest(
    validBody({
      operation: "update",
      expected_version: 2,
      photo: { action: "keep" },
    }),
  );
  assert(update.ok);
  assertEquals(update.request.expectedVersion, 2);
});

Deno.test("fixable problems name their fields (#18, #23)", () => {
  const cases: [Record<string, unknown>, string][] = [
    [{ title: "   " }, "title"],
    [{ title: "x".repeat(LIMITS.title + 1) }, "title"],
    [{ title: "بادل، مساء" }, "title"],
    [{ title: "بادل ٧ مساء" }, "title"],
    [{ title: "ب".repeat(LIMITS.title + 1) }, "title"],
    [{ title: "Padel <script>" }, "title"],
    [{ description: "x".repeat(LIMITS.description + 1) }, "description"],
    [{ location_name: " \t " }, "location"],
    [{ location_name: "x".repeat(LIMITS.locationName + 1) }, "location"],
    [{ latitude: 200 }, "location"],
    [{ latitude: null }, "location"],
    [{ ends_at: "2026-12-01T16:00:00.000Z" }, "time"],
    [{ starts_at: "tomorrow" }, "time"],
    [{ max_participants: 1 }, "capacity"],
    [{ max_participants: 21 }, "capacity"],
    [{ max_participants: 4.5 }, "capacity"],
  ];
  for (const [changes, field] of cases) {
    const result = parseSaveRequest(withActivity(changes));
    assert(!result.ok && result.kind === "fields", JSON.stringify(changes));
    assert(
      result.fields.includes(field as never),
      `${JSON.stringify(changes)} → ${result.fields}`,
    );
  }
});

Deno.test("empty description becomes null and isn't checked (#17)", () => {
  const result = parseSaveRequest(withActivity({ description: "  \n " }));
  assert(result.ok);
  assertEquals(result.request.activity.description, null);
});

Deno.test("an oversized photo is a photo field problem before decoding (#28)", () => {
  const big = "A".repeat(LIMITS.imageBase64Chars + 4);
  const result = parseSaveRequest(
    validBody({ photo: { action: "replace", jpeg_base64: big } }),
  );
  assert(!result.ok && result.kind === "fields");
  assertEquals(result.fields, ["photo"]);
});

Deno.test("photo data must be base64", () => {
  const result = parseSaveRequest(
    validBody({ photo: { action: "replace", jpeg_base64: "not base64!" } }),
  );
  assert(!result.ok && result.kind === "contract");
});

Deno.test("cleanText removes invisible and control characters (#24)", () => {
  assertEquals(cleanText("a\u200Bb\u202Ec\u0000d"), "abcd");
  assertEquals(cleanText("line\r\nnext", true), "line\nnext");
  assertEquals(cleanText("e\u0301"), "é");
  assertEquals(characterCount("👍🏽ab"), 3);
});

Deno.test("the moderation copy undoes common tricks (#16, #24)", () => {
  assertEquals(moderationVariant("f.u.c.k"), "fuck");
  assertEquals(moderationVariant("f u c k you"), "fuck you");
  assertEquals(moderationVariant("shiiiiit"), "shiit");
  assertEquals(moderationVariant("ＦＵＣＫ"), "fuck");
  assertEquals(moderationVariant("قَتْل"), "قتل");
  assertEquals(moderationVariant("قـــتل"), "قتل");
  assertEquals(moderationVariant("💩 padel 🔥"), "padel");
  assertEquals(moderationInput("Padel night"), "Padel night");
  assertEquals(moderationInput("f.u.c.k"), "f.u.c.k\nfuck");
});

Deno.test("the payload hash follows the cleaned content", async () => {
  const a = parseSaveRequest(validBody());
  const b = parseSaveRequest(withActivity({ title: " Padel night\u200B " }));
  const c = parseSaveRequest(withActivity({ title: "Padel day" }));
  const d = parseSaveRequest(
    validBody({ photo: { action: "replace", jpeg_base64: "AAAA" } }),
  );
  assert(a.ok && b.ok && c.ok && d.ok);
  assertEquals(await payloadHash(a.request), await payloadHash(b.request));
  assertNotEquals(await payloadHash(a.request), await payloadHash(c.request));
  assertNotEquals(await payloadHash(a.request), await payloadHash(d.request));
  assert(/^[0-9a-f]{64}$/.test(await payloadHash(a.request)));
});

Deno.test("English, Arabic and mixed titles are allowed", () => {
  for (
    const title of [
      "Padel night",
      "ليلة بادل",
      "بادل night مع Sara",
      "Coffee & كتب, 7 pm",
      "قَهْوَة الصباح",
      "قـــهوة",
      "Ahmad's بادل",
    ]
  ) {
    const result = parseSaveRequest(withActivity({ title }));
    assert(result.ok, title);
    assertEquals(result.request.activity.title, title);
  }
});

Deno.test("Arabic titles still follow the length rule", () => {
  assert(
    parseSaveRequest(withActivity({ title: "ب".repeat(LIMITS.title) })).ok,
  );
  // Harakat are part of a character, so they don't add to the count.
  assert(
    parseSaveRequest(withActivity({ title: "بَ".repeat(LIMITS.title) })).ok,
  );
});

Deno.test("an Arabic title's moderation copy drops harakat and stretched letters", () => {
  assertEquals(moderationInput("قَهْوَة"), "قَهْوَة\nقهوة");
  assertEquals(moderationInput("ليلة بادل"), "ليلة بادل");
});
