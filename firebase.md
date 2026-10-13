# Firebase (Analytics + Cloud Messaging)

Firebase project: **`esmfamil-87855`** (project number `866082036026`).
Two Firebase apps registered:

| Platform | App id | Bundle / package |
| --- | --- | --- |
| Android | `1:866082036026:android:9ba38bbcf9045f1643d803` | `com.PardisSaz.game` |
| iOS | `1:866082036026:ios:a2c424a1c4b21cec43d803` | `com.PardisSaz.game` |

What we use it for:

- **Analytics** — usage events + `screen_view` per route. Works on every
  device (own transport, no Google Play Services needed).
- **Cloud Messaging (FCM)** — push notifications. **Delivery requires
  Google Play Services** (Android) / **APNs** (iOS). On the many Cafe
  Bazaar–market phones with no Play Services, push will NOT arrive — the
  in-app `/notifications` REST API ([notifications.md](../notifications.md))
  is the fallback there.

---

## Where things live

| Concern | File |
| --- | --- |
| Per-platform Firebase options | [lib/firebase_options.dart](lib/firebase_options.dart) — hand-written from the two config files below (flutterfire CLI isn't on PATH; regenerate with `flutterfire configure` if you add web/macOS) |
| Init | [lib/main.dart](lib/main.dart) — `Firebase.initializeApp` before `runApp`, wrapped so a failure never blocks startup |
| Analytics wrapper | [lib/services/analytics_service.dart](lib/services/analytics_service.dart) |
| Analytics providers | [lib/providers/analytics_provider.dart](lib/providers/analytics_provider.dart) — `analyticsServiceProvider`, `analyticsUserSyncProvider` (keeps the Analytics user id == logged-in player id) |
| `screen_view` logging | [lib/router.dart](lib/router.dart) — `FirebaseAnalyticsObserver` in `GoRouter(observers: …)` |
| Push service | [lib/services/push_service.dart](lib/services/push_service.dart) — FCM init, permission, token, foreground display via `flutter_local_notifications`, tap stream |
| Push provider | [lib/providers/push_provider.dart](lib/providers/push_provider.dart) — `pushControllerProvider` arms it; subscribes to the `all` topic while logged in; a push tap refreshes the in-app notifications badge/list |
| Android config | `android/app/google-services.json` (gitignored) |
| iOS config | `ios/Runner/GoogleService-Info.plist` (gitignored, registered in the Runner target) |

### Config files are gitignored

`google-services.json` / `GoogleService-Info.plist` aren't hard secrets
(they ship inside every build), but they're kept out of version control so
a clone/fork doesn't inherit our Firebase project. **A fresh checkout must
re-download both from the Firebase Console** (Project settings → the
Android / iOS app → *Download config file*) and drop them at the paths
above before building.

---

## Android — done

Everything below is already wired and verified (`flutter build apk --debug`
succeeds):

- Packages: `firebase_core`, `firebase_analytics`, `firebase_messaging`,
  `flutter_local_notifications` (see [pubspec.yaml](pubspec.yaml)).
- `android/build.gradle.kts` — `com.google.gms:google-services:4.4.2` on the
  buildscript classpath (the `plugins{}` marker didn't resolve reliably
  behind the dev proxy).
- `android/app/build.gradle.kts` — `id("com.google.gms.google-services")`
  applied.
- `AndroidManifest.xml` — `POST_NOTIFICATIONS` permission (Android 13+) and
  the `default_notification_channel_id` = `high_importance_channel`
  meta-data. `PushService` creates that channel at startup.

Nothing else to do for Android. FCM push works on any Android device **with
Google Play Services**.

---

## iOS — code done, needs a Mac to finish

The Flutter iOS project is scaffolded and all the Firebase wiring is in
place, but building iOS and the APNs setup can only be done on macOS.

### Already done (in this repo)

- `flutter create --platforms=ios --org com.PardisSaz` — the `ios/` folder.
- `ios/Runner.xcodeproj/project.pbxproj`
  - `PRODUCT_BUNDLE_IDENTIFIER` = `com.PardisSaz.game` (RunnerTests =
    `com.PardisSaz.game.RunnerTests`).
  - `GoogleService-Info.plist` added to the Runner group and its Resources
    build phase.
- `ios/Runner/GoogleService-Info.plist` — the iOS Firebase config.
- `ios/Runner/AppDelegate.swift` — `import FirebaseCore` +
  `FirebaseApp.configure()` before the plugins register. Firebase's
  AppDelegate method swizzling is left **on**, so `firebase_messaging`
  picks up the APNs token itself (no manual delegate code).
- `ios/Runner/Info.plist`
  - `UIBackgroundModes` = `fetch`, `remote-notification` (FCM).
  - Portrait-only (`UISupportedInterfaceOrientations` = Portrait), matching
    `main.dart` and the Android manifest.
  - `CFBundleDisplayName` = «اسم و فامیل».
- `ios/Podfile` — standard Flutter Podfile, `platform :ios, '13.0'`,
  `use_frameworks!`.
- `lib/firebase_options.dart` — the `ios` branch is filled in.

### To do on a Mac

1. **Pods**
   ```sh
   cd client
   flutter pub get
   cd ios && pod install        # first run installs the Firebase pods
   ```
   From then on open **`ios/Runner.xcworkspace`** (not the `.xcodeproj`) in
   Xcode.

2. **Signing** — Xcode → *Runner* target → *Signing & Capabilities* → pick
   the Apple Developer **Team**. Confirm the bundle id shows
   `com.PardisSaz.game`.

3. **Push Notifications capability** — same tab → **+ Capability** → add
   **Push Notifications**. (Background Modes → *Remote notifications* is
   already set via `Info.plist`, but you can add the capability too for
   clarity.)

4. **APNs key → Firebase** — the one piece without which iOS push does
   nothing:
   - [Apple Developer](https://developer.apple.com) → *Certificates,
     Identifiers & Profiles* → **Keys** → **+** → enable **Apple Push
     Notifications service (APNs)** → download the **`.p8`** file (you only
     get to download it once — store it safely).
   - Note the **Key ID** and your **Team ID**.
   - Firebase Console → *Project settings* → **Cloud Messaging** → *Apple
     app configuration* → **APNs Authentication Key** → upload the `.p8`
     with its Key ID + Team ID.

5. **Build / run**
   ```sh
   flutter run                       # on a real iOS device — the simulator
                                     # cannot receive push
   flutter build ipa                 # release, for App Store / TestFlight
   ```

6. **Verify**
   - On launch, the Xcode console should log `[push] permission: authorized`
     and `[push] token: <fcm token>` (from `PushService`). On iOS the FCM
     token only appears after the APNs token is granted — if it's null,
     re-check steps 3–4.
   - Firebase Console → *Messaging* → *Send test message* → paste that FCM
     token → the notification should arrive (background the app to see the
     system banner; foreground is shown by `flutter_local_notifications`).

---

## Sending push from the backend (not built yet)

The server (`api.woundai.ir`) currently does **in-app** broadcast only
(`POST /notifications`, see [notifications.md](../notifications.md)). To
send real push:

1. Add the **Firebase Admin SDK** server-side with a service-account key.
2. Either:
   - **Topic fan-out (simple)** — the client already calls
     `subscribeToTopic('all')` while logged in; the server just sends to
     `/topics/all`. No token storage. Good enough for "new broadcast"
     pings.
   - **Per-device (targeted)** — add a `POST /devices/token` endpoint,
     store `(player, fcmToken, platform)`, and in `PushService` /
     `pushControllerProvider` POST `push.token` on login and on
     `push.onTokenChanged`. Then the server can target one player.
3. On `POST /notifications`, after writing the row, also send an FCM
   message (to the topic or the stored tokens) with the same `title` /
   `body`. The client treats the push as a "go re-check" signal — it
   refreshes the badge and list over the existing REST API.

---

## Analytics — logging events

```dart
final analytics = ref.read(analyticsServiceProvider);
await analytics.gameStarted(players: 4);
await analytics.coinsPurchased(pack: 'medium', coins: 500);
await analytics.logEvent('custom_event', {'foo': 'bar'});
```

Named helpers live in `AnalyticsService`; add more there rather than
sprinkling raw event-name strings around.

### Debugging Analytics

```sh
# Android — enable DebugView for the app, then watch Firebase Console → DebugView
adb shell setprop debug.firebase.analytics.app com.PardisSaz.game
# turn it off again:
adb shell setprop debug.firebase.analytics.app .none.
```

Normal (non-debug) events can take up to 24h to show in the standard
reports. `screen_view` is logged automatically on every route change.
