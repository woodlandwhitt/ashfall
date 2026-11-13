# Ashfall Meridian — Android project

The whole game is one file: `app/src/main/assets/index.html`. This project wraps it in a full-screen Android app.

## Get the APK without installing anything (GitHub builds it)
1. Create a free GitHub account and a new empty repository.
2. Upload the contents of this folder to it (on the repo page: Add file > Upload files; drag everything in, including the `.github` folder).
3. Open the repo's **Actions** tab. A run called "Build APK" starts on its own and takes about 3 minutes.
4. Open the finished run and download **AshfallMeridian-apk** at the bottom. Unzip it to get `app-debug.apk`.
5. Send that file to your phone, tap it, and allow "install unknown apps" when Android asks.

## Or build on your own computer
Open this folder in Android Studio and press Run with your phone plugged in, or run `gradle assembleDebug` (JDK 17, Gradle 8.9, Android SDK 34).
