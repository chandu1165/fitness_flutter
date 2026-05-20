# Virtual Fitness System

Virtual Fitness System is a Flutter fitness app backed by a Python Flask REST API. It helps users sign up, calculate BMI, understand their body category, choose a fitness goal, receive workout and calorie guidance, and track daily workout progress.

## Highlights

- Flutter mobile app with a polished fitness dashboard
- Python Flask backend with REST API endpoints
- SQLite database for users, profiles, auth sessions, and progress
- Signup, login, logout, forgot-password, and token-based session flow
- BMI calculation with body category feedback
- Body goal planning for leaning, bulking, weight loss, and cutting
- Workout recommendation API based on selected body goal
- Daily workout challenge with progress tracking and streak summary
- Calorie target guidance based on body weight and selected goal
- Multi-language UI labels for English, Hindi, and Telugu
- Android APK-ready Flutter project

## Tech Stack

| Layer | Tools |
| --- | --- |
| Mobile app | Flutter, Dart |
| Backend | Python, Flask, Flask-CORS |
| API | REST, JSON |
| Database | SQLite |
| Auth | Password hashing, bearer tokens, session expiry |
| Local storage | Shared Preferences |

## Project Structure

```text
.
├── app.py                  # Flask backend and REST API
└── fitness_flutter/        # Flutter mobile app
    ├── lib/main.dart       # App UI, state, and API integration
    ├── android/            # Android build project
    └── pubspec.yaml        # Flutter dependencies
```

## Core API Features

- `POST /signup` creates a new user account.
- `POST /login` returns a bearer token for authenticated app flows.
- `GET /profile` fetches the signed-in user's profile.
- `POST /profile/update` stores height, weight, body goal, BMI, and calorie targets.
- `GET /body-types` lists available body goal plans.
- `GET /workout?body_type=...` returns a recommended workout plan.
- `GET /daily-workout` returns the daily challenge board.
- `GET /dashboard` returns profile, daily progress, and streak data.
- `POST /daily-workout/progress` updates daily task completion.

## Run The Backend

```bash
python app.py
```

By default, the backend runs on:

```text
http://127.0.0.1:5000
```

## Run The Flutter App

```bash
cd fitness_flutter
flutter pub get
flutter run
```

When running on a physical Android device, pass the backend URL that your phone can reach:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LOCAL_IP:5000
```

## Build APK

```bash
cd fitness_flutter
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_BACKEND_URL:5000
```

The release APK will be generated under:

```text
fitness_flutter/build/app/outputs/flutter-apk/
```

## What I Learned

This project helped me connect a real Flutter UI with a Flask backend, design authentication flows, store user fitness data, build REST endpoints, and turn app logic such as BMI, body goals, calorie targets, and workout progress into usable product features.

## Future Improvements

- Deploy the Flask API to a cloud host
- Add richer charts for progress history
- Add exercise images or short demo videos
- Improve password reset with email verification
- Add admin controls for editing workout plans
