# Sign in with Apple and Google — setup

The app code is done. What remains is console and portal configuration, which
cannot be committed to the repo.

**Sign-in is mandatory**, so this configuration is not optional polish — until
it is finished nobody gets past onboarding, on a device or in the simulator.
Until then the buttons render and fail: Google with `ApiException: 10` or a
redirect that never returns, Apple with a provisioning error at signing.

While working on other screens, `--dart-define=SKIP_ONBOARDING=true` starts the
app past the gate, exactly as it already skips the rest of onboarding.

Firebase project: `agentrix-health-70a12`.

## 0. Bundle IDs — done in code, pending in the console

Everything below is keyed to a bundle ID, so a mismatch here wastes the rest.
All of these now read `com.stratava.agentrixhealth`:

| Where | Status |
| --- | --- |
| `ios/Runner.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`) | done |
| `ios/Runner/GoogleService-Info.plist` (`BUNDLE_ID`) | done, and in the Runner target |
| `ios/Runner/Info.plist` (`CFBundleURLSchemes`) | done — real `REVERSED_CLIENT_ID` |
| `lib/firebase_options.dart` (`iosBundleId`, both `appId`s) | done |
| `android/app/build.gradle.kts` (`applicationId`) | done |
| `android/app/google-services.json` | done — real download, two clients |

`android { namespace }` stays `com.example.agentrix_health` on purpose: it is
only the R/BuildConfig package, and moving it would relocate `MainActivity.kt`
for no functional gain.

Verified by `flutter build ios --release --no-codesign` — the built
`Runner.app` carries the plist, bundle ID `com.stratava.agentrixhealth` and the
`com.googleusercontent.apps.…` URL scheme.

`google-services.json` still lists the retired `com.example.agentrix_health`
app alongside the real one. Harmless — the Gradle plugin matches on
`applicationId` — but the old Firebase app can be deleted to tidy it up.

## 1. Enable the providers

Firebase console → Authentication → Sign-in method.

- **Anonymous — leave enabled.** Every existing install has an anonymous uid,
  and the app links onto it rather than replacing it. Disabling this strands
  their profile.
- **Google** — enable, set a support email.
- **Apple** — enable. For iOS-native sign-in nothing else is needed. For Android
  or web (Apple's redirect flow) also fill in Services ID, Apple Team ID
  (`M5VV3927G6`), Key ID and the `.p8` key.

Authentication → Settings → **one account per email address** (the default).
With multiple accounts allowed, a user who signs in with Google and later with
Apple gets two uids and two unrelated profiles.

## 2. Apple Developer portal

1. Certificates, Identifiers & Profiles → Identifiers →
   `com.stratava.agentrixhealth` → enable **Sign in with Apple**.
2. Regenerate the provisioning profile (Xcode's automatic signing does this).

`ios/Runner/Runner.entitlements` already declares the entitlement. If the
capability is not enabled on the App ID, signing fails with
"Provisioning profile doesn't include the com.apple.developer.applesignin
entitlement".

## 3. Google Sign-In client IDs

**iOS — done.** `ios/Runner/Info.plist` carries the real `REVERSED_CLIENT_ID`
(`com.googleusercontent.apps.368943821492-bi43h31p6akhhbhgslphn91f4mtc2q7t`).
It must be re-pasted if the Firebase iOS app is ever re-registered, because that
issues a new OAuth client.

`AuthConfig.clientId` returns null on iOS now that the plist is bundled, and
`google_sign_in_ios` reads `CLIENT_ID` straight from it. The `--dart-define`
escape hatch below is only for builds that omit the plist.

**Android — still broken.** The `com.stratava.agentrixhealth` client in
`google-services.json` has only a `client_type: 3` (web) entry. There is **no
`client_type: 1`** with a `certificate_hash`, which is exactly what a missing
SHA fingerprint looks like; Google sign-in will fail with `ApiException: 10`.
The retired `com.example.agentrix_health` client does have one, which is why
the file looks populated at a glance.

Fix: Firebase console → Project settings → the `com.stratava.agentrixhealth`
Android app → add the SHA-1 **and** SHA-256 of both keystores, then re-download
`google-services.json` and confirm a `client_type: 1` entry appears.

```sh
# debug
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
# release
keytool -list -v -alias <alias> -keystore <path-to-release.jks>
```

This does not block the App Store submission — it blocks Play.

**Builds without `GoogleService-Info.plist`** can pass the IDs directly:

```sh
flutter run \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios client>.apps.googleusercontent.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client>.apps.googleusercontent.com
```

See `AuthConfig` in `lib/data/auth/social_sign_in.dart`.

## 4. Firestore rules

Account deletion removes `health_profiles/{uid}`, which the current rules
already permit. No change is required for auth itself. When per-user
subcollections land, widen to:

```js
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

## 5. Verify

- Fresh install → onboarding → the account step cannot be passed: Continue is
  disabled and states why.
- Fresh install → sign in with Apple → Firebase console shows **one** user with
  both `anonymous` and `apple.com` providers, and the same uid as before the
  sign-in. Two users means linking failed and fell through to a plain sign-in.
- Sign in on a second device with the same Apple ID → the profile appears.
- Settings → Sign out → the app returns to the sign-in gate rather than staying
  in the tabs.
- Settings → Delete account → the Firebase user and the `health_profiles`
  document are both gone, and the app returns to the welcome screen.
- Existing anonymous installs: on the next launch they hit the gate, and signing
  in **links** onto their uid, so their profile and logs survive.

## Known gaps

- **Apple sign-in on Android** is hidden (`SocialSignIn.supportsApple`), because
  it needs the Services ID from step 1 plus a callback intent filter. Ship it
  with the Android release, not before.
- **Health Connect** is unrelated to auth but blocks a usable Android build —
  no health permissions are declared in `AndroidManifest.xml`, and `minSdk`
  needs to be 26.
