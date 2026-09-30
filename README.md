![Synk Banner](assets/synk_readme_banner.png)

# Synk

Synk is an Android-focused Flutter application that helps Riyadh residents connect through shared interests, discover local activities, and organize meetups.

The current implementation includes onboarding, account creation and verification, authentication, profile management, activity creation, a public activity feed, and location search for activities.

**Team:** Group #10  
**Project version:** `1.0.0+1`  
**Last documentation review:** 30 September 2026

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
| Activity search | Interface only |
| Map | Placeholder screen; live nearby-activity map is not implemented |

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

---

## Planned Features

The following features are not yet fully available:

- Functional activity search and advanced filtering
- Live Google Maps view for nearby activities
- Live weather information and weather-based suggestions
- Joining and leaving activities
- Participant lists and capacity tracking beyond the host
- Waitlist and capacity notifications
- Activity group chats
- Friend management
- Participant ratings
- Profile verification
- Activity check-in and link sharing

---

## Technology Stack

| Component | Technology |
| --- | --- |
| Frontend | Flutter and Dart |
| Platform | Android |
| Backend | Supabase |
| Authentication | Supabase Authentication |
| Database | Supabase PostgreSQL |
| Storage | Supabase Storage |
| Server-side integration | Supabase Edge Functions |
| Location search | Google Places API |
| Map dependency | `google_maps_flutter` |
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
├── screens/
│   └── auth/
├── views/
│   ├── create_activity/
│   ├── home/
│   ├── signup/
│   └── widgets/
├── service/
└── utils/
    └── custom_widgets/

supabase/
├── functions/
│   └── places-proxy/
└── migrations/

assets/
android/
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

### Supabase Configuration

The application requires:

- Email and password authentication
- Email confirmation configuration
- A `users` table for profile information
- An `activities` table for activity data
- Row-Level Security policies for profiles, activities, and storage
- An `avatars` Storage bucket for profile photos
- An `activity-photos` Storage bucket for activity photos
- The `places-proxy` Edge Function for Google Places requests
- A server-side `GOOGLE_PLACES_API_KEY` secret for the Edge Function
- Password-recovery and email-confirmation redirect URLs

Android redirect URLs:

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
flutter run -d <android-device-id>
```

Replace `<android-device-id>` with an ID displayed by `flutter devices`.

---

## Usage

1. Open the application.
2. Select **Sign Up** or **Log In** from the welcome screen.
3. To create an account, complete onboarding, personal details, and account setup.
4. Open the verification email or request another verification message.
5. Log in using either the registered email or username.
6. Use the Home screen to view upcoming public activities.
7. Use **Create Activity** to enter activity details, select a location, configure the schedule and capacity, and publish the activity.
8. Use the Activities screen to view the signed-in user’s upcoming and past activities.
9. Use the Profile screen to view or edit account information, interests, email, password, and profile photo.
10. Use **Forgot Password** to request a password-recovery email.
11. Log out from the profile area when finished.

---

## Static Code Analysis

The project was analyzed using:

```bash
flutter analyze
```

Result:

```text
No issues found!
```

This result confirms that the current project complies with the configured Dart and Flutter analysis rules.

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

The default counter test in `test/widget_test.dart` still needs to be replaced with a test that reflects the current Synk interface.

---

