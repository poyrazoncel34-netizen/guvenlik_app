allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Release resolution must be reproducible. Lockfiles are generated with
    // `./gradlew app:dependencies --write-locks` and reviewed like source.
    dependencyLocking {
        lockAllConfigurations()
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

// Fix JVM target compatibility for all subprojects
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

// Fix for plugins that don't declare a namespace (e.g. optimize_battery)
// Must be applied via gradle.projectsLoaded to run before evaluation
subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
        if (android.namespace.isNullOrEmpty()) {
            val manifest = file("${projectDir}/src/main/AndroidManifest.xml")
            if (manifest.exists()) {
                val packageName = Regex("package=\"([^\"]+)\"")
                    .find(manifest.readText())?.groupValues?.get(1)
                if (!packageName.isNullOrEmpty()) {
                    android.namespace = packageName
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
