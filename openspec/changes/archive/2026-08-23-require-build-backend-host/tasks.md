## 1. Build Configuration

- [x] 1.1 Read `backendHost` from `local.properties`, with `-PbackendHost` as an override, and derive both the client backend URL and a generated network security configuration from it; verify `./gradlew assembleDebug` and `./gradlew -PbackendHost=192.168.0.42 assembleDebug` succeed.
- [x] 1.2 Replace the fixed Kotlin URL and static IP-based network security resource with the build-derived configuration; verify the assembled debug APK permits HTTP only for `192.168.0.42` and requests `http://192.168.0.42:8080/`.

## 2. Build Interface

- [x] 2.1 Verify an Android build without a non-empty `backendHost` in `local.properties` or `-PbackendHost` fails before producing an APK and reports that `backendHost` is required.
- [x] 2.2 Document `backendHost` in `local.properties` and its `-PbackendHost=<IP-address>` override; verify the documented property name matches the accepted configuration.
