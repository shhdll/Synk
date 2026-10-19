# Running Synk on an iPhone (no Mac, no paid Apple account)

Synk can be installed on an iPhone for free, from a Windows PC. A GitHub-hosted
Mac builds the app, and Sideloadly installs it with a normal Apple ID.

**Android is not affected.** The iOS work only adds the `ios/` folder, a
build workflow, and the iOS app icon. No Dart code or Android files changed.

| Step | Who | Time |
| --- | --- | --- |
| 1. Create a Google Maps key for iOS | Whoever owns the Google Cloud project | 5 min |
| 2. Add 3 secrets to the GitHub repo | A repo admin | 5 min |
| 3. Build the app | Anyone with repo access | ~15 min (automatic) |
| 4. Install it on an iPhone | Each person who wants the app | 10 min |

---

## 1. Create a Google Maps key for iOS

The Android map key does not work on iPhone: Google needs **Maps SDK for iOS**
enabled, and the Android key is usually restricted to Android apps. Without
this step the app works, but the map is a blank grey screen.

Showing the map in a phone app is free. Turning on the SDK and creating a key
add no charges (the project already has billing set up for Android).

1. Go to <https://console.cloud.google.com> and pick the Synk project at the top.
2. **APIs & Services → Library** → search **Maps SDK for iOS** → **Enable**.
3. **APIs & Services → Credentials** → **+ Create credentials → API key**.
4. Click the new key and set:
   - **Name:** `Synk iOS`
   - **Application restrictions:** **None**.
     (Not "iOS apps": Sideloadly can change the app's bundle ID when it
     signs it, which makes Google reject the key.)
   - **API restrictions:** **Restrict key** → tick only **Maps SDK for iOS**.
5. **Save**, then copy the key (starts with `AIza…`) and send it to the repo
   admin privately (not in a group chat or a commit).

Leave the existing Android key exactly as it is.

## 2. Add the secrets to GitHub

Repo → **Settings → Secrets and variables → Actions → New repository secret**.
Add these three:

| Name | Value |
| --- | --- |
| `SUPABASE_URL` | `SUPABASE_URL` from your local `.env` |
| `SUPABASE_ANON_KEY` | `SUPABASE_ANON_KEY` from your local `.env` |
| `MAPS_API_KEY` | The **iOS** key from step 1 (not the Android key) |

Secrets are never shown in logs and are only used by the build.

## 3. Build the app

1. Repo → **Actions** → **Build iOS app** (left sidebar) → **Run workflow**
   → choose the branch → **Run workflow**.
2. Wait about 15 minutes for the green check.
3. Open the run, scroll to **Artifacts**, and download **Synk-ios**.
4. Unzip `Synk-ios.zip` → you get **`Synk.ipa`**.

The build only runs when started by hand, so normal pushes don't use Actions
minutes. If it fails (red X), open the failed step and share the error.

## 4. Install on your iPhone

### One-time setup on your PC

1. Install **iTunes** from Apple's website, not the Microsoft Store:
   <https://www.apple.com/itunes/download/win64>
2. Install **Sideloadly**: <https://sideloadly.io>
3. Restart the PC.

### Install

1. Plug the iPhone into the PC with a cable, unlock it, and tap **Trust**.
2. Open Sideloadly:
   - **iDevice:** pick your iPhone.
   - **Apple ID:** your Apple ID email (a normal free one works).
   - Drag **`Synk.ipa`** onto the big **IPA** icon (the `.ipa`, not the `.zip`).
   - Leave **Advanced Options** as they are (Fake Anisette, Apple ID Sideload).
3. Click **Start**, enter your Apple ID password and the 6-digit code if asked.
4. Wait for **Done**.

### Allow it on the iPhone

1. **Settings → Privacy & Security → Developer Mode** → on → restart →
   **Turn On**.
2. **Settings → General → VPN & Device Management** → tap your email →
   **Trust**.
3. Open **Synk**.

### If something goes wrong in Sideloadly

- **iPhone not listed:** make sure iTunes is the Apple-website version,
  replug, tap Trust, restart Sideloadly.
- **Sign-in / "anisette" error:** Advanced Options → gear → try **Remote**,
  then Start again.
- **"Maximum number of apps":** a free Apple ID allows 3 sideloaded apps;
  delete one.

---

## Limits of the free setup

- **The app stops opening after 7 days.** Plug in the phone, open
  Sideloadly, drag in the same `Synk.ipa`, click Start. Data is kept.
- **No push notifications on iPhone.** Apple only allows them with the paid
  Apple Developer account ($99/year). The app already skips notification
  setup on iOS, so nothing breaks.
- **No `flutter run` / hot reload on iPhone** (that needs a Mac). Keep
  developing on Android with hot reload; the Dart code is shared, so changes
  behave the same. Build for iPhone when you want to check it there.
- **Getting a newer version:** run step 3 again on the latest branch and
  install the new `Synk.ipa` the same way. It replaces the old one and keeps
  your data.

## What changed in the code (for reviewers)

- `ios/` — generated with `flutter create --platforms=ios` (Flutter 3.47.3),
  plus:
  - `Runner/Info.plist` — location, photo library and camera permission
    messages; the `io.supabase.synk://` URL scheme for password reset and
    email confirmation links (same as Android); `FlutterDeepLinkingEnabled`
    off, matching the Android manifest; `GMSApiKey` read from the build.
  - `Runner/AppDelegate.swift` — passes the Maps key to Google Maps.
  - `Flutter/Debug.xcconfig`, `Release.xcconfig` — include the git-ignored
    `Secrets.xcconfig` that holds `MAPS_API_KEY`, so the key is never
    committed.
- `.github/workflows/ios-build.yml` — manual cloud build that produces
  `Synk.ipa` (unsigned; Sideloadly signs it).
- `pubspec.yaml` — `flutter_launcher_icons` now also generates the iOS icon.
- `analysis_options.yaml`, `.metadata` — Flutter's automatic updates when the
  iOS platform is added.
