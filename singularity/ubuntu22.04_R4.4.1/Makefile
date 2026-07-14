# Makefile for building Singularity container with specified versions

# Software versions
UBUNTU_VERSION=22.04
R_VERSION=4.4.1
CONTAINER_NAME=ubuntu22.04_R4.4.1.sif
DEFINITION_FILE=ubuntu22.04_R4.4.1.def

# Build the Singularity container
$(CONTAINER_NAME):
	@echo "Building Singularity container..."
	singularity build --build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) --build-arg R_VERSION=$(R_VERSION) $(CONTAINER_NAME) $(DEFINITION_FILE)

# Clean up the container image
clean:
	@echo "Cleaning up..."
	rm -f $(CONTAINER_NAME)

# Help message
help:
	@echo "Makefile for building Singularity container with specified versions"
	@echo "Usage:"
	@echo "  make"  # Build the container with specified versions
	@echo "  make clean"  # Remove the container image