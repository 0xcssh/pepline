// POST /api/apple/revoke  {"code": "<authorizationCode from Sign in with Apple>"}
//
// The app re-authenticates the user, sends the one-time authorization code,
// and this function exchanges it for a token at Apple and revokes it — the
// account deletion App Review requires for Sign in with Apple (5.1.1(v)).
// Stateless: nothing is stored or logged except the HTTP status.
//
// Env (Vercel project settings, never in git): APPLE_TEAM_ID, APPLE_CLIENT_ID
// (com.awdia.pepline), APPLE_KEY_ID, APPLE_PRIVATE_KEY (the .p8 contents).
import { SignJWT, importPKCS8 } from "jose";

const APPLE = "https://appleid.apple.com";

// Env values may carry stray whitespace, and the key escaped "\n" line breaks.
const env = (name) => (process.env[name] || "").trim();

async function clientSecret() {
  const key = await importPKCS8(env("APPLE_PRIVATE_KEY").replace(/\\n/g, "\n"), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env("APPLE_KEY_ID") })
    .setIssuer(env("APPLE_TEAM_ID"))
    .setSubject(env("APPLE_CLIENT_ID"))
    .setAudience(APPLE)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

async function post(path, params) {
  return fetch(APPLE + path, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params),
  });
}

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();
  const code = req.body && req.body.code;
  if (typeof code !== "string" || code.length < 10 || code.length > 2000) return res.status(400).end();

  let secret;
  try {
    secret = await clientSecret();
  } catch {
    return res.status(503).json({ error: "not_configured" });
  }
  const base = { client_id: env("APPLE_CLIENT_ID"), client_secret: secret };

  const tokenResponse = await post("/auth/token", { ...base, code, grant_type: "authorization_code" });
  if (!tokenResponse.ok) return res.status(502).json({ step: "token", status: tokenResponse.status });
  const { refresh_token, access_token } = await tokenResponse.json();

  const revokeResponse = await post("/auth/revoke", refresh_token
    ? { ...base, token: refresh_token, token_type_hint: "refresh_token" }
    : { ...base, token: access_token, token_type_hint: "access_token" });
  if (!revokeResponse.ok) return res.status(502).json({ step: "revoke", status: revokeResponse.status });

  return res.status(200).json({ revoked: true });
}
