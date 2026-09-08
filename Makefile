.PHONY: test
test: build
	dune test

.PHONY: build
build:
	dune build @unused-libs

.PHONY: run
run:
	dune exec remote_dev -- $(ARGS)

.PHONY: watch
watch:
	dune exec --watch remote_dev -- $(ARGS)

.PHONY: android-run
android-run:
	ANDROID_SERIAL=emulator-5554 ./android/gradlew --no-daemon -p android :app:installDebug
	adb -s emulator-5554 shell am start -n io.y2k.remote_client/.MainActivity
