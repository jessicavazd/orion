include common.mk

default: lib sim

.PHONY: clean
clean: clean-lib clean-sim

################################################################################
# OrionSim
################################################################################
.PHONY: lint
lint:
	@printf "$(CLR_GR)>> Performing Lint Check$(CLR_NC)\n"
	$(MAKE) -C sim lint

.PHONY: sim
sim:
	@printf "$(CLR_GR)>> Building OrionSim$(CLR_NC)\n"
	$(MAKE) -C sim

.PHONY: clean-sim
clean-sim:
	@printf "$(CLR_GR)>> Cleaning OrionSim$(CLR_NC)\n"
	$(MAKE) -C sim clean


################################################################################
# LibTinyC
################################################################################
.PHONY: lib
lib:
	@printf "$(CLR_GR)>> Building LibTinyC$(CLR_NC)\n"
	$(MAKE) -C sw/lib

.PHONY: clean-lib
clean-lib:
	@printf "$(CLR_GR)>> Cleaning LibTinyC$(CLR_NC)\n"
	$(MAKE) -C sw/lib clean


################################################################################
# Docs
################################################################################
.PHONY: docs
docs: docs-html docs-serve

.PHONY: docs-html
docs-html:
	@printf "$(CLR_GR)>> Generating docs: html$(CLR_NC)\n"
	mkdocs build --site-dir docs/build

.PHONY: docs-serve
docs-serve:
	mkdocs serve --dev-addr localhost:8000 -w mkdocs.yml -w docs -w docs/assets -w docs/js

################################################################################
# Run Tests
################################################################################
.PHONY: test
test: sim lib
	@printf "$(CLR_GR)>> Running Tests$(CLR_NC)\n"
	bash scripts/run_tests.sh
