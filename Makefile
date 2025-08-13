UNAME := $(shell uname)
ARCH := $(shell uname -m)

ifeq ($(UNAME), Linux)
	EXT := so
else ifeq ($(UNAME), Darwin)
	EXT := dylib
else
	$(error Unsupported operating system: $(UNAME))
endif

# Lua versions supported by the crate
LUA_VERSIONS := lua51 lua52 lua53 lua54 luajit

# Default target
all: luajit

# Build directory
BUILD_DIR := target/release

# Lua paths for macOS
LUA_INCLUDE_DIR := /usr/local/include
LUA_LIB_DIR := /usr/local/lib

# Define build targets for each Lua version
define build_version_template
$(2)_$(1):
	@if [ "$(UNAME)" = "Darwin" ]; then \
		RUSTFLAGS="-C link-args=-undefined -C link-args=dynamic_lookup" cargo build --release --features=$(1) -p $(2); \
	else \
		RUSTFLAGS="-C link-args=-Wl,-soname,lib$(2).$(EXT)" cargo build --release --features=$(1) -p $(2); \
	fi
	@mkdir -p build
	@cp $(BUILD_DIR)/lib$(2).$(EXT) build/$(2)_$(1).$(EXT)
	@if [ "$(UNAME)" = "Darwin" ]; then \
		install_name_tool -id @rpath/$(2)_$(1).$(EXT) build/$(2)_$(1).$(EXT); \
	fi
endef

# Generate build targets for each Lua version
$(foreach version,$(LUA_VERSIONS),$(eval $(call build_version_template,$(version),markdown_to_html)))
$(foreach version,$(LUA_VERSIONS),$(eval $(call build_version_template,$(version),chrome_cookie)))

# Build all versions
all_versions: $(LUA_VERSIONS)

# Clean target
clean:
	cargo clean
	rm -rf build

# Development targets
lint:
	cargo clippy --all-features -- -D warnings

test:
	@if [ "$(UNAME)" = "Darwin" ]; then \
		RUSTFLAGS="-C link-args=-undefined -C link-args=dynamic_lookup" cargo test --features=lua51; \
	else \
		RUSTFLAGS="-C link-args=-Wl,-soname,libmarkdown_to_html.$(EXT)" cargo test --features=lua51; \
	fi

.PHONY: all $(LUA_VERSIONS) all_versions clean lint test
