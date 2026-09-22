import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = request.headers.get("Authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!authorization || !supabaseUrl || !anonKey) {
      return json({ error: "Unauthorized" }, 401);
    }
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) return json({ error: "Unauthorized" }, 401);
    const { data: allowed, error: rateLimitError } = await supabase.rpc(
      "consume_api_rate_limit",
      {
        requested_action: "search-osm-places",
        maximum_requests: 30,
        window_seconds: 3600,
      },
    );
    if (rateLimitError) return json({ error: "Rate limiter unavailable" }, 503);
    if (!allowed) return json({ error: "Too many requests" }, 429);

    const body = await request.json();
    const rawParts = [body.village, body.district, body.province];
    if (rawParts.some((value) => typeof value === "string" && value.length > 120)) {
      return json({ error: "Location value is too long" }, 400);
    }
    const parts = rawParts
      .filter((value) => typeof value === "string" && value.trim().length > 0)
      .map((value) => value.trim());
    const area = parts.length > 0 ? `${parts.join(" ")} Laos` : "Vientiane Laos";

    const geocodeUrl = new URL("https://nominatim.openstreetmap.org/search");
    geocodeUrl.searchParams.set("q", area);
    geocodeUrl.searchParams.set("format", "jsonv2");
    geocodeUrl.searchParams.set("limit", "1");
    geocodeUrl.searchParams.set("countrycodes", "la");
    const geocode = await fetch(geocodeUrl, {
      headers: osmHeaders,
      signal: AbortSignal.timeout(8_000),
    });
    if (!geocode.ok) return json({ error: "Unable to locate selected area" }, 502);
    const matches = await geocode.json();
    if (!Array.isArray(matches) || matches.length === 0) {
      return json({ places: [], area, attribution: "© OpenStreetMap contributors" });
    }

    const latitude = Number(matches[0].lat);
    const longitude = Number(matches[0].lon);
    const radius = body.village ? 4000 : body.district ? 8000 : 18000;
    const overpassQuery = `[out:json][timeout:20];(
      nwr["tourism"="apartment"](around:${radius},${latitude},${longitude});
      nwr["building"~"^(apartments|dormitory)$"](around:${radius},${latitude},${longitude});
      nwr["amenity"="dormitory"](around:${radius},${latitude},${longitude});
    );out center tags 80;`;
    const overpass = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { ...osmHeaders, "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ data: overpassQuery }),
      signal: AbortSignal.timeout(25_000),
    });
    if (!overpass.ok) return json({ error: "OpenStreetMap search is busy" }, 502);
    const data = await overpass.json();
    const seen = new Set<string>();
    const places = (data.elements ?? []).flatMap((element: Record<string, any>) => {
      const tags = element.tags ?? {};
      const name = tags["name:lo"] ?? tags.name ?? tags["name:en"];
      const lat = element.lat ?? element.center?.lat;
      const lon = element.lon ?? element.center?.lon;
      if (!name || typeof lat !== "number" || typeof lon !== "number") return [];
      const key = `${String(name).toLowerCase()}|${lat.toFixed(5)}|${lon.toFixed(5)}`;
      if (seen.has(key)) return [];
      seen.add(key);
      const address = [
        tags["addr:housenumber"], tags["addr:street"], tags["addr:village"],
        tags["addr:district"], tags["addr:city"],
      ].filter(Boolean).join(" ");
      return [{
        id: `${element.type}/${element.id}`,
        name,
        address: address || null,
        latitude: lat,
        longitude: lon,
        category: tags.tourism === "apartment" ? "apartment" : "residential_building",
        osm_url: `https://www.openstreetmap.org/${element.type}/${element.id}`,
      }];
    }).slice(0, 40);

    return json({ places, area, attribution: "© OpenStreetMap contributors" });
  } catch (error) {
    console.error(error);
    return json({ error: "Unable to search OpenStreetMap" }, 500);
  }
});

const osmHeaders = {
  "User-Agent": "RoomRentalLaos/1.0 (Supabase Edge Function)",
  "Accept-Language": "lo,th,en",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}
