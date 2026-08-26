.PHONY: test
test:
	dune build @unused-libs
	dune test

.PHONY: run
run:
	dune exec remote_dev $(ARGS)

.PHONY: watch
watch:
	dune exec --watch remote_dev $(ARGS)

.PHONY: android-run
android-run:
	./android/gradlew --no-daemon -p android :app:installDebug
	adb shell am start -n io.y2k.remote_client/.MainActivity
