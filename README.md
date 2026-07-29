# Vitals — Health Correlation App

Correlates daily Apple HealthKit telemetry (HRV, resting heart rate, sleep, active energy, steps)
with point-in-time clinical lab reports (PDF or photo) to produce actionable, evidence-backed
lifestyle and dietary suggestions.

The product thesis in one line: **a ferritin of 21 ng/mL is "normal" on every lab report in the
world, and a ferritin of 21 alongside three weeks of falling HRV is a reason to act.** Neither
signal alone is interesting. The intersection is the whole app.

---

## Stack

| Concern | Choice |
| --- | --- |
| Framework | Expo SDK 55 · React Native 0.83.10 · Hermes · New Architecture (default in 55) |
| Navigation | `expo-router` v55 — file-based, typed routes, native modal presentation |
| Styling | `nativewind` v4 + `lucide-react-native` |
| HealthKit | `react-native-health` behind a platform-agnostic provider interface |
| Lab ingestion | `expo-document-picker` + `expo-image-picker` |
| Server state | `@tanstack/react-query` v5 |
| Client state | `zustand` v5 with `AsyncStorage` persistence |
| Validation | `zod` at every boundary — network, storage, and rule output |
| Types | Strict TypeScript, `noUncheckedIndexedAccess` on |

## Getting started

```bash
npm install
cp .env.example .env          # leave EXPO_PUBLIC_API_BASE_URL empty to run fully offline
npx expo prebuild --clean     # required: HealthKit needs a native build
npx expo run:ios --device     # HealthKit returns no data on the Simulator
```

`react-native-health` is **not** available in Expo Go. You need a development build.

### Offline mode

With `EXPO_PUBLIC_API_BASE_URL` empty the app runs entirely on-device:

- `src/features/labs/parser.mock.ts` returns a fixed, clinically coherent 18-marker panel.
- `src/features/health/synthetic.provider.ts` generates deterministic telemetry encoding a
  three-week HRV decline.

The two are designed to agree, so the iron, inflammation and vitamin-D rules light up and every
screen is developable and screenshot-stable without a backend or a paired Apple Watch.

Nutrition, the brief and dish ranking need no backend at all — they are deterministic and run
entirely on device. Dining falls back to curated venues without a Places key.

### Demo persona

Settings › Demo data loads a complete example user: a wellness panel whose ferritin clears the
lab's own floor but sits below the optimal band, a fortnight of vegetarian meals, hydration, and a
logged cycle history placing them mid-luteal with a measured 29-day cycle. It is coherent on
purpose — the low ferritin, the synthetic provider's HRV decline, the iron-poor week of eating and
the luteal phase all point at the same story. `__tests__/demo-persona.test.ts` asserts that story
still falls out of the data, so a seeded fixture cannot quietly stop producing findings.

---

## Architecture

```
app/                              expo-router tree — routing only, no business logic
├── _layout.tsx                   providers, root stack, modal registration
├── index.tsx                     hydration gate → onboarding or dashboard
├── onboarding/                   welcome → sex → body → goals → diet → HealthKit priming
├── (tabs)/                       today · food · insights · labs · (settings, off-bar)
├── brief.tsx                     the composed morning plan
├── dining.tsx                    nearby restaurants, ranked dish-first
├── profile.tsx                   full profile editor incl. cycle logging
├── meal/log.tsx                  meal logging — photo, search, portions
├── upload.tsx                    lab ingestion sheet (modal)
├── metric/[metric].tsx           metric detail + correlations (modal)
└── lab/[id].tsx                  report detail, grouped by panel (modal)

src/
├── schemas/                      zod contracts — the single source of truth for every type
├── features/
│   ├── health/                   HealthKit adapter, synthetic provider, daily aggregation
│   ├── labs/                     pickers, parser client, reference-range table
│   ├── correlation/              statistics kernel, rule catalogue, engine, readiness
│   ├── insights/                 the hook that joins telemetry + labs and runs the engine
│   ├── profile/                  resolves the declared profile + demographics into one object
│   ├── cycle/                    menstrual phase model and phase-specific guidance
│   ├── nutrition/                food table, targets, plate suggestions, weekly patterns
│   ├── brief/                    the morning-brief composer
│   ├── dining/                   Places client, fixture venues, dish-level ranking
│   └── demo/                     seeded persona for demos and screenshots
├── components/                   ui/ · health/ · labs/ · insights/ · nutrition/ · navigation/
├── store/                        zustand slices (settings, labs, health, profile, nutrition)
├── lib/                          api, query client, storage, date, env, logger
└── theme/                        hex mirrors of the Tailwind palette (SVG icons need values)
```

### Layer rules

- **`app/` contains no business logic.** Screens read hooks and render. Everything testable lives
  in `src/features`.
- **The engine is pure.** `runEngine(context)` does no I/O and reads no clock beyond
  `context.now`, so the same inputs always produce the same output. That is what makes it
  testable and the UI cacheable.
- **Every boundary is validated.** Network responses go through `zod` in `src/lib/api.ts`;
  persisted state is re-validated on hydration; even rule output is parsed before it reaches the
  UI, so a malformed rule cannot take down the Insights tab.

---

## The correlation engine

### Statistics (`src/features/correlation/stats.ts`)

Dependency-free and pure. Notably it computes a real two-tailed p-value from the Student's *t*
distribution via the regularised incomplete beta function (Lentz's continued fraction). A normal
approximation is not good enough here — correlation windows are routinely 14–30 days, where the
*t* and *z* tails diverge materially.

Correlations are **gated conservatively**: `n ≥ 10` paired days and `p < 0.05` before anything is
shown. An r of 0.8 across six days is noise, and presenting it as a finding is how health apps
lose credibility.

### Rules (`src/features/correlation/rules.ts`)

Twelve rules, each a pure predicate over `{ biomarkers, telemetry }`. Nine require **both** sides
to agree; three fire from telemetry alone (sleep debt, overreaching, circadian drift).

Severity is `info | watch | action | urgent`. `urgent` never means "you have X" — it means "take
this to a clinician". Citations are curated links to standing clinical references (NIH ODS,
CDC, AHA, ATA) fixed at authoring time; nothing is generated at runtime.

Scores are discounted for lab staleness (120-day half-life), OCR confidence, and telemetry
coverage — with a floor under medical-referral insights so "see a doctor" never falls off the list
because the data was imperfect.

### Readiness (`src/features/correlation/readiness.ts`)

Weighted composite of HRV (0.40), resting HR (0.25), sleep duration (0.20) and efficiency (0.15),
expressed as z-scores against the user's **own** 28-day baseline, not a population norm. Metrics
where lower is better have their sign flipped, so a positive contribution always means "this is
helping you today". Suppressed entirely below 7 baseline days rather than showing an invented
number.

---

## Nutrition, the brief, and dining

Three subsystems sit on top of the correlation engine. All three are **deterministic** — the same
inputs always compose the same output, everything works with the network off, and there is no
model that can invent a biomarker the user does not have. For anything that touches blood results
that is the right trade: the prose is assembled from clauses rather than written fresh, but it can
be audited line by line.

### Targets (`src/features/nutrition/targets.ts`)

Mifflin–St Jeor BMR, then total expenditure from **measured** wearable active energy where a week
of it exists and the declared activity multiplier only as a fallback — the UI says which. Protein
is set per kilo of bodyweight and goes *up* in a deficit, carbohydrate share tightens for declared
dysglycaemia, and the luteal phase adds a 5% expenditure premium. There is a hard calorie floor no
goal can push through.

### Weekly patterns (`src/features/nutrition/patterns.ts`)

Counts days, never averages them — three clean days and four heavy ones average out to "fine",
which is exactly the conclusion worth avoiding. Days with no log are excluded from denominators
rather than counted as zero-intake, and below three logged days it reports sparseness instead of
inventing findings.

### The brief (`src/features/brief/compose.ts`)

Composes blood work + last night's recovery + cycle phase + the week's eating into one plan.
Training intensity starts from readiness and is only ever *capped* by sleep, cycle phase and
urgent lab findings — one good night never unlocks a hard session on a suppressed HRV. Food focus
resolves in priority order: flagged biomarker → weekly pattern → cycle phase → standing goal. Every
brief carries a `drivers` list (what shaped it) and a `caveats` list (what it could not see).

### Dining (`src/features/dining/`)

Google Places supplies venues; it does **not** supply menus, and nothing here pretends otherwise.
Dishes come from the same food table the logger uses, filtered by the venue's cuisine, which is
what makes the macros real — the numbers behind a recommendation are the numbers written to the
food log if the user taps to log it. Allergens and diet pattern are hard filters that apply
identically in cheat mode; restrictions down-rank rather than exclude.

Places failures are non-fatal at every step: no key, no network, exhausted quota or an empty result
all fall through to the curated venues in `fixtures.ts`, disclosed in the UI as example venues.

---

## HealthKit notes

Three things about HealthKit that shaped the implementation:

1. **Read permissions are opaque by design.** iOS never tells you whether read access was granted
   — that would let an app infer a condition from an empty result set. The only honest signal is
   "did `initHealthKit` succeed", so the UI must also handle *granted but permanently empty*. That
   is the `syncedButEmpty` flag surfaced in Settings.

2. **Overlapping sleep samples are the norm.** The iPhone writes `INBED` while the Watch writes
   staged sleep and a third-party ring writes its own take on the same night. Summing raw
   durations reports 14 hours of sleep. `src/features/health/aggregate.ts` does an interval sweep:
   every distinct boundary becomes an elementary segment credited to the single highest-priority
   stage covering it, so total minutes can never exceed wall-clock time.

3. **Observers cover a fixed enum only.** `react-native-health` cannot observe step count, active
   energy or sleep analysis. Heart-rate observers are the useful proxy — the Watch writes HR and
   the day's activity in the same sync burst. Anything missed is caught by the foreground refetch.

`null` and `0` are never conflated. A day with no steps recorded is *unknown*, not a day of zero
walking, and the engine depends on being able to tell those apart.

---

## Backend contract

Only one endpoint is required, and only if you want real OCR:

```
POST /v1/labs/parse        multipart: document=<file>, source=pdf|image
→ 200 { reportId, status, collectedAt, labName, panelName,
        biomarkers[], overallConfidence, warnings[] }
```

The exact response shape is `LabParseResponseSchema` in [src/schemas/labs.ts](src/schemas/labs.ts)
— that schema *is* the contract, and a drift surfaces as a typed `ValidationError` rather than an
undefined-property crash three screens later.

Biomarker flagging is deliberately **client-side** even when the server supplies ranges: the
"optimal band" opinion belongs to the app and can be revised without a server deploy.

---

## Tests

```bash
npm test        # 153 tests
npm run typecheck
```

Coverage is concentrated where the risk is — the pure logic that produces health claims:

- `stats.test.ts` — Pearson against hand-computed values, p-values against the *t* distribution,
  and the significance gating that rejects strong-looking correlations on thin data.
- `aggregate.test.ts` — the sleep interval sweep (no double-counting across sources, priority
  resolution, wake-day attribution) and null-vs-zero handling.
- `reference-ranges.test.ts` — unit conversion, the optimal-band distinction, and refusal to guess
  at unknown units.
- `engine.test.ts` — that rules fire only when both signals agree, severity escalation, staleness
  discounting, and readiness orientation.
- `nutrition-targets.test.ts` — the Mifflin–St Jeor constants, measured-over-estimated expenditure,
  the protein floor rising in a deficit, the luteal premium, and the calorie floor no goal breaks.
- `cycle-phase.test.ts` — that ovulation lands at length−14 rather than a fixed day 14, that a
  skipped log cannot distort the measured length, and that a stale log yields *no* phase rather
  than a rolled-over one.
- `nutrition-patterns.test.ts` — that findings count days instead of averaging them, that a single
  banana is not a logged day, and that no water logged produces silence, not an accusation.
- `dining-rank.test.ts` — the hard dietary filters, including that **cheat mode is not an allergen
  exemption**, and that a venue with nothing edible is dropped rather than recommended.
- `brief-compose.test.ts` — that sleep and cycle phase can only cap intensity, that a low ferritin
  leads on iron, that diet filters reach the recommended examples, and that composition is
  deterministic.
- `demo-persona.test.ts` — that the seeded demo still tells the story it is supposed to tell.

Two of these caught real bugs during development: `enrichBiomarker` was not idempotent (it
relabelled app-supplied ranges as lab-supplied on re-run, and it re-runs on every render of the
insights feed), and the readiness bands were asymmetric about 50, so a user exactly at their own
baseline was told their readiness was "Low".

---

## Known gaps / deliberate choices

- **Meal photos are not analysed.** There is no vision model in this build. `recognize.ts` narrows
  the food table down to what a given user plausibly ate at a given meal — from their cuisines,
  diet, time of day and logging history — and the user confirms in two taps. The photo is captured
  and attached to the entry, but the macros come from that confirmation, not from the image. The UI
  says so verbatim (`SUGGESTION_BASIS`) and never claims to have identified anything. Dropping in a
  real vision endpoint means implementing one function against the existing `PlateSuggestion[]`
  shape; every call site downstream already treats confidence below 1 as "needs confirming".
- **Restaurant menus are not read.** Places returns names, ratings, types and coordinates — never
  dish lists. Dish recommendations are cuisine-typical, which every card discloses.
- **The Places key ships in the bundle.** There is no backend to proxy it, so it **must** be
  restricted in the Cloud console to this bundle ID and the Places API alone. See `.env.example`.
- **Cycle data is logged in-app, not read from HealthKit.** iOS records menstrual flow, but
  `react-native-health` exposes no menstrual category at all, so there is nothing to read. Phase is
  inferred from logged period starts, with cycle length *measured* from the user's own history
  (median gap, so one skipped log cannot distort it) once two are on file.
- **Nothing pulls results from a phone number.** iOS gives no programmatic SMS access. The paths
  that could work are a share-sheet extension, an inbound WhatsApp Business number, or a
  forwarding address — none of which are built. Gmail import *is* built and works.
- **Gmail is limited to test users.** `gmail.readonly` is a Google Restricted scope; until OAuth
  verification and a CASA assessment complete, only accounts added as Test Users can connect.
- **Tab bar is a custom component, not `unstable-native-tabs`.** `src/components/navigation/PillTabBar.tsx`
  implements the floating pill bar with a centre FAB, which the stock tab bar clips. Navigation
  semantics still come from React Navigation, so deep links, state restoration and the Android back
  button behave normally. Swapping to `expo-router/unstable-native-tabs` is a contained change to
  `app/(tabs)/_layout.tsx` — but it is still marked unstable and does not accept arbitrary SVG icons.
- **Android has no telemetry.** HealthKit is iOS-only; Android resolves to the synthetic provider.
  A Health Connect adapter would implement the same `HealthProvider` interface in
  [src/features/health/types.ts](src/features/health/types.ts) and need no changes above it.
- **Icons and splash are flat-colour placeholders** generated at scaffold time. Replace
  `assets/*.png` before shipping.
- **`exactOptionalPropertyTypes` is off.** It makes `<Foo bar={cond ? x : undefined} />` an error
  for every optional prop, which is idiomatic React and would be worked around with casts — a net
  loss in type safety. Everything else under `strict` is on.

## Not a medical device

This app does not diagnose. It surfaces statistical associations in a user's own data alongside
population reference intervals, and every screen that shows a finding says so.
