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

function isAllowedGoogleMapsHost(hostname: string) {
  const host = hostname.toLowerCase().replace(/\.$/, "");
  return host === "google.com" || host.endsWith(".google.com") ||
    host === "maps.app.goo.gl" || host === "goo.gl";
}

async function authenticatedClient(request: Request) {
  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!authorization || !supabaseUrl || !anonKey) return null;
  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return client;
}

async function fetchAllowedRedirects(initialUrl: URL) {
  let current = initialUrl;
  for (let redirects = 0; redirects <= 5; redirects++) {
    if (current.protocol !== "https:" || !isAllowedGoogleMapsHost(current.hostname)) {
      throw new Error("Only HTTPS Google Maps links are supported");
    }
    const response = await fetch(current, {
      method: "GET",
      redirect: "manual",
      headers: { "User-Agent": "Mozilla/5.0" },
      signal: AbortSignal.timeout(8_000),
    });
    if (response.status < 300 || response.status >= 400) return response;
    const location = response.headers.get("location");
    if (!location) throw new Error("Invalid redirect response");
    current = new URL(location, current);
  }
  throw new Error("Too many redirects");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const supabase = await authenticatedClient(request);
    if (!supabase) return json({ error: "Unauthorized" }, 401);
    const { data: allowed, error: rateLimitError } = await supabase.rpc(
      "consume_api_rate_limit",
      {
        requested_action: "resolve-google-maps-link",
        maximum_requests: 20,
        window_seconds: 3600,
      },
    );
    if (rateLimitError) return json({ error: "Rate limiter unavailable" }, 503);
    if (!allowed) return json({ error: "Too many requests" }, 429);

    const { url } = await request.json();
    const input = String(url ?? "").trim();
    if (input.length === 0 || input.length > 2048) {
      return json({ error: "Invalid URL" }, 400);
    }
    const parsed = new URL(input);
    if (parsed.protocol !== "https:") {
      return json({ error: "Invalid URL" }, 400);
    }
    if (!isAllowedGoogleMapsHost(parsed.hostname)) {
      return json({ error: "Only Google Maps links are supported" }, 400);
    }

    const response = await fetchAllowedRedirects(parsed);
    if (!response.ok) return json({ error: "Unable to resolve Google Maps link" }, 502);
    const resolvedUrl = response.url || input;
    const resolved = new URL(resolvedUrl);
    if (!isAllowedGoogleMapsHost(resolved.hostname)) {
      return json({ error: "Unsafe redirect blocked" }, 400);
    }
    let coordinates = coordinatesFrom(resolvedUrl);
    if (!coordinates) {
      const contentLength = Number(response.headers.get("content-length") ?? 0);
      if (contentLength > 1_000_000) {
        return json({ error: "Google Maps response is too large" }, 413);
      }
      const html = await response.text();
      if (html.length > 1_000_000) {
        return json({ error: "Google Maps response is too large" }, 413);
      }
      coordinates = coordinatesFrom(html);
    }
    if (!coordinates) return json({ error: "Coordinates not found" }, 422);

    return json({ url: resolvedUrl, ...coordinates });
  } catch (error) {
    console.error(error);
    return json({ error: "Unable to resolve Google Maps link" }, 400);
  }
});
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
