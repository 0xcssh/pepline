# CLAUDE.md — Pepline

Pepline is a native iOS app for people who inject peptides and GLP-1 compounds:
a **reconstitution calculator that is correct and saveable**, plus a **dose
journal**, reminders, progress and nutrition. No account, no dosing advice
(AI — OpenAI — only estimates food macros from a meal photo, with consent),
on-device data, honest paywall. It is the exact inverse of the category
leaders, whose reviews are majority 1-star (see "Why this app").

Sister project: RepLock (`../replock`) — same owner, same pipeline, same
conventions. Read `../replock/CLAUDE.md` for anything not covered here; when
in doubt, do it the RepLock way.

## The one constraint: NO MAC

Development happens 100% from this Windows machine. No Xcode, no simulator, no
local build. Loop: edit Swift here → GitHub Actions (macos runner) builds and
tests → TestFlight (or USB IPA via `pymobiledevice3` under Python 3.12) → the
user tests on his iPhone and reports in French. Push every piece of logic into
a **pure, unit-tested Swift core**; CI tests are the cheap iteration path.
The calculator math is the heart of this app and MUST be 100% covered by tests
before any UI exists (competitors ship wrong results — that is our opening).

GitHub Actions on private repos has been billing-blocked on this account; the
workaround used on RepLock is flipping the repo public for a run and back to
private (`gh repo edit 0xcssh/pepline --visibility public
--accept-visibility-change-consequences`). Never commit a secret, ever.

## Why this app (from the leaders' reviews, 2026-10-15)

PeptidePal (4.7k ratings since 2026-04, ~10k ratings/year pace) and Pep AI
(3.9k since 2026-02) have MORE 1-star than 5-star recent reviews. Recurring
complaints, each one a requirement for us:

- Paywall hidden behind a long quiz + mandatory sign-up ("bait and switch").
  → Short onboarding with value first, trial terms and price visible, no
  account required.
- Reconstitution calculator missing, removed by an update, or wrong (decimal
  input broken, wrong result). → Calculator first, exact, decimals OK, tested.
- Calculations cannot be saved; doses cannot be edited/deleted when logged on
  the wrong date. → Save per vial; every entry editable and deletable.
- AI assistant giving dangerous doses. → No AI advice. Journal + math only. This is
  also our App Review line (guideline 1.4 health): we never recommend a dose.
- Bloated updates, mascots, broken timer, unreachable support. → Small,
  calm UI (RepLock design system), support email answered.
- What 5-star users ask for: notes field, left/right injection site, cycle
  calendar + dose log next to the calculator, reminders to reorder vials.

PepCalc (one-time $9.99 as of 2026-10-15, 4.8★) proves a correct calculator alone sells.

Also watch **Peptide Tracker Log & Reminder** (id 6763939355): 2.6k US
ratings at 4.92★ — likely the best-liked app in the category; study it.

Ratings by storefront (iTunes Search API, 2026-10-15):

| App (id) | US | CA | GB | DE | FR |
|---|---|---|---|---|---|
| PeptidePal (6762102880) | 4712 | 446 | 372 | 12 | 1 |
| Pep AI (6758682710) | 3881 | 118 | 109 | 23 | 6 |
| Peptide Tracker Log & Reminder (6763939355) | 2572 | 183 | 93 | – | – |
| PepCalc (1524577846) | 951 | 41 | 21 | 4 | 0 |
| PepFlow (6740525224) | 424 | 45 | 16 | 22 | 7 |
| Milligram (6759593151) | 368 | – | 203 | 5 | – |

The market is overwhelmingly US. Continental Europe has no leader: the most
rated app in FR has 7 ratings (PepFlow, the only one localized). Revenue is
won in the US against PeptidePal/Pep AI; non-English storefronts are ours to
take with day-one localization (smaller volume, stricter regulation).

## v1 scope

1. **Calculator**: vial mg, bacteriostatic water ml, desired dose (mcg or mg),
   syringe size (0.3/0.5/1 ml) → units on the syringe with a drawn syringe,
   concentration, doses per vial, IU↔mcg↔mg conversions. Saved per vial,
   vial manager (archive/restore/delete).
2. **Journal**: dose, time, compound, injection site (body map: abdomen/thigh/
   glute/arm × left/right, least-rested zone pulses), notes; edit/delete
   anything; month calendar taken/skipped/missed; side effects.
3. **Protocols**: several compounds with different schedules (daily, EOD,
   every N days, weekdays, N-on/N-off); actionable reminders (Log/Skip from
   the notification); "vial runs out on …" + reorder reminder. Editing a
   started schedule versions it (`Journal.saveEdited`, `Regimen.replacedAt`).
4. **Progress**: weight (Apple Health read/write, no duplicates), photos with
   compare slider, estimated levels (sourced half-lives only), weekly recap.
5. **Nutrition** (decision 2026-10-17, to match MeAgain/Shotsy): protein,
   water and calorie goals set by the user, Open Food Facts search and
   barcode, Pro meal-photo estimate via `server/api/food/scan` (OpenAI, with
   a consent screen, guideline 5.1.2(i)).
6. **Export** CSV + PDF doctor report; next-dose widget (Home + Lock Screen).
7. **Monetization**: hard paywall after the onboarding, 7-day trial on yearly,
   monthly without trial. **Prices aligned on PeptidePal (decision
   2026-10-15): yearly $44.99, monthly $14.99**, plus an exit offer
   `com.awdia.pepline.pro.yearly.offer` at $34.99/yr (−22%, 7-day trial) shown
   once when the user cancels Apple's payment sheet. All in
   `scripts/store.json`, created by `scripts/asc_admin.py` (ACTION=setup).
   Consider a one-time "calculator only" unlock later (PepCalc's audience).
8. **9 languages** from day one (en, fr, es, de, it, pt-BR, ja, ko, zh-Hans) —
   the leaders are US-only.

Out of scope v1: AI dosing advice or chat, community, compound library,
Android, web.

Later (decision 2026-10-17): a web-to-app quiz funnel (SOSA p26-27: sell
the problem on the web, discounted first month via Stripe/RevenueCat Web
Billing, unlock in the app) only once there is a paid-ads budget; check
Meta/Google health ad policies first. App Store/ASO comes first.

## Identifiers (already created 2026-10-15 — don't re-derive)

| Item | Value |
|---|---|
| Bundle ID | `com.awdia.pepline` (registered in the portal, id `DNMW4F45LX`) |
| App Store record | app ID **`6823184469`**, name "Pepline: Peptide Calculator", SKU `pepline`, primary locale en-US (created 2026-10-15) |
| Team ID | `8L8G4P4Z9X` |
| Widget | extension `com.awdia.pepline.widget` (2026-10-17). Shares only the upcoming doses with the app through the keychain group `TEAMID.com.awdia.pepline.shared`, NOT an App Group: the ASC API cannot create App Groups (`/v1/appGroups` → 404) and every profile already allows `TEAMID.*` keychain groups. The journal stays in the app container |
| RevenueCat | same project as RepLock (`proj33517486`), app `app5a505ff039`, **public SDK key `appl_dEELKElrptAkKrvAAbPAKwdrnaT`** (ships in the binary by design), entitlement lookup key **`pepline_pro`** (`entlb31718d3df`), offering `pepline` (`ofrng97715eb10e`) with `$rc_annual` → `com.awdia.pepline.pro.yearly`, `$rc_monthly` → `com.awdia.pepline.pro.monthly` |
| IAP key (RevenueCat) | `QL2P7M4WRG` (configured for Pepline 2026-10-16 by API) — the account-level In-App Purchase key **shared with RepLock and Flux**, same as RepLock's CLAUDE.md. Needed for StoreKit 2 transaction validation. ⚠️ Revoking it in ASC breaks purchases in all three apps |
| TelemetryDeck | app ID **`CAA9F19C-A911-46FE-B97A-AB0EB9E70748`** (org H&A Ltd, namespace `com.haltd`) |
| ASC API key | RepLock's `R3CPFXXF92` (account-level) — secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8_BASE64` must be copied to this repo's GitHub secrets, plus the signing secrets (`CERT_P12_BASE64`, `CERT_DIST_P12_BASE64`, `CERT_P12_PASSWORD`, variable `APPLE_TEAM_ID`) |
| Subscriptions in ASC | group "Pepline Pro" `22481589`: `.yearly` `6823217429` ($44.99, 7-day trial), `.monthly` `6823220365` ($14.99), `.yearly.offer` `6823221387` ($34.99, 7-day trial); 175 territories, 9 locales, 16-day grace period (2026-10-15, `scripts/asc_admin.py`). Still MISSING_METADATA: review screenshot before submission. RevenueCat: offer product `prod2bf1c4f118` in `pepline_pro`, package `exit_offer` in offering `pepline` (RepLock's "Pro" stays the project's current offering; the app matches products across all offerings) |

## App structure (2026-10-17)

- **Tabs**: Today · Journal (History | Progress switch) · Nutrition · Tools
  (calculator + saved vials). Settings behind the gear on every tab.
- **Today** is the daily loop (SOSA p116): next dose with units to draw on
  the drawn syringe and the most rested site, one-tap **I injected**
  (`QuickLog`: newest vial, least-recent zone, logged at its slot when late),
  then today's doses (Log / Undo skip), nutrition shortcuts, the week's
  recap, estimated level, vial, quick actions.
- **Onboarding**: 11 screens, order in `Core/Onboarding.swift`: welcome →
  compounds → **first vial (the aha, third)** → name → goals → weight (weight
  loss only) → reminders → account (optional SIWA) → disclaimer → building →
  summary → paywall. Long web quizzes are for web funnels, not the app (SOSA
  p26-27); a paywall without context feels jarring (p67). Screens with text
  fields set `hasTextInput: true` (always scroll, see Pipeline lessons).
- **Paywall**: one screen (scroll only on SE), yearly shown per month
  (p22), trial-reminder day picked by the user (p78), exit offer on cancel.
- **In-context help**: TipKit tips (`Design/Tips.swift`), each shown once.
- **Ratings**: Apple's prompt only (5.6.1, no custom pre-prompt) after the
  first onboarding result, the 3rd logged dose and a 7-dose streak
  (`ReviewMoment`); "Rate Pepline" link in Settings.
- **Churn signal**: `CancelSurveyView` before Apple's subscription page and
  once when auto-renew is found off; reason sent as an enum.
- **Shared UI**: `Design/Controls.swift` (`NumberEntry`, `ChipPicker`,
  `ChipStyle`, `StepCard`, `FormCard`, `CompoundChips`, `DoseAmountCard`) —
  every editor uses cards with big numerals, no plain iOS forms.
- **Server** (`server/`, Vercel `pepline-api.vercel.app`): `api/apple/revoke.js`
  (SIWA token revocation, 5.1.1(v)), `api/food/scan.js` (OpenAI
  `gpt-6-luna`, cheapest vision model, decision 2026-10-27; entitlement
  checked through RevenueCat, photo not kept).
  Env vars listed in `server/README.md`; secrets only in Vercel.

## Pipeline lessons (this repo)

- Bash heredocs choke on quotes and mangle non-ASCII on this machine: write
  patch scripts with the Write tool into the scratchpad, then run them.
  New translations go through a JSON file + a merge into the catalog that
  keeps key order (sorting rewrites the whole file).
- `ViewThatFits` that depends on height re-creates its subtree when the
  keyboard opens (fields lose focus): keep layout choices keyboard-proof
  (`.ignoresSafeArea(.keyboard)`) and make text-input screens always scroll.
  Number pads have no return key: offer a Done button.
- A `.toolbar` mixing a bare `Button` with `ToolbarItemGroup` makes the type
  checker give up ("failed to produce diagnostic"): wrap every item.
- The Core coverage gate counts autoclosures (`??`) and default property
  values: test the empty and fallback paths too.
- App Groups cannot be created through the ASC API; shared keychain groups
  (`TEAMID.*`) need no portal step.
- Info.plist strings need an `en` entry in `InfoPlist.xcstrings`, or ASC
  flags the key name as the purpose string.

## Server secrets (2026-10-27)

All set in Vercel (pepline-api, Production) and kept in the All in one vault
(`Bureau/All in one/scripts/vault-get.ps1`, every decrypt needs the owner's
OK): `OPENAI_API_KEY` (vault `pepline/openai-api-key.txt`; credits added 2026-10-29, test call
OK: ~144 tokens for a photo, about $0.00003),
`REVENUECAT_SECRET_KEY` (vault `replock/revenuecat_v2.key`, same RevenueCat
project), `APPLE_KEY_ID` `27XC5K46K6` + `APPLE_PRIVATE_KEY` (vault
`pepline/AuthKey_27XC5K46K6-…p8`; mislabelled "cyranox ASC key" in the vault
but verified against appleid.apple.com as a Sign in with Apple key of team
8L8G4P4Z9X for com.awdia.pepline). Server deps pinned by `package-lock.json`
(Vercel's build cache once skipped installing `openai`).

## Conventions

Identical to RepLock: imperative commits ending with
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; code, comments and
commits in English, user reports in French; localization mandatory (8
translations with every new string, in the same commit); SF Symbols, no emoji;
never ship hand-drawn artwork blind (CI renders snapshots as an artifact).

**Design V2 "calm futurism"** (chosen 2026-10-15 over a full JARVIS HUD, for
the audience: reviews praise "easy/simple", GLP-1 users skew 50–64 per KFF;
mockups in `research/design/pepline-hud.html`): dark first with light mode
following the system, mint accent on near-black, glass cards, rounded type
(`.fontDesign(.rounded)`), ONE glowing value per screen (`.plGlow()`: the
units to draw), constellation reward after each logged dose. Tokens only in
`Design/Theme.swift` (`PLColor.*`, `PLBackground`, `.plCard()`,
`.plScreen()`); never a literal color in a view. Icon: the "P-vial", variant
B, generated by `scripts/icon/make_icon.py`. Not RepLock's navy/orange.

**Nothing language-specific is hardcoded.** Every user-facing string goes
through `Localizable.xcstrings` (no literal text in views, alerts,
notifications or exports); the supported-language list lives only in the
project/catalog, never in a Swift array or `if locale == "fr"` branch (read it
from `Bundle.main.localizations` when needed). Numbers, decimals, units, dates
and currencies are parsed and formatted with the user's `Locale`
(`FormatStyle`, `Decimal` parsing that accepts "0,25" as well as "0.25") —
broken decimal input is a top competitor complaint. Prices come from
StoreKit/RevenueCat localized strings, never typed in. Scripts (listing,
screenshots) derive their locale list from one config file, not per-script
copies.

## Knowledge base in this repo

- `docs/LESSONS.md` — the RepLock playbook (pipeline, pure core, ASC-by-API
  pitfalls, App Review rejections, analytics rules, the private/public trick).
- `docs/SOURCES.md` — the cited source of every hardcoded constant and App
  Review claim (U-100, graduations, IU, FDA alert, guideline 1.4.2). No new
  constant without a line there.
- `research/` (gitignored): competitor screenshots and teardowns, local only.
- `docs/SOSA_2026_STRATEGIES.md` — RevenueCat State of Subscription Apps 2026
  digest with per-category strategy; the PDF is next to it.
- `.claude/skills/` — the 38 app-marketing skills (ASO audit, keyword
  research, metadata, screenshots, paywall, onboarding, retention, Apple
  Search Ads, launch, PR, review management…). Invoke them with `/<name>`.

## Status

- [x] 2026-10-15 niche chosen from App Store data + SOSA (see LESSONS.md §3 and
  the review audit above); name "Pepline" (free on the store); bundle ID,
  RevenueCat app/products/offering, TelemetryDeck app created by API.
- [x] ASC app record (2026-10-15) → next: subscriptions + grace period by script
- [x] GitHub secrets copied from RepLock (incl. `ASC_ISSUER_ID`)
- [x] 2026-10-15 Bootstrap + core with tests: reconstitution, decimal input,
  schedules, journal, CSV, reminder planner — 72 tests, Core 100% covered
  (CI gate), translation check in CI. Plan: ~/.claude/plans/mellow-wondering-chipmunk.md
- [x] 2026-10-17 Leaders' feature set: Today loop, body map, adherence
  calendar, side effects, levels, progress photos, Apple Health, nutrition
  (OFF + Pro photo estimate), doctor PDF, next-dose widget.
- [x] 2026-10-17 UX rethink from SOSA (user decision): tabs Today ·
  Journal · Nutrition · Tools (Nutrition tab restored the same day: users
  did not find it on Today), one-tap "I injected" on Today, 11-screen onboarding with
  the aha (own vial on own syringe) third, TipKit tips in context instead of a
  tour (p116), weekly recap, trial-reminder day picked on the paywall (p78),
  cancel-reason survey, Apple review prompt after the 3rd dose / 7-streak
  (5.6.1: system prompt only, no custom pre-prompt).
- [x] 2026-10-17 Code audit (21 findings) fixed: late logs answer their slot,
  no reminder/double log for answered doses, Health de-duplication, schedule
  versions, vial manager, editors as cards, keyboard-safe onboarding.
  123 tests, Core 100%. TestFlight builds go out with every round.
- [x] 2026-10-18 By API/CLI: server deployed on Vercel (`pepline-api`,
  non-secret env set), legal pages live (`0xcssh/pepline-legal`), listing in
  12 locales (`scripts/listing/1.0.0.json`), 4 screenshots × 12 locales
  (`MarketingScreenshotTests` → `scripts/asc_screenshots.py`), categories,
  age rating, subscription review screenshots (all READY_TO_SUBMIT).
- [x] 2026-10-27 Food scan moved to OpenAI (`gpt-6-luna`); all server secrets
  set from the All in one vault; both endpoints verified live.
- [ ] Owner: App Review contact (name,
  phone) + notes from `docs/APP_REVIEW.md`; App Privacy questionnaire; pick
  the build and submit. Quote guidelines 3.1.2 and 5.1.2(i) in SOURCES.
