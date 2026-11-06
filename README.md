![Synk Banner](assets/synk_readme_banner.png)

# Synk

Synk is a Flutter application for Android and iOS that helps Riyadh residents connect through shared interests, discover local activities, and organize meetups.

The current implementation includes accounts and profiles, creating and joining activities, search and filters, a live map, waitlists, friends, activity and friend chats, ratings, weather, a weekly streak, notifications, an admin dashboard, and Arabic/English support.

**Team:** Group #10  
**Project version:** set automatically at build time  
**Last documentation review:** 6 November 2026

---

## Implementation Status

| Area | Current Status |
| --- | --- |
| Welcome and onboarding | Implemented |
| Personal details and account setup | Implemented with validation |
| Account creation | Implemented using Supabase Authentication |
| Username availability checking | Implemented |
| Email verification | Implemented |
| Resend verification email | Implemented with a cooldown |
| Login | Implemented using email or username |
| Logout | Implemented |
| Password recovery | Implemented using an Android deep link |
| Change password | Implemented with current-password verification |
| Profile viewing and editing | Implemented |
| Username and email updates | Implemented |
| Profile photo management | Implemented with local fallback and Supabase Storage |
| Main navigation | Implemented |
| Public activity feed | Implemented using Supabase |
| Upcoming and past user activities | Implemented |
| Create Activity | Implemented |
| Activity location search | Implemented using Google Places through a Supabase Edge Function |
| Activity photo upload | Implemented using Supabase Storage |
| Activity search | Implemented (typo-tolerant, matches the start of words, Arabic and English) |
| Activity filtering | Implemented (time, location, category) |
| Map | Implemented with activity markers, filters, and marker preview |
| Activity details | Implemented with status tags: Available, One More Needed, Full |
| Joining and leaving activities | Implemented |
| Public/private activities | Implemented |
| Join with activity code | Implemented (six-digit code; private activities send a join request) |
| Join requests | Implemented (hosts accept or reject; requesters can cancel) |
| Waitlist | Implemented with automatic promotion in waiting order |
| Scheduling conflicts | Prevented server-side |
| Edit and delete activity | Implemented for hosts only |
| Share activity code | Implemented with a ready-made message |
| View another user's profile | Implemented |
| Past activities and completed count | Implemented |
| Push notifications | Implemented on Android; on iPhone through the ntfy app |
| Notification center | Implemented (read and delete notifications) |
| Notification settings | Implemented (each notification type can be turned on or off) |
| Arabic/English | Implemented with RTL/LTR layout |
| iOS support | Implemented |
| Same-gender visibility | Activities, activity codes, and friends are limited to users of the same gender |
| Friends | Implemented (send, accept, reject, cancel, and remove friend requests) |
| Friends going | Shows which friends joined an activity |
| Blocking | Implemented (block and unblock users from Settings) |
| Reporting users | Implemented with a reason and optional details |
| Activity chats | Implemented (created automatically, closed after the activity ends) |
| Friend chats | Implemented (one-to-one) |
| Chat features | Share activities, photos, and locations; mute and delete chats; delete messages for everyone or just me |
| Ratings | Implemented (rate participants after an activity; view ratings and reviews on profiles) |
| Recent activities | Shown on a user's profile |
| Waitlist position | Shows your place in the waitlist and how many are waiting |
| Activity suggestions | Implemented (Top Picks based on interests and location) |
| Weather | Implemented for an activity's location and date using Open-Meteo |
| Weekly streak | Implemented (weeks in a row with an attended activity; shown on Home) |
| Settings | Implemented (language, notifications, blocked users, support, About page, delete account) |
| Contact support | Implemented (form in Settings; replies by email) |
| Delete account | Implemented (permanently deletes the account and its data) |
| Admin dashboard | Implemented as a web page (statistics, support requests, and reports review) |

### Implemented Highlights

- Secure signup with personal details, a unique username, email, and password validation
- Email confirmation screen with resend support
- Sign-in using either a username or an email address
- Password reset through a recovery email and Android deep link
- Profile editing for name, username, bio, age, gender, email, interests, and profile photo
- Activity creation with:
  - Title and description
  - Date and start time
  - Participant limit
  - Public or private visibility
  - Optional activity photo
  - Google Places location search and address resolution
- Supabase-backed public activity feed
- Separate upcoming and past activity lists for the signed-in user
- Push notifications for join requests, accepted and rejected requests, waitlist promotion, and activity updates or cancellations
- Joining, leaving, waitlist promotion, and host transfer run in database functions with row-level locking, so simultaneous actions stay consistent
- Friends, friend requests, blocking, and reporting, with notifications for new and accepted requests
- Group chats for every activity and one-to-one chats with friends, with shared activities, photos, and locations
- Ratings and reviews after an activity, shown on user profiles
- Weather forecast on activity details
- A weekly streak that greets the user once a day and turns grey near the end of the week when nothing is booked
- A web admin dashboard for statistics, support requests, and reported content

---

## Planned Features

The following features are not yet fully available:

- Profile verification
- Activity check-in

---

## Technology Stack

| Component | Technology |
| --- | --- |
| Frontend | Flutter and Dart |
| Platform | Android and iOS |
| Backend | Supabase |
| Authentication | Supabase Authentication |
| Database | Supabase PostgreSQL |
| Storage | Supabase Storage |
| Server-side integration | Supabase Edge Functions |
| Location search | Google Places API |
| Map dependency | `google_maps_flutter` |
| Push notifications | Firebase Cloud Messaging (`firebase_messaging`); ntfy on iPhone |
| Weather | Open-Meteo API (`http`) |
| Swipe actions | `flutter_slidable` |
| App version info | `package_info_plus` |
| Admin dashboard and landing pages | HTML, CSS, and JavaScript in `landing/`, deployed on Vercel |
| Localization | `flutter_localizations` with ARB files in `lib/l10n/` |
| Environment configuration | `flutter_dotenv` |
| Image selection | `image_picker` |
| Local file storage | `path_provider` |
| State management | `ChangeNotifier` and Flutter widget state |
| Navigation | Flutter `Navigator` |
| Architecture | Model-View-Controller style organization |
| Version control | Git and GitHub |

---

## Project Structure

The project follows an MVC-style organization. Views display the interface, controllers manage state and user actions, and models handle application data and Supabase operations.

```text
lib/
├── main.dart
├── controllers/
├── models/
├── core/
│   └── constants/
├── l10n/
├── screens/
│   └── auth/
├── views/
│   ├── create_activity/
│   ├── home/
│   ├── signup/
│   └── widgets/
├── services/
└── utils/
    └── custom_widgets/

supabase/
├── functions/
│   ├── delete-account/
│   ├── notify-waitlist-promotion/
│   ├── places-proxy/
│   ├── reply-support/
│   ├── request-admin/
│   └── submit-support/
├── migrations/
└── templates/

landing/
└── admin/

assets/
android/
ios/
docs/
test/
.env.example
pubspec.yaml
```

---

## Local Setup

### Prerequisites

Before running the project, install:

- Flutter SDK
- Dart SDK
- Android Studio
- Android SDK
- An Android emulator or physical Android device
- Git
- Access to the team’s Supabase project

For iOS, you also need macOS, Xcode, CocoaPods, and an iOS simulator or iPhone. Switch Flutter to CocoaPods once:

```bash
flutter config --no-enable-swift-package-manager
```

Flutter installs the pods on the first iOS run. Without a Mac, see [docs/IOS_SETUP.md](docs/IOS_SETUP.md).

Check the Flutter installation:

```bash
flutter --version
flutter doctor
```

### Clone the Repository

```bash
git clone https://github.com/shhdll/Synk.git
cd Synk
```

### Install Dependencies

```bash
flutter pub get
```

### Configure Environment Variables

Create a `.env` file in the project root. You can copy the provided template:

```bash
cp .env.example .env
```

Add the Supabase project values:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_publishable_key
```

Only use a client-safe Supabase publishable or anonymous key. Never include a service-role key or another server secret in the application.

The `.env` file must not be committed to Git.

### Maps and Firebase Keys

Ask a teammate for these files. They are git-ignored and must not be committed:

- `android/local.properties`: `MAPS_API_KEY=...` (Android Maps key)
- `ios/Flutter/Secrets.xcconfig`: `MAPS_API_KEY=...` (iOS Maps key)
- `android/app/google-services.json`: Firebase config for push notifications

### Supabase Configuration

The application requires:

- Email and password authentication
- Email confirmation configuration
- A `users` table for profile information
- An `activities` table for activity data
- Row-Level Security policies for profiles, activities, and storage
- An `avatars` Storage bucket for profile photos
- An `activity-photos` Storage bucket for activity photos
- A `chat-photos` Storage bucket for photos sent in chats
- A `support-screenshots` Storage bucket for screenshots attached to support requests
- The `places-proxy` Edge Function for Google Places requests
- A server-side `GOOGLE_PLACES_API_KEY` secret for the Edge Function
- The `notify-waitlist-promotion` Edge Function for push notifications, with the `FCM_SERVICE_ACCOUNT_JSON` and `PROMOTION_WEBHOOK_SECRET` secrets
- The `submit-support`, `reply-support`, `request-admin`, and `delete-account` Edge Functions
- The migrations in `supabase/migrations/`
- Password-recovery and email-confirmation redirect URLs

Android and iOS redirect URLs:

```text
io.supabase.synk://reset-password
io.supabase.synk://login-callback
```

The Google Places key must remain in Supabase’s secret store. It must not be placed in the Flutter application or committed to the repository.

### Run the Application

List available devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

To select a specific device:

```bash
flutter run -d <device-id>
```

Replace `<device-id>` with an ID displayed by `flutter devices`.

---

## Usage

1. Open the application.
2. Select **Sign Up** or **Log In** from the welcome screen.
3. To create an account, complete onboarding, personal details, and account setup.
4. Open the verification email or request another verification message.
5. Log in using either the registered email or username.
6. Use the Home screen to browse, search, and filter upcoming public activities.
7. Use the Map screen to find activities near you.
8. Open an activity to join, leave, or join its waitlist, or enter an activity code to join.
9. Use **Create Activity** to enter activity details, select a location, configure the schedule and capacity, and publish the activity.
10. Use the Activities screen to view the signed-in user’s upcoming and past activities.
11. Use the Chats screen to talk in activity group chats or with friends.
12. Use the friends button on Home to find people, manage friend requests, and view friends.
13. Tap the 🔥 streak next to your name on Home to see your weekly streak.
14. Use the Profile screen to view or edit account information, interests, email, password, and profile photo.
15. Use **Settings** to change the language and notifications, manage blocked users, contact support, or delete the account.
16. Use **Forgot Password** to request a password-recovery email.
17. Log out from the profile area when finished.

---

## Static Code Analysis

The project was analyzed using:

```bash
flutter analyze
```

Result on 6 November 2026:

```text
10 issues found.
```

There are no errors: 2 warnings and 8 style suggestions, mostly missing braces and unneeded string interpolation.

---

## Testing

Run the automated tests using:

```bash
flutter test
```

The repository currently includes tests for:

- Username validation
- Password security rules
- Email verification screen content
- Email-change interface states
- Activity status tags and completed activity count
- Home and map filters
- Localization
- Typo-tolerant search
- Weekly streak
- Activity suggestions (Top Picks)
- Participant ratings
- Recent activities on profiles

On 6 November 2026, all 170 tests passed.

---

