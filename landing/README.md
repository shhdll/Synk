# synk.cc auth landing pages

Static pages that Supabase auth emails link to. Each page forwards the email's
token into the app through the `io.supabase.synk://` scheme; the app verifies
it with `verifyOTP` (see `lib/models/auth_deep_link_handler.dart`).

| Page                  | Email          | Opens in app                                              |
| --------------------- | -------------- | --------------------------------------------------------- |
| `index.html`          | Confirm signup, Magic link | `io.supabase.synk://login-callback?token=…&type=…` |
| `reset-password.html` | Reset password | `io.supabase.synk://reset-password?token=…`               |
| `change-email.html`   | Change email   | `io.supabase.synk://login-callback?token=…&type=email_change` |
| `expired.html`        | (any, when Supabase reports an expired or used link) | `io.supabase.synk://login-callback` |
| `support-reply.html`  | Support message (team inbox) | Not opened in the app; sends a reply through the `reply-support` function |
| `activity.html`       | (shared activity link, `?id=…`) | `io.supabase.synk://activity?id=…` |

Sign-up, magic link and email change links are confirmed on the page itself
(Supabase `/auth/v1/verify`, using `config.js`), so it can show the real
result. For sign-up the session is passed to the app as
`io.supabase.synk://login-callback?refresh_token=…` so it signs straight in.
Password reset links are forwarded to the app as before, and the page also
shows a new password form so the link works on a phone without Synk. The token
is only used when the form is submitted (`/auth/v1/verify`, then
`PUT /auth/v1/user`), so "Continue to Synk" can still pass it to the app.

`config.js` holds the project URL and the public anon key (the same values the
app ships with).

## Admin dashboard

`admin/` is the team's dashboard at `https://synk.cc/admin/`: overview numbers,
support tickets, reports, users, activities and an audit log. Admins sign in
with their normal Synk email and password. All data goes through the
`admin_*` functions in `20261107100000_admin_dashboard.sql`, which check admin
access on the server.

To add an admin, run this in the Supabase SQL editor:

```sql
insert into private.admins (user_id)
select id from auth.users where email = 'someone@example.com';
```

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
