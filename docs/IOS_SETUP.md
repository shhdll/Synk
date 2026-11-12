# Install Synk on your iPhone

Works from **Windows or Mac**.

## 1. Install Sideloadly

1. Download and install **Sideloadly**: [sideloadly.io](https://sideloadly.io)
2. **Windows only:** also install **iTunes** from [Apple's site](https://www.apple.com/itunes/download/win64), then restart your PC.

## 2. Download the app

1. Open [Actions → Build iOS app](https://github.com/shhdll/Synk/actions/workflows/ios-build.yml).
2. Open the latest run with a green ✓.
3. Under **Artifacts**, download **Synk-ios** and unzip it → **`Synk.ipa`**.

## 3. Install it

1. Plug your iPhone into the computer, unlock it, tap **Trust**.
2. In Sideloadly:
   - **iDevice:** your iPhone
   - **Apple ID:** your Apple ID email
   - Drag **`Synk.ipa`** onto the **IPA** icon
3. Click **Start**, enter your Apple ID password (and the 6-digit code if asked).
4. Wait for **Done**.

## 4. Allow it on your iPhone

1. **Settings → Privacy & Security → Developer Mode** → on → restart → **Turn On**.
2. **Settings → General → VPN & Device Management** → your email → **Trust**.
3. Open **Synk**.

## Have a Mac? Run it live with hot reload

Instead of steps 1–4, you can `flutter run` straight onto your iPhone, like on Android.

**One-time setup**

1. Install [Flutter](https://docs.flutter.dev/get-started/install/macos/mobile-ios) and **Xcode** from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835). Open Xcode once and let it install the iOS components.
2. Install CocoaPods and switch Flutter to it:
   ```sh
   brew install cocoapods
   flutter config --no-enable-swift-package-manager
   ```
3. Add the secret files (see Environment and Keys in the [README](../README.md#3-environment)):
   - `.env` in the project root (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
   - `ios/Flutter/Secrets.xcconfig` containing `MAPS_API_KEY=<the iOS Maps key>`
4. Run `flutter pub get`, then `open ios/Runner.xcworkspace`.
5. In Xcode: **Runner** target → **Signing & Capabilities**:
   - **Team:** **Add an Account…** → sign in with your Apple ID → pick **(Personal Team)**.
   - **Bundle Identifier:** change to something unique, e.g. `com.yourname.synk`.
     **Don't commit this change.**
6. On the iPhone: turn on **Developer Mode** (step 4 above).

**Every time**

Plug in the iPhone and run:

```sh
flutter run
```

Hot reload (`r`) works like on Android. The first launch may ask you to **Trust** your Apple ID on the iPhone (step 4 above).

## Important

- **The app stops opening every 7 days.** Plug in, open Sideloadly, drag in `Synk.ipa`, click **Start** again. Your data stays.
- **No notifications on iPhone.** Apple only allows them with a paid account.
- **Newer version?** Download the latest `Synk.ipa` (step 2) and install it the same way.
- **iPhone not showing in Sideloadly (Windows)?** Make sure iTunes is from Apple's site, replug, tap Trust.
