// POST /api/food/scan
// Body: {"image": "<base64 JPEG>", "appUserID": "<RevenueCat app user ID>"}
// Returns: {"items": [{"name", "kcal", "protein", "carbs", "fat", "fiber"}]}
//
// Pepline Pro only: the app user ID must hold the pepline_pro entitlement in
// RevenueCat. The photo is sent to Claude for this one estimate and is not
// stored or logged here. The user consented in the app before the first
// scan (App Review 5.1.2(i)).
//
// Env (Vercel project settings, never in git): ANTHROPIC_API_KEY,
// REVENUECAT_SECRET_KEY (v2), REVENUECAT_PROJECT_ID, PEPLINE_ENTITLEMENT_ID.
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

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

async function hasPro(appUserID) {
  const url = `https://api.revenuecat.com/v2/projects/${process.env.REVENUECAT_PROJECT_ID}` +
    `/customers/${encodeURIComponent(appUserID)}/active_entitlements`;
  const response = await fetch(url, { headers: { Authorization: `Bearer ${process.env.REVENUECAT_SECRET_KEY}` } });
  if (!response.ok) return false;
  const body = await response.json();
  return (body.items || []).some((item) => item.entitlement_id === process.env.PEPLINE_ENTITLEMENT_ID);
}

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();
  const { image, appUserID, language } = req.body || {};
  if (typeof image !== "string" || image.length < 100 || image.length > 8_000_000) return res.status(400).end();
  if (typeof appUserID !== "string" || appUserID.length < 3 || appUserID.length > 200) return res.status(400).end();
  if (!(await hasPro(appUserID))) return res.status(403).json({ error: "not_pro" });
  if (rateLimited(appUserID)) return res.status(429).json({ error: "rate_limited" });

  try {
    const response = await client.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      system: SYSTEM,
      // Portion estimates don't need deep reasoning.
      output_config: { effort: "low", format: { type: "json_schema", schema: ITEMS_SCHEMA } },
      messages: [{
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: "image/jpeg", data: image } },
          { type: "text", text: `Language for item names: ${typeof language === "string" ? language.slice(0, 20) : "en"}` },
        ],
      }],
    });

    if (response.stop_reason === "refusal") return res.status(422).json({ error: "refused", items: [] });
    const text = response.content.find((block) => block.type === "text")?.text ?? '{"items":[]}';
    return res.status(200).json(JSON.parse(text));
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) return res.status(503).json({ error: "busy" });
    if (error instanceof Anthropic.BadRequestError) return res.status(400).json({ error: "bad_image" });
    if (error instanceof Anthropic.APIError) return res.status(502).json({ error: "upstream", status: error.status });
    return res.status(500).json({ error: "failed" });
  }
}
