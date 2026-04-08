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
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.property("android")
            if (android != null) {
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    if (getNamespace.invoke(android) == null) {
                        if (project.name == "flutter_inappwebview") {
                            setNamespace.invoke(android, "com.pichillilorenzo.flutter_inappwebview")
                        } else {
                            // For other plugins, try to use their group id or a fallback
                            val namespace = project.group.toString().ifEmpty { "com.example.${project.name.replace("-", "_")}" }
                            setNamespace.invoke(android, namespace)
                        }
                    }
                } catch (e: Exception) {
                    // Ignore if methods don't exist
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
