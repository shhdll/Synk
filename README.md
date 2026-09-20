![Synk Banner](assets/synk_readme_banner.png)

# Synk

Synk is a Flutter mobile application designed to help Riyadh residents connect through shared interests, discover local activities, and coordinate meetups.

The current repository includes onboarding, authentication, password recovery, profile management, activity creation, and the main application navigation. Additional activity-discovery and coordination features are still under development.

**Team:** Group #10  
**Project version:** `1.0.0+1`  
**Last documentation review:** 20 September 2026

---

## Implementation Status

| Area | Current Status |
| --- | --- |
| Welcome and onboarding | Implemented |
| Account creation | Implemented using Supabase Authentication |
| Login and logout | Implemented |
| Password recovery | Implemented |
| Profile management | Implemented |
| Profile photo management | Implemented |
| Main navigation | Implemented |
| Activity lists | Partially implemented |
| Create Activity | Implemented |
| Activity search | Interface only |
| Map | Placeholder screen; live map integration is not implemented |

### Planned Features

The following features are planned but are not yet available in the current repository:

- Activity discovery and advanced search
- Google Maps integration and nearby venue discovery
- Live weather information
- Activity group chats
- Capacity and waitlist notifications
- Mutual participant ratings
- Profile verification

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
| Environment configuration | `flutter_dotenv` |
| State management | `ChangeNotifier` and Flutter widget state |
| Navigation | Flutter `Navigator` |
| Architecture | Model-View-Controller style organization |
| Version control | Git and GitHub |

---

## Project Structure

The project follows an MVC-style organization. Views display the interface, controllers manage state and user actions, and models handle data and backend operations.

```text
lib/
├── main.dart
├── controllers/
├── models/
├── views/
│   ├── signup/
│   ├── home/
│   └── widgets/
├── core/
│   └── constants/
└── utils/
    └── custom_widgets/

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
- Access to the team's Supabase project

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

Only use a client-safe Supabase publishable or anonymous key. Never include a service-role or secret key in the application.

The `.env` file must not be committed to Git.

### Supabase Configuration

The application requires:

- Email and password authentication
- Email confirmation configuration
- A `users` table for profile information
- Row-Level Security policies that allow users to access their own profiles
- An `avatars` Storage bucket for profile photos
- A password-recovery redirect URL configured in Supabase

The Android password-recovery redirect URL is:

```text
io.supabase.synk://reset-password
```

### Run the Application

List the available devices:

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
3. To create an account, complete the onboarding and personal-information steps.
4. Confirm the registered email address if email confirmation is enabled.
5. Log in to access the main application.
6. Use the Profile screen to view or edit personal information and interests.
7. Use **Forgot Password** to request a password-reset email.
8. Use **Create Activity** to plan and publish a new activity.
9. Use the main navigation to access Home, Activities, Map, and Profile.

---

## Static Code Analysis

The project was analyzed using:

```bash
flutter analyze
```

Result:

```text
No issues found! (ran in 1.4s)
```

This result confirms that the analyzed version complied with the configured Dart and Flutter analysis rules at the time of review.

---

## Known Limitations

- Google Maps integration is not implemented.
- Live weather integration is not implemented.
- Activity group chats and capacity notifications are not implemented.
- Participant ratings and profile-verification workflows are not implemented.
- The existing default widget test must be replaced with tests that reflect the current Synk interface.
- Production Android packaging and release signing are not yet complete.