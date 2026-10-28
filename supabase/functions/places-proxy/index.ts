// supabase/functions/places-proxy/index.ts
//
// Proxies Google Places API (New) so the Places server key never reaches the
// Flutter app or the repository. Reads GOOGLE_PLACES_API_KEY from Supabase's
// secret store (set via `supabase secrets set`).
//
// JWT verification is ON (the Supabase default) — only a signed-in Synk user
// can call this function. Do not deploy with --no-verify-jwt.
//
// Three actions, chosen by the request body's "action" field:
//   { "action": "autocomplete", "input": "padel", "sessionToken": "..." }
//   { "action": "details", "placeId": "...", "sessionToken": "..." }
//   { "action": "poi", "placeId": "..." }
//
// The Details call intentionally requests only `id`, `formattedAddress` and
// `location` — Places Details Essentials pricing. It never requests
// `displayName`, which is Pro-tier. The venue name is expected to come from
// the autocomplete suggestion the caller already has (structuredFormat in the
// autocomplete response), not from this call.
//
// The poi action is for a place pin tapped on the map. There is no
// autocomplete suggestion to take the name from, so it also requests
// `displayName` and is billed at the Pro tier.

const GOOGLE_PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY");

// Riyadh, used to bias (not restrict) autocomplete results toward the city.
const RIYADH_BIAS = {
  circle: {
    center: { latitude: 24.7136, longitude: 46.6753 },
    radius: 30000.0, // metres
  },
};

const DETAILS_FIELD_MASK = "id,formattedAddress,location";
const POI_FIELD_MASK = "id,displayName,formattedAddress,location";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function handleAutocomplete(
  input: string,
  sessionToken: string | undefined,
  languageCode: string,
): Promise<Response> {
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    return jsonResponse({ suggestions: [] });
  }

  const payload: Record<string, unknown> = {
    input: trimmed,
    locationBias: RIYADH_BIAS,
    includedRegionCodes: ["sa"],
    languageCode: languageCode === "ar" ? "ar" : "en",
  };
  if (sessionToken) payload.sessionToken = sessionToken;

  const googleResponse = await fetch(
    "https://places.googleapis.com/v1/places:autocomplete",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY!,
      },
      body: JSON.stringify(payload),
    },
  );

  const data = await googleResponse.json();
  if (!googleResponse.ok) {
    console.error("Autocomplete error:", JSON.stringify(data));
    return jsonResponse(
      { error: "autocomplete_failed", detail: data },
      googleResponse.status,
    );
  }

  return jsonResponse(data);
}

async function handleDetails(
  placeId: string,
  sessionToken: string | undefined,
  languageCode: string,
  fieldMask = DETAILS_FIELD_MASK,
): Promise<Response> {
  if (!placeId) {
    return jsonResponse({ error: "placeId is required" }, 400);
  }

  const url = new URL(
    `https://places.googleapis.com/v1/places/${placeId}`,
  );
  if (sessionToken) url.searchParams.set("sessionToken", sessionToken);
  url.searchParams.set("languageCode", languageCode === "ar" ? "ar" : "en");

  const googleResponse = await fetch(url.toString(), {
    method: "GET",
    headers: {
      "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY!,
      // Hard-coded, not caller-supplied: this is what keeps us on the
      // Essentials pricing tier rather than Pro.
      "X-Goog-FieldMask": fieldMask,
    },
  });

  const data = await googleResponse.json();
  if (!googleResponse.ok) {
    console.error("Details error:", JSON.stringify(data));
    return jsonResponse(
      { error: "details_failed", detail: data },
      googleResponse.status,
    );
  }

  return jsonResponse(data);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!GOOGLE_PLACES_API_KEY) {
    console.error("GOOGLE_PLACES_API_KEY is not set.");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }

  const action = body.action;
  const sessionToken =
    typeof body.sessionToken === "string" ? body.sessionToken : undefined;
  const languageCode = body.languageCode === "ar" ? "ar" : "en";

  if (action === "autocomplete") {
    const input = typeof body.input === "string" ? body.input : "";
    return handleAutocomplete(input, sessionToken, languageCode);
  }

  if (action === "details") {
    const placeId = typeof body.placeId === "string" ? body.placeId : "";
    return handleDetails(placeId, sessionToken, languageCode);
  }

  if (action === "poi") {
    const placeId = typeof body.placeId === "string" ? body.placeId : "";
    return handleDetails(placeId, undefined, languageCode, POI_FIELD_MASK);
  }

  return jsonResponse({ error: "unknown_action" }, 400);
});
