# App Store submission

Bundle ID `com.stratava.agentrixhealth`, team `M5VV3927G6`, iPhone-only
(`TARGETED_DEVICE_FAMILY = 1`), deployment target iOS 15.0.

Auth and Firebase setup lives in [AUTH_SETUP.md](AUTH_SETUP.md); this file is
everything else between here and a build in review.

## Blocking — placeholder URLs

`lib/core/config/app_info.dart` ships **placeholder URLs**. Apple opens the
privacy-policy link during review, and a 404 behind it is a rejection on its
own. Replace before archiving:

| Constant | Needs |
| --- | --- |
| `privacyPolicyUrl` | A live page. Must disclose the Gemini processing below. |
| `termsUrl` | A live page. |
| `websiteUrl` | Support/marketing landing page. |
| `supportEmail` | A monitored inbox — it is also the ASC support contact. |

`AppInfo.version` is maintained by hand against `version:` in `pubspec.yaml`.
Bump both together; `test/about_section_test.dart` pins that the footer and the
About row agree, but nothing checks it against the pubspec.

## Blocking — what the privacy policy has to say

The app sends health data to a third party, so the policy cannot be generic.
It must name, at minimum:

- **Lab reports → Google Gemini.** An uploaded PDF or photograph is sent to
  Gemini to be read into biomarker values (`lib/data/labs/gemini_lab_parser.dart`).
- **Assistant questions → Google Gemini.** Each message carries a summary of
  the user's readiness, food log and latest results
  (`buildHealthAssistantSystemPrompt` in `lib/features/chat/health_assistant.dart`).
  The readiness score is **derived from HealthKit** — HRV, resting heart rate,
  sleep — which is what brings this under App Review guideline 5.1.3.
  Disclosure plus consent makes it permissible as "improving health
  management"; silence does not.
- **Location → Google Places.** Sent for the nearby-restaurant search, not
  retained.
- **Profile → Firebase.** Name, goal and body measurements, keyed by uid.

Check which Gemini tier the key is on. Consumer-tier terms let Google use
submissions to improve their products; that is not a property you want true of
someone's blood work, and the policy would have to admit it.

The in-app version of this disclosure is the "What leaves your device" section
of `AboutScreen`, reachable from Settings → About and support.

## Done in the repo

- `ios/Runner/PrivacyInfo.xcprivacy`, in the Runner target. Declares no
  tracking, eight collected data types, and `CA92.1` / `C617.1` required-reason
  APIs. Every plugin that touches a required-reason API ships its own manifest;
  those are not restated. **Keep this in step with the App Privacy answers in
  App Store Connect** — a mismatch is its own rejection.
- `NSHealthUpdateUsageDescription` removed. The app is read-only
  (`HealthDataAccess.READ` for every type in `HealthKitHealthProvider`).
  Add the key back in the same commit as the first write.
- HealthKit entitlement scoped without `health-records`.
- Sign in with Apple alongside Google, as guideline 4.8 requires.
- In-app account deletion (guideline 5.1.1(v)), which clears the cloud copy and
  local storage.
- Medical disclaimers on the morning brief, home, insights and About screens.
- App icon at 1024px with no alpha.
- `ITSAppUsesNonExemptEncryption = false` — the only crypto is a SHA-256 nonce
  for the Apple sign-in handshake, which is exempt.

## App Store Connect

- App record under `com.stratava.agentrixhealth`, category Health & Fitness
- **Demo account in the review notes**, seeded with lab reports and a food log.
  Sign-in is mandatory, so a reviewer with no account sees nothing but the gate.
- Review notes should also say: how to trigger the HealthKit prompt, that the
  simulator uses a synthetic telemetry provider, and where location is used
- App Privacy questionnaire matching `PrivacyInfo.xcprivacy`
- Screenshots: 6.9" iPhone (1320×2868 or 1290×2796). No iPad set — iPhone-only.
- Privacy policy URL and support URL
- Age rating — typically 12+ with "Medical or Treatment Information: Infrequent"
- Export compliance, matching the plist flag above

## Build

```sh
flutter build ipa --release --dart-define=PLACES_API_KEY=…
```

Forgetting `PLACES_API_KEY` does not fail the build — restaurant search falls
back to fixtures silently. The Gemini key comes from `secrets.dart`, which is
gitignored; a build without it falls back to the local rule-based assistant.

Verify on a **physical device**: HealthKit does not exist on the simulator, so
the synthetic provider masks real permission bugs. Check the app survives the
user *denying* HealthKit, location, camera and photos.

## Known gaps

- **Gmail import needs Google OAuth verification + annual CASA.**
  `gmail.readonly` is a restricted scope: until verified you are capped at 100
  users and every user sees an unverified-app warning. The share-sheet path
  (`CFBundleDocumentTypes` → `SharedDocumentReceiver`) reaches every mail
  provider with none of that. Consider shipping v1 on the share sheet alone.
- **The Gemini API key ships inside the binary** and is extractable from an
  IPA. Not an Apple problem; a quota-bill problem. A thin proxy is the fix.
- **Android** is not submission-ready: the `com.stratava.agentrixhealth` client
  in `google-services.json` has no SHA fingerprint, so Google sign-in fails
  with `ApiException: 10`. See AUTH_SETUP.md §3.
- Three tests fail on `main`, all pre-existing: two in
  `tab_bar_alignment_test.dart` (looking for an `Icons.add` centre action that
  is not in the bar) and one in `rank_test.dart` — `rank.dart` keeps
  `reasons.take(2)` but appends the focus reason last, so it is always
  truncated away.
