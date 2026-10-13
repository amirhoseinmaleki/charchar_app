# Flutter / plugin ProGuard rules for the release build.
# Flutter's own engine + Dart AOT lib are native and unaffected by R8, but
# the plugins below use reflection / JNI and need their entry points kept.

# --- Flutter embedding ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Google Mobile Ads (AdMob adapter for tapsell_mediation) ---
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.android.gms.**

# --- Tapsell mediation SDK + adapters (reflection-loaded adapter classes) ---
-keep class ir.tapsell.** { *; }
-keep class ir.tapsell.mediation.** { *; }
-keep class ir.tapsell.mediation.adapter.** { *; }
-dontwarn ir.tapsell.**

# --- Cafe Bazaar Poolakey IAP (flutter_poolakey) — PurchaseInfo / signature
#     paths go through reflection / the Bazaar AIDL. ---
-keep class ir.cafebazaar.poolakey.** { *; }
-keep class com.farsitel.bazaar.** { *; }
-dontwarn ir.cafebazaar.poolakey.**
-dontwarn com.farsitel.bazaar.**

# --- Myket IAP (myket_iap & myket-billing-client) ---
#     myket_iap serializes IabResult, Purchase, and Inventory via Gson reflection.
#     Without explicit <fields>; and <methods>;, R8 eliminates the fields (e.g.
#     mResponse, mMessage, mToken, mSku) because they lack @SerializedName,
#     causing Gson to output empty JSON {} in release builds!
-keep class ir.myket.billingclient.** {
    <fields>;
    <methods>;
}
-keepclassmembers class ir.myket.billingclient.** {
    <fields>;
    <methods>;
}
-keep class ir.mservices.myketiap.** {
    <fields>;
    <methods>;
}
-keepclassmembers class ir.mservices.myketiap.** {
    <fields>;
    <methods>;
}
-keep class com.android.vending.billing.** {
    <fields>;
    <methods>;
}
-keepclassmembers class com.android.vending.billing.** {
    <fields>;
    <methods>;
}
-dontwarn ir.myket.billingclient.**
-dontwarn ir.mservices.myketiap.**
-dontwarn com.android.vending.billing.**

# --- flutter_secure_storage (uses the Android Keystore via reflection) ---
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# --- webview_flutter ---
-keep class io.flutter.plugins.webviewflutter.** { *; }

# --- Play Core (referenced by Flutter's deferred-components API but unused
#     here) + core library desugaring: silence unresolved refs so R8's
#     release build doesn't fail on dead code paths.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn java.lang.instrument.**
-dontwarn org.conscrypt.**

# Keep annotations and generic signatures (needed by JSON/reflection paths).
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
