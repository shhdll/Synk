// "Is this evening nice where they are?" for the nice_weather nudge
// (supabase/migrations/20261121100000_marketing_nudges.sql). Asks Open-Meteo,
// which needs no key, about many places in one request.

export type Spot = { latitude: number; longitude: number };
export type NiceSpot = Spot & { temperature: number };

// The evening hours checked, in each place's own time: 16:00 to 21:00.
const EVENING = [16, 17, 18, 19, 20, 21];

// Pleasant enough to suggest going out: dry, clear or partly cloudy, not
// windy, and between 17° and 31° the whole evening.
const MIN_TEMP = 17;
const MAX_TEMP = 31;
const MAX_RAIN_CHANCE = 20;
const MAX_WIND_KMH = 25;
// WMO codes 0-3: clear to overcast. Fog, dust, rain and storms are higher.
const MAX_WEATHER_CODE = 3;

// Open-Meteo takes up to about 100 places per request.
const BATCH = 50;

type Hourly = {
  time: string[];
  temperature_2m: number[];
  precipitation_probability: (number | null)[];
  weather_code: number[];
  wind_speed_10m: number[];
};

function isNiceEvening(hourly: Hourly): number | null {
  const temps: number[] = [];
  for (let i = 0; i < hourly.time.length; i++) {
    const hour = Number(hourly.time[i].slice(11, 13));
    if (!EVENING.includes(hour)) continue;
    const temp = hourly.temperature_2m[i];
    const rain = hourly.precipitation_probability[i] ?? 0;
    if (
      temp < MIN_TEMP || temp > MAX_TEMP ||
      rain > MAX_RAIN_CHANCE ||
      hourly.wind_speed_10m[i] > MAX_WIND_KMH ||
      hourly.weather_code[i] > MAX_WEATHER_CODE
    ) {
      return null;
    }
    temps.push(temp);
  }
  if (temps.length < EVENING.length) return null;
  return Math.round(temps.reduce((a, b) => a + b, 0) / temps.length);
}

// The places from [spots] where this evening looks nice, with its average
// temperature. Places whose forecast fails to load are left out.
export async function niceEveningSpots(spots: Spot[]): Promise<NiceSpot[]> {
  const nice: NiceSpot[] = [];
  for (let start = 0; start < spots.length; start += BATCH) {
    const batch = spots.slice(start, start + BATCH);
    const url = new URL("https://api.open-meteo.com/v1/forecast");
    url.searchParams.set("latitude", batch.map((s) => s.latitude).join(","));
    url.searchParams.set("longitude", batch.map((s) => s.longitude).join(","));
    url.searchParams.set(
      "hourly",
      "temperature_2m,precipitation_probability,weather_code,wind_speed_10m",
    );
    url.searchParams.set("timezone", "auto");
    url.searchParams.set("forecast_days", "1");
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
      if (!response.ok) {
        console.error("Open-Meteo answered", response.status);
        continue;
      }
      const body = await response.json();
      // One place comes back as an object, several as a list.
      const results = Array.isArray(body) ? body : [body];
      results.forEach((result, i) => {
        const hourly = result?.hourly as Hourly | undefined;
        if (!hourly?.time) return;
        const temperature = isNiceEvening(hourly);
        if (temperature !== null) nice.push({ ...batch[i], temperature });
      });
    } catch (error) {
      console.error("Weather check failed for a batch:", error);
    }
  }
  return nice;
}
