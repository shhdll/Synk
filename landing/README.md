# synk.cc auth landing pages

Static pages that Supabase auth emails link to. Each page forwards the email's
token into the app through the `io.supabase.synk://` scheme; the app verifies
it with `verifyOTP` (see `lib/models/auth_deep_link_handler.dart`).

| Page                  | Email          | Opens in app                                              |
| --------------------- | -------------- | --------------------------------------------------------- |
| `index.html`          | Confirm signup, Magic link | `io.supabase.synk://login-callback?token=…&type=…` |
| `reset-password.html` | Reset password | `io.supabase.synk://reset-password?token=…`               |
| `change-email.html`   | Change email   | `io.supabase.synk://login-callback?token=…&type=email_change` |

The pages never verify the token themselves: verifying consumes it, and the
app needs it to create its session. So the link must be opened on the phone
where Synk is installed.

## Deploy

Serve this folder as the root of `https://synk.cc` (Netlify, Cloudflare Pages,
GitHub Pages, etc.). No build step.

## Supabase dashboard

**Authentication → URL Configuration**

- Site URL: `https://synk.cc`
- Redirect URLs:
  - `https://synk.cc/*`
  - `io.supabase.synk://login-callback`
  - `io.supabase.synk://reset-password`

**Authentication → Email Templates**: paste the matching file from
`supabase/templates/`:

| Template       | File                  | Link                                                                        |
| -------------- | --------------------- | --------------------------------------------------------------------------- |
| Confirm signup | `confirm_signup.html` | `https://synk.cc/index.html?token={{ .TokenHash }}&type=signup`             |
| Reset password | `reset_password.html` | `https://synk.cc/reset-password.html?token={{ .TokenHash }}`                |
| Change email   | `change_email.html`   | `https://synk.cc/change-email.html?token={{ .TokenHash }}&type=email_change` |
| Magic link     | `magic_link.html`     | `https://synk.cc/index.html?token={{ .TokenHash }}&type=magiclink`          |
