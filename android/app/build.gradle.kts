import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase (Analytics + Cloud Messaging). Must come after the Android
    // plugin. Reads android/app/google-services.json.
    id("com.google.gms.google-services")
}

// Release signing config, loaded from android/key.properties if present
// (that file is gitignored and holds the keystore path + passwords). When
// it's absent the release build falls back to the debug keystore *and
// prints a loud warning* — fine for `flutter run --release` locally, never
// acceptable for a build you actually distribute.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.PardisSaz.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by tapsell_mediation (and its bundled adapters) which use
        // java.time APIs that need desugaring on older Android runtimes.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.PardisSaz.game"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Tapsell mediation app key. The tapsell_mediation plugin's own
        // manifest has `<meta-data android:name="ir.tapsell.mediation.
        // APPLICATION_KEY" android:value="${TapsellMediationAppKey}"/>`, so
        // this placeholder name MUST be exactly `TapsellMediationAppKey`.
        // The SDK reads it at process start (no Dart init call). Not a
        // secret — the SDK sends it to Tapsell from the device anyway — so
        // a compile-time default is fine; override per build with
        // -PtapsellAppKey=xxxx. Keep it equal to the backend's
        // TAPSELL_APP_KEY (served at GET /config/client) for one source of
        // truth even though the client no longer passes the key at runtime.
        manifestPlaceholders["TapsellMediationAppKey"] =
            (project.findProperty("tapsellAppKey") as String?)
                ?: "bjneatlgtesjldnondihbfcnshpprbdtddmrifccklkchiinijoeamhajtbnfmmbalhmgc"

        // The myket_iap native module's manifest is parameterised with
        // these placeholders (Myket market package id + its billing-service
        // bind action) — it declares <queries>/<action>/<meta-data> using
        // ${marketApplicationId} / ${marketBindAddress}. The myket_iap
        // library manifest is merged into EVERY variant (both IAP plugins
        // are always compiled in), so define them unconditionally here
        // rather than per-flavor — they're inert Myket constants in a
        // `bazaar` build.
        manifestPlaceholders["marketApplicationId"] = "ir.mservices.market"
        manifestPlaceholders["marketBindAddress"] = "ir.mservices.market.InAppBillingService.BIND"
        manifestPlaceholders["marketPermission"] = "ir.mservices.market.BILLING"
    }

    // One store per build. Build with `--flavor bazaar` or `--flavor myket`
    // (plus the matching `--dart-define=STORE=...` — see MYKET_IAP.md).
    // Same applicationId on both markets (Firebase / dev-panel registration
    // stay valid); the flavor exists so each market gets its own build
    // artifact and so `flutter run --flavor` works during development.
    flavorDimensions += "store"
    productFlavors {
        create("bazaar") {
            dimension = "store"
        }
        create("myket") {
            dimension = "store"
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n**********************************************************************\n" +
                        "WARNING: no android/key.properties found — the release build is being\n" +
                        "signed with the DEBUG keystore. Do NOT distribute this build.\n" +
                        "Create android/key.properties (see android/key.properties.example)\n" +
                        "with a real upload keystore before publishing.\n" +
                        "**********************************************************************\n",
                )
                signingConfigs.getByName("debug")
            }

            // Shrink + obfuscate the release build. Flutter's Dart code is
            // already AOT-compiled to a native library (not reversible via
            // jadx), but this covers the Kotlin/Java glue and third-party
            // SDK code, and strips unused classes.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Myket's billing client shows its purchase dialog with Material's
    // BottomSheetDialog but doesn't bundle it; without this the shop crashes
    // (NoClassDefFoundError in DialogActivity) on the myket flavor.
    "myketImplementation"("com.google.android.material:material:1.12.0")
}

flutter {
    source = "../.."
}
