# Install Synk on your iPhone

Free, no paid Apple account needed. Works from **Windows or Mac**.

## 1. Install Sideloadly

| Windows | Mac |
| --- | --- |
| 1. Install **iTunes** from Apple's site (**not** the Microsoft Store): [64-bit](https://www.apple.com/itunes/download/win64) · [32-bit](https://www.apple.com/itunes/download/win32) | — |
| 2. Install **Sideloadly**: [sideloadly.io](https://sideloadly.io) | 1. Install **Sideloadly**: [sideloadly.io](https://sideloadly.io) |
| 3. Restart your PC | |

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

## Important

- **The app stops opening every 7 days.** Plug in, open Sideloadly, drag in `Synk.ipa`, click **Start** again. Your data stays.
- **No notifications on iPhone.** Apple only allows them with a paid account.
- **Newer version?** Download the latest `Synk.ipa` (step 2) and install it the same way.
- **iPhone not showing in Sideloadly (Windows)?** Make sure iTunes is from Apple's site, replug, tap Trust.
