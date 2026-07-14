# ============================================
# Meta Makefile to build Singularity container
# ============================================
# IMPORTANT:
# If you get permission denied errors when running this Makefile,
# rerun with sudo:
#   sudo make all

CONTAINERS := ubuntu22.04_R4.4.1 champ

.PHONY: all clean help $(CONTAINERS)

# -----------------------------
# Default: build all
# -----------------------------
all: ubuntu22.04_R4.4.1 champ

# -----------------------------
# Build each container
# -----------------------------
ubuntu22.04_R4.4.1:
	@echo "==============================================="
	@echo " Building container: ubuntu22.04_R4.4.1"
	@echo "==============================================="
	$(MAKE) -C ubuntu22.04_R4.4.1

champ:
	@echo "==============================================="
	@echo " Building container: champ"
	@echo "==============================================="
	$(MAKE) -C champ

# -----------------------------
# Clean all containers
# -----------------------------
clean:
	@for dir in $(CONTAINERS); do \
		if [ -d $$dir ]; then \
			$(MAKE) -C $$dir clean; \
		fi \
	done
	@echo "All containers cleaned."

# -----------------------------
# Help
# -----------------------------
help:
	@echo ""
	@echo "Usage:"
	@echo "  make all      Build all containers (in order)"
	@echo "  make clean    Clean all built containers"
	@echo "  make help     Show this help message"
	@echo ""