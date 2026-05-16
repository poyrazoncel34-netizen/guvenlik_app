plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase plugins removed for offline-first architecture
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

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

if (releaseArtifactRequested) {
    val env = dartDefineValue("ENV")
    val revenueCatKey = dartDefineValue("REVENUECAT_ANDROID_API_KEY")
    val encryptionKey = dartDefineValue("ENCRYPTION_KEY")
    if (env != "production") {
        throw GradleException("Release build requires --dart-define=ENV=production.")
    }
    if (revenueCatKey.isBlank()) {
        throw GradleException("Release build requires --dart-define=REVENUECAT_ANDROID_API_KEY.")
    }
    if (encryptionKey.isBlank()) {
        throw GradleException("Release build requires --dart-define=ENCRYPTION_KEY.")
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
        minSdk = flutter.minSdkVersion // Android 6.0: USE_BIOMETRIC minimum
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Ship only 64-bit native libraries. Almost all Android 7.0+ devices
        // use a 64-bit ARM SoC; dropping 32-bit shrinks the AAB and avoids
        // 16 KB page-size compatibility regressions on the 32-bit ELF path.
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }

        // Ship only Turkish and English resource flavors. The app is
        // bilingual (TR primary, EN secondary) and bundling every Android
        // locale's strings adds size with zero user benefit.
        resourceConfigurations += listOf("en", "tr")
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.12.1")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.2.1")
    testImplementation("androidx.test:core:1.5.0")
}

flutter {
    source = "../.."
}
