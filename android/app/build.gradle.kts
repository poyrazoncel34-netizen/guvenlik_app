plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase plugins removed for offline-first architecture
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

// KoruBeni is distributed only through Google Play. RevenueCat's Flutter
// hybrid dependency also exposes its optional Amazon store adapter; exclude
// that adapter and Amazon Appstore SDK from every app variant. Google Play
// Billing and RevenueCat core remain present.
configurations.configureEach {
    exclude(group = "com.revenuecat.purchases", module = "purchases-store-amazon")
    exclude(group = "com.amazon.device", module = "amazon-appstore-sdk")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val releaseArtifactRequested = gradle.startParameter.taskNames.any {
    val taskName = it.lowercase()
    taskName.contains("release") &&
        (taskName.contains("assemble") ||
            taskName.contains("bundle") ||
            taskName.contains("package") ||
            taskName.contains("install"))
}
val playReleaseArtifactRequested = gradle.startParameter.taskNames.any {
    val taskName = it.lowercase()
    taskName.contains("playrelease") &&
        (taskName.contains("assemble") ||
            taskName.contains("bundle") ||
            taskName.contains("package") ||
            taskName.contains("install"))
}
val smokeReleaseArtifactRequested = gradle.startParameter.taskNames.any {
    val taskName = it.lowercase()
    taskName.contains("smokerelease") &&
        (taskName.contains("assemble") ||
            taskName.contains("bundle") ||
            taskName.contains("package") ||
            taskName.contains("install"))
}
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
if (releaseArtifactRequested && !keystorePropertiesFile.exists()) {
    throw GradleException("Release signing requires android/key.properties; refusing to fall back to debug signing.")
}

fun releaseSigningValue(name: String): String {
    val value = keystoreProperties.getProperty(name)
    if (releaseArtifactRequested && value.isNullOrBlank()) {
        throw GradleException("Release signing property '$name' is missing in android/key.properties.")
    }
    return value.orEmpty()
}

fun dartDefineValue(name: String): String {
    val encodedDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    if (encodedDefines.isBlank()) return ""
    return encodedDefines.split(",")
        .mapNotNull {
            try {
                String(Base64.getDecoder().decode(it), Charsets.UTF_8)
            } catch (_: IllegalArgumentException) {
                null
            }
        }
        .firstOrNull { it.startsWith("$name=") }
        ?.substringAfter("=")
        .orEmpty()
}

fun isProductionRevenueCatAndroidSdkKey(value: String): Boolean {
    val normalized = value.trim()
    val lower = normalized.lowercase()
    return normalized.isNotEmpty() &&
        !normalized.any { it.isWhitespace() } &&
        lower.startsWith("goog_") &&
        !lower.startsWith("sk_") &&
        !lower.contains("placeholder") &&
        !lower.contains("dummy") &&
        !lower.contains("non_release_smoke")
}

if (playReleaseArtifactRequested) {
    val env = dartDefineValue("ENV")
    val revenueCatKey = dartDefineValue("REVENUECAT_ANDROID_API_KEY")
    if (env != "production") {
        throw GradleException("Play release requires --dart-define=ENV=production.")
    }
    if (!isProductionRevenueCatAndroidSdkKey(revenueCatKey)) {
        throw GradleException(
            "Play release requires a goog_ RevenueCat Android public SDK key; " +
                "test_, sk_, and placeholder values are forbidden.",
        )
    }
} else if (smokeReleaseArtifactRequested) {
    val env = dartDefineValue("ENV")
    val revenueCatKey = dartDefineValue("REVENUECAT_ANDROID_API_KEY")
    if (env != "ci_smoke" || revenueCatKey != "NON_RELEASE_SMOKE_REVENUECAT_KEY") {
        throw GradleException(
            "Smoke release requires ENV=ci_smoke and the fixed non-release SDK-key sentinel.",
        )
    }
} else if (releaseArtifactRequested) {
    throw GradleException("Unknown release distribution; use --flavor play or --flavor smoke.")
}

if (releaseArtifactRequested && !playReleaseArtifactRequested && !smokeReleaseArtifactRequested) {
    throw GradleException("Release artifact flavor could not be proven safe.")
}

if (playReleaseArtifactRequested && smokeReleaseArtifactRequested) {
    throw GradleException("Play and smoke release artifacts cannot be requested together.")
}

if (!releaseArtifactRequested && (playReleaseArtifactRequested || smokeReleaseArtifactRequested)) {
    throw GradleException("Inconsistent release artifact task detection.")
}

if (releaseArtifactRequested && keystorePropertiesFile.exists()) {
    val storeFile = releaseSigningValue("storeFile")
    if (!rootProject.file(storeFile).isFile) {
        throw GradleException("Release keystore file does not exist at the configured storeFile path.")
    }
}

android {
    namespace = "com.poyrazoncel.korubeni"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.poyrazoncel.korubeni"
        // Published support envelope: telephony-capable phones on API 29-36.
        // Keep this explicit; inheriting Flutter's lower default silently
        // expands Play eligibility beyond the qualified device matrix.
        minSdk = 29
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

    }

    // First production runtime/listing is Turkish-only. English source copy is
    // retained as an internal parity reference but is not shipped as a locale.
    androidResources {
        localeFilters += listOf("tr")
    }

    buildFeatures {
        buildConfig = true
    }

    flavorDimensions += "distribution"

    productFlavors {
        create("play") {
            dimension = "distribution"
            manifestPlaceholders["appLabelSuffix"] = ""
        }
        create("smoke") {
            dimension = "distribution"
            applicationIdSuffix = ".smoke"
            versionNameSuffix = "-smoke"
            manifestPlaceholders["appLabelSuffix"] = " Smoke"
            // Emulator/CI-only distribution. The Play flavor never receives
            // x86_64 through this flavor-specific filter.
            ndk {
                abiFilters.clear()
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = releaseSigningValue("keyAlias")
                keyPassword = releaseSigningValue("keyPassword")
                storeFile = rootProject.file(releaseSigningValue("storeFile"))
                storePassword = releaseSigningValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfigs.findByName("release")?.let { signingConfig = it }
            // The production Play artifact is arm64-only. The smoke flavor
            // explicitly adds x86_64 for emulator validation.
            ndk {
                abiFilters.clear()
                abiFilters += listOf("arm64-v8a")
                // Preserve full native symbols as a separate release artifact.
                // This does not put debug symbols in the shipped libraries.
                debugSymbolLevel = "FULL"
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Keep host/instrumentation builds on the same supported ABI set
            // as release. Mixing Flutter's 64-bit release native-assets
            // snapshot with a later implicit armv7 debug build is
            // nondeterministic and KoruBeni does not ship a 32-bit artifact.
            ndk {
                abiFilters.clear()
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // AAB: Single universal bundle for Play Store

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.jvmArgs("-noverify", "-Xmx2g")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.12.1")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.2.1")
    testImplementation("androidx.test:core:1.5.0")
    androidTestImplementation("androidx.test:core:1.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}

flutter {
    source = "../.."
}
