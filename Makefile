.PHONY : build run_tests check_asm test clean

.DEFAULT_GOAL := build

REPO_ROOT=$(shell realpath .)
OUT_DIR=$(shell realpath ../out/sfi-spectre-test/)
LUCET_SRC=$(shell realpath ../lucet-spectre/)
LUCET=$(LUCET_SRC)/target/debug/lucetc
WASM_CLANG=/opt/wasi-sdk/bin/clang
WASM_AR=/opt/wasi-sdk/bin/ar
WASM_RANLIB=/opt/wasi-sdk/bin/ranlib
WASM_CFLAGS=--sysroot /opt/wasi-sdk/share/wasi-sysroot/ -O3
WASM_LDFLAGS=-Wl,--export-all
WASM_LIBM=/opt/wasi-sdk/share/wasi-sysroot/lib/wasm32-wasi/libm.a
RUN_WASM_SO=$(LUCET_SRC)/target/debug/lucet-wasi --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" --dir /:/
export RUST_BACKTRACE=1

define generate_lucet_obj_files =
	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit clif \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1).clif

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1).so && \
	objdump -d $(OUT_DIR)/$(1).so > $(OUT_DIR)/$(1)_so.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--pinned-heap-reg \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1)_pinned.so && \
	objdump -d $(OUT_DIR)/$(1)_pinned.so > $(OUT_DIR)/$(1)_pinned_so.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigation strawman \
		--emit obj \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1)_spectre_strawman.o && \
	objdump -d $(OUT_DIR)/$(1)_spectre_strawman.o > $(OUT_DIR)/$(1)_spectre_strawman.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigation strawman \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1)_spectre_strawman.so && \
	objdump -d $(OUT_DIR)/$(1)_spectre_strawman.so > $(OUT_DIR)/$(1)_spectre_strawman_so.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigation loadlfence \
		--emit obj \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1)_spectre_loadlfence.o && \
	objdump -d $(OUT_DIR)/$(1)_spectre_loadlfence.o > $(OUT_DIR)/$(1)_spectre_loadlfence.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigation loadlfence \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1)_spectre_loadlfence.so && \
	objdump -d $(OUT_DIR)/$(1)_spectre_loadlfence.so > $(OUT_DIR)/$(1)_spectre_loadlfence_so.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigation sfi \
		--emit obj \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1)_spectre_sfi.o && \
	objdump -d $(OUT_DIR)/$(1)_spectre_sfi.o > $(OUT_DIR)/$(1)_spectre_sfi.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigation sfi \
		$(OUT_DIR)/$(1).wasm -o $(OUT_DIR)/$(1)_spectre_sfi.so && \
	objdump -d $(OUT_DIR)/$(1)_spectre_sfi.so > $(OUT_DIR)/$(1)_spectre_sfi_so.asm

	touch $(OUT_DIR)/$(1)_all
endef

###########################################################################

$(OUT_DIR)/basic_test/test.wasm: basic_test/test.cpp
	mkdir -p $(OUT_DIR)/basic_test && \
	$(WASM_CLANG)++ $(WASM_CFLAGS) $(WASM_LDFLAGS) $< -o $@

$(OUT_DIR)/basic_test/test_all: $(OUT_DIR)/basic_test/test.wasm $(LUCET)
	$(call generate_lucet_obj_files,basic_test/test)

###########################################################################

$(OUT_DIR)/zlib/Makefile: zlib/configure
	mkdir -p $(OUT_DIR)/zlib
	cd $(OUT_DIR)/zlib && CC=$(WASM_CLANG) AR=$(WASM_AR) RANLIB=$(WASM_RANLIB) CFLAGS='$(WASM_CFLAGS)' LDFLAGS='$(WASM_LDFLAGS)' $(REPO_ROOT)/zlib/configure

$(OUT_DIR)/zlib/libz.a: $(OUT_DIR)/zlib/Makefile
	$(MAKE) -C $(OUT_DIR)/zlib

$(OUT_DIR)/libpng/Makefile: $(OUT_DIR)/zlib/libz.a libpng/CMakeLists.txt
	mkdir -p $(OUT_DIR)/libpng
	cd $(OUT_DIR)/libpng && cmake -DCMAKE_C_COMPILER=$(WASM_CLANG) -DCMAKE_C_FLAGS='$(WASM_CFLAGS) -DPNG_NO_SETJMP=1' -DCMAKE_EXE_LINKER_FLAGS='$(WASM_LDFLAGS)' -DM_LIBRARY=$(WASM_LIBM) -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(OUT_DIR)/zlib/libz.a -DPNG_SHARED=0 $(REPO_ROOT)/libpng

$(OUT_DIR)/libpng/pngtest_all: $(OUT_DIR)/libpng/Makefile $(LUCET)
	$(MAKE) -C $(OUT_DIR)/libpng
	# Have to build pngtest manually
	$(WASM_CLANG) $(WASM_CFLAGS) $(WASM_LDFLAGS) libpng/pngtest.c -I $(OUT_DIR)/libpng/ -I zlib/ -o $(OUT_DIR)/libpng/pngtest.wasm -L $(OUT_DIR)/libpng -L $(OUT_DIR)/zlib -lpng -lz
	$(call generate_lucet_obj_files,libpng/pngtest)

###########################################################################

$(OUT_DIR)/zlib_original/Makefile: zlib/configure
	mkdir -p $(OUT_DIR)/zlib_original
	cd $(OUT_DIR)/zlib_original && CFLAGS='-O3 -fPIC' $(REPO_ROOT)/zlib/configure

$(OUT_DIR)/zlib_original/libz.a: $(OUT_DIR)/zlib_original/Makefile
	$(MAKE) -C $(OUT_DIR)/zlib_original

$(OUT_DIR)/libpng_original/Makefile: $(OUT_DIR)/zlib_original/libz.a libpng/CMakeLists.txt
	mkdir -p $(OUT_DIR)/libpng_original
	cd $(OUT_DIR)/libpng_original && cmake -DCMAKE_C_FLAGS='-O3 -fPIC' -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(OUT_DIR)/zlib_original/libz.a $(REPO_ROOT)/libpng

$(OUT_DIR)/libpng_original/png_test: $(OUT_DIR)/libpng_original/Makefile
	$(MAKE) -C $(OUT_DIR)/libpng_original

###########################################################################

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

build: $(OUT_DIR) $(OUT_DIR)/basic_test/test_all $(OUT_DIR)/libpng_original/png_test $(OUT_DIR)/libpng/pngtest_all

run_tests:
	@echo "-------------------"
	@echo "Testing"
	@echo "-------------------"
	@echo "Basic Test"
	@echo "-------------------"
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_strawman.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_loadlfence.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_sfi.so
	@echo "-------------------"
	@echo "PNG Test"
	@echo "-------------------"
	cd libpng && $(OUT_DIR)/libpng_original/pngtest
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_strawman.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_loadlfence.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_sfi.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	@echo "-------------------"

test: run_tests
	@echo "Tests completed successfully!"

clean:
	rm -rf out