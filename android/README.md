# Android client

Set the development backend IP in `local.properties`:

```properties
backendHost=192.168.0.15
```

Then build a debug APK with:

```sh
./gradlew assembleDebug
```

Pass `-PbackendHost=<IP-address>` to override the local value for one build. The resulting APK sends requests to port `8080` on that IP address.
