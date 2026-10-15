# pepline-api

One stateless Vercel function: `POST /api/apple/revoke` revokes a Sign in
with Apple token when a user deletes their account in the app (App Review
5.1.1(v)). The app cannot do it itself: the request needs a client secret
signed with the Sign in with Apple private key, which must never ship in the
binary.

Deploy: `vercel deploy --prod` from this folder (project name `pepline-api`).
Environment variables (Vercel project settings, never committed):

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | `8L8G4P4Z9X` |
| `APPLE_CLIENT_ID` | `com.awdia.pepline` |
| `APPLE_KEY_ID` | Key ID of the "Sign in with Apple" key (developer portal → Keys) |
| `APPLE_PRIVATE_KEY` | contents of that key's `.p8` |
