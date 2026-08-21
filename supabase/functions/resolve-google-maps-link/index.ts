const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function coordinatesFrom(value: string) {
  let decoded = value;
  try {
    decoded = decodeURIComponent(value);
  } catch (_) {
    // Keep the original value when it is not URL encoded.
  }

  const match =
    decoded.match(/(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)/) ??
    decoded.match(/!3d(-?\d{1,2}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)/);
  if (!match) return null;
  const latitude = Number(match[1]);
  const longitude = Number(match[2]);
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) return null;
  return { latitude, longitude };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { url } = await request.json();
    const input = String(url ?? "").trim();
    const parsed = new URL(input);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return json({ error: "Invalid URL" }, 400);
    }
    if (!parsed.hostname.endsWith("google.com") &&
        parsed.hostname !== "maps.app.goo.gl" &&
        parsed.hostname !== "goo.gl") {
      return json({ error: "Only Google Maps links are supported" }, 400);
    }

    const response = await fetch(input, {
      method: "GET",
      redirect: "follow",
      headers: { "User-Agent": "Mozilla/5.0" },
    });
    const resolvedUrl = response.url || input;
    let coordinates = coordinatesFrom(resolvedUrl);
    if (!coordinates) {
      const html = await response.text();
      coordinates = coordinatesFrom(html);
    }
    if (!coordinates) return json({ error: "Coordinates not found" }, 422);

    return json({ url: resolvedUrl, ...coordinates });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 400);
  }
});
