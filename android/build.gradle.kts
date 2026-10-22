allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // The Flutter OCR plugin defaults to the bundled model. Substitute it in
    // every project, including the plugin, so it cannot re-enter the APK.
    configurations.configureEach {
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.google.mlkit:text-recognition"))
                .using(module("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1"))
        }
    }
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
