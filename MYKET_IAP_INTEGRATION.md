# Myket IAP — reusable integration guide (Flutter, Android)

A self-contained, copy-paste guide for adding **Myket in-app purchases** to
any Flutter Android app with `myket_iap`. Everything here is store-specific
to Myket; where a project also ships Cafe Bazaar (Poolakey) the last two
sections cover running them side by side.

- Package: [`myket_iap`](https://pub.dev/packages/myket_iap) — Android only.
- Native SDK: `com.github.myketstore:myket-billing-client` (from
  `https://maven.myket.ir`).
- Myket's mirror docs (pub / maven proxies for filtered networks):
  <https://maven.myket.ir/services/flutter.html>

---

## 1. Prerequisites — Myket developer panel

1. Register the app (same `applicationId` you publish).
2. Create each **in-app product** (SKU). Note the exact product id string.
3. Copy the app's **RSA public key** (پنل مایکت → «کلید RSA»). You'll pass
   the *bare base64 body* to `MyketIAP.init` and to your server for
   signature verification.
4. Publish at least once (even to Myket's internal/beta track) — billing
   won't work for an app Myket has never seen.

---

## 2. pubspec.yaml

```yaml
dependencies:
  myket_iap: ^1.1.10   # 1.1.12 was current at time of writing
```

Then `flutter pub get`.

---

## 3. Android Gradle setup

### 3a. Maven repo — `android/build.gradle.kts` (or `build.gradle`)

The native `myket-billing-client` and its `androidx` transitives come from
Myket's Maven repo. Add `maven("https://maven.myket.ir")` to **every**
repositories block (`settings.gradle(.kts)` `pluginManagement` +
`dependencyResolutionManagement`, or the root `buildscript` + `allprojects`).

If you build on an unfiltered network, position doesn't matter — put it
last:

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.myket.ir")   // just for myket-billing-client
    }
}
```

If you build behind Iran's filtering, put it **first** — it's a full
mirror of the other repos too (see 3d).

### 3b. Manifest placeholders — `android/app/build.gradle.kts`

`myket_iap`'s **native module ships an AndroidManifest** whose `<queries>`,
billing-service `<action>`s, `<meta-data>` and `BILLING` permission are
parameterised by three placeholders. Define them in `defaultConfig` (they
are plain Myket constants, safe to set unconditionally):

```kotlin
android {
    defaultConfig {
        // ...
        manifestPlaceholders["marketApplicationId"] = "ir.mservices.market"
        manifestPlaceholders["marketBindAddress"]   = "ir.mservices.market.InAppBillingService.BIND"
        manifestPlaceholders["marketPermission"]    = "ir.mservices.market.BILLING"
    }
}
```

Groovy:

```groovy
android {
    defaultConfig {
        manifestPlaceholders = [
            marketApplicationId: "ir.mservices.market",
            marketBindAddress  : "ir.mservices.market.InAppBillingService.BIND",
            marketPermission   : "ir.mservices.market.BILLING",
        ]
    }
}
```

> You do **not** add the Myket permission or `<queries>` to your own
> `AndroidManifest.xml` — the plugin's library manifest contributes them
> via the placeholders above. (Older `myket_iap` docs told you to add them
> by hand and then to remove them on upgrade; with a placeholder-driven
> library manifest, hand-declaring them risks a merge conflict.)

### 3c. JDK toolchain

`myket_iap`'s `android/build.gradle` pins `kotlin { jvmToolchain(21) }`.
If your project builds on JDK 21 already, nothing to do. If it's on **JDK
17** (common — Flutter's default), Gradle will fail with:

```
Cannot find a Java installation on your machine ... matching: {languageVersion=21}
```

Two options:

**Option A — let Gradle download JDK 21.** Add the Foojay resolver to
`android/settings.gradle.kts`:

```kotlin
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.8.0"
}
```

**Option B — pin the plugin module back to your JDK** (no second JDK
download). In `android/build.gradle.kts`:

```kotlin
subprojects {
    if (name == "myket_iap") {
        afterEvaluate {
            extensions.findByType<JavaPluginExtension>()?.toolchain {
                languageVersion.set(JavaLanguageVersion.of(17))
            }
            (extensions.findByName("kotlin")
                as? org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension)
                ?.jvmToolchain(17)
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = JavaVersion.VERSION_17.toString()
                targetCompatibility = JavaVersion.VERSION_17.toString()
                javaCompiler.set(
                    project.extensions.getByType<JavaToolchainService>().compilerFor {
                        languageVersion.set(JavaLanguageVersion.of(17))
                    },
                )
            }
        }
    }
}
```

Nothing in the plugin's method-channel bridge needs Java 21, so Option B is
safe.

### 3d. Building behind Iran's filtering

`pub.dev` / `storage.googleapis.com` / `dl.google.com` / JitPack may be
unreachable. Myket runs a **full mirror** of all of them — see
<https://maven.myket.ir/services/flutter.html>. With the mirror configured
everywhere, **no system proxy is needed**.

**Flutter SDK + engine + Dart packages** — set both env vars to
`https://pub.myket.ir` (yes, the same host for both):

```bash
# Linux / macOS
export PUB_HOSTED_URL=https://pub.myket.ir
export FLUTTER_STORAGE_BASE_URL=https://pub.myket.ir
```

```powershell
# Windows PowerShell (this session)
$env:PUB_HOSTED_URL = "https://pub.myket.ir"
$env:FLUTTER_STORAGE_BASE_URL = "https://pub.myket.ir"

# persist for the user
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.myket.ir", "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://pub.myket.ir", "User")
```

To download the SDK zip itself, swap `https://storage.googleapis.com` for
`https://pub.myket.ir`, e.g.
`https://pub.myket.ir/flutter_infra_release/releases/stable/windows/flutter_windows_<ver>-stable.zip`.

**Gradle** — `maven("https://maven.myket.ir")` is a full proxy for
`google()` / `mavenCentral()` / the plugin portal / JitPack, not just
Myket's own artifacts. List it **first** in every repositories block so it
actually acts as the mirror; keep the originals after it as a fallback:

```kotlin
// android/settings.gradle.kts
pluginManagement {
    repositories {
        maven("https://maven.myket.ir")   // first — the mirror
        google(); mavenCentral(); gradlePluginPortal()
    }
}

// android/build.gradle.kts
buildscript {
    repositories { maven("https://maven.myket.ir"); google(); mavenCentral() }
}
allprojects {
    repositories {
        maven("https://maven.myket.ir")
        google(); mavenCentral(); maven("https://jitpack.io")
    }
}
```

With the two env vars **and** the mirror-first Gradle repos, the whole
toolchain — SDK download, `flutter pub get`, and every native dependency —
resolves through Myket with no proxy.

### 3e. ProGuard / R8 rules for release builds (`android/app/proguard-rules.pro`)

In release builds (when R8 minification or shrinking is enabled), R8 strips or
obfuscates fields inside `ir.myket.billingclient` and the plugin. Because
Myket's native billing client serializes its state via reflection/Gson,
stripped fields like `mResponse`, `mMessage`, `mSku`, and `mToken` become null
or default values.

This causes the exact rejection error reported by Myket review teams on release APKs:
> **«با کلیک بر روی بخش قابل خرید در برنامه برای خرید درون برنامه‌ای با استفاده از درون پرداخت مایکت، پیام: «خرید کامل نشد» نمایش داده شده و امکان خرید وجود ندارد»**

Add these rules to `android/app/proguard-rules.pro`:

```proguard
# Myket In-App Billing Client & AIDL
-keep class ir.myket.billingclient.** { *; }
-keepclassmembers class ir.myket.billingclient.** { *; }
-keep class ir.mservices.myketiap.** { *; }
-keepclassmembers class ir.mservices.myketiap.** { *; }
-keep class com.android.vending.billing.** { *; }
-keepclassmembers class com.android.vending.billing.** { *; }
```

Ensure `proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")`
is configured in `buildTypes.release` in `android/app/build.gradle.kts` (or `build.gradle`).

---

## 4. The `myket_iap` API (v1.1.x)

All methods are **static** on `MyketIAP`; there is no instance to hold.

| Call | Returns |
| --- | --- |
| `MyketIAP.init(rsaKey:, enableDebugLogging:)` | `IabResult?` — binds the billing service |
| `MyketIAP.launchPurchaseFlow(sku:, payload:)` | `Map` → `{ MyketIAP.RESULT: IabResult?, MyketIAP.PURCHASE: Purchase? }` |
| `MyketIAP.consume(purchase:)` | `Map` → same shape; **consumables only** |
| `MyketIAP.getPurchase(sku:, querySkuDetails:)` | `Map` → `{ RESULT, PURCHASE }` |
| `MyketIAP.queryInventory(querySkuDetails:, skus:)` | `Map` → `{ RESULT, MyketIAP.INVENTORY: Inventory? }` |
| `MyketIAP.dispose()` | releases the service connection |

### `IabResult` (`package:myket_iap/util/iab_result.dart`)

```dart
int    mResponse;   // 0 = OK
String mMessage;
bool isSuccess();   // mResponse == 0
bool isFailure();
```

Response codes (`util/constants.dart`): `0` OK, `1` USER_CANCELED,
`3` BILLING_UNAVAILABLE, `4` ITEM_UNAVAILABLE, `5` DEVELOPER_ERROR,
`6` ERROR, `7` ITEM_ALREADY_OWNED, `8` ITEM_NOT_OWNED;
IAB-helper: `-1005` USER_CANCELLED, `-1003` VERIFICATION_FAILED, etc.

### `Purchase` (`package:myket_iap/util/purchase.dart`)

```dart
String  mItemType;          // "inapp" | "subs"
String  mOrderId;
String  mPackageName;
String  mSku;
int     mPurchaseTime;
int     mPurchaseState;     // 0 = purchased, 1 = canceled/refunded
String? mDeveloperPayload;
String  mToken;             // idempotency key; what consume() needs
String  mOriginalJson;      // raw JSON — verify the signature over THESE bytes
String  mSignature;         // base64 RSA-SHA1
```

`mOriginalJson` decodes to the Play-Billing shape:

```jsonc
{
  "orderId": "...",
  "packageName": "com.example.app",
  "productId": "coins_1500",
  "purchaseTime": 1788890000000,
  "purchaseState": 0,
  "purchaseToken": "...",
  "developerPayload": ""
}
```

### `Inventory` (`package:myket_iap/util/inventory.dart`)

```dart
Map<String, Purchase>   mPurchaseMap;   // owned/unconsumed, keyed by sku
Map<String, SkuDetails> mSkuMap;        // when querySkuDetails == true
```

---

## 5. Minimal service wrapper

A small wrapper that (a) lazily binds on first use, (b) dedupes the bind,
(c) maps cancel-vs-error, (d) keeps `mOriginalJson` / `mSignature`
untouched for server verification.

```dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:myket_iap/myket_iap.dart';
import 'package:myket_iap/util/iab_result.dart';
import 'package:myket_iap/util/inventory.dart';
import 'package:myket_iap/util/purchase.dart' as myket;

/// The signed payload your server needs, verbatim from Myket.
class MyketPurchase {
  const MyketPurchase({
    required this.purchaseData,   // Purchase.mOriginalJson — do NOT re-serialize
    required this.dataSignature,  // Purchase.mSignature (base64)
    required this.purchaseToken,  // Purchase.mToken
    required this.productId,      // Purchase.mSku
  });
  final String purchaseData, dataSignature, purchaseToken, productId;
}

class MyketPurchaseResult {
  const MyketPurchaseResult._({this.purchase, this.cancelled = false, this.unavailable = false, this.error});
  final MyketPurchase? purchase;
  final bool cancelled;      // user backed out — not an error
  final bool unavailable;    // non-Android / no key / bind failed
  final Object? error;
  bool get success => purchase != null;

  factory MyketPurchaseResult.success(MyketPurchase p) => MyketPurchaseResult._(purchase: p);
  factory MyketPurchaseResult.cancelled()   => const MyketPurchaseResult._(cancelled: true);
  factory MyketPurchaseResult.unavailable() => const MyketPurchaseResult._(unavailable: true);
  factory MyketPurchaseResult.failed(Object e) => MyketPurchaseResult._(error: e);
}

class MyketBillingService {
  String _rsaKey = '';
  bool _initialized = false;
  Future<bool>? _initializing;

  static const _userCancelled = {1, -1005}; // USER_CANCELED, IABHELPER_USER_CANCELLED
  static const _ipcTimeout = Duration(seconds: 8);

  /// Call once at startup with the RSA key (from your backend config, or a
  /// compile-time constant). Safe to call repeatedly — it dedupes and
  /// re-binds only if the key changed.
  void configure({required String rsaKey}) {
    if (rsaKey == _rsaKey) {
      if (isSupported && !_initialized) _ensureInit();
      return;
    }
    if (_initialized) dispose();
    _rsaKey = rsaKey;
    if (isSupported) _ensureInit();
  }

  bool get isSupported => !kIsWeb && Platform.isAndroid && _rsaKey.isNotEmpty;

  Future<bool> _ensureInit() {
    if (_initialized) return Future.value(true);
    return _initializing ??= _init();
  }

  Future<bool> _init() async {
    try {
      final IabResult? r = await MyketIAP
          .init(rsaKey: _rsaKey, enableDebugLogging: kDebugMode)
          .timeout(_ipcTimeout);
      _initialized = r?.isSuccess() ?? false;
    } catch (_) {
      _initialized = false;
    }
    _initializing = null;
    return _initialized;
  }

  bool _isCancel(IabResult? r) => r != null && _userCancelled.contains(r.mResponse);

  MyketPurchase _map(myket.Purchase p) => MyketPurchase(
        purchaseData: p.mOriginalJson,
        dataSignature: p.mSignature,
        purchaseToken: p.mToken,
        productId: p.mSku,
      );

  Future<MyketPurchaseResult> purchase(String sku, {String payload = ''}) async {
    if (!isSupported || !await _ensureInit()) return MyketPurchaseResult.unavailable();
    try {
      final m = await MyketIAP.launchPurchaseFlow(sku: sku, payload: payload);
      final IabResult? res = m[MyketIAP.RESULT] as IabResult?;
      final myket.Purchase? p = m[MyketIAP.PURCHASE] as myket.Purchase?;

      if (res == null || res.isFailure() || p == null) {
        if (_isCancel(res)) return MyketPurchaseResult.cancelled();
        return MyketPurchaseResult.failed(res?.mMessage ?? 'no result');
      }
      if (p.mPurchaseState != 0) return MyketPurchaseResult.cancelled();
      return MyketPurchaseResult.success(_map(p));
    } catch (e) {
      return MyketPurchaseResult.failed(e);
    }
  }

  /// Consume a consumable so it can be bought again. Call ONLY after your
  /// server has credited the purchase.
  Future<bool> consume(String purchaseToken) async {
    if (!isSupported || !await _ensureInit()) return false;
    try {
      final stub = myket.Purchase()
        ..mItemType = 'inapp'
        ..mOrderId = ''
        ..mPackageName = ''
        ..mSku = ''
        ..mPurchaseTime = 0
        ..mPurchaseState = 0
        ..mDeveloperPayload = ''
        ..mToken = purchaseToken
        ..mOriginalJson = ''
        ..mSignature = '';
      final m = await MyketIAP.consume(purchase: stub).timeout(_ipcTimeout);
      return (m[MyketIAP.RESULT] as IabResult?)?.isSuccess() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Owned/unconsumed purchases — replay these through your server on app
  /// start (app killed between a paid purchase and the server credit).
  Future<List<MyketPurchase>> pendingPurchases() async {
    if (!isSupported || !await _ensureInit()) return const [];
    try {
      final m = await MyketIAP.queryInventory(querySkuDetails: false).timeout(_ipcTimeout);
      final IabResult? res = m[MyketIAP.RESULT] as IabResult?;
      final Inventory? inv = m[MyketIAP.INVENTORY] as Inventory?;
      if (res == null || res.isFailure() || inv == null) return const [];
      return [
        for (final p in inv.mPurchaseMap.values)
          if (p.mPurchaseState == 0) _map(p),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    try {
      await MyketIAP.dispose();
    } catch (_) {}
    _initialized = false;
  }
}
```

---

## 6. Purchase → verify → consume flow

**Order matters:** credit server-side *before* you consume, so a crash
after the charge but before the credit leaves an unconsumed purchase that
`pendingPurchases()` can replay.

```dart
Future<void> buyCoinPack(String sku, String playerId) async {
  final r = await billing.purchase(sku, payload: playerId);
  if (r.cancelled)   return;                 // say nothing
  if (r.unavailable) { showSoftMessage();    return; }
  if (!r.success)    { showError(r.error);   return; }

  final p = r.purchase!;
  try {
    // Send p.purchaseData + p.dataSignature VERBATIM to your backend.
    final credit = await api.creditPurchase(
      purchaseData: p.purchaseData,
      dataSignature: p.dataSignature,
      store: 'myket',
    );
    await billing.consume(p.purchaseToken);  // any 2xx => consume
    applyBalance(credit.balance);
  } on ApiRejected {
    // leave it unconsumed; pendingPurchases() retries on next launch
  }
}

Future<void> restorePending() async {
  for (final p in await billing.pendingPurchases()) {
    try {
      await api.creditPurchase(
        purchaseData: p.purchaseData,
        dataSignature: p.dataSignature,
        store: 'myket',
      );
      await billing.consume(p.purchaseToken);
    } catch (_) {/* try again next time */}
  }
}
```

---

## 7. Server-side signature verification

Myket signs `mOriginalJson` with **RSA-SHA1** using the app's private key;
you verify with the **RSA public key** from the Myket panel. This is the
same scheme Google Play Billing / Cafe Bazaar use — only the key differs.

Node sketch:

```js
const crypto = require('crypto');

// key = bare base64 body from the Myket panel
function verifyMyketPurchase(purchaseData, dataSignature, key) {
  const pem =
    '-----BEGIN PUBLIC KEY-----\n' +
    key.replace(/(.{64})/g, '$1\n').trimEnd() + '\n' +
    '-----END PUBLIC KEY-----\n';
  const v = crypto.createVerify('RSA-SHA1');
  v.update(Buffer.from(purchaseData, 'utf8'));   // exact bytes, no re-serialize
  return v.verify(pem, Buffer.from(dataSignature, 'base64'));
}
```

Then: parse `productId` → look up the SKU → credit **idempotently** keyed
on `purchaseToken` (a UNIQUE row) → return the same result on a replay.
A local signature check does **not** catch a later refund/chargeback; add
Myket's server-side validate API if you need that.

---

## 8. Running Myket + Cafe Bazaar in one codebase

If the app also ships `flutter_poolakey`:

### Pick the store at build time

Using Flutter Gradle flavors (`--flavor bazaar|myket`) or `--dart-define=STORE=bazaar|myket`:

```dart
import 'package:flutter/services.dart' show appFlavor;

enum ActiveStore {
  bazaar,
  myket;

  String get id => name;
}

class StoreConfig {
  static ActiveStore get active {
    // 1. Check Flutter Gradle flavor (flutter build apk --flavor myket)
    final flavor = appFlavor?.trim().toLowerCase();
    if (flavor == 'myket') return ActiveStore.myket;
    if (flavor == 'bazaar') return ActiveStore.bazaar;

    // 2. Check --dart-define=STORE=myket|bazaar
    const raw = String.fromEnvironment('STORE', defaultValue: '');
    if (raw.trim().toLowerCase() == 'myket') return ActiveStore.myket;

    return ActiveStore.bazaar;
  }

  static bool get isMyket => active == ActiveStore.myket;
  static bool get isBazaar => active == ActiveStore.bazaar;
}
```

Put both SDKs behind one interface (`IapStore` with `configure` /
`isSupported` / `purchase` / `consume` / `pendingPurchases` / `disconnect`)
and choose the impl from `StoreConfig.active`. Pair it with Gradle product
flavors so each market gets its own artifact:

```kotlin
android {
    flavorDimensions += "store"
    productFlavors {
        create("bazaar") { dimension = "store" }
        create("myket")  { dimension = "store" }
    }
}
```

```bash
flutter build apk --release --flavor bazaar --dart-define=STORE=bazaar
flutter build apk --release --flavor myket  --dart-define=STORE=myket
```

> **Run `flutter clean` right after adding the second flavor.** AGP can cache
> an empty result for the new flavor's `copyFlutterAssets…` task, producing
> an APK with **no `flutter_assets`** that hangs forever on the native splash
> screen. Details and the one-command fix are in §9.

### Fix the duplicate class

Poolakey's AAR and `myket-billing-client` each embed
`com.android.vending.billing.IInAppBillingService{,$Stub,$Stub$Proxy,$Default}`
— the standard Play-Billing AIDL stub. It's the only overlap, but both
`checkDuplicateClasses` and D8's `mergeExtDex` hard-fail on it, and Gradle
artifact transforms don't reach either step.

Repackage Poolakey's AAR once without that package and feed the stripped
file to `:flutter_poolakey` (Myket keeps its copy — the more complete one).
In `android/build.gradle.kts`:

```kotlin
val poolakeyGroup = "com.github.cafebazaar.Poolakey"
val poolakeyName = "poolakey"
val poolakeyVersion = "2.2.0"   // match flutter_poolakey's bundled version

val originalPoolakeyAar: java.io.File by lazy {
    val cfg = configurations.detachedConfiguration(
        dependencies.create("$poolakeyGroup:$poolakeyName:$poolakeyVersion@aar"),
    )
    cfg.isTransitive = false
    cfg.resolve().single()
}

val strippedPoolakeyAar: java.io.File =
    rootProject.layout.buildDirectory
        .file("poolakey-nobilling/poolakey-$poolakeyVersion-nobilling.aar")
        .get().asFile

val stripPoolakeyPlayBilling by tasks.registering {
    outputs.file(strippedPoolakeyAar)
    doLast {
        val src = originalPoolakeyAar
        val dst = strippedPoolakeyAar
        dst.parentFile.mkdirs()
        val tmpJar = java.io.File(dst.parentFile, "classes-stripped.jar")
        java.util.zip.ZipFile(src).use { aar ->
            val classes = aar.getEntry("classes.jar") ?: error("no classes.jar")
            java.util.zip.ZipInputStream(aar.getInputStream(classes).buffered()).use { jin ->
                java.util.zip.ZipOutputStream(tmpJar.outputStream().buffered()).use { jout ->
                    var e = jin.nextEntry
                    while (e != null) {
                        if (!e.name.startsWith("com/android/vending/billing/")) {
                            jout.putNextEntry(java.util.zip.ZipEntry(e.name))
                            jin.copyTo(jout); jout.closeEntry()
                        }
                        e = jin.nextEntry
                    }
                }
            }
            java.util.zip.ZipOutputStream(dst.outputStream().buffered()).use { aout ->
                val entries = aar.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    aout.putNextEntry(java.util.zip.ZipEntry(entry.name))
                    if (entry.name == "classes.jar") {
                        tmpJar.inputStream().buffered().use { it.copyTo(aout) }
                    } else if (!entry.isDirectory) {
                        aar.getInputStream(entry).use { it.copyTo(aout) }
                    }
                    aout.closeEntry()
                }
            }
        }
        tmpJar.delete()
    }
}

subprojects {
    if (name == "flutter_poolakey") {
        configurations.configureEach { exclude(group = poolakeyGroup, module = poolakeyName) }
        afterEvaluate {
            dependencies {
                add("implementation", files(strippedPoolakeyAar).builtBy(stripPoolakeyPlayBilling))
            }
        }
    }
}
```

---

## 9. Troubleshooting

### The new flavor hangs on the native splash screen

**Symptom.** After adding the `myket` flavor, `flutter run --flavor myket`
builds and installs fine, the process starts, but the app never gets past
Android's own launch theme (the `LaunchTheme` window) — no Flutter UI, no
Dart error. The `bazaar` flavor still works.

Logcat shows the engine loading normally and then nothing useful:

```
D/FlutterJNI: flutter (null) was loaded normally!
I/flutter : Using the Impeller rendering backend (OpenGLES).
D/FlutterRenderer: Width is zero. 0,0
I/Choreographer: Skipped 85 frames! The application may be doing too much work…
I/flutter : The Dart VM service is listening on http://127.0.0.1:41039/…
```

**Cause.** AGP wrongly marks the new flavor's `copyFlutterAssets<Flavor><BuildType>`
task **up-to-date**, so it never runs and the APK ships with **no
`flutter_assets` at all** — no fonts, no images, no `.env`. The Dart isolate
starts, but the first frame has nothing to render, so the launch theme stays
on screen forever.

**How to confirm.** Compare `flutter_assets` entries between the two APKs:

```bash
unzip -l build/app/outputs/flutter-apk/app-bazaar-debug.apk | grep -c flutter_assets   # e.g. 43
unzip -l build/app/outputs/flutter-apk/app-myket-debug.apk  | grep -c flutter_assets   # 0  ← the bug
```

A healthy APK contains `assets/flutter_assets/.env`, the fonts, and the
images. A broken one has none of them and is noticeably smaller (in this
project: 55 MB broken vs 89 MB correct).

You can also check the merge output directly:

```bash
find build/app/intermediates/assets/myketDebug -type f | wc -l    # 0-3 when broken, 46 when correct
```

**Fix.**

```bash
flutter clean
flutter run --flavor myket --dart-define=STORE=myket
```

If you'd rather not pay for a full clean, force just the one task:

```bash
cd android
./gradlew :app:copyFlutterAssetsMyketDebug --rerun-tasks
cd ..
flutter build apk --debug --flavor myket --dart-define=STORE=myket
```

Then re-check the `unzip -l` count before blaming anything else.

**Dead ends** — none of these were the cause here, don't lose time on them:

| Suspect | Why it isn't the problem |
| --- | --- |
| `MyketIapStore` / the IAP Dart code | `iapStoreProvider` is only read from the Shop screen; it never loads at startup |
| `myket_iap` native plugin | `onAttachedToEngine` only registers a MethodChannel — it does no blocking work |
| Impeller / GPU driver | `Could not link pipeline program` is a red herring; `EnableImpeller=false` changes nothing here |
| Main thread blocked | Repeated `kill -3` ANR dumps show `main` parked in `Looper.loop`/`MessageQueue.next` — **idle**, not blocked |
| An HTTP proxy in the environment | A local proxy does break the `flutter run` ↔ VM-Service WebSocket (`Invalid WebSocket upgrade request`, HTTP 503), but that's a *tooling* symptom — the app itself still hangs without it |

### `flutter run` can't attach: `Invalid WebSocket upgrade request` / HTTP 503

Separate issue, same session. If `HTTP_PROXY` / `HTTPS_PROXY` point at a
local proxy and `NO_PROXY` doesn't fully exempt loopback, the tool cannot
upgrade its connection to the VM Service on `127.0.0.1`:

```
E/DartVM : vm-service: Error: Unhandled exception:
E/DartVM : WebSocketException: Invalid WebSocket upgrade request
Exception attempting to connect to the VM Service: … HTTP status code: 503
```

The app runs; only the debug attach fails. Clear the proxy for the shell you
launch from:

```bash
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
export NO_PROXY='*'
```

### Only the Myket build is affected, Bazaar is fine

That asymmetry is normal for the asset bug above — the flavors have separate
AGP task instances and separate up-to-date state, so one can be healthy while
the other is broken. It is **not** evidence that the Myket integration code is
at fault. Verify with the `unzip -l` check before investigating further.

### Release build rejection: «خرید کامل نشد» (Missing ProGuard rules)

**Symptom.** Debug builds work, but release APKs submitted to Myket review fail with:
> «با کلیک بر روی بخش قابل خرید در برنامه برای خرید درون برنامه‌ای با استفاده از درون پرداخت مایکت، پیام: «خرید کامل نشد» نمایش داده شده و امکان خرید وجود ندارد»

**Cause.** R8 code shrinking strips fields (`mResponse`, `mMessage`, `mSku`, `mToken`) in `ir.myket.billingclient.**` because they are serialized/deserialized via reflection / Gson. When stripped, `mResponse` defaults to 0 or null, causing `isFailure() == true` on every purchase attempt.

**Fix.** Add the ProGuard rules from §3e to `android/app/proguard-rules.pro`:
```proguard
-keep class ir.myket.billingclient.** { *; }
-keepclassmembers class ir.myket.billingclient.** { *; }
-keep class ir.mservices.myketiap.** { *; }
-keepclassmembers class ir.mservices.myketiap.** { *; }
-keep class com.android.vending.billing.** { *; }
-keepclassmembers class com.android.vending.billing.** { *; }
```

### Response code 6: `BILLING_RESPONSE_RESULT_ERROR` (SKU mismatch)

**Symptom.** Error dialog showing `Problem purchasing item. (response: 6:Error)` or `BILLING_RESPONSE_RESULT_ERROR`.

**Cause.**
1. The requested SKU does not exist or is not activated in the Myket Developer Panel.
2. Typos in backend catalog (e.g. `1000coim` instead of `1000coin`).
3. Re-using Cafe Bazaar SKU names when Myket has different product IDs.

**Fix.** Ensure the exact string sent to `MyketIAP.launchPurchaseFlow(sku: ...)` matches the Product ID configured in the Myket Developer Panel. If sharing the backend with Cafe Bazaar, have the server return separate `bazaarSku` and `myketSku` fields, and let the client select `StoreConfig.isMyket ? item.myketSku : item.bazaarSku`.

### `IabException`: "Can't start async operation because another is in progress"

**Symptom.** Logcat shows:
```
IabException: Can't start async operation (launchPurchaseFlow) because another async operation (launchPurchaseFlow) is in progress.
```

**Cause.** Myket's native `IabHelper` uses a single `mAsyncInProgress` boolean guard (`flagStartAsync` / `flagEndAsync`). Overlapping calls (e.g. rapid user double-taps on buy buttons, or `queryInventory` running concurrently with `launchPurchaseFlow`) throw an exception.

**Fix.** Wrap all calls to `MyketIAP` through a sequential execution queue / mutex in Dart:
```dart
Future<T> _synchronized<T>(Future<T> Function() task) {
  final prev = _lock;
  final completer = Completer<void>();
  _lock = completer.future;
  return prev.then((_) => task()).whenComplete(completer.complete);
}
```

---

## 10. Checklist

- [ ] `myket_iap` in `pubspec.yaml`, `flutter pub get`
- [ ] `maven("https://maven.myket.ir")` in `allprojects.repositories`
- [ ] `marketApplicationId` / `marketBindAddress` / `marketPermission`
      manifest placeholders in `defaultConfig`
- [ ] ProGuard / R8 rules added to `android/app/proguard-rules.pro` (§3e)
- [ ] JDK 21 toolchain available, or `myket_iap` pinned to your JDK
- [ ] Sequential mutex / queue implemented for `MyketIAP` async operations
- [ ] `MyketIAP.init(rsaKey:)` called once, early, before the first buy tap
- [ ] In-app product IDs in Myket Panel match the exact SKUs sent by the app (`myketSku`)
- [ ] Send `mOriginalJson` + `mSignature` **verbatim** to the server
- [ ] Server verifies RSA-SHA1 against the Myket panel's RSA public key
- [ ] Credit is idempotent on `purchaseToken`; `consume()` only after credit
- [ ] `queryInventory()` replayed on app start for interrupted purchases
- [ ] `MyketIAP.dispose()` on teardown
- [ ] (dual-store) build-time `STORE` / `appFlavor` switch + Gradle flavors + the
      Poolakey AAR strip
- [ ] **After adding the flavor:** `flutter clean`, then confirm the new
      flavor's APK actually contains `flutter_assets`
      (`unzip -l … | grep -c flutter_assets`) — see §9
