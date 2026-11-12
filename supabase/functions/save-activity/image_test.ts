import { assert, assertEquals } from "@std/assert";

import { LIMITS } from "./contract.ts";
import {
  decodeBase64,
  encodeBase64,
  IMAGE_LIMITS,
  jpegDimensions,
  processPhoto,
} from "./image.ts";
import { makeJpeg } from "./test_helpers.ts";

// Puts an EXIF block with GPS-looking content right after the start marker.
function withExif(bytes: Uint8Array): Uint8Array {
  const payload = new TextEncoder().encode(
    "Exif\0\0GPSLatitude=24.7136;GPSLongitude=46.6753",
  );
  const length = payload.length + 2;
  const segment = new Uint8Array([
    0xff,
    0xe1,
    length >> 8,
    length & 255,
    ...payload,
  ]);
  return new Uint8Array([
    ...bytes.subarray(0, 2),
    ...segment,
    ...bytes.subarray(2),
  ]);
}

function contains(haystack: Uint8Array, needle: string): boolean {
  return new TextDecoder("latin1").decode(haystack).includes(needle);
}

Deno.test("a safe JPEG is decoded and re-encoded (#26)", () => {
  const result = processPhoto(encodeBase64(makeJpeg(800, 400)));
  assert(result.ok);
  assertEquals([result.width, result.height], [800, 400]);
  assertEquals([...result.jpeg.subarray(0, 3)], [0xff, 0xd8, 0xff]);
});

Deno.test("EXIF and GPS data are removed (A9)", () => {
  const tagged = withExif(makeJpeg(400, 200));
  assert(contains(tagged, "GPSLatitude"));
  const result = processPhoto(encodeBase64(tagged));
  assert(result.ok);
  assert(!contains(result.jpeg, "GPSLatitude"));
  assert(!contains(result.jpeg, "Exif"));
});

Deno.test("data hidden after the image is dropped (#32)", () => {
  const hidden = new TextEncoder().encode("<?php system($_GET['x']); ?>");
  const result = processPhoto(
    encodeBase64(new Uint8Array([...makeJpeg(200, 100), ...hidden])),
  );
  assert(result.ok);
  assert(!contains(result.jpeg, "<?php"));
});

Deno.test("PNG, GIF, WebP and HEIC are unsupported (#29)", () => {
  const starts = [
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    [...new TextEncoder().encode("GIF89a")],
    [...new TextEncoder().encode("RIFF\0\0\0\0WEBPVP8 ")],
    [0, 0, 0, 0x18, ...new TextEncoder().encode("ftypheic")],
  ];
  for (const start of starts) {
    const result = processPhoto(
      encodeBase64(new Uint8Array([...start, ...new Uint8Array(64)])),
    );
    assertEquals(result, { ok: false, reason: "unsupported" });
  }
});

Deno.test("empty, random, truncated and renamed files are corrupt (#30-#32)", () => {
  const good = makeJpeg(400, 200);
  const cases = [
    new Uint8Array(),
    crypto.getRandomValues(new Uint8Array(500)),
    good.subarray(0, Math.floor(good.length / 2)),
    new TextEncoder().encode("#!/bin/sh\nrm -rf /\n"),
    new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 1, 2, 3]),
  ];
  for (const bytes of cases) {
    const result = processPhoto(encodeBase64(bytes));
    assert(
      !result.ok && (result.reason === "corrupt"),
      `${bytes.length} bytes → ${JSON.stringify(result)}`,
    );
  }
});

Deno.test("a decompression bomb is refused from its header (A8)", () => {
  // A real small JPEG whose frame header claims 20000 x 20000.
  const bytes = makeJpeg(64, 64);
  const size = jpegDimensions(bytes)!;
  assertEquals(size, { width: 64, height: 64 });
  for (let i = 2; i < bytes.length - 8; i++) {
    if (bytes[i] === 0xff && bytes[i + 1] === 0xc0) {
      bytes[i + 5] = 20000 >> 8;
      bytes[i + 6] = 20000 & 255;
      bytes[i + 7] = 20000 >> 8;
      bytes[i + 8] = 20000 & 255;
      break;
    }
  }
  assertEquals(processPhoto(encodeBase64(bytes)), {
    ok: false,
    reason: "dimensions",
  });
  // Too many pixels without either side being too long.
  const wide = makeJpeg(64, 64);
  for (let i = 2; i < wide.length - 8; i++) {
    if (wide[i] === 0xff && wide[i + 1] === 0xc0) {
      wide[i + 5] = 4000 >> 8;
      wide[i + 6] = 4000 & 255;
      wide[i + 7] = 4000 >> 8;
      wide[i + 8] = 4000 & 255;
      break;
    }
  }
  assertEquals(processPhoto(encodeBase64(wide)), {
    ok: false,
    reason: "dimensions",
  });
});

Deno.test("over 2 MB after decoding is too large (#28)", () => {
  const bytes = new Uint8Array(LIMITS.imageBytes + 1);
  bytes.set([0xff, 0xd8, 0xff]);
  assertEquals(processPhoto(encodeBase64(bytes)), {
    ok: false,
    reason: "too_large",
  });
});

Deno.test("base64 round trip", () => {
  const bytes = crypto.getRandomValues(new Uint8Array(65_536));
  assertEquals(decodeBase64(encodeBase64(bytes)), bytes);
  assertEquals(decodeBase64("%%%"), null);
});

Deno.test("a full-size photo fits the Edge Function CPU limit (#47)", () => {
  const photo = makeJpeg(1600, 800);
  const base64 = encodeBase64(photo);
  const runs = 3;
  const started = performance.now();
  for (let i = 0; i < runs; i++) assert(processPhoto(base64).ok);
  const average = (performance.now() - started) / runs;
  console.log(
    `1600x800 decode + re-encode: ${
      average.toFixed(0)
    } ms (${photo.length} bytes)`,
  );
  // Supabase allows 2 s of CPU per request; keep well inside it.
  assert(average < 1000, `${average} ms is too close to the 2 s CPU limit`);
  assert(IMAGE_LIMITS.maxPixels >= 1600 * 800);
});
