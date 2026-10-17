# Sources behind the calculator and the App Review stance

Every number hardcoded in `Pepline/Core` and every claim in the listing must
trace back to a line here. Checked 2026-10-15. Primary sources first; a
secondary source is marked as such and is never the only support for a constant.

## Syringe math (`Syringe`, `Reconstitution`)

| Fact | Used in | Source | Grade |
|---|---|---|---|
| U-100 = 100 units per ml, so 1 unit = 0.01 ml; 0.3/0.5/1 ml barrels hold 30/50/100 units | `Syringe.unitsPerMl`, `capacityUnits` | ISO 8537:2016 (scale graduated for one insulin concentration only) — [ISO preview](https://cdn.standards.iteh.ai/samples/60510/48984eed42a3423cbc00211624e06068/ISO-8537-2016.pdf); FDA alert examples (5 units = 0.05 ml) — [FDA, 2024-07-26](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded) | primary |
| Graduation: 0.3 ml → 1 unit **or 0.5 unit**; 0.5 ml → 1 unit; 1 ml → 1 **or 2** units | `Syringe.tickUnits` | ISO 8537:2016 says increments are set by risk analysis; Annex H carries the legacy U-100 increments (paywalled). Interval table from the MSF supply catalogue citing ISO 8537 — [MSF unicat](https://unicat.msf.org/cat/product/76543) (secondary); half-unit 0.3 ml SKUs exist — [McKesson listing](https://mms.mckesson.com/product/1084640/Embecta-Medical-II-LLC-326730) | secondary — **tick depends on the SKU, so it must be a user setting, not a constant** |
| Volume = dose × water ÷ vial mass | `Reconstitution.draw` | Dimensional analysis (concentration = mass ÷ volume); no source needed | — |

## IU conversion (`IUConversion`)

| Fact | Source | Grade |
|---|---|---|
| Somatropin: 1 mg anhydrous = 3.0 IU | European Pharmacopoeia somatropin monograph — [Ph. Eur. 6 (drugfuture mirror)](https://www.drugfuture.com/Pharmacopoeia/EP6/data/somatropin%20concentrated%20solution.pdf); USP: "one mg of anhydrous Somatropin is equivalent to 3.0 USP Somatropin Units" — [USP 35](https://www.drugfuture.com/Pharmacopoeia/USP35/data/v35300/usp35nf30s0_m77500.html) | primary (pharmacopoeias) |
| No other IU preset ships: IU/mg is compound- and batch-specific (it is a bioactivity unit) | same | — |

## Why exact math and unit clarity matter

- **FDA alert, 2024-07-26** — overdoses of 5–20× with compounded semaglutide
  drawn from vials; causes: confusion between ml, mg and units, and providers
  miscalculating. Example: 5 units (0.05 ml) drawn as 50 units on a 1 ml
  syringe; 0.25 mg prescribed as 25 units instead of 5. FDA asks for "the
  appropriate syringe size for the intended dose". —
  [FDA](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded)
  → Product rules: always show units **and** ml **and** mg side by side; draw
  the syringe; flag doses that are a tiny fraction of the barrel.

- Onboarding "facts" screen (`OnboardingView.FactsScreen`): the three
  numbers come only from the FDA alert above (5–20× overdoses; 5 units drawn
  as 50 on a 1 ml syringe) and U-100 (1 unit = 0.01 ml). No efficacy claim
  for any compound, ever (guideline 1.4.1; the competitor's "2.4× faster
  healing on BPC-157" is exactly what we don't do).
- "One misread mark" screen: 5 mg + 2 ml, 250 mcg = 10 units = 0.1 ml; 15
  units = 0.15 ml = 375 mcg (+50%) — the calculator's own math
  (`ReconstitutionTests.testClassicFiveMgTwoMl`).

## App Review (guidelines read 2026-10-15 on developer.apple.com)

- **1.4.2** "Drug dosage calculators must come from the drug manufacturer, a
  hospital, university, health insurance company, pharmacy or other approved
  entity, or receive approval by the FDA or one of its international
  counterparts." Apple has never defined "dosage calculator" publicly
  ([forum thread, no answer](https://developer.apple.com/forums/thread/774177)).
  — [Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **1.4.1** medical apps get more scrutiny; "Apps should remind users to check
  with a doctor in addition to using the app and before making medical
  decisions."
- **5.1.3(ii)** may not store personal health information in iCloud → on-device
  only (matches our no-account stance; no CloudKit sync of the journal).
- **5.1.1(v)** an app that lets users create an account must let them delete
  it in the app; with Sign in with Apple that includes revoking the token
  through Apple's REST API ("Apps that support Sign in with Apple should use
  the Sign in with Apple REST API to revoke user tokens" —
  [Apple, Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/))
  → `server/api/apple/revoke.js` + Settings > Delete my account.
- **5.2.1** no third-party trademarks without permission → no Ozempic/Wegovy/
  Mounjaro/Zepbound in name, subtitle, keywords or screenshots.
- How the live competitors pass 1.4.2 (App Store pages, 2026-10-15):
  - PeptidePal: "Unit conversion only — PeptidePal does not recommend a dose."
    — [listing](https://apps.apple.com/us/app/peptidepal-peptide-tracker/id6762102880)
  - PepCalc: "for research and educational purposes only. Not for medical use.
    This app does not provide medical advice." Now **$9.99** one-time. —
    [listing](https://apps.apple.com/us/app/pepcalc-peptide-calculator/id1524577846)
  → Our stance: a **unit converter for the dose the user's prescriber already
  set**, never a dose suggestion; disclaimer + "check with your doctor" in
  onboarding, calculator footer and listing; no dose presets, no titration.

## Calendar (`DoseSchedule` tests)

- EU summer time starts the last Sunday of March and ends the last Sunday of
  October (Directive 2000/84/EC) → 2026-03-29 and 2026-10-25 in the tests.
  — [EUR-Lex](https://eur-lex.europa.eu/eli/dir/2000/84/oj/eng) (Art. 2–3: 01:00 GMT, last Sunday of March / October)

## Weight (`Fmt.weight`, `Fmt.kilograms`)

- Stored in kg; converted for display with Foundation's `UnitMass.pounds`
  (no constant in our code). The international avoirdupois pound is exactly
  0.45359237 kg since the 1959 international yard and pound agreement —
  [Wikipedia, International yard and pound](https://en.wikipedia.org/wiki/International_yard_and_pound)
  (secondary; NIST SP 811 Appendix B lists 4.535 924 E-01).

## Half-lives (`CompoundPreset.halfLifeHours`, `MedicationLevel`)

The estimated-level curve uses first-order elimination,
amount(t) = Σ doseᵢ · 0.5^((t − tᵢ)/t½), each dose counted as absorbed at once.
It is shown as an estimate, never a measurement, with this method stated
(App Review 1.4.1). Presets only where a product label states a half-life;
otherwise the user types the value from their own label, or no curve is drawn.

| Compound | t½ used | Source | Grade |
|---|---|---|---|
| Semaglutide | 168 h | Ozempic label §12.3, "an elimination half-life of approximately 1 week" (rev. 5/2026) — [DailyMed](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=adec4fd2-6858-4c99-91d4-531f5f2a2d79) | primary |
| Tirzepatide | 120 h | "elimination half-life of approximately 5 days", citing the Mounjaro package insert — [Lilly Medical](https://medical.lilly.com/us/products/answers/what-is-the-half-life-of-mounjaro-tirzepatide-311137) | manufacturer |
| Liraglutide | 13 h | Saxenda label, plasma half-life about 13 h — [label reproduction](https://medlibrary.org/lib/rx/meds/saxenda/page/5/), [SAHPRA label](https://www.sahpra.org.za/wp-content/uploads/2021/02/Saxenda_PI_Novo-Nordisk-Pty-Ltd_Old-MCC-Format31-March-2020.pdf) | label copies |
| Retatrutide | none | ~6 days is quoted online but could not be found in the NEJM 2023 phase-2 paper (Jastreboff, DOI 10.1056/NEJMoa2301972) | not verified → no preset |

## Nutrition data (`FoodData`, `FoodService`)

- **Open Food Facts**: product data under the Open Database License (ODbL),
  which requires attribution — shown in Add food and Settings
  ("Food data © Open Food Facts contributors, ODbL").
  [openfoodfacts.org/terms-of-use](https://world.openfoodfacts.org/terms-of-use),
  [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
- API etiquette from the [Open Food Facts API docs](https://openfoodfacts.github.io/openfoodfacts-server/api/):
  a custom `User-Agent` "AppName/Version (contact)", at most 15 product
  reads/min and 10 searches/min per user. Search therefore runs on submit
  only, never per keystroke.
- **Meal photo estimate**: Claude (`claude-opus-5-5`) through
  `server/api/food/scan`, Pro only. Values are labelled "AI estimate" and
  always editable before saving. No nutrition goal is suggested: the user
  types targets agreed with their clinician.
- App Review 5.1.2(i): an app must disclose and get permission before it
  shares personal data with a third party, **including third-party AI** (this
  wording was added in 2025). Covered by `ScanConsentView` before the first
  photo and a Settings toggle. ⚠️ Quote the exact wording here before
  submission (developer.apple.com was unreachable on 2026-10-17).
