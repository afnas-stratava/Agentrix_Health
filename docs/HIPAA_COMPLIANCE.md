# HIPAA Compliance

Status: **not compliant today**. This documents what the app currently does with
health data, why that fails HIPAA, and the concrete work — code and paperwork —
to close the gap. It describes the shipping app in this repo, not the backend
migration proposed in [ARCHITECTURE.md](ARCHITECTURE.md) (whose §8 is the
target end-state this doc's remediation plan converges toward).

Gemini AI and Firebase are both slated for removal (§6) — §§1–5 describe the
app as it stands with them still present, and §6 covers what's actually left
once both are gone.

---

## 1. Does HIPAA even apply?

HIPAA binds **covered entities** (providers, health plans, clearinghouses) and
their **business associates** (vendors who handle PHI *on behalf of* a covered
entity). A direct-to-consumer wellness app is not automatically either —
plenty of health apps legally run on a plain privacy policy and no BAA at all,
because no covered entity is in the loop.

You are pulled into HIPAA the moment any of these becomes true:

- A clinic, hospital, insurer, or telehealth provider integrates the app or
  white-labels it for their patients.
- The app ingests data *from* a covered entity's system (e.g. a lab pushes
  results in on the patient's behalf, not the patient uploading their own PDF).
- You sign a contract that says you're a business associate — it becomes true
  by agreement, not just by data type.

Uploading a photo of your own lab report is not, by itself, a HIPAA event —
you disclosing your own data to a company you chose is a privacy-policy /
consumer-protection matter (FTC Health Breach Notification Rule territory),
not HIPAA. **This still needs to be built for the day a covered-entity deal
shows up**, because retrofitting encryption and audit trails onto a live
production database with real user data is much more expensive than building
them in now — and §3 shows several of these gaps are worth fixing regardless
of HIPAA, because they're also just weak security.

## 2. Data inventory

| Data | Sensitivity | Where it's created | Where it goes today |
|---|---|---|---|
| Lab report PDF/photo + parsed biomarkers | High (PHI-grade) | `file_picker`/`image_picker` | Google Gemini API (parsing), device `shared_preferences` (plaintext) |
| Prescription photo + parsed contents | High | `image_picker` | Google Gemini API (parsing), device `shared_preferences` (plaintext) |
| Meal photos | Medium | `image_picker` | Google Gemini API (vision) |
| AI chat messages (health questions) | High | `ai_chat_screen.dart` | Google Gemini API |
| Voice conversation audio | High | Mic, via `flutter_sound` | Hume EVI WebSocket, direct device→Hume (never touches our backend) |
| HRV, resting HR, sleep, steps, active energy | High | HealthKit / Health Connect | `health_profiles/{uid}` in Firestore |
| Sex, DOB-adjacent age, height, weight, goals, conditions, diet/allergies | High | Onboarding screens | Firestore (`health_profiles/{uid}`) + `agentrix_backend` (`/users/me/*`) |
| Food log, hydration | Medium | Meal logging screens | Device `shared_preferences` (plaintext) |
| Location (lat/lon) | Low, transient | `geolocator` | OpenStreetMap Overpass mirrors (three third-party servers), Google Maps deep link — used for the query, not persisted server-side (per `NSLocationWhenInUseUsageDescription`) |
| Auth identity (email, name, Google/Apple ID token) | Medium | Sign-in flow | Firebase Auth, `agentrix_backend` (`/auth/google`, verifies server-side) |

Six third parties see this data before any "backend" of ours does: **Google
Firebase, Google Gemini API, Hume AI, OpenStreetMap (3 mirrors), Google Sign-In,
Apple Sign-In.**

## 3. Gap analysis

### 3.1 No Business Associate Agreement covers most of this data's path

This is the gap that makes everything else moot — a BAA is a legal
prerequisite to sending PHI to a vendor at all, independent of how well the
integration is engineered.

| Vendor | Used for | BAA available? | Status here |
|---|---|---|---|
| Google Cloud (Firebase Auth, Firestore) | Auth, profile storage — *on paper* | Yes, via [Google Cloud's HIPAA BAA](https://cloud.google.com/security/compliance/hipaa) — Firebase is in scope once accepted | **Not signed — and moot.** See §6: neither package is actually in the live data path today |
| **Google Gemini API** (`google_generative_ai`, `generativelanguage.googleapis.com`) | Lab/prescription parsing, meal vision, chat | **No.** The public Gemini API (API-key auth, what this app calls) is explicitly *not* covered by Google's BAA. Only **Vertex AI Gemini**, on a BAA-signed GCP project, qualifies. | **Sending PHI to a non-BAA endpoint today** — the single biggest compliance gap in the app |
| Hume AI (EVI voice) | Real-time voice assistant | Enterprise-tier only, confirm current terms directly with Hume before relying on it | **Not confirmed/signed** |
| OpenStreetMap Overpass mirrors | Restaurant search | N/A — no BAA program; only a coordinate pair crosses, not PHI | Fine as-is, see §3.4 |
| Apple / Google Sign-In | Auth | N/A — identity only, not PHI | Fine as-is |

**Fix:** migrate every model call in `lib/data/{labs,nutrition,prescriptions,chat}/gemini_*.dart`
from the direct Gemini API to **Vertex AI** on a BAA-covered GCP project
(same models, different endpoint/auth — `google_generative_ai` would be
replaced by Vertex's SDK, or proxied through `agentrix_backend`). Until that
lands, no lab report, prescription, meal photo, or chat message from a
real (non-test) user should reach the current integration.

### 3.2 PHI stored unencrypted on-device

`prefs_lab_repository.dart`, `prefs_meal_log_repository.dart`, and
`prefs_prescription_repository.dart` write biomarkers, meal logs, and parsed
prescriptions to `shared_preferences` — plaintext XML/plist, readable by
anything with filesystem access on a rooted/jailbroken device, and included
unencrypted in an unencrypted device backup.

**Fix:** swap `shared_preferences` for `flutter_secure_storage` (already a
dependency, currently used only for the session token in
`session_storage.dart`) or an encrypted local database (SQLCipher via Drift —
ARCHITECTURE.md §12 already scopes this for the backend migration; it applies
here regardless of whether that migration happens).

### 3.3 No audit trail on PHI access

The HIPAA Security Rule requires logging *who* accessed *which* patient's data
*when*. Today: Firestore's rules restrict access to the owning `uid` (correct
for authorization), but nothing logs reads, and `agentrix_backend` has no
access-log table at all (`app/db/`, `app/models/user.py` — just the user
record, no audit model).

**Fix:** every PHI read/write in `agentrix_backend` goes through one
data-access layer that writes an audit row (who, whose data, which fields,
when) — not scattered `db.query()` calls. Direct-SQL-from-handler becomes a
lint failure. (Same principle as ARCHITECTURE.md §8.)

### 3.4 No data-processing agreement / minimization for location

Low severity, cheap to fix: `OverpassClient` queries three independent
third-party Overpass mirrors concurrently with the user's coordinates. Not
PHI, but still worth minimizing exposure — round coordinates to ~1km precision
before the query, since restaurant search doesn't need exact GPS.

### 3.5 No breach notification procedure, no retention policy, no Security Officer

All organizational, not code. See §5.

## 4. What "compliant" actually requires (not just code)

HIPAA compliance is mostly paperwork and process; the codebase can be perfect
and you'd still not be compliant without these:

- **A signed BAA with every vendor that touches PHI** (§3.1) — legally, this
  has to exist *before* the first real PHI reaches that vendor, not after.
- **A designated Security Officer and Privacy Officer** (can be the same
  person at this size) — required by the Security Rule, §164.308(a)(2).
- **A documented risk assessment**, redone at least annually or on material
  architecture change.
- **Workforce training** — anyone with prod DB or Firebase console access
  needs documented HIPAA training, however small the team.
- **A breach notification procedure** — HHS + affected individuals within 60
  days of discovery, sooner if state law is stricter.
- **A data retention & deletion policy in writing**, matching what the code
  actually does — `AUTH_SETUP.md` already documents account-deletion
  behavior; extend it to a written retention schedule for lab documents,
  meal photos, and voice transcripts.
- **Minimum necessary access** — support staff and any admin tooling should
  see only what's needed to do the task, audited identically to user access.

## 5. Remediation priority

| # | Item | Blocks |
|---|---|---|
| 1 | Route all Gemini calls through Vertex AI on a BAA-covered project (or a backend proxy that does) | Everything — this is the active PHI leak |
| 2 | Sign Google Cloud BAA covering Firebase Auth + Firestore | Same |
| 3 | Confirm Hume AI's BAA terms, or stop sending health-context voice audio to it until confirmed | Voice feature's compliance |
| 4 | Replace `shared_preferences` PHI storage with `flutter_secure_storage` / encrypted DB | Any real user data at rest |
| 5 | Add an audited data-access layer to `agentrix_backend` | Technical safeguards requirement |
| 6 | Designate Security/Privacy Officer, write the risk assessment, retention policy, breach procedure | Legal compliance as a whole — can run in parallel with 1–5 |

Items 1–2 are the ones that matter before any covered-entity relationship is
even discussed — everything downstream of them is easier to fix once PHI
isn't already sitting somewhere it legally can't be.

## 6. Target state — after removing Gemini and Firebase

### 6.1 Firebase is already dead code in the live flow

Worth knowing before ripping it out: **Firebase isn't actually handling any
real PHI today**, despite `firebase_core`/`firebase_auth`/`cloud_firestore`
being dependencies.

- `AccountController.signIn` (`account_provider.dart`) never calls
  `FirebaseAuth.instance.signInWithCredential`. Sign-in goes device →
  `agentrix_backend`'s `/auth/google`, which verifies the Google ID token
  itself (`app/services/google_auth.py`) and reads/writes its own Postgres
  `users` row (`app/models/user.py`) — which already has `biological_sex`,
  `height_cm`, `weight_kg`, `goals`, `conditions`, `diet_pattern`,
  `allergies`, `restrictions`, `cuisines` as real columns. `firebase_auth` is
  imported only for the `FirebaseAuthException` type in
  `describeAuthError()`, whose own comment says *"No backend in this build
  ever throws one of these."*
- `FirestoreUserProfileRepository` exists (`firestore_user_profile_repository.dart`)
  but nothing constructs it. The live repository is `PrefsUserProfileRepository`
  — local device storage, not Firestore.
- `functions/` has no source beyond a scaffolded `node_modules` — nothing
  deployed there processes anything.

So removing `firebase_core`, `firebase_auth`, `cloud_firestore`,
`firestore.rules`, and the dead `firestore_user_profile_repository.dart` is
closer to **deleting unused code** than migrating live data. Good to confirm
before doing it — but it does *not* remove a working safeguard, because none
of this was providing one.

### 6.2 What's left holding PHI

| Component | Role | HIPAA posture |
|---|---|---|
| `agentrix_backend` + Postgres (self-hosted) | Auth verification, full profile (sex, body, goals, diet, conditions) | No vendor BAA needed — you control the box — but every Security Rule technical safeguard now rests entirely on this one service: encryption at rest, network isolation, access logging, encrypted backups |
| Hume AI (EVI voice) | Real-time voice assistant | Unaffected by removing Gemini/Firebase — voice audio never went through either. Still needs its BAA question answered (§3.1) |
| Device local storage (`shared_preferences`) | Labs, meals, prescriptions, food log, hydration | Unaffected — still plaintext (§3.2) |
| OpenStreetMap Overpass | Restaurant search | Unaffected — non-PHI |
| Google / Apple Sign-In | Identity handshake | Unaffected — was already going straight to `agentrix_backend`, never through Firebase |

### 6.3 Remaining gaps, reprioritized

| # | Item | Why it's here |
|---|---|---|
| 1 | Harden the Postgres instance: encryption at rest (KMS-managed keys), private networking/no public IP, encrypted backups | New emphasis, not a new problem — removing Firebase concentrates every PHI field into one database you fully own, so its infrastructure alone now has to carry what the Security Rule expects |
| 2 | Add an audited data-access layer to `agentrix_backend` (§3.3) | More urgent now — this is the *only* PHI store left |
| 3 | Replace `shared_preferences` PHI storage with `flutter_secure_storage` / an encrypted DB (§3.2) | Unchanged by either removal |
| 4 | Confirm Hume AI's BAA terms, or drop health-context voice until confirmed (§3.1) | Unchanged — the only vendor BAA question left |
| 5 | Security/Privacy Officer, risk assessment, breach procedure, retention policy, workforce training, minimum-necessary access (§4) | Unchanged — none of this was ever about which vendor was in the stack |

**Net effect:** removing Gemini and Firebase clears every *vendor BAA*
problem except Hume, because the PHI that's left never leaves infrastructure
you already control. It does not shrink the technical-safeguards or
paperwork work — if anything it sharpens item 1, since there's no longer a
large cloud vendor's own compliance program backing the data at rest. Once
Postgres is hardened and audited, and Hume is confirmed or dropped, the
remaining checklist is entirely organizational (§4), which is true no matter
what the codebase looks like.
