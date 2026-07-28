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

---

## Architecture

```
app/                              expo-router tree — routing only, no business logic
├── _layout.tsx                   providers, root stack, modal registration
├── index.tsx                     hydration gate → onboarding or dashboard
├── onboarding/                   welcome → reference-range profile → HealthKit priming
├── (tabs)/                       today · insights · labs · settings
├── upload.tsx                    lab ingestion sheet (modal)
├── metric/[metric].tsx           metric detail + correlations (modal)
└── lab/[id].tsx                  report detail, grouped by panel (modal)

src/
├── schemas/                      zod contracts — the single source of truth for every type
├── features/
│   ├── health/                   HealthKit adapter, synthetic provider, daily aggregation
│   ├── labs/                     pickers, parser client, reference-range table
│   ├── correlation/              statistics kernel, rule catalogue, engine, readiness
│   └── insights/                 the hook that joins telemetry + labs and runs the engine
├── components/                   ui/ · health/ · labs/ · insights/ · navigation/
├── store/                        zustand slices (settings, labs, health)
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
npm test        # 62 tests
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

Two of these caught real bugs during development: `enrichBiomarker` was not idempotent (it
relabelled app-supplied ranges as lab-supplied on re-run, and it re-runs on every render of the
insights feed), and the readiness bands were asymmetric about 50, so a user exactly at their own
baseline was told their readiness was "Low".

---

## Known gaps / deliberate choices

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
