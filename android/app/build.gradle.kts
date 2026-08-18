import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "ai.enjoy.player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    flavorDimensions += "distribution"
    productFlavors {
        create("store") {
            dimension = "distribution"
            isDefault = true
        }
        create("direct") {
            dimension = "distribution"
        }
    }

    defaultConfig {
        applicationId = "ai.enjoy.player"
        // media_kit + plugin baseline; Azure Speech SDK 1.49+ pulls com.azure:azure-core,
        // which uses MethodHandle APIs dexable only from API 26+ (D8).
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    // Local/CI builds without key.properties: debug keystore (not for Play upload).
                    signingConfigs.getByName("debug")
                }
        }
    }

    // lintVitalAnalyze* loads plugin bytecode into Metaspace and OOMs at the 512m
    // MaxMetaspaceSize used to keep packageStoreReleaseBundle safe on 16GB hosts.
    // Skip release lint gates; run `./gradlew :app:lint` separately when needed.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    // Vendored eSpeak-NG per-ABI libraries (packages/forced_alignment); the
    // directory layout <abi>/libespeak-ng.so is exactly the jniLibs shape.
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs(
                "src/main/jniLibs",
                "../../packages/forced_alignment/native/android",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by ota_update (direct sideload updates).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Workaround: flutter/flutter#187553 — flavored release APKs can ship stale libapp.so on 3.44.
// merge*JniLibFolders may stay UP-TO-DATE while copyJniLibsflutterBuild* produces fresh libapp.so.
afterEvaluate {
    android.applicationVariants.forEach { variant ->
        val capitalized = variant.name.replaceFirstChar { it.uppercase() }
        val copyTask = tasks.findByName("copyJniLibsflutterBuild$capitalized") ?: return@forEach
        val mergeTask = tasks.findByName("merge${capitalized}JniLibFolders") ?: return@forEach
        mergeTask.dependsOn(copyTask)
        copyTask.doLast {
            layout.buildDirectory
                .dir("intermediates/merged_jni_libs/${variant.name}")
                .get()
                .asFile
                .takeIf { it.exists() }
                ?.deleteRecursively()
        }
    }
}

// Flutter `run` without --flavor looks for app-debug.apk; copy the default store variant.
tasks.configureEach {
    if (name == "assembleStoreDebug" || name == "assembleDebug") {
        doLast {
            val flutterApkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            val source = flutterApkDir.resolve("app-store-debug.apk")
            val target = flutterApkDir.resolve("app-debug.apk")
            if (source.exists()) {
                source.copyTo(target, overwrite = true)
            }
        }
    }
}
