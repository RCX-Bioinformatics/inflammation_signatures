# Makefile for building Singularity container with specified versions

# Software versions
BASE_IMAGE_NAME=ubuntu22.04_R4.4.1.sif
BASE_IMAGE_FILE=ubuntu22.04_R4.4.1.def
GGPLOT2_VERSION=3.5.1
DPLYR_VERSION=1.1.4
CONTAINER_NAME=champ.sif
DEFINITION_FILE=champ.def

# Build the Singularity container
$(CONTAINER_NAME): $(DEFINITION_FILE)
	@echo "Building Singularity container..."
	singularity build --build-arg GGPLOT2_VERSION=$(GGPLOT2_VERSION) --build-arg DPLYR_VERSION=$(DPLYR_VERSION) $(CONTAINER_NAME) $(DEFINITION_FILE)

# Build the base image
$(BASE_IMAGE_NAME):
	@echo "Building base image $(BASE_IMAGE_NAME)..."
	make -C ../ubuntu22.04_R4.4.1/
	singularity build ../ubuntu22.04_R4.4.1/$(BASE_IMAGE_NAME) ../ubuntu22.04_R4.4.1/$(BASE_IMAGE_FILE)

# Clean up the container image
clean:
	@echo "Cleaning up..."
	rm -f $(CONTAINER_NAME)

# Help message
help:
	@echo "Makefile for building Singularity container with specified versions"
	@echo "Usage:"
	@echo "  make"  # Build the container with specified versions based on the $(BASE_IMAGE)
	@echo "  make clean"  # Remove the container image