# Activity content moderation

Before an activity is published or edited, its **title, description, location name and photo** are checked by OpenAI's moderation model (`omni-moderation-latest`). Inappropriate content is never saved. The check runs on the server, so it can't be bypassed from the app.

## How it works

```
App ──► save-activity (Edge Function)
          1. Checks the user's token (Supabase, then the function itself)
          2. Body ≤ 2.9 MiB; strict field allowlist, before the photo is decoded
          3. begin_activity_save   suspension, idempotency, leases, one save at a time, rate limit
          4. Photo: JPEG only, ≤ 2 MB, ≤ 4096 px a side and 4 MP, fully decoded,
             re-encoded (removes EXIF/GPS and anything hidden in the file)
          5. OpenAI: one call per text field + one for the photo, in parallel
          6. Upload the re-encoded photo to <user>/<activity>.<request>.jpg
          7. finish_activity_save  the one transaction that writes the activity
          (or fail_activity_save after any failure in 4–6, which releases the lease)
          8. Delete the files the database says to delete (the replaced photo, unused uploads)
```

| Piece | Where |
|---|---|
| Edge Function | `supabase/functions/save-activity/` (term check in `text_policy.ts`) |
| Database (phase 1) | `supabase/migrations/20261112100000_activity_save_requests.sql` |
| Lock-down, rollbacks, inspection | `supabase/manual/activity_moderation/` (kept out of `migrations/` on purpose) |
| App | `lib/models/activity_save_model.dart`, `lib/models/pending_activity_save_store.dart`, `lib/utils/activity_photo_jpeg.dart`, `lib/controllers/create_activity_controller.dart`, `lib/views/create_activity/` |
| Tests | `supabase/tests/activity_moderation/`, `supabase/functions/save-activity/*_test.ts` (incl. `text_policy_test.ts`), `test/activity_moderation_test.dart` |

### Moderation rules (version 1)

Only OpenAI's own true/false decisions are used. There are **no custom score thresholds**.

- **Synk's own term check first** (`text_policy.ts`): title, description and location name are rejected without calling OpenAI when they contain an obvious sexual or explicit term in English or Arabic as a whole word, including spaced, repeated, leetspeak, look-alike and punctuated spellings (`sex`, `s 3 x`, `سكس`, `إباحية`). The model can pass a lone word like "sex"; this closes that gap. Innocent words containing the letters (`Sussex`, `unisex`, `الجنسين`) pass. The app gets the usual `rejected` with the field; the matched word isn't returned or logged (logs show `detail: text_policy`).
- **Text** (title, description, location name): blocked when `flagged` is `true`. That covers every category: harassment, hate, illicit, sexual, sexual/minors, self-harm and violence.
- **Photo**: blocked when any category in `IMAGE_BLOCK_CATEGORIES` is `true`. The default list is the six categories OpenAI applies to images: `sexual`, `violence`, `violence/graphic`, `self-harm`, `self-harm/intent`, `self-harm/instructions`. The model looks at the image pixels; the file name and metadata are never sent.
- **Each text field is also sent with a cleaned copy**, to catch tricks like `f.u.c.k`, `ｆｕｃｋ`, `shiiiit`, and harakat or stretched letters in Arabic.
- **Failures block the save.** If the answer is missing, malformed, a timeout, a 429/5xx after one retry, or the key is missing or invalid, nothing is saved and the host sees "We couldn't check your activity right now. Please try again."

**Before launch, calibrate the photo list.** Run about 40 test photos:
- normal padel and football;
- people holding rackets, bats, bows and similar equipment;
- blood or severe injuries;
- graphic violence;
- weapons in a threatening setting;
- sexual images;
- self-harm;
- medical images;
- violent cartoons;
- text inside images.

If ordinary sports photos come back with `violence: true`, set `IMAGE_BLOCK_CATEGORIES` to the other five; `violence/graphic` still blocks blood and gore. Unknown names or an empty value fall back to all six, so a typo can't switch photo checks off.

### What the app shows

| Result | The app |
|---|---|
| `saved` | Success |
| `rejected` | "This doesn't follow our community guidelines…", with the flagged fields highlighted and the form kept |
| `moderation_unavailable`, `storage_failed`, `save_failed`, lost connection | A retry message. Saving again with the same content reuses the request id |
| `conflict` | "This activity was changed on another device…". The latest version is shown and the editor closes |
| `schedule_conflict`, `capacity_below_participants` | The same behaviour as before, now translated |
| `request_mismatch` | A general error. **Never resent automatically**; the next tap is a new attempt |

Scores, categories and database errors are never sent to the app.

### Idempotency and concurrent edits

- **Each save has its own `request_id`, and the server stores a SHA-256 hash of its content.**
  - Same id and same content: the stored result comes back, and nothing runs again (no triggers, no notifications, no upload).
  - Same id and different content: `request_mismatch`.
- **A new activity's id is made once per form**, so retries can't create a second activity.
- **`activities.edit_version` goes up only when something the host edits changes.** An edit sends the version it started from; if the activity changed since, the save is refused with `conflict`.
- **Interrupted saves are kept on the phone until a final answer arrives.** When the app or the form opens again, the user is asked "Finish saving your activity?".

### Limits

| | |
|---|---|
| Request body | 2.9 MiB, checked from the header and while reading |
| Photo | 2 MB after decoding; JPEG only (the app converts every photo first) |
| Photo size | at most 4096 px a side and 4 megapixels, checked before decoding |
| Title / description / location / address | 30 / 500 / 80 / 300 characters |
| Rate | 10 new saves per 10 minutes, 50 per 24 hours per user (retries of the same save don't count) |
| Attempts | 5 per save; then `too_many_attempts` |
| One at a time | per user and per activity (`busy`) |

## Privacy

- **Sent to OpenAI:** activity titles, descriptions, location names and photos, for automated safety checks only. OpenAI says API data isn't used for training by default; check their current data policy. **Mention this in the app's privacy policy and store listing.**
- **Not sent:** names, user ids or tokens.
- **Photos lose their EXIF and GPS data** on the phone and again on the server, before anything is stored or checked.
- **Logs** contain only ids, result codes, field names, timings and database error codes; never the text, the photo, the key or the token.
- **The request table** (`private.activity_save_requests`) stores ids, a hash, statuses and result codes, never activity content. Rows are deleted after 7 days.
- **Activity reports** stay as the safety net for anything moderation misses.

## Configuration

| Secret | Required | Value |
|---|---|---|
| `OPENAI_API_KEY` | yes | An OpenAI API key. Without it every save fails closed |
| `IMAGE_BLOCK_CATEGORIES` | no | A comma-separated subset of the six image categories. Default: all six |

`SUPABASE_URL` and the service key are provided by Supabase.

`config.toml` keeps `verify_jwt = true` for `save-activity`, and the function also checks the token with Supabase Auth. Only if Supabase rejects valid tokens (reported with the newer JWT signing keys) should this become `verify_jwt = false`. The function already refuses requests without a valid `Authorization: Bearer` token and a user from `auth.getUser`.

## Deployment, in this order

**Phase 0: check the live project (read-only).** Run `supabase/manual/activity_moderation/00_inspect_live_setup.sql` in the SQL Editor and keep the output. In particular:
- the insert and update policies on `activities` (they were made in the dashboard);
- the photo bucket's current limits;
- that `private.is_suspended` exists.

If any `activities` policy enforces more than "host is you" or "not suspended", that rule must be added to `finish_activity_save`.

**Phase 1: database.** Run `supabase/migrations/20261112100000_activity_save_requests.sql`. It only adds things, so older app versions keep working.

**Phase 2: Edge Function.**
```bash
supabase link --project-ref <project-ref>
supabase secrets set OPENAI_API_KEY=<key>
supabase functions deploy save-activity
```
Test it with the new app build: create and edit activities with clean and inappropriate text and photos, in English and Arabic. Also run the photo calibration set.

**Phase 3: release the app.** The new version saves only through `save-activity`. Direct writes are still allowed here, which is expected. Watch the function logs (`result` counts, `ms`, `photo_px`) for a few days.

**Phase 4: lock down**, only after phase 3 is confirmed. Run `supabase/manual/activity_moderation/lockdown.sql`. It:
- revokes direct insert and update on `activities` from app users;
- removes the hosts' photo upload and overwrite storage policies;
- limits the photo bucket to `image/jpeg` up to 2 MB.

From then on, **older app versions can no longer create or edit activities**; viewing, joining, deleting and chat still work. There's no forced-update mechanism in the app, so ask testers to update first.

## Rollback

| To undo | Run |
|---|---|
| Phase 4 | `supabase/manual/activity_moderation/lockdown_rollback.sql`. Direct writes come back for older apps, and the bucket goes back to JPEG/PNG up to 5 MiB; this also reopens the way around moderation |
| Phase 2 | Redeploy the previous function version. Moderation fails closed, so an OpenAI outage pauses publishing; there's no bypass switch on purpose |
| Phase 1 | `supabase/manual/activity_moderation/phase1_rollback.sql`, only after phase 4 is rolled back and no released app uses the function |

## Tests

```bash
# Database (a throwaway local Postgres 15+, never the Supabase project)
PGHOST=localhost PGPORT=5432 PGUSER=postgres ./supabase/tests/activity_moderation/run.sh

# Edge Function (needs Deno 2, or: npx deno@2 ...)
cd supabase/functions/save-activity && deno task test

# App
flutter test test/activity_moderation_test.dart
```

## Known limitations

- **The model isn't perfect.** Dialect Arabic, new spellings and text inside photos can get through; borderline photos can be wrongly blocked. Reports remain the safety net.
- **Old activities aren't re-checked** until they're next saved.
- **Location names from Google** are checked too, because the server can't tell them apart from typed ones, so a real venue name could be wrongly flagged.
- **Orphan photo files** can remain if deleting them fails and the user never saves again (there's no cleanup job). They're unused and unlinked.
- **Content-Disposition** can't be set per file in Supabase Storage. Photos are always freshly encoded JPEGs, stored with `image/jpeg`, and the bucket only accepts `image/jpeg`.
- **Re-encoding takes about 0.1 s** of CPU per photo on a laptop. Check `ms` in the logs; Edge Functions allow 2 s of CPU per request.
- **Older app versions** keep writing without moderation until phase 4, and stop being able to create or edit after it.
