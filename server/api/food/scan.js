// POST /api/food/scan
// Body: {"image": "<base64 JPEG>", "appUserID": "<RevenueCat app user ID>", "language": "fr"}
// Returns: {"items": [{"name", "kcal", "protein", "carbs", "fat", "fiber"}]}
//
// Pepline Pro only: the app user ID must hold the pepline_pro entitlement in
// RevenueCat. The photo is sent to OpenAI for this one estimate and is not
// stored or logged here. The user consented in the app before the first
// scan (App Review 5.1.2(i)).
//
// Model: OpenAI's cheapest current model with image input and Structured
// Outputs (decision 2026-10-27: cost first). `gpt-6-luna` at $0.10 / $0.50
// per 1M tokens (developers.openai.com/api/docs/pricing, read 2026-10-27);
// override with OPENAI_MODEL without a code change.
//
// Env (Vercel project settings, never in git): OPENAI_API_KEY, OPENAI_MODEL
// (optional), REVENUECAT_SECRET_KEY (v2), REVENUECAT_PROJECT_ID,
// PEPLINE_ENTITLEMENT_ID.
import OpenAI from "openai";

// Created on first use: the SDK throws at construction without a key, which
// would crash the whole function before it can answer.
let client;
const MODEL = process.env.OPENAI_MODEL || "gpt-6-luna";

const ITEMS_SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          kcal: { type: "number" },
          protein: { type: "number" },
          carbs: { type: "number" },
          fat: { type: "number" },
          fiber: { type: "number" },
        },
        required: ["name", "kcal", "protein", "carbs", "fat", "fiber"],
        additionalProperties: false,
      },
    },
  },
  required: ["items"],
  additionalProperties: false,
};

const SYSTEM = `You estimate the nutrition of a meal from one photo for a food log.
List each distinct food or drink you can see as one item with your best estimate of the portion shown:
energy in kcal and protein, carbohydrates, fat and fiber in grams.
Name each item briefly in the language given by the user, including the portion (for example "Grilled chicken breast, ~150 g").
If the photo shows no food, return an empty items list. Never give dietary or medical advice.`;

// Best-effort abuse guard per server instance: 20 scans per user per hour.
const recent = new Map();
function rateLimited(userID) {
  const now = Date.now();
  const hits = (recent.get(userID) || []).filter((t) => now - t < 3_600_000);
  hits.push(now);
  recent.set(userID, hits);
  return hits.length > 20;
}

// Any failure (missing or malformed key, RevenueCat down) means "not
// verified": the scan is refused instead of the function crashing.
async function hasPro(appUserID) {
  const env = (name) => (process.env[name] || "").trim();
  try {
    const url = `https://api.revenuecat.com/v2/projects/${env("REVENUECAT_PROJECT_ID")}` +
      `/customers/${encodeURIComponent(appUserID)}/active_entitlements`;
    const response = await fetch(url, { headers: { Authorization: `Bearer ${env("REVENUECAT_SECRET_KEY")}` } });
    if (!response.ok) return false;
    const body = await response.json();
    return (body.items || []).some((item) => item.entitlement_id === env("PEPLINE_ENTITLEMENT_ID"));
  } catch {
    return false;
  }
}

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();
  const { image, appUserID, language } = req.body || {};
  if (typeof image !== "string" || image.length < 100 || image.length > 8_000_000) return res.status(400).end();
  if (typeof appUserID !== "string" || appUserID.length < 3 || appUserID.length > 200) return res.status(400).end();
  if (!(await hasPro(appUserID))) return res.status(403).json({ error: "not_pro" });
  if (rateLimited(appUserID)) return res.status(429).json({ error: "rate_limited" });

  const apiKey = (process.env.OPENAI_API_KEY || "").trim();
  if (!apiKey) return res.status(503).json({ error: "not_configured" });
  try {
    client ??= new OpenAI({ apiKey });
    const completion = await client.chat.completions.create({
      model: MODEL,
      // Portion estimates don't need deep reasoning; keeps cost and latency down.
      reasoning_effort: "low",
      response_format: { type: "json_schema", json_schema: { name: "meal", strict: true, schema: ITEMS_SCHEMA } },
      messages: [
        { role: "system", content: SYSTEM },
        {
          role: "user",
          content: [
            { type: "text", text: `Language for item names: ${typeof language === "string" ? language.slice(0, 20) : "en"}` },
            { type: "image_url", image_url: { url: `data:image/jpeg;base64,${image}`, detail: "low" } },
          ],
        },
      ],
    });

    const message = completion.choices[0]?.message;
    if (!message || message.refusal) return res.status(422).json({ error: "refused", items: [] });
    return res.status(200).json(JSON.parse(message.content || '{"items":[]}'));
  } catch (error) {
    if (error instanceof OpenAI.RateLimitError) return res.status(503).json({ error: "busy" });
    if (error instanceof OpenAI.BadRequestError) return res.status(400).json({ error: "bad_image" });
    if (error instanceof OpenAI.APIError) return res.status(502).json({ error: "upstream", status: error.status });
    return res.status(500).json({ error: "failed" });
  }
}
