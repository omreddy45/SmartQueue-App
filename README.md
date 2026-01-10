# SmartQueue Flutter App

This is the Android mobile application version of SmartQueue, migrated from the React web app.

## Prerequisites

1.  **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install)
2.  **Android Studio**: [Install Android Studio](https://developer.android.com/studio) (required for Android toolchain)
3.  **VS Code** (Optional, recommended for editing)

## Setup Instructions

1.  **Navigate to the project folder**:
    Open a terminal in this directory (`flutter_app`).

2.  **Install Dependencies**:
    Run the following command to download the required packages:
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**:
    - This app uses Firebase. You need to adding your `google-services.json` file.
    - Go to your [Firebase Console](https://console.firebase.google.com/).
    - Open your project settings.
    - Add an Android App (package name: `com.example.smart_queue_app` or similar - check `android/app/build.gradle` after you run the app once or create the android platform).
    - **Note**: Since this project was generated manually, you might need to enable the android platform first.
    
    If `android` folder is missing (it likely is, as I only created `lib`), run:
    ```bash
    flutter create .
    ```
    This will generate the `android`, `ios`, `web` folders around the existing `lib` and `pubspec.yaml`.

    - Download `google-services.json` and place it in `android/app/`.

4.  **Run the App**:
    Connect your Android device or start an emulator.
    ```bash
    flutter run
    ```

## Features

- **Student View**: Order food, scan QR codes (simulated or real), track active orders.
- **Admin View**: Register canteens, view dashboards, generate QR codes.
- **Staff View**: Real-time kitchen display system (KDS) to mark orders ready.

## Troubleshooting

- **'Target not found'**: Make sure an emulator is running or device is connected.
- **Firebase Errors**: Ensure `google-services.json` is in the correct location (`android/app/`).
