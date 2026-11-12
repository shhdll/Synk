// Activity photo checks. The server accepts JPEG only (the app converts
// every photo to JPEG first). The photo is:
//   1. size-checked after base64 decoding (2 MB),
//   2. checked to start like a JPEG,
//   3. measured from its header BEFORE decoding (at most 4096 px a side and
//      4 megapixels), so a small file that would decode into a huge image
//      (a decompression bomb) is refused cheaply,
//   4. fully decoded with memory and resolution limits (a broken or fake
//      file fails here),
//   5. re-encoded to a fresh JPEG. That drops EXIF/GPS and any other
//      metadata, and anything hidden after the image data. The re-encoded
//      bytes are what gets moderated and stored.
import jpeg from "jpeg-js";

import { LIMITS } from "./contract.ts";

export const IMAGE_LIMITS = {
  maxSide: 4096,
  maxPixels: 4_000_000,
  // Decoding 4 MP as RGBA needs 16 MB; the rest is decoder overhead.
  maxMemoryMB: 64,
  quality: 85,
} as const;

export type ImageProblem =
  | "too_large"
  | "unsupported"
  | "corrupt"
  | "dimensions";

export type ImageResult =
  | { ok: true; jpeg: Uint8Array; width: number; height: number }
  | { ok: false; reason: ImageProblem };

export function decodeBase64(data: string): Uint8Array | null {
  try {
    const binary = atob(data);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

export function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

// Width and height from the JPEG frame header, without decoding.
// Null when the markers don't add up.
export function jpegDimensions(
  bytes: Uint8Array,
): { width: number; height: number } | null {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null;
  let offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] !== 0xff) return null;
    let marker = bytes[offset + 1];
    // Fill bytes.
    while (marker === 0xff && offset + 2 < bytes.length) {
      offset++;
      marker = bytes[offset + 1];
    }
    offset += 2;
    // Markers without a length.
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd8)) continue;
    // Start of scan or end of image before any frame header.
    if (marker === 0xda || marker === 0xd9) return null;
    if (offset + 2 > bytes.length) return null;
    const length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return null;
    // SOF0-SOF15, except DHT (C4), JPG (C8) and DAC (CC).
    if (
      marker >= 0xc0 && marker <= 0xcf &&
      marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc
    ) {
      if (length < 7) return null;
      const height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      const width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      return { width, height };
    }
    offset += length;
  }
  return null;
}

function looksLikeOtherImage(bytes: Uint8Array): boolean {
  const text = String.fromCharCode(...bytes.subarray(0, 12));
  return text.startsWith("\x89PNG") || text.startsWith("GIF8") ||
    (text.startsWith("RIFF") && text.slice(8, 12) === "WEBP") ||
    text.slice(4, 12).startsWith("ftyp"); // HEIC/HEIF/AVIF
}

export function processPhoto(base64: string): ImageResult {
  if (base64.length > LIMITS.imageBase64Chars) {
    return { ok: false, reason: "too_large" };
  }
  const bytes = decodeBase64(base64);
  if (bytes === null || bytes.length === 0) {
    return { ok: false, reason: "corrupt" };
  }
  if (bytes.length > LIMITS.imageBytes) {
    return { ok: false, reason: "too_large" };
  }

  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) {
    return {
      ok: false,
      reason: looksLikeOtherImage(bytes) ? "unsupported" : "corrupt",
    };
  }

  const size = jpegDimensions(bytes);
  if (size === null) return { ok: false, reason: "corrupt" };
  if (
    size.width === 0 || size.height === 0 ||
    size.width > IMAGE_LIMITS.maxSide || size.height > IMAGE_LIMITS.maxSide ||
    size.width * size.height > IMAGE_LIMITS.maxPixels
  ) {
    return { ok: false, reason: "dimensions" };
  }

  let decoded: { width: number; height: number; data: Uint8Array };
  try {
    decoded = jpeg.decode(bytes, {
      useTArray: true,
      formatAsRGBA: true,
      tolerantDecoding: false,
      maxResolutionInMP: IMAGE_LIMITS.maxPixels / 1_000_000,
      maxMemoryUsageInMB: IMAGE_LIMITS.maxMemoryMB,
    });
  } catch {
    return { ok: false, reason: "corrupt" };
  }
  if (
    decoded.width !== size.width || decoded.height !== size.height ||
    decoded.data.length !== decoded.width * decoded.height * 4
  ) {
    return { ok: false, reason: "corrupt" };
  }

  const encoded = jpeg.encode(
    { data: decoded.data, width: decoded.width, height: decoded.height },
    IMAGE_LIMITS.quality,
  );
  const output = new Uint8Array(encoded.data);
  if (output.length > LIMITS.imageBytes) {
    return { ok: false, reason: "too_large" };
  }
  return {
    ok: true,
    jpeg: output,
    width: decoded.width,
    height: decoded.height,
  };
}
