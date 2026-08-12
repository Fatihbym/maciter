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
}
subprojects {
    project.evaluationDependsOn(":app")
    
    val buildFile = project.file("build.gradle")
    if (buildFile.exists()) {
        try {
            val content = buildFile.readText()
            if (content.contains("proguard-android.txt")) {
                buildFile.writeText(content.replace("proguard-android.txt", "proguard-android-optimize.txt"))
            }
        } catch (e: Exception) {}
    }
}

subprojects {
    val configureProject = {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            // Force compileSdk, buildToolsVersion and targetSdk to 36 using robust method iteration
            androidExt.javaClass.methods.forEach { method ->
                if (method.name == "setCompileSdk" || method.name == "compileSdk" || method.name == "setCompileSdkVersion") {
                    try {
                        method.invoke(androidExt, 36)
                    } catch (e: Exception) {}
                }
                if (method.name == "setBuildToolsVersion" || method.name == "buildToolsVersion") {
                    try {
                        method.invoke(androidExt, "36.0.0")
                    } catch (e: Exception) {}
                }
                if (method.name == "setNdkVersion" || method.name == "ndkVersion") {
                    try {
                        method.invoke(androidExt, "28.2.13676358")
                    } catch (e: Exception) {}
                }
            }

            val defaultConfig = try {
                androidExt.javaClass.getMethod("getDefaultConfig").invoke(androidExt)
            } catch (e: Exception) {
                null
            }
            if (defaultConfig != null) {
                defaultConfig.javaClass.methods.forEach { method ->
                    if (method.name == "setTargetSdk" || method.name == "targetSdk" || method.name == "setTargetSdkVersion") {
                        try {
                            method.invoke(defaultConfig, 36)
                        } catch (e: Exception) {}
                    }
                }
            }
            
            // Dynamically set namespace from AndroidManifest.xml package attribute if missing
            try {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestContent = manifestFile.readText()
                    val packageRegex = """package=["']([^"']+)["']""".toRegex()
                    val matchResult = packageRegex.find(manifestContent)
                    if (matchResult != null) {
                        val packageName = matchResult.groupValues[1]
                        val setNamespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        setNamespaceMethod.invoke(androidExt, packageName)
                    }
                }
            } catch (e: Exception) {
                // Hardcoded fallback list if dynamic parsing fails
                try {
                    if (project.name == "carrier_info") {
                        val namespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        namespaceMethod.invoke(androidExt, "com.chizi.carrier_info")
                    } else if (project.name == "flutter_jailbreak_detection") {
                        val namespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        namespaceMethod.invoke(androidExt, "appmire.be.flutterjailbreakdetection")
                    }
                } catch (ex: Exception) {
                }
            }
        }
    }

    if (project.state.executed) {
        configureProject()
    } else {
        project.afterEvaluate {
            configureProject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
