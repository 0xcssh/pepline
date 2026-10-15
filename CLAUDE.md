# CLAUDE.md — Pepline

Pepline is a native iOS app for people who inject peptides and GLP-1 compounds:
a **reconstitution calculator that is correct and saveable**, plus a **dose
journal**, reminders and a weight curve. No account, no AI, no dosing advice,
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
  → Paywall announced on screen 2, trial terms and price visible, no account.
- Reconstitution calculator missing, removed by an update, or wrong (decimal
  input broken, wrong result). → Calculator first, exact, decimals OK, tested.
- Calculations cannot be saved; doses cannot be edited/deleted when logged on
  the wrong date. → Save per vial; every entry editable and deletable.
- AI assistant giving dangerous doses. → No AI. Journal + math only. This is
  also our App Review line (guideline 1.4 health): we never recommend a dose.
- Bloated updates, mascots, broken timer, unreachable support. → Small,
  calm UI (RepLock design system), support email answered.
- What 5-star users ask for: notes field, left/right injection site, cycle
  calendar + dose log next to the calculator, reminders to reorder vials.

PepCalc (one-time $5.99, 4.7★) proves a correct calculator alone sells.

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
   concentration, doses per vial, IU↔mcg↔mg conversions. Saved per vial.
2. **Journal**: dose, time, compound, injection site (abdomen/thigh/glute,
   left/right), notes; edit/delete anything; history by day and by compound.
3. **Protocols**: several compounds with different schedules (daily, EOD,
   weekly, N-on/N-off); reminders; "vial runs out on …" + reorder reminder.
4. **Weight** log with chart (HealthKit read optional, later).
5. **Export** CSV. Data in the app sandbox (no App Group needed — no extensions).
6. **Monetization**: hard paywall with 7-day trial on yearly, monthly without
   trial (RepLock lot-1 paywall, reused). Yearly $39.99 / monthly $9.99 (Health
   & Fitness anchors, see docs/SOSA_2026_STRATEGIES.md). Consider a one-time
   "calculator only" unlock later (PepCalc's audience).
7. **9 languages** from day one (en, fr, es, de, it, pt-BR, ja, ko, zh-Hans) —
   the leaders are US-only.

Out of scope v1: AI, food/macros, community, Android, web.

## Identifiers (already created 2026-10-15 — don't re-derive)

| Item | Value |
|---|---|
| Bundle ID | `com.awdia.pepline` (registered in the portal, id `DNMW4F45LX`) |
| App Store record | **NOT YET CREATED** — one click in ASC (My Apps → +, name "Pepline", bundle above, SKU `pepline-ios`). Subscriptions/listing scripts need it. |
| Team ID | `8L8G4P4Z9X` |
| RevenueCat | same project as RepLock (`proj33517486`), app `app5a505ff039`, **public SDK key `appl_dEELKElrptAkKrvAAbPAKwdrnaT`** (ships in the binary by design), entitlement lookup key **`pepline_pro`** (`entlb31718d3df`), offering `pepline` (`ofrng97715eb10e`) with `$rc_annual` → `com.awdia.pepline.pro.yearly`, `$rc_monthly` → `com.awdia.pepline.pro.monthly` |
| TelemetryDeck | app ID **`CAA9F19C-A911-46FE-B97A-AB0EB9E70748`** (org H&A Ltd, namespace `com.haltd`) |
| ASC API key | RepLock's `R3CPFXXF92` (account-level) — secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8_BASE64` must be copied to this repo's GitHub secrets, plus the signing secrets (`CERT_P12_BASE64`, `CERT_DIST_P12_BASE64`, `CERT_P12_PASSWORD`, variable `APPLE_TEAM_ID`) |
| Subscriptions in ASC | to create once the app record exists: `com.awdia.pepline.pro.yearly` (1 year, 7-day free trial, $39.99) and `.monthly` (1 month, $9.99), group "Pepline Pro", review screenshot, 16-day grace period — all scriptable with `../replock/scripts/asc_admin.py` patterns |

## Build plan

1. Bootstrap from RepLock: `project.yml` (XcodeGen), `.github/workflows/ios.yml`,
   `Design/Theme.swift`, `Services/SubscriptionManager.swift` (swap product
   IDs, entitlement, key), `Services/Analytics.swift` (swap app ID; write a
   new event vocabulary), paywall views, `Localizable.xcstrings` skeleton,
   `scripts/asc_*.py` + listing/screenshot workflows.
2. `Core/Reconstitution.swift` + tests (pure math), `Core/Protocol.swift`
   (schedule → next doses) + tests. Nothing else until these are green.
3. Journal + calculator UI, protocols, reminders, weight.
4. Onboarding of at most 4 screens; paywall on screen 2 of the funnel.
5. Localization, listing (12 locales, en-GB/AU/CA keyword variants),
   screenshots generated with the RepLock generator pattern, TestFlight.

## Conventions

Identical to RepLock: imperative commits ending with
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; code, comments and
commits in English, user reports in French; localization mandatory (8
translations with every new string, in the same commit); navy structure +
orange→pink gradient for reward moments only; SF Symbols, no emoji; never ship
hand-drawn artwork blind.

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
- `docs/SOSA_2026_STRATEGIES.md` — RevenueCat State of Subscription Apps 2026
  digest with per-category strategy; the PDF is next to it.
- `.claude/skills/` — the 38 app-marketing skills (ASO audit, keyword
  research, metadata, screenshots, paywall, onboarding, retention, Apple
  Search Ads, launch, PR, review management…). Invoke them with `/<name>`.

## Status

- [x] 2026-10-15 niche chosen from App Store data + SOSA (see LESSONS.md §3 and
  the review audit above); name "Pepline" (free on the store); bundle ID,
  RevenueCat app/products/offering, TelemetryDeck app created by API.
- [ ] ASC app record (user, 1 click) → then subscriptions + grace period by script
- [ ] GitHub secrets copied from RepLock
- [ ] Bootstrap + calculator core with tests
- [ ] Journal, protocols, reminders, weight
- [ ] Paywall, onboarding, localization, listing, screenshots, TestFlight
