import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.Optional
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

abstract class GenerateNetworkSecurityConfig : DefaultTask() {
    @get:Input
    @get:Optional
    abstract val backendHost: Property<String>

    @get:OutputDirectory
    abstract val outputDirectory: DirectoryProperty

    @TaskAction
    fun generate() {
        val host =
            backendHost.orNull
                ?.takeIf { it.isNotBlank() }
                ?: throw GradleException("backendHost is required; use -PbackendHost=<IP-address>")
        outputDirectory.file("xml/network_security_config.xml").get().asFile.apply {
            parentFile.mkdirs()
            writeText(
                """
                <?xml version="1.0" encoding="utf-8"?>
                <network-security-config>
                    <domain-config cleartextTrafficPermitted="true">
                        <domain>$host</domain>
                    </domain-config>
                </network-security-config>
                """.trimIndent()
            )
        }
    }
}

val localBackendHost =
    providers.fileContents(rootProject.layout.projectDirectory.file("local.properties")).asText.map { content ->
        Properties().apply { load(content.reader()) }.getProperty("backendHost").orEmpty()
    }
val configuredBackendHost = providers.gradleProperty("backendHost").orElse(localBackendHost)
val generatedNetworkSecurityResDir = layout.buildDirectory.dir("generated/network-security/res")
val generateNetworkSecurityConfig =
    tasks.register<GenerateNetworkSecurityConfig>("generateNetworkSecurityConfig") {
        backendHost.set(configuredBackendHost)
        outputDirectory.set(generatedNetworkSecurityResDir)
    }

android {
    namespace = "io.y2k.remote_client"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "io.y2k.remote_client"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField(
            "String",
            "BACKEND_URL",
            "\"http://${configuredBackendHost.orNull.orEmpty()}:8080/\"",
        )
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        buildConfig = true
        compose = true
    }
    sourceSets {
        getByName("main") {
            res.directories.add(generatedNetworkSecurityResDir.get().asFile.path)
        }
    }
}

tasks.named("preBuild") {
    dependsOn(generateNetworkSecurityConfig)
}

dependencies {
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))

    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.ktor.client.android)
    implementation(libs.ktor.client.core)
    implementation(platform(libs.androidx.compose.bom))

    testImplementation(libs.junit)
}
