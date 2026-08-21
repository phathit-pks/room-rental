import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const schema = {
  type: "object",
  properties: {
    title: { type: "string", nullable: true },
    description: { type: "string", nullable: true },
    property_type: {
      type: "string",
      nullable: true,
      enum: ["apartment", "room", "house", "condo", "commercial", "other"],
    },
    monthly_price: { type: "number", nullable: true },
    currency: {
      type: "string",
      nullable: true,
      enum: ["LAK", "THB", "USD"],
    },
    province: { type: "string", nullable: true },
    district: { type: "string", nullable: true },
    village: { type: "string", nullable: true },
    address: { type: "string", nullable: true },
    bedrooms: { type: "integer", nullable: true },
    bathrooms: { type: "integer", nullable: true },
    amenities: { type: "array", items: { type: "string" } },
    contact_name: { type: "string", nullable: true },
    contact_phone: { type: "string", nullable: true },
    source_url: { type: "string", nullable: true },
    posted_at: { type: "string", nullable: true },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    missing_fields: { type: "array", items: { type: "string" } },
  },
  required: [
    "title", "description", "property_type", "monthly_price", "currency",
    "province", "district", "village", "address", "bedrooms", "bathrooms",
    "amenities", "contact_name", "contact_phone", "source_url", "posted_at",
    "confidence", "missing_fields",
  ],
  additionalProperties: false,
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return json({ error: "GEMINI_API_KEY is not configured" }, 500);

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
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", authData.user.id)
      .maybeSingle();
    if (profile?.role !== "admin") return json({ error: "Admin access required" }, 403);

    const body = await request.json();
    const text = typeof body.text === "string" ? body.text.trim() : "";
    const sourceUrl = typeof body.source_url === "string" ? body.source_url.trim() : "";
    const postedAt = typeof body.posted_at === "string" ? body.posted_at.trim() : "";
    if (!text || text.length > 20_000) {
      return json({ error: "text is required and must not exceed 20,000 characters" }, 400);
    }

    const prompt = `Extract a rental listing from the text below. The text may be Lao, Thai, or English.
Rules:
- Never invent missing information; use null and include its field name in missing_fields.
- Preserve Lao/Thai names as written.
- Normalize prices to a numeric monthly amount only when clearly stated.
- Normalize currency to LAK, THB, or USD only when clear.
- posted_at must be ISO-8601 when known; otherwise null.
- confidence is confidence in the whole extraction from 0 to 1.

Source URL supplied by caller: ${sourceUrl || "none"}
Posted date supplied by caller: ${postedAt || "none"}

Listing text:
${text}`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: schema,
          },
        }),
      },
    );

    const gemini = await response.json();
    if (!response.ok) {
      console.error("Gemini error", response.status, gemini?.error?.message);
      return json({ error: "AI parser is temporarily unavailable" }, 502);
    }

    const output = gemini?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof output !== "string") return json({ error: "AI returned no result" }, 502);
    return json({ data: JSON.parse(output) });
  } catch (error) {
    console.error(error);
    return json({ error: "Unable to parse rental post" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}
