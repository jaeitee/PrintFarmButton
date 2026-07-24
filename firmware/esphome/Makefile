# ESPHome PrintFarmButton Makefile
#
# Usage:
#   make <target>                # Uses system ESPHome (default)
#   ESPHOME_MODE=docker make <target>  # Uses Docker
#   ESPHOME_MODE=podman make <target>  # Uses Podman
#
# Web flasher (local flash.html):
#   make publish-s3-zero         # build + copy bins into firmware/output/
#   ESPHOME_MODE=docker make publish-all  # build+publish every board
#   make serve-flash             # http://localhost:8080/flash.html
#
# Container modes reuse PlatformIO cache via .esphome/platformio.
#
# Supported targets: build/run for s3-mini, c3-mini, s3-zero, c3-zero, atom-matrix
#
ESPHOME ?= esphome
ESPHOME_MODE ?= system
ESPHOME_IMAGE ?= esphome/esphome:2025.7.0
REPO_ROOT := $(abspath ../..)

ifeq ($(ESPHOME_MODE),podman)
	ESPHOME_CMD = podman run --rm -v $(CURDIR):/data -v $(CURDIR)/.esphome/platformio:/cache $(ESPHOME_IMAGE)
	YAML_PREFIX = /data/
else ifeq ($(ESPHOME_MODE),docker)
	ESPHOME_CMD = docker run --rm -v $(CURDIR):/data -v $(CURDIR)/.esphome/platformio:/cache $(ESPHOME_IMAGE)
	YAML_PREFIX = /data/
else
	ESPHOME_CMD = $(ESPHOME)
	YAML_PREFIX =
endif

.PHONY: clean build-s3-mini run-s3-mini build-c3-mini run-c3-mini build-s3-zero run-s3-zero build-c3-zero run-c3-zero build-atom-matrix run-atom-matrix clean-build-s3-mini clean-build-c3-mini clean-build-s3-zero clean-build-c3-zero clean-build-atom-matrix s3 c3 publish-s3-mini publish-c3-mini publish-s3-zero publish-c3-zero publish-atom-matrix publish-all serve-flash testbuild-s3-mini testbuild-c3-mini testbuild-s3-zero testbuild-c3-zero testbuild-atom-matrix

# Clean all build artifacts
clean:
	rm -rf .esphome/build/printfarmbutton*
	rm -rf .esphome/.storage

# ESP32-S3 SuperMini builds
build-s3-mini:
	$(ESPHOME_CMD) compile $(YAML_PREFIX)esp32s3-supermini.yaml

run-s3-mini:
	$(ESPHOME_CMD) run $(YAML_PREFIX)esp32s3-supermini.yaml

# ESP32-C3 SuperMini builds  
build-c3-mini:
	$(ESPHOME_CMD) compile $(YAML_PREFIX)esp32c3-supermini.yaml

run-c3-mini:
	$(ESPHOME_CMD) run $(YAML_PREFIX)esp32c3-supermini.yaml

# ESP32-S3 Zero builds
build-s3-zero:
	$(ESPHOME_CMD) compile $(YAML_PREFIX)esp32s3-zero.yaml

run-s3-zero:
	$(ESPHOME_CMD) run $(YAML_PREFIX)esp32s3-zero.yaml

# ESP32-C3 Zero builds
build-c3-zero:
	$(ESPHOME_CMD) compile $(YAML_PREFIX)esp32c3-zero.yaml

run-c3-zero:
	$(ESPHOME_CMD) run $(YAML_PREFIX)esp32c3-zero.yaml

# M5Stack ATOM Matrix builds (unique process)
build-atom-matrix:
	$(ESPHOME_CMD) compile $(YAML_PREFIX)atom-matrix.yaml

run-atom-matrix:
	$(ESPHOME_CMD) run $(YAML_PREFIX)atom-matrix.yaml

clean-build-atom-matrix: clean build-atom-matrix

# Clean and build targets (automatically clean before building different chip families)
clean-build-s3-mini: clean build-s3-mini
clean-build-c3-mini: clean build-c3-mini  
clean-build-s3-zero: clean build-s3-zero
clean-build-c3-zero: clean build-c3-zero

# --- Local test builds -------------------------------------------------------
# Appends -testing to the reported version (e.g. 1.0.14-testing) and copies the
# binaries into firmware/test-build/ (NOT firmware/output/, which is for releases).
TESTING_SUFFIX ?= -testing
TESTBUILD_DIR := ../test-build
BUILD_BIN := .esphome/build/printfarmbutton/.pioenvs/printfarmbutton

# $(1) = board yaml (no prefix), $(2) = test-build basename (printfarmbutton-<name>)
define testbuild
	$(ESPHOME_CMD) -s version_suffix "$(TESTING_SUFFIX)" compile $(YAML_PREFIX)$(1)
	cp $(BUILD_BIN)/firmware.factory.bin $(TESTBUILD_DIR)/$(2).factory.bin
	cp $(BUILD_BIN)/firmware.ota.bin $(TESTBUILD_DIR)/$(2).ota.bin
	@echo "Test build ($(TESTING_SUFFIX)) copied to $(TESTBUILD_DIR)/$(2).{factory,ota}.bin"
endef

testbuild-s3-mini:
	$(call testbuild,esp32s3-supermini.yaml,printfarmbutton-supermini-esp32s3)

testbuild-c3-mini:
	$(call testbuild,esp32c3-supermini.yaml,printfarmbutton-supermini-esp32c3)

testbuild-s3-zero:
	$(call testbuild,esp32s3-zero.yaml,printfarmbutton-zero-esp32s3)

testbuild-c3-zero:
	$(call testbuild,esp32c3-zero.yaml,printfarmbutton-zero-esp32c3)

testbuild-atom-matrix:
	$(call testbuild,atom-matrix.yaml,printfarmbutton-atom-matrix-esp32)

# Build and copy into firmware/output for local flash.html
publish-s3-mini: build-s3-mini
	./publish-to-output.sh esp32s3-supermini

publish-c3-mini: build-c3-mini
	./publish-to-output.sh esp32c3-supermini

publish-s3-zero: build-s3-zero
	./publish-to-output.sh esp32s3-zero

publish-c3-zero: build-c3-zero
	./publish-to-output.sh esp32c3-zero

publish-atom-matrix: build-atom-matrix
	./publish-to-output.sh atom-matrix

# Build and publish every board for local flash.html (sequential — shared build dir)
publish-all:
	$(MAKE) clean publish-s3-zero
	$(MAKE) clean publish-c3-zero
	$(MAKE) clean publish-s3-mini
	$(MAKE) clean publish-c3-mini
	$(MAKE) clean publish-atom-matrix
	@echo "All boards published to firmware/output/. Run: make serve-flash"

# Serve repo root so flash.html can load firmware/output manifests + bins
serve-flash:
	@echo "Open http://localhost:8080/flash.html"
	cd $(REPO_ROOT) && python3 -m http.server 8080
