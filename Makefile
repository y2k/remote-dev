.PHONY: test
test:
	dune test

.PHONY: run
run:
	dune exec remote_dev $(ARGS)

.PHONY: watch
watch:
	dune exec --watch remote_dev $(ARGS)
