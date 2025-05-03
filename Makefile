include common.mk

default: lib sim

.PHONY: clean
clean: clean-lib clean-sim

################################################################################
# OrionSim
################################################################################
.PHONY: lint
lint:
	@echo -e "$(CLR_GR)>> Performing Lint Check$(CLR_NC)"
	$(MAKE) -C sim lint

.PHONY: sim
sim:
	@echo -e "$(CLR_GR)>> Building OrionSim$(CLR_NC)"
	$(MAKE) -C sim

.PHONY: clean-sim
clean-sim:
	@echo -e "$(CLR_GR)>> Cleaning OrionSim$(CLR_NC)"
	$(MAKE) -C sim clean


################################################################################
# LibTinyC
################################################################################
.PHONY: lib
lib:
	@echo -e "$(CLR_GR)>> Building LibTinyC$(CLR_NC)"
	$(MAKE) -C sw/lib

.PHONY: clean-lib
clean-lib:
	@echo -e "$(CLR_GR)>> Cleaning LibTinyC$(CLR_NC)"
	$(MAKE) -C sw/lib clean


################################################################################
# Run Tests
################################################################################
.PHONY: test
test: sim lib
	@echo -e "$(CLR_GR)>> Running Tests$(CLR_NC)"
	bash scripts/run_tests.sh
