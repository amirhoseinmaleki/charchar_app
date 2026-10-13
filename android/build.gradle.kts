// The Google Services (Firebase) Gradle plugin isn't reliably resolvable
// via the plugins{} marker on the Gradle Plugin Portal here, so pull it in
// the classic way — a buildscript classpath dependency from google() — and
// apply it by id (no version) in android/app/build.gradle.kts.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // flutter_poolakey pulls the native Poolakey (Cafe Bazaar IAP) SDK
        // from JitPack.
        maven("https://jitpack.io")
        // myket_iap pulls the native Myket billing client from Myket's own
        // Maven repo. (It also mirrors google()/mavenCentral(); if you ever
        // build on a network where those are blocked, move this line to the
        // top of each repositories block — see MIRROR_MYKET.md.)
        maven("https://maven.myket.ir")
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// The myket_iap plugin's android/build.gradle pins `kotlin { jvmToolchain(21) }`,
// which makes Gradle demand a JDK 21 toolchain that isn't installed here
// (the rest of the project builds on JDK 17). Nothing in the plugin's tiny
// method-channel bridge needs Java 21 — pin every toolchain/target it sets
// back down to 17 (after the plugin has evaluated its own build script) so
// it compiles with the same JDK as everything else.
subprojects {
    if (name == "myket_iap") {
        afterEvaluate {
            extensions.findByType<JavaPluginExtension>()?.toolchain {
                languageVersion.set(JavaLanguageVersion.of(17))
            }
            extensions.findByName("kotlin")?.let { kotlinExt ->
                (kotlinExt as? org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension)
                    ?.jvmToolchain(17)
            }
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

// ---------------------------------------------------------------------------
// Duplicate-class fix for the two IAP SDKs.
//
// Both `flutter_poolakey` (Cafe Bazaar) and `myket_iap` (Myket) are compiled
// into every build — only one is used at runtime (see lib/services/iap/).
// Poolakey's native AAR (`com.github.cafebazaar.Poolakey:poolakey`) and
// Myket's (`com.github.myketstore:myket-billing-client`) each embed their own
// copy of the standard AIDL-generated Play-Billing interface
// `com.android.vending.billing.IInAppBillingService{,$Stub,$Stub$Proxy,
// $Default}`. Everything else in the two AARs is namespaced
// (`ir.cafebazaar.poolakey.*` vs `ir.myket.billingclient.*`); the shared
// Play-Billing stub is the *only* overlap — but AGP's `checkDuplicateClasses`
// and the D8 `mergeExtDex` step both hard-fail on it, and Gradle artifact
// transforms don't reach either.
//
// So: repackage Myket's AAR once, dropping `com/android/vending/billing/`
// from its `classes.jar`, and point `:myket_iap`'s `implementation` at that
// file instead of the Maven coordinate. Poolakey keeps its copy of the stub —
// it must: Myket's `myket-billing-client:1.19` interface only goes up to
// `getBuyIntentV2`/`getPurchaseConfig`, while Poolakey's `PurchaseFunction`
// calls `getBuyIntentV3`. An earlier version of this workaround stripped
// Poolakey's copy and kept Myket's instead, which compiled fine but crashed
// every real Cafe Bazaar purchase at runtime with
// `NoSuchMethodError: getBuyIntentV3` — Bazaar's installed billing service
// implements the newer interface Poolakey expects, but the app only carried
// Myket's older one. Myket_iap binds Myket's own billing service instead
// (a different app/interface implementation entirely), so sharing Poolakey's
// more complete stub is safe for it.
// ---------------------------------------------------------------------------
val myketGroup = "com.github.myketstore"
val myketName = "myket-billing-client"
val myketVersion = "1.19"

// Resolve the original Myket AAR through a throwaway detached configuration.
val originalMyketAar: java.io.File by lazy {
    val cfg = configurations.detachedConfiguration(
        dependencies.create("$myketGroup:$myketName:$myketVersion@aar"),
    )
    cfg.isTransitive = false
    cfg.resolve().single()
}

val strippedMyketAar: java.io.File =
    rootProject.layout.buildDirectory.file("myket-nobilling/myket-billing-client-$myketVersion-nobilling.aar")
        .get().asFile

val stripMyketPlayBilling by tasks.registering {
    description = "Repackages the Myket billing-client AAR without the shared Play-Billing AIDL package."
    outputs.file(strippedMyketAar)
    doLast {
        val src = originalMyketAar
        val dst = strippedMyketAar
        dst.parentFile.mkdirs()

        // Pass 1: rewrite the inner classes.jar without com/android/vending/billing/**
        val tmpJar = java.io.File(dst.parentFile, "classes-stripped.jar")
        java.util.zip.ZipFile(src).use { aar ->
            val classesEntry = aar.getEntry("classes.jar") ?: error("myket-billing-client AAR has no classes.jar")
            java.util.zip.ZipInputStream(aar.getInputStream(classesEntry).buffered()).use { jin ->
                java.util.zip.ZipOutputStream(tmpJar.outputStream().buffered()).use { jout ->
                    var e = jin.nextEntry
                    while (e != null) {
                        if (!e.name.startsWith("com/android/vending/billing/")) {
                            jout.putNextEntry(java.util.zip.ZipEntry(e.name))
                            jin.copyTo(jout)
                            jout.closeEntry()
                        }
                        e = jin.nextEntry
                    }
                }
            }

            // Pass 2: rebuild the AAR, swapping in the stripped classes.jar.
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
        logger.lifecycle("[iap] wrote stripped Myket billing-client AAR: $dst")
    }
}

subprojects {
    if (name == "myket_iap") {
        // Drop the Maven Myket billing-client AAR; use the stripped local copy instead.
        configurations.configureEach {
            exclude(group = myketGroup, module = myketName)
        }
        afterEvaluate {
            dependencies {
                add("implementation", files(strippedMyketAar).builtBy(stripMyketPlayBilling))
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
