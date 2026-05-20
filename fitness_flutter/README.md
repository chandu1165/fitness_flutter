# Fitness Flutter App

This folder contains the Flutter mobile app for the Virtual Fitness System.

The app connects to the Flask backend in the repo root and supports authentication, BMI calculation, body goal planning, workout recommendations, calorie targets, daily workout tracking, and progress history.

## Run

```bash
flutter pub get
flutter run
```

For a physical Android device, pass a backend URL that the phone can access:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LOCAL_IP:5000
```

## Build APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_BACKEND_URL:5000
```
