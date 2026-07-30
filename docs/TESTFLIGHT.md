# Shipping Agentrix Health to TestFlight

Runbook for the iOS beta. Steps marked **[you]** need a human with account
access; the rest are repeatable commands.

---

## 0. Prerequisites

| Thing | State |
| --- | --- |
| Apple Developer Program | Enrolled |
| Xcode account on this Mac | **Not signed in** — see step 1 |
| Bundle identifier | **Placeholder `com.example.agentrixHealth`** — see step 2 |
| App icon | Done — lime/ink "A", all 15 sizes, no alpha |
| Export compliance | Done — `ITSAppUsesNonExemptEncryption = false` |
| Orientation | Done — portrait only, matching the RN app |
| Free disk space | **~2 GB. An archive wants 5–10 GB.** See step 6 |

---

## 1. Sign this Mac into the developer account **[you]**

`security find-identity -v -p codesigning` currently reports *0 valid
identities*, so nothing can be signed yet.

1. Xcode → Settings → Accounts → **+** → Apple ID → sign in.
2. Select the team → **Manage Certificates…** → **+** → *Apple Development*
   and *Apple Distribution*.
3. Confirm: `security find-identity -v -p codesigning` now lists at least one
   `Apple Distribution: …` identity.
4. Note the 10-character Team ID (Xcode → Settings → Accounts, or
   developer.apple.com → Membership).

---

## 2. Set the bundle identifier

`com.example.*` is rejected at upload. Pick a reverse-DNS ID you control, then:

```bash
OLD=com.example.agentrixHealth
NEW=com.yourorg.agentrixhealth        # <- the real one
TEAM=ABCDE12345                       # <- 10-char Team ID

cd ios
sed -i '' "s/${OLD}/${NEW}/g" Runner.xcodeproj/project.pbxproj
# DEVELOPMENT_TEAM is absent entirely; add it to each of the three Runner configs
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = ${NEW};/PRODUCT_BUNDLE_IDENTIFIER = ${NEW};\n\t\t\t\tDEVELOPMENT_TEAM = ${TEAM};/g" Runner.xcodeproj/project.pbxproj
```

Verify — expect the new ID for Runner **and** `${NEW}.RunnerTests`:

```bash
grep -E "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM" ios/Runner.xcodeproj/project.pbxproj | sort -u
```

> The RN app uses `com.vitals.health` and is named "Vitals". If these are meant
> to be the same product, align the name and pick distinct IDs per platform —
> two apps cannot share one bundle ID.

---

## 3. Register the app in App Store Connect **[you]**

1. developer.apple.com → Certificates, IDs & Profiles → Identifiers → **+** →
   App IDs → App → bundle ID from step 2. Enable no extra capabilities (the app
   currently uses none — no HealthKit, no push).
2. appstoreconnect.apple.com → Apps → **+** → New App:
   - Platform iOS, name, primary language, the bundle ID, SKU (any unique
     string, e.g. `agentrix-health-ios`).
3. Under the new app → **App Privacy**: a privacy declaration is required
   before external testing. The app collects name, age, gender, dietary
   preferences and (later) blood-test data — declare *Health & Fitness* and
   *Contact Info*, and whether it is linked to identity.

---

## 4. Version and build number

`pubspec.yaml` drives both (`version: 1.0.0+1` → `CFBundleShortVersionString`
1.0.0, `CFBundleVersion` 1).

**Every upload needs a build number no one has used before.** Bump the `+N` on
each attempt, including re-uploads of the same version.

---

## 5. Enable Firebase anonymous auth **[you]**

Startup currently logs:

```
Firebase setup failed, continuing without cloud sync:
[firebase_auth/admin-restricted-operation]
```

Anonymous sign-in is disabled for project `agentrix-health-70a12`, so **nothing
a tester enters is persisted anywhere**. The app degrades gracefully, so this
will not fail review — but the beta collects no data until it is fixed.

Firebase console → Authentication → Sign-in method → **Anonymous** → Enable.

Also check Firestore → Rules. Default test-mode rules expire ~30 days after
creation and are world-readable until then — not something to point real
testers at.

---

## 6. Free disk space

The archive step needs several GB and this volume has ~2 GB. Reclaimable, in
descending order:

```bash
du -sh ~/Library/Caches/Google ~/Library/Caches/com.openai.atlas \
       ~/Library/Caches/com.spotify.client ~/Library/Developer/Xcode/DerivedData
```

---

## 7. Build and upload

```bash
flutter clean
flutter pub get
flutter build ipa --release
```

The IPA lands in `build/ios/ipa/`. Upload with either:

```bash
# App-specific password from appleid.apple.com → Sign-In and Security
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  -u you@example.com -p "xxxx-xxxx-xxxx-xxxx"
```

…or open `build/ios/archive/Runner.xcarchive` in Xcode → Organizer →
**Distribute App** → App Store Connect, which reports validation errors more
legibly on a first attempt.

---

## 8. TestFlight **[you]**

- **Internal testing** — up to 100 App Store Connect users, no review, live in
  minutes. Start here.
- **External testing** — up to 10 000 testers, but requires Beta App Review
  (typically < 24 h) plus a description, feedback email, and the completed
  privacy declaration from step 3.

Processing takes 5–15 minutes after upload before a build is selectable.

---

## Known gaps before external testers see this

- **No health data integration.** `HealthKit` appears only in comments and Dart
  contracts (`lib/features/health/telemetry_samples.dart` defines the platform
  contract; nothing implements it on iOS). The onboarding "connect your health
  apps" step toggles local state only. Do not describe Apple Health support in
  the TestFlight notes yet — claiming an absent feature is a review risk.
- **No medical disclaimer in-app.** The RN app carries one on its welcome
  screen ("not a medical device and does not diagnose"). Guideline 1.4.1
  applies to anything health-adjacent; add it before external review.
- **Firestore rules** unverified (step 5).
