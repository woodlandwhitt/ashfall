# Ashfall: Meridian 3.0 — Android build

## Build the APK on GitHub (no computer software needed)
1. Upload everything in this folder to your GitHub repository, replacing the old files.
   Keep the hidden `.github` folder: it holds the build recipe.
2. Uploading starts the build automatically. Open the repo's **Actions** tab and wait for the green tick (about 2 minutes).
3. Get the APK either way:
   - **Releases** (easiest on a phone): open the repo's main page, tap **Releases** on the right
     (or go to `/releases`), then tap **AshfallMeridian.apk**. It downloads as a plain APK.
   - **Artifacts**: open the finished run, scroll to **Artifacts**, tap **AshfallMeridian-apk**.
     This downloads as a zip; extract it to get `AshfallMeridian.apk`.
4. Tap the APK to install. Allow "install unknown apps" for your browser or Files app if asked.

Every build is signed with the same key (`app/debug.keystore`), so new versions install over old ones and keep your save.
If you installed version 2.0 earlier, uninstall it once first: it was signed with a different key.

## Build locally
Open this folder in Android Studio and press Run, or run `gradle assembleDebug` (JDK 17, Gradle 8.9, Android SDK 34).
