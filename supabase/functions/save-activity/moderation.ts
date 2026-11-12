// OpenAI moderation (omni-moderation-latest) for activity text and photos.
//
// Version 1 uses only OpenAI's own true/false decisions, never score
// thresholds:
//   * text fields are blocked when `flagged` is true (every category);
//   * a photo is blocked when any category in the configured list is true.
//     The default list is the six categories OpenAI applies to images;
//     the IMAGE_BLOCK_CATEGORIES secret can narrow it after calibration
//     (for example dropping "violence" if ordinary sports photos trip it).
//
// Fails closed: anything other than a clear, well-formed answer for every
// input counts as "unavailable", and nothing is saved.

export const MODERATION_MODEL = "omni-moderation-latest";
export const MODERATION_URL = "https://api.openai.com/v1/moderations";

export const IMAGE_CATEGORIES = [
  "sexual",
  "violence",
  "violence/graphic",
  "self-harm",
  "self-harm/intent",
  "self-harm/instructions",
] as const;

export type ImageCategory = typeof IMAGE_CATEGORIES[number];

// The configured list. Unknown names or an empty value fall back to all
// six, so a typo can never switch photo checks off.
export function imageBlockCategories(
  setting: string | undefined,
): ImageCategory[] {
  if (!setting || setting.trim() === "") return [...IMAGE_CATEGORIES];
  const names = setting.split(",").map((name) => name.trim()).filter(Boolean);
  if (
    names.length === 0 ||
    names.some((name) =>
      !(IMAGE_CATEGORIES as readonly string[]).includes(name)
    )
  ) {
    return [...IMAGE_CATEGORIES];
  }
  return names as ImageCategory[];
}

export type Verdict =
  | { status: "allowed" }
  | { status: "blocked" }
  // The photo itself was refused by OpenAI as not an image it can read.
  | { status: "unreadable_image" }
  | { status: "unavailable"; detail: string };

export interface ModerationOptions {
  apiKey: string | undefined;
  fetch?: typeof fetch;
  // Per call, and the time left for the whole save.
  timeoutMs?: number;
  deadline?: number;
  now?: () => number;
  sleep?: (ms: number) => Promise<void>;
}

interface ModerationResult {
  flagged: boolean;
  categories: Record<string, boolean>;
}

type CallOutcome =
  | { kind: "ok"; result: ModerationResult }
  | { kind: "retry"; detail: string; waitMs: number }
  | { kind: "fail"; detail: string; status?: number };

function parseResult(body: unknown): ModerationResult | null {
  if (typeof body !== "object" || body === null) return null;
  const results = (body as { results?: unknown }).results;
  if (!Array.isArray(results) || results.length < 1) return null;
  const first = results[0] as Record<string, unknown>;
  if (typeof first !== "object" || first === null) return null;
  if (typeof first.flagged !== "boolean") return null;
  const categories = first.categories;
  if (
    typeof categories !== "object" || categories === null ||
    Array.isArray(categories)
  ) {
    return null;
  }
  for (const value of Object.values(categories as Record<string, unknown>)) {
    if (typeof value !== "boolean") return null;
  }
  return {
    flagged: first.flagged,
    categories: categories as Record<string, boolean>,
  };
}

async function callOnce(
  input: unknown,
  options: Required<Pick<ModerationOptions, "fetch">> & ModerationOptions,
  timeoutMs: number,
): Promise<CallOutcome> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await options.fetch(MODERATION_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${options.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model: MODERATION_MODEL, input }),
      signal: controller.signal,
    });
    if (response.status === 429 || response.status >= 500) {
      await response.body?.cancel();
      const retryAfter = Number(response.headers.get("retry-after"));
      return {
        kind: "retry",
        detail: `http_${response.status}`,
        waitMs: Number.isFinite(retryAfter) && retryAfter > 0
          ? Math.min(retryAfter * 1000, 2000)
          : 500,
      };
    }
    if (!response.ok) {
      await response.body?.cancel();
      return {
        kind: "fail",
        detail: `http_${response.status}`,
        status: response.status,
      };
    }
    let body: unknown;
    try {
      body = await response.json();
    } catch {
      return { kind: "fail", detail: "bad_json" };
    }
    const result = parseResult(body);
    return result === null
      ? { kind: "fail", detail: "bad_shape" }
      : { kind: "ok", result };
  } catch (error) {
    const aborted = error instanceof DOMException &&
      error.name === "AbortError";
    return {
      kind: "retry",
      detail: aborted ? "timeout" : "network",
      waitMs: 300,
    };
  } finally {
    clearTimeout(timer);
  }
}

// One input, with at most one retry for timeouts, 429s, 5xx and network
// errors, inside the time left.
async function moderate(input: unknown, options: ModerationOptions): Promise<
  { kind: "ok"; result: ModerationResult } | {
    kind: "fail";
    detail: string;
    status?: number;
  }
> {
  if (!options.apiKey) return { kind: "fail", detail: "missing_key" };
  const now = options.now ?? Date.now;
  const sleep = options.sleep ??
    ((ms: number) => new Promise((r) => setTimeout(r, ms)));
  const resolved = { ...options, fetch: options.fetch ?? fetch };
  const perCall = options.timeoutMs ?? 10_000;
  const deadline = options.deadline ?? now() + 25_000;

  let last = "unknown";
  for (let attempt = 0; attempt < 2; attempt++) {
    const left = deadline - now();
    if (left < 1000) {
      return { kind: "fail", detail: `out_of_time_after_${last}` };
    }
    const outcome = await callOnce(input, resolved, Math.min(perCall, left));
    if (outcome.kind !== "retry") return outcome;
    last = outcome.detail;
    if (attempt === 0) {
      if (deadline - now() < outcome.waitMs + 1000) break;
      await sleep(outcome.waitMs);
    }
  }
  return { kind: "fail", detail: last };
}

export async function moderateText(
  text: string,
  options: ModerationOptions,
): Promise<Verdict> {
  const outcome = await moderate(text, options);
  if (outcome.kind === "fail") {
    return { status: "unavailable", detail: outcome.detail };
  }
  return outcome.result.flagged ? { status: "blocked" } : { status: "allowed" };
}

export async function moderateImage(
  jpegBase64: string,
  blockCategories: ImageCategory[],
  options: ModerationOptions,
): Promise<Verdict> {
  const outcome = await moderate(
    [{
      type: "image_url",
      image_url: { url: `data:image/jpeg;base64,${jpegBase64}` },
    }],
    options,
  );
  if (outcome.kind === "fail") {
    // OpenAI couldn't read the photo itself: not something to retry.
    if (outcome.status === 400) return { status: "unreadable_image" };
    return { status: "unavailable", detail: outcome.detail };
  }
  const categories = outcome.result.categories;
  // A configured category missing from the answer is treated as unknown.
  for (const name of blockCategories) {
    if (typeof categories[name] !== "boolean") {
      return { status: "unavailable", detail: `missing_category_${name}` };
    }
  }
  return blockCategories.some((name) => categories[name])
    ? { status: "blocked" }
    : { status: "allowed" };
}
