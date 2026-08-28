## 1. Dependency And Tooling Alignment

- [x] 1.1 Keep existing Android dependency versions in `android/gradle/libs.versions.toml` and add the source versions and aliases for Spotless, ktfmt, detekt, and Compose detekt rules; verify `./gradlew tasks --all` completes without catalog or plugin-resolution errors.
- [x] 1.2 Configure root `android/build.gradle.kts` with the source-client Spotless ktfmt Kotlin style targets and shared detekt plugin/configuration; verify `./gradlew spotlessCheck detekt` discovers and runs both quality tools.
- [x] 1.3 Add `android/detekt.yml` with the source-client Compose parameter order, swallowed cancellation, and immutable data class rules; verify detekt loads the file and the Compose rule dependency.

## 2. Format And Verify

- [x] 2.1 Run `./gradlew spotlessApply` and retain the required Kotlin and Gradle Kotlin DSL formatting changes; verify a following `./gradlew spotlessCheck` passes.
- [x] 2.2 Set generated network security config `includeSubdomains="false"` to retain the single-host policy and satisfy Android lint, then run `./gradlew check -PbackendHost=192.168.0.15` and `./gradlew assembleDebug -PbackendHost=192.168.0.15`; verify the Android quality lifecycle and debug APK build both succeed.
