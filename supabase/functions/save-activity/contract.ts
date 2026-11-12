// The save-activity request contract: strict checks, text cleanup and the
// payload hash. Nothing here talks to the network, so it is unit-tested
// directly (contract_test.ts).

export const LIMITS = {
  // 2.9 MiB for the whole request body.
  bodyBytes: Math.floor(2.9 * 1024 * 1024),
  // 2 MB for the decoded photo, and the base64 length that decodes to it.
  imageBytes: 2_000_000,
  imageBase64Chars: Math.ceil(2_000_000 / 3) * 4,
  // Same limits as ActivityConstants in the app.
  title: 30,
  description: 500,
  locationName: 80,
  locationAddress: 300,
  categoryEmoji: 16,
  categoryLabel: 40,
  minParticipants: 2,
  maxParticipants: 20,
} as const;

export type Operation = "create" | "update";
export type PhotoAction = "none" | "keep" | "remove" | "replace";
export type Field =
  | "title"
  | "description"
  | "location"
  | "time"
  | "capacity"
  | "photo";

export interface ActivityFields {
  title: string;
  description: string | null;
  starts_at: string;
  ends_at: string;
  location_name: string;
  location_address: string | null;
  latitude: number | null;
  longitude: number | null;
  max_participants: number;
  is_public: boolean;
  setting: "indoor" | "outdoor" | null;
  category_emoji: string | null;
  category_label: string | null;
}

export interface SaveRequest {
  operation: Operation;
  requestId: string;
  activityId: string;
  expectedVersion: number | null;
  activity: ActivityFields;
  photoAction: PhotoAction;
  jpegBase64: string | null;
}

// "contract": the app sent something it never should (a bug or a forged
// request) → HTTP 400. "fields": something the host can fix → result
// "invalid" with the fields.
export type ParseResult =
  | { ok: true; request: SaveRequest }
  | { ok: false; kind: "contract"; detail: string }
  | { ok: false; kind: "fields"; fields: Field[] };

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const UUID_V4 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const BASE64 = /^[A-Za-z0-9+/]*={0,2}$/;

const TOP_KEYS = [
  "operation",
  "request_id",
  "activity_id",
  "expected_version",
  "activity",
  "photo",
];
const ACTIVITY_KEYS = [
  "title",
  "description",
  "starts_at",
  "ends_at",
  "location_name",
  "location_address",
  "latitude",
  "longitude",
  "max_participants",
  "is_public",
  "setting",
  "category_emoji",
  "category_label",
];

// Zero-width, direction-control, soft hyphen and other invisible
// characters, plus control characters (newlines are allowed separately).
const INVISIBLE =
  /[\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\u3164\uFE00-\uFE0F\uFEFF\uFFA0]/gu;
const CONTROL_EXCEPT_NEWLINE = /[\u0000-\u0009\u000B-\u001F\u007F-\u009F]/gu;
const CONTROL = /[\u0000-\u001F\u007F-\u009F]/gu;

// The title rule the app applies: letters in any script (Arabic, English
// or both, with their marks), digits 0-9, & ' , and spaces.
const TITLE_ALLOWED = /^[\p{L}\p{M}0-9&', ]*$/u;

const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

// Counts characters the way the app's fields do (grapheme clusters).
export function characterCount(value: string): number {
  let count = 0;
  for (const _ of segmenter.segment(value)) count++;
  return count;
}

// What is stored: NFC, no invisible or control characters, trimmed.
export function cleanText(value: string, allowNewlines = false): string {
  return value
    .normalize("NFC")
    .replace(INVISIBLE, "")
    .replace(allowNewlines ? CONTROL_EXCEPT_NEWLINE : CONTROL, "")
    .replace(/\r\n?/g, "\n")
    .trim();
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(
  value: Record<string, unknown>,
  allowed: readonly string[],
  required: readonly string[],
): boolean {
  const keys = Object.keys(value);
  return keys.every((key) => allowed.includes(key)) &&
    required.every((key) => keys.includes(key));
}

function nullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

// Parses a request body that is already valid JSON. The photo isn't
// decoded here; only its length and characters are checked.
export function parseSaveRequest(body: unknown): ParseResult {
  const fail = (detail: string): ParseResult => ({
    ok: false,
    kind: "contract",
    detail,
  });

  if (!isPlainObject(body)) return fail("body");
  if (
    !hasExactKeys(body, TOP_KEYS, [
      "operation",
      "request_id",
      "activity_id",
      "activity",
      "photo",
    ])
  ) {
    return fail("keys");
  }

  const operation = body.operation;
  if (operation !== "create" && operation !== "update") {
    return fail("operation");
  }

  const requestId = body.request_id;
  const activityId = body.activity_id;
  if (typeof requestId !== "string" || !UUID_V4.test(requestId)) {
    return fail("request_id");
  }
  if (typeof activityId !== "string" || !UUID.test(activityId)) {
    return fail("activity_id");
  }
  if (operation === "create" && !UUID_V4.test(activityId)) {
    return fail("activity_id");
  }

  const expected = body.expected_version;
  if (operation === "update") {
    if (
      typeof expected !== "number" || !Number.isInteger(expected) ||
      expected < 1
    ) {
      return fail("expected_version");
    }
  } else if (expected !== undefined) {
    return fail("expected_version");
  }

  // Photo.
  const photo = body.photo;
  if (!isPlainObject(photo) || typeof photo.action !== "string") {
    return fail("photo");
  }
  const action = photo.action as PhotoAction;
  const allowedActions: PhotoAction[] = operation === "create"
    ? ["none", "replace"]
    : ["keep", "remove", "replace"];
  if (!allowedActions.includes(action)) return fail("photo.action");
  let jpegBase64: string | null = null;
  if (action === "replace") {
    if (
      !hasExactKeys(photo, ["action", "jpeg_base64"], ["action", "jpeg_base64"])
    ) {
      return fail("photo.keys");
    }
    const data = photo.jpeg_base64;
    if (typeof data !== "string" || data.length === 0) {
      return fail("photo.data");
    }
    if (data.length > LIMITS.imageBase64Chars) {
      return { ok: false, kind: "fields", fields: ["photo"] };
    }
    if (data.length % 4 !== 0 || !BASE64.test(data)) return fail("photo.data");
    jpegBase64 = data;
  } else if (!hasExactKeys(photo, ["action"], ["action"])) {
    return fail("photo.keys");
  }

  // Activity fields: exactly the allowed keys, with the right types.
  const raw = body.activity;
  if (!isPlainObject(raw) || !hasExactKeys(raw, ACTIVITY_KEYS, ACTIVITY_KEYS)) {
    return fail("activity.keys");
  }
  if (
    typeof raw.title !== "string" ||
    !nullableString(raw.description) ||
    typeof raw.starts_at !== "string" ||
    typeof raw.ends_at !== "string" ||
    typeof raw.location_name !== "string" ||
    !nullableString(raw.location_address) ||
    !(raw.latitude === null || typeof raw.latitude === "number") ||
    !(raw.longitude === null || typeof raw.longitude === "number") ||
    typeof raw.max_participants !== "number" ||
    typeof raw.is_public !== "boolean" ||
    !(raw.setting === null || raw.setting === "indoor" ||
      raw.setting === "outdoor") ||
    !nullableString(raw.category_emoji) ||
    !nullableString(raw.category_label)
  ) {
    return fail("activity.types");
  }

  const fields = new Set<Field>();

  const title = cleanText(raw.title);
  if (
    title.length === 0 ||
    characterCount(title) > LIMITS.title ||
    !TITLE_ALLOWED.test(title)
  ) {
    fields.add("title");
  }

  const description = raw.description === null
    ? null
    : cleanText(raw.description, true) || null;
  if (
    description !== null && characterCount(description) > LIMITS.description
  ) {
    fields.add("description");
  }

  const locationName = cleanText(raw.location_name);
  if (
    locationName.length === 0 ||
    characterCount(locationName) > LIMITS.locationName
  ) {
    fields.add("location");
  }
  const locationAddress = raw.location_address === null
    ? null
    : cleanText(raw.location_address) || null;
  if (
    locationAddress !== null &&
    characterCount(locationAddress) > LIMITS.locationAddress
  ) {
    fields.add("location");
  }
  const latitude = raw.latitude as number | null;
  const longitude = raw.longitude as number | null;
  if (
    (latitude === null) !== (longitude === null) ||
    (latitude !== null &&
      (!Number.isFinite(latitude) || latitude < -90 || latitude > 90)) ||
    (longitude !== null &&
      (!Number.isFinite(longitude) || longitude < -180 || longitude > 180))
  ) {
    fields.add("location");
  }

  const startsAt = Date.parse(raw.starts_at);
  const endsAt = Date.parse(raw.ends_at);
  if (
    !/^\d{4}-\d{2}-\d{2}T/.test(raw.starts_at) ||
    !/^\d{4}-\d{2}-\d{2}T/.test(raw.ends_at) ||
    Number.isNaN(startsAt) || Number.isNaN(endsAt) || endsAt <= startsAt
  ) {
    fields.add("time");
  }

  const capacity = raw.max_participants;
  if (
    !Number.isInteger(capacity) ||
    capacity < LIMITS.minParticipants ||
    capacity > LIMITS.maxParticipants
  ) {
    fields.add("capacity");
  }

  const categoryEmoji = raw.category_emoji === null
    ? null
    : cleanText(raw.category_emoji) || null;
  const categoryLabel = raw.category_label === null
    ? null
    : cleanText(raw.category_label) || null;
  if (
    (categoryEmoji !== null &&
      characterCount(categoryEmoji) > LIMITS.categoryEmoji) ||
    (categoryLabel !== null &&
      characterCount(categoryLabel) > LIMITS.categoryLabel)
  ) {
    return fail("activity.category");
  }

  if (fields.size > 0) {
    return { ok: false, kind: "fields", fields: [...fields] };
  }

  return {
    ok: true,
    request: {
      operation,
      requestId,
      activityId,
      expectedVersion: operation === "update" ? expected as number : null,
      activity: {
        title,
        description,
        starts_at: new Date(startsAt).toISOString(),
        ends_at: new Date(endsAt).toISOString(),
        location_name: locationName,
        location_address: locationAddress,
        latitude,
        longitude,
        max_participants: capacity,
        is_public: raw.is_public,
        setting: raw.setting as ActivityFields["setting"],
        category_emoji: categoryEmoji,
        category_label: categoryLabel,
      },
      photoAction: action,
      jpegBase64,
    },
  };
}

// Stable JSON: object keys sorted at every level.
function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (isPlainObject(value)) {
    return `{${
      Object.keys(value)
        .sort()
        .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
        .join(",")
    }}`;
  }
  return JSON.stringify(value);
}

async function sha256Hex(data: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(data),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

// SHA-256 of the cleaned-up request. The photo goes in as its own hash,
// so the same photo always gives the same request hash.
export async function payloadHash(request: SaveRequest): Promise<string> {
  return sha256Hex(canonicalJson({
    operation: request.operation,
    activity_id: request.activityId,
    expected_version: request.expectedVersion,
    activity: request.activity,
    photo: {
      action: request.photoAction,
      sha256: request.jpegBase64 === null
        ? null
        : await sha256Hex(request.jpegBase64),
    },
  }));
}

// ---- The extra copy sent for moderation ----------------------------------------------

const HARAKAT =
  /[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED]/gu;
const TATWEEL = /\u0640/gu;

// A cleaned-up copy that makes common tricks visible to the model:
// compatibility forms (fullwidth, styled letters) folded, harakat and
// stretched letters removed, punctuation and emoji between letters dropped,
// spaced-out single letters joined, and letters repeated 3+ times cut to 2.
export function moderationVariant(value: string): string {
  let text = value
    .normalize("NFKC")
    .toLowerCase()
    .replace(INVISIBLE, "")
    .replace(HARAKAT, "")
    .replace(TATWEEL, "")
    .replace(/[^\p{L}\p{N}\s]/gu, "")
    .replace(/\s+/gu, " ")
    .trim();

  // "f u c k" → "fuck": single letters separated by single spaces.
  let previous: string;
  do {
    previous = text;
    text = text.replace(
      /(?<![\p{L}\p{N}])(\p{L}) (?=\p{L}(?![\p{L}\p{N}]))/gu,
      "$1",
    );
  } while (text !== previous);

  return text.replace(/(\p{L})\1{2,}/gu, "$1$1");
}

// What is sent for one text field: the original, plus the cleaned copy
// when it differs.
export function moderationInput(value: string): string {
  const variant = moderationVariant(value);
  return variant.length > 0 && variant !== value.toLowerCase()
    ? `${value}\n${variant}`
    : value;
}
