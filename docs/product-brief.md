# Product Brief — Agentrix Health (working name)

**Purpose of this document:** the *idea* and the *product*. No stack, no architecture, no build
instructions. Anyone can read this and understand what we are making and why it is worth making.

**Deadline:** demo-ready for Ai4, Las Vegas, Aug 4–6 2026.

---

## 1. The idea

Three sources of health data exist in most people's lives already. Each one is individually
useless.

- **A blood test** gives you a number, once a year, with no instruction attached. It tells you
  ferritin is 21 ng/mL and that this is "within range". It does not tell you to eat anything.
- **A wearable** gives you a trend with no cause attached. It tells you HRV has fallen for three
  weeks. It does not know why, so it says "consider resting".
- **A food log** gives you calories with no consequence attached. It tells you that you ate 1,840
  kcal. It does not know that you needed iron and did not get any.

Nobody has joined them. That join is the entire product.

> **The thesis, in one line:** a ferritin of 21 is "normal" on every lab report in the world, and a
> ferritin of 21 *alongside three weeks of falling HRV* is a reason to act — and the action is a
> lunch.

The output is not a dashboard. It is **one short plan a day**, in plain language, that a person can
follow before they have finished their coffee — and which tells them tomorrow whether following it
worked.

**Positioning line:** *Everyone else shows you your data. We tell you what to do with it today —
and whether it worked.*

---

## 2. Why this is different

| What exists today | What it misses | What we do |
| --- | --- | --- |
| Lab portals (LabCorp, Quest, 1mg) | A number with no behaviour attached | Turn each flagged marker into a food and habit instruction |
| Wearables (Apple Health, Oura, Whoop) | No idea *why* your recovery is poor | Explain the trend using your blood chemistry |
| Food trackers (MyFitnessPal, Cronometer) | Counts calories, ignores what your body actually lacks | Score meals against *your* deficiencies, not a generic RDA |
| AI health chatbots | Generic advice, no memory, no data | Personal, longitudinal, grounded in the user's own numbers |

The moat is the **closed loop**: deficiency → daily instruction → adherence → measurable change at
the next blood test. Nobody in this market can currently show a user a before/after on their own
biology. That is the screenshot people share.

---

## 3. The two loops

**The daily loop (retention):**

```
morning brief  →  the day happens  →  evening check-in  →  tomorrow's brief references yesterday
```

Without the evening check-in and the callback, the morning brief is a horoscope. This is the single
most important thing missing from the original spec.

**The long loop (proof, and the reason anyone pays):**

```
blood test  →  8–12 weeks of daily loops  →  re-test  →  "your ferritin went 21 → 38"
```

---

## 4. Who it is for

Primary: adults 25–45 who have had a blood test in the last year, already own a wearable or use
their phone's health app, and are "fine" but tired. Not patients, not athletes. People with a
result they did not understand and no follow-up appointment.

Secondary: people managing a chronic marker (pre-diabetic glucose, thyroid, vitamin D) between
doctor visits.

---

## 5. Screens

Screens marked **NEW** were not in the original 7-screen spec and are the gaps that need filling.
Screens marked **REVISED** need changes to work.

### 1. Welcome & Onboarding — REVISED

Name, tagline, `Get Started`. Then collect, in this order (one question per screen, keep it fast):

1. Name, age, sex at birth (needed for reference ranges — say why in one line)
2. Height, weight
3. **Dietary pattern — non-negotiable addition.** Vegetarian / vegan / eggetarian / no beef / no
   pork / halal / no restrictions, plus allergies. *The hero screen in the original spec tells the
   user to eat red meat. If she is vegetarian, the app is dead on the first screen she sees.* Every
   food suggestion in the app must be filtered through this.
4. **Medications & supplements — NEW.** Free-text or search. Two reasons: (a) safety — we must not
   tell someone on a blood thinner to load up on vitamin K greens; (b) it is the best narrative in
   the app — *"you started iron three weeks ago and your energy scores are up"*.
5. **Existing conditions** (optional, skippable): thyroid, PCOS, diabetes, hypertension, pregnancy.
6. Health goal: more energy / lose weight / build muscle / manage a condition / general wellness.
7. **Consent screen — NEW.** Plainly: what we store, what we send to an AI model, what we never
   sell, how to delete everything. One screen, plain English, one checkbox. Health data without a
   visible consent moment is a trust failure and, in most markets, a legal one.

### 2. Blood Test Upload

Upload a PDF or photo. Show the parsed panel grouped sensibly (Iron studies, Vitamins, Metabolic,
Lipids, Thyroid), each marker with its value, unit, range, and a clear flag: **Low / Optimal /
High**. Confirm state: "Report analyzed ✓ — 3 markers need attention".

Add: **an "is this right?" correction affordance.** Any parsed value must be tappable and editable.
Parsing will occasionally be wrong, and a wrong number silently driving health advice is the worst
failure mode this app has.

### 3. Connect Health Data

Apple Health, Google Fit, Fitbit, Oura, Garmin. Toggle to connect. Show what came back — steps,
sleep, resting heart rate, HRV, calories burned — so the connection is visibly real.

Add: **a baseline honesty note.** Recovery and readiness numbers mean nothing until we have ~7 days
of the user's own history. Say so — *"we'll have your baseline by Friday"* — rather than inventing
a score on day one.

### 4. Food Log — REVISED

Photo capture is the headline, but photo-only logging dies in week two. Three ways in:

- **Photo** → recognised items → **a confirm/edit step** (portion size, "was that one roti or
  three?"). Never show an unconfirmed number as fact.
- **Text or voice** ("two idli and sambar", "chicken salad")
- **Recents & favourites** — one tap for the meal you eat four mornings a week

Each logged meal card shows: items, calories, macros, and — this is the differentiator — **a
personal tag**: `+4mg iron ✓` or `high sugar — you were asked to avoid this today`. A generic
calorie count is a commodity; scoring the meal against *this user's* flagged markers is not.

Bottom: today's totals and a one-line weekly read ("avg 1,840 kcal — protein consistently low").

**Tone rule:** never scold, never show a red "over budget" number, never gamify restriction. This
app can reach people with disordered eating. Calories are present but visually quiet; nutrient
adequacy is the loud number.

### 5. Daily Morning Brief — HERO SCREEN

The screen the entire demo rests on. It must be beautiful, calm, and short enough to read in
fifteen seconds.

Content — generated from the user's actual data, not a template:

> **Good morning, Maya.**
> Tuesday, 4 August
>
> Here's today, based on your blood work and last night's sleep.
>
> 🩸 **Your iron is low.** Lentils, spinach or tofu today — with something citrus, it triples
> absorption.
> 😴 **You slept 6h 20m.** Aim for 7h 30m tonight; lights down by 10:45.
> 👟 **8,500 steps** — a little above your usual, you have room today.
> 🔥 **500 kcal burn**
> 💧 **2.5 L water**
> 🚫 **Go easy on sugar today** — yesterday was high.
> 💪 **Energy: high.** Good day to train.

Also on this screen:

- Date, greeting, readiness/energy score
- **Yesterday's callback — NEW:** one line at the top. *"Yesterday you hit your steps and got iron
  in at lunch. Two days running."* This is what converts a static card into a relationship.
- **`Why am I being told this?` — NEW.** Every line in the brief is tappable and opens a short
  sheet: the marker and value it came from, the wearable trend it came from, and a link to a
  standing clinical reference. No claim in this app should be unattributable. This is the single
  cheapest trust feature we can build and the thing a sceptical conference audience will ask about
  within ten seconds.
- **`Make it real` — NEW.** One tap turns "eat more iron" into either three specific meal options
  that fit the user's dietary pattern, or a four-item shopping list. Advice that stops at the noun
  does not change behaviour.
- `Regenerate` and `Share`

**Graceful degradation:** the brief must produce something useful with any *one* input present. No
labs yet → run off sleep, steps and food. No wearable → run off labs and food. Never show an empty
hero screen.

### 6. Evening Check-in — NEW

Thirty seconds, at ~9pm. Three or four taps:

- Did you get the iron in? ✓ / ✗
- Energy today: low / ok / high
- Anything off? (headache, bloated, poor focus, stressed) — optional chips

This is the missing half of the product. It gives us adherence data, it gives the user a sense of
closing the day, and it is what makes tomorrow's brief feel like it was written by something paying
attention. It also produces the correlations that become insights: *"your low-energy days follow
nights under 6 hours, eight times out of ten."*

### 7. Progress & Proof — NEW

The retention screen and the best thing in the demo.

- Each tracked marker over time, with the target band shaded: **Ferritin 21 → 38 ng/mL** across ten
  weeks, with the date of each blood test marked.
- Directly beside it: adherence over the same period — *"you hit your iron target on 47 of 68
  days"*.
- A `Time to re-test` prompt when a marker's follow-up window arrives.
- Trends for readiness, sleep and energy alongside it.

This is the screen that makes the case that the app *worked*. It should be the last thing shown in
any pitch.

### 8. Weekly Review — NEW

Sunday evening. What improved, what slipped, and **one single focus for next week**. One focus —
not a list. A list is how weekly summaries get dismissed.

### 9. Cycle & Wellness — REVISED

The original spec forks the app by gender and gives men a consolation prize. Don't. Instead:

- **Cycle tracking is an optional module** any user can switch on in onboarding or settings.
- **Everyone** gets the readiness / energy score — it is core, not a fallback.
- When the module is on, cycle phase becomes **an input to the morning brief**, which is the whole
  point of having it: iron demand rises during menstruation, so the low-ferritin finding gets
  louder that week; perceived effort rises in the luteal phase, so the step target eases off. A
  calendar that does not feed the brief is decoration.
- Calendar with the current phase highlighted, plus one AI line: *"Day 14 — energy peaks around
  now. Good week for the heavier sessions."*

### 10. Profile & Settings

Name, goal, dietary pattern, medications, connected devices. Blood test history as a list with
dates, each opening the full panel. Morning brief time (default 7:00 AM), evening check-in time,
weekly review on/off. Export my data. Delete my account. Disclaimer.

---

## 6. What the morning brief is actually made of

Worth being explicit, because "AI generates it" is not a spec.

**Inputs:** flagged biomarkers with values and how old the report is · last night's sleep · 7-day
and 28-day trends for HRV, resting heart rate, steps · yesterday's food log and nutrient gaps ·
yesterday's check-in answers · cycle phase if enabled · dietary pattern and allergies · medications
· stated goal.

**Output shape:** a greeting, a yesterday callback, and 5–7 lines, each with an emoji, a claim, and
an action. Every line carries the marker or trend it came from so the `Why?` sheet can be built
from it.

**Hard rules for the generated text:**

1. Never diagnose. Never name a disease. "Your iron is low" — not "you have anaemia".
2. Never contradict the dietary profile. A vegan must never be told to eat fish.
3. Never contradict the medication list.
4. If a value is in a genuinely concerning range, the only advice is **"take this to a doctor"** —
   with the value and the range shown so it can be handed over. No self-treatment for red flags.
5. No number appears in the brief that we cannot trace back to a source.
6. Encouraging, never scolding. Short sentences. No jargon. No hedging paragraphs.

---

## 7. Safety and scope

Non-negotiable, and worth saying on stage before anyone asks:

- **This is not a medical device and does not diagnose.** It surfaces associations in the user's own
  data alongside published reference ranges. A persistent, plain-English disclaimer on the brief and
  on every insight.
- **Red-flag escalation, not reassurance.** Certain values route straight to "see a clinician".
- **Pregnancy, eating disorders, and under-18s** are out of scope for now; detect and hold back
  advice rather than guess.
- **The user owns their data.** Export and delete must exist and must work.

---

## 8. It has to learn

Two small mechanics, easy to miss, that separate this from a generator:

- **Dismissals stick.** "Not for me" on a suggestion removes that class of suggestion. Tell someone
  to go running four times after they have dismissed it and the app is dead.
- **It notices patterns and says them out loud.** *"You skip breakfast on weekdays — let's put the
  iron in lunch instead."* Adapting to real behaviour rather than restating the ideal is what makes
  it feel like an assistant.

---

## 9. Design direction

Clean, minimal, premium. References: **Whoop** (data density with restraint), **Levels** (warmth,
plain-language insight), **Zero** (typographic confidence — one number per screen).

**Palette.** Deep teal as the brand, white/off-white as the ground, soft gold as an accent used
*sparingly*. Gold marks exactly one thing per screen — the day's primary action, or a milestone
reached. The moment gold appears three times on a screen it has stopped meaning anything.

**Status colour is a separate system from the brand palette.** Low / optimal / high needs its own
ramp, and it cannot be red-amber-green alone — that is invisible to roughly one man in twelve, which
is a real fraction of a conference floor. Pair every status colour with a shape or a word: a filled
dot *and* the label "Low". Never encode a health claim in hue alone.

**Light or dark?** Recommendation: **light app, dark hero.** The app is off-white and calm; the
morning brief card is deep teal with white type and a single gold accent, so the one screen that
matters looks like nothing else in the product. Whoop and Zero are dark-first because they are
night-and-recovery products — a morning brief reads better bright. Build a real dark mode, but after
the demo.

**Type.** Inter or DM Sans, either is fine. What reads as premium is the scale, not the family: one
hero number per screen at a size that feels almost too large, body text at 16–17pt, no more than
three weights in the entire app, and tabular figures everywhere numeric so values don't jitter as
they animate.

**Space over ornament.** What reads as a $20/month app: generous whitespace, one clear action per
screen, real typographic hierarchy, precise alignment, restrained motion. What reads as cheap:
gradient soup, stock illustrations of smiling people, four accent colours, drop shadows on
everything, an emoji in every heading, dense cards competing for attention. The brief's emoji are
the deliberate exception — they earn their place by making a wall of text scannable in fifteen
seconds.

**Motion has one job.** The brief should *assemble* — line by line, quickly, as though it is being
written for you. That single animation is as much of the wow moment as the content is. Everything
else: a readiness ring that draws once, and standard transitions. No parallax, no bounce, no
confetti.

**Charts follow three rules.** Shade the target band so "good" is obvious without reading numbers.
Baseline against the user's own history, never a population average. Never draw a trend from four
data points — say *"we'll have your baseline by Friday"* instead.

**Every screen owes three more states.** Loading, empty, and wrong. Design them now, not the night
before — half of a demo's ugliness lives in states nobody designed.

**Accessibility is not polish.** System text sizing, 4.5:1 body contrast, 44pt touch targets, never
colour alone. Also practical: strangers will hold this phone at arm's length under bad booth
lighting. Anything under 15pt disappears at the booth.

---

## 10. The demo at Ai4

### Three lengths, because most people give you thirty seconds

**30 seconds — the walk-by.** Hold up the brief. *"Her blood test says her iron is low. Her watch
says her recovery has been falling for three weeks. Nobody connects those two facts — we do, and we
turn them into what she should eat today."* Then swipe to Progress: *"Ten weeks later her ferritin
went from 21 to 38."*

**3 minutes — the interested visitor.** The walk-through below.

**10 minutes — an investor or partner.** Add the closed loop and why re-test data is defensible, the
safety position, the pricing thesis, and Phase 2.

### The three-minute walk-through

Three changes from the original script: onboarding is skipped, the `Why?` tap-through is added, and
it ends on proof instead of the cycle tracker.

One persona, chosen so that every differentiator fires:

> **Maya, 34.** Vegetarian. Goal: more energy. Blood work: **ferritin 21 ng/mL** (low-normal),
> **vitamin D 18 ng/mL** (low), HbA1c 5.4 (fine). Wearable: HRV down 12% over three weeks, sleep
> averaging 6h 20m, 7,240 steps yesterday. Cycle: day 3, menstrual phase.

1. **Start with her profile already filled** — one line: *"Maya, 34, vegetarian, wants more
   energy."* Do not demo form fields. Nobody at a booth wants to watch typing. Have onboarding ready
   to show only if someone asks.
2. **Her blood test, already analysed.** Ferritin flagged low. *"Every lab report in the world calls
   this normal."*
3. **Health data synced.** The HRV trend, falling for three weeks.
4. **Food log** — a few meals already in, iron tags visible on each.
5. **`Generate My Plan`** → the brief assembles, line by line. The wow moment.
6. **Tap the iron line.** The `Why?` sheet: ferritin 21, HRV down 12%, the clinical citation. *This*
   is the moment the room understands it is not a chatbot with a nice card. Do not skip it — it is
   the first question a technical audience asks.
7. **Evening check-in**, three taps. Then next morning: *"Yesterday you got your iron in. Third day
   running."*
8. **Cycle tracker**, briefly — and only to show that phase feeds the brief.
9. **Progress screen. Ferritin 21 → 38.** Close here: *"We didn't show her data. We changed a number
   in her blood."*

**On the closing line:** drop *"knows your body better than you do"*. It is unprovable, and to a room
full of AI people it reads as surveillance rather than insight. The number in the blood is the
stronger claim because it is concrete and checkable.

### The most fragile moment

Step 5 is a live generation on conference wifi, and it is also the moment the entire demo rests on.
Assume the network fails. The brief for this persona must be **pre-generated and cached** so that
`Generate My Plan` produces the same beautiful line-by-line result with the device in airplane mode.
Rehearse it that way. If the live call works at the booth, nobody can tell the difference — and if it
doesn't, nobody can tell either.

### Booth logistics

- **Two devices**, both loaded, both charged, one in a pocket as backup.
- **Brightness maxed and locked. Auto-lock off. Notifications off.** A personal text arriving on the
  lock screen mid-pitch is a memorable way to lose a room.
- **Reset-to-start in one action** — you will run this two hundred times. A hidden long-press on the
  logo that reloads the demo state is worth the hour it takes to build.
- **An answer ready for "what's real?"** — *"the analysis and the plan generation are real; reading
  the lab PDF and the wearable connection are mocked for the floor."* Honest reads as competent.
  Caught pretending does not.
- **Have an ask.** A QR code to a waitlist, on the table and on the final screen. A conference demo
  with no capture is an expensive way to be admired.

---

## 11. Scope order for the seven days

**P0 — the demo path, must work end to end:** onboarding including dietary pattern and medications ·
blood upload with parsed panel · health connect with visible data · morning brief · the `Why?`
sheet · evening check-in · progress/proof screen.

**P1 — build if the P0 path is solid:** food log with confirm step · `Make it real` · cycle module
feeding the brief · weekly review.

**P2 — after the conference:** notification scheduling depth · trend detail per marker · re-test
reminders · adaptive dismissals · data export.

Pre-load and rehearse the demo data. A booth demo that depends on a live camera, live parsing, and
conference wifi will fail in front of the one person who matters.

---

## 12. Deliverables by Aug 3

- [ ] App installed and running on a real phone, demo-ready
- [ ] Every screen navigable, no dead ends and no placeholder screens
- [ ] Brief generation working — **and the cached fallback verified in airplane mode**
- [ ] Mock data loaded and **clinically coherent**: the labs, the wearable trend, the food log and the
      check-ins must all agree with one another. There will be clinicians on that floor, and a
      ferritin of 21 sitting next to a perfect recovery score is the one detail that unravels the
      pitch
- [ ] Loading, empty and error states present on every screen
- [ ] Disclaimer copy in place on the brief and on every insight
- [ ] Reset-to-start action working
- [ ] No crash across a twenty-run rehearsal
- [ ] **Full dry run on Aug 2** — real device, airplane mode, driven by someone who has never seen
      the app. Not Aug 3. Aug 3 is for fixing what the dry run finds
- [ ] Six screenshots for the deck, and a 60-second screen recording to loop at the booth for people
      who walk past without stopping
- [ ] Waitlist QR code live and tested

---

## 13. Open decisions — need answers before Friday

1. **The name.** "Agentrix Health" is a placeholder. It needs to survive being said out loud at a
   booth.
2. **Calorie visibility.** Recommendation: show them, keep them visually quiet, make nutrient
   adequacy the loud number. Confirm.
3. **Food coverage.** Indian meals must be recognised well (our own testing) while the demo audience
   is American. Which cuisine set do we guarantee for the demo?
4. **Units.** Recommendation: US conventional (ng/mL, mg/dL, lbs) for this audience, with metric as
   a setting.
5. **How much do we claim on stage?** Recommendation: "decision support, not diagnosis", said
   explicitly and early. It is a stronger position with this audience than overclaiming.
6. **Cycle module default** — on for users who report female sex at birth, or always opt-in?
   Recommendation: opt-in, prompted once.
7. **What justifies $20 a month?** Worth settling before the booth, because someone will ask. The
   morning brief is the *habit* — it is also the part a competitor can copy in a quarter. The part
   that justifies the price is the **receipt**: a marker that moved, with the adherence data beside
   it. Recommendation: lead with the brief, price on the proof, and never pitch this as an
   AI-chat-for-your-labs product.
8. **Who owns the waitlist** and what happens to the addresses collected at the booth? Decide before
   we start collecting them.

---

## 14. Phase 2 — deliberately not yet

Not being built for the demo, and worth saying so plainly when asked:

- Real health-platform integration (Apple Health / Google Fit) — mock data for the demo
- Real lab-report reading — pre-parsed data for the demo
- Telemedicine, live clinicians, referrals
- Broad food recognition beyond the demo set
- Insurance, claims, employer wellness programmes
- Family or multi-user accounts
- Wearable and Android parity
- Anything requiring a partnership to demonstrate

**One item on that list deserves a direct note: facial or expression analysis.** It is the most
likely thing on this list to draw a hostile question at an AI conference, and the honest answer is
that we have no evidence it measures anything useful about health and no consent model that would
make it acceptable. Leaving it out is the stronger position, not the weaker one. If it comes up, say
that.

Otherwise: say what is mocked whenever you are asked. An honest prototype reads as competence. A
prototype caught pretending does not.

---

## 15. Project

**Product:** Agentrix Health (name TBD — see decision 1)
**Founder:** Stebin
**Conference:** Ai4 2026 · Las Vegas · Aug 4–6 · booth TBD
**Demo build due:** Aug 3 · **dry run:** Aug 2

**Not a medical device.** This app does not diagnose. It surfaces associations in a person's own data
alongside published reference ranges, and every screen that shows a finding says so.
