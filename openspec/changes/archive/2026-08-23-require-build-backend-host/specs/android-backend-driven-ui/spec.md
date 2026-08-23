## ADDED Requirements

### Requirement: Configure development backend at build time
The Android build SHALL obtain `backendHost` from `local.properties`. A `-PbackendHost` Gradle property SHALL override that local value for one build. The produced client SHALL send backend requests to `http://<backendHost>:8080/`, where `<backendHost>` is the resolved value.

#### Scenario: Build with local backend host
- **WHEN** `local.properties` sets `backendHost=192.168.0.15` and a developer builds the Android client without `-PbackendHost`
- **THEN** the resulting client sends its backend requests to `http://192.168.0.15:8080/`

#### Scenario: Override local backend host
- **WHEN** `local.properties` sets `backendHost=192.168.0.15` and a developer builds with `-PbackendHost=192.168.0.42`
- **THEN** the resulting client sends its backend requests to `http://192.168.0.42:8080/`

#### Scenario: Build without configured backend host
- **WHEN** a developer starts an Android build without a non-empty `backendHost` in either source
- **THEN** the build fails before producing an APK and identifies `backendHost` as required

## MODIFIED Requirements

### Requirement: Restrict development cleartext traffic
The Android client SHALL permit cleartext HTTP traffic only to the `backendHost` configured for that build and SHALL NOT enable cleartext traffic globally for other destinations.

#### Scenario: Connect to the development backend
- **WHEN** the client requests `http://<backendHost>:8080/` using the host configured at build time
- **THEN** Android network security permits the cleartext connection
