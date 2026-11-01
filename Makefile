ARGS ?= --agent opencode

.PHONY: test
test: build
	dune test

.PHONY: build
build:
	dune build @unused-libs

.PHONY: run
run: android-run
	@pids=$$(lsof -tiTCP:8080 -sTCP:LISTEN); if [ -n "$$pids" ]; then kill $$pids; fi
	dune exec remote_dev -- $(ARGS) "$(abspath $(CURDIR)/..)"

.PHONY: watch
watch:
	dune exec --watch remote_dev -- $(ARGS)

.PHONY: android-run
android-run:
	./android/gradlew --no-daemon -p android :app:installDebug && \
		adb shell am start -n io.y2k.remote_client/.MainActivity
