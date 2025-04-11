CLR_GR := \033[0;32m
CLR_CY := \033[0;36m
CLR_BL := \033[34m
CLR_NC := \033[0m

all: sim

MAKEFLAGS += --no-print-directory

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


.PHONY: clean
clean: clean-sim


.PHONY: clean-sim
clean-sim:
	@echo -e "$(CLR_GR)>> Cleaning OrionSim$(CLR_NC)"
	$(MAKE) -C sim clean
