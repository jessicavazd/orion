include common.mk

default: sim

.PHONY: clean
clean: clean-sim

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
