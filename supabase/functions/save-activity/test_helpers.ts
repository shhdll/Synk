// Shared fixtures for the save-activity tests (not a test file itself).
import jpeg from "jpeg-js";

export function validBody(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    operation: "create",
    request_id: "6f1c8a52-3b8e-4a8f-9d6e-1c2b3a4d5e6f",
    activity_id: "0b6d4a2e-9c1f-4e7a-8b5d-2f3e4a5b6c7d",
    activity: {
      title: "Padel night",
      description: "Friendly doubles, all levels",
      starts_at: "2026-12-01T17:00:00.000Z",
      ends_at: "2026-12-01T19:00:00.000Z",
      location_name: "Kingdom Arena",
      location_address: "Riyadh",
      latitude: 24.7,
      longitude: 46.6,
      max_participants: 4,
      is_public: true,
      setting: "indoor",
      category_emoji: null,
      category_label: null,
    },
    photo: { action: "none" },
    ...overrides,
  };
}

// A photo-like JPEG (gradients plus noise, the slow case for a codec).
export function makeJpeg(width = 1600, height = 800, quality = 85): Uint8Array {
  const data = new Uint8Array(width * height * 4);
  let seed = 7;
  for (let i = 0; i < width * height; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    const x = i % width;
    const y = Math.floor(i / width);
    data[i * 4] = (x * 255 / width + (seed & 31)) & 255;
    data[i * 4 + 1] = (y * 255 / height + (seed >> 5 & 31)) & 255;
    data[i * 4 + 2] = ((x + y) & 255) ^ (seed >> 10 & 15);
    data[i * 4 + 3] = 255;
  }
  return new Uint8Array(jpeg.encode({ data, width, height }, quality).data);
}
