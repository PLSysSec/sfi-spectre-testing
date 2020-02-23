.PHONY : build

.DEFAULT_GOAL := build

REPO_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
LUCET_SRC=$(shell realpath $(REPO_ROOT)/../lucet-spectre/)
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
		out/$(1).wasm -o $(REPO_ROOT)/out/$(1).clif

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit obj \
		out/$(1).wasm -o $(REPO_ROOT)/out/$(1).o && \
	objdump -d $(REPO_ROOT)/out/$(1).o > $(REPO_ROOT)/out/$(1).asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		out/$(1).wasm -o $(REPO_ROOT)/out/$(1).so && \
	objdump -d $(REPO_ROOT)/out/$(1).so > $(REPO_ROOT)/out/$(1)_so.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit obj \
		--spectre-mitigations-enable \
		out/$(1).wasm -o $(REPO_ROOT)/out/$(1)_spectre.o && \
	objdump -d $(REPO_ROOT)/out/$(1)_spectre.o > $(REPO_ROOT)/out/$(1)_spectre.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigations-enable \
		out/$(1).wasm -o $(REPO_ROOT)/out/$(1)_spectre.so && \
	objdump -d $(REPO_ROOT)/out/$(1)_spectre.so > $(REPO_ROOT)/out/$(1)_spectre_so.asm
endef

###########################################################################

$(REPO_ROOT)/out/test.wasm: $(REPO_ROOT)/basic_test/test.cpp
	mkdir -p $(REPO_ROOT)/out && \
	$(WASM_CLANG)++ $(WASM_CFLAGS) $(WASM_LDFLAGS) $< -o $@

$(REPO_ROOT)/out/test.so: $(REPO_ROOT)/out/test.wasm $(LUCET)
	$(call generate_lucet_obj_files,test)

###########################################################################

$(REPO_ROOT)/out/zlib/Makefile: $(REPO_ROOT)/zlib/configure
	mkdir -p $(REPO_ROOT)/out/zlib
	cd $(REPO_ROOT)/out/zlib && CC=$(WASM_CLANG) AR=$(WASM_AR) RANLIB=$(WASM_RANLIB) CFLAGS='$(WASM_CFLAGS)' LDFLAGS='$(WASM_LDFLAGS)' $(REPO_ROOT)/zlib/configure

$(REPO_ROOT)/out/zlib/libz.a: $(REPO_ROOT)/out/zlib/Makefile
	$(MAKE) -C $(REPO_ROOT)/out/zlib

$(REPO_ROOT)/out/libpng/Makefile: $(REPO_ROOT)/out/zlib/libz.a $(REPO_ROOT)/libpng/CMakeLists.txt
	mkdir -p $(REPO_ROOT)/out/libpng
	cd $(REPO_ROOT)/out/libpng && cmake -DCMAKE_C_COMPILER=$(WASM_CLANG) -DCMAKE_C_FLAGS='$(WASM_CFLAGS) -DPNG_NO_SETJMP=1' -DCMAKE_EXE_LINKER_FLAGS='$(WASM_LDFLAGS)' -DM_LIBRARY=$(WASM_LIBM) -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(REPO_ROOT)/out/zlib/libz.a -DPNG_SHARED=0 $(REPO_ROOT)/libpng

$(REPO_ROOT)/out/libpng/libpng16.a: $(REPO_ROOT)/out/libpng/Makefile $(LUCET)
	$(MAKE) -C $(REPO_ROOT)/out/libpng
	# Have to build pngtest manually
	$(WASM_CLANG) $(WASM_CFLAGS) $(WASM_LDFLAGS) $(REPO_ROOT)/libpng/pngtest.c -I $(REPO_ROOT)/out/libpng/ -I zlib/ -o $(REPO_ROOT)/out/libpng/pngtest.wasm -L $(REPO_ROOT)/out/libpng -L $(REPO_ROOT)/out/zlib -lpng -lz
	$(call generate_lucet_obj_files,libpng/pngtest)

###########################################################################

$(REPO_ROOT)/out/zlib_original/Makefile: $(REPO_ROOT)/zlib/configure
	mkdir -p $(REPO_ROOT)/out/zlib_original
	cd $(REPO_ROOT)/out/zlib_original && CFLAGS='-O3' $(REPO_ROOT)/zlib/configure

$(REPO_ROOT)/out/zlib_original/libz.a: $(REPO_ROOT)/out/zlib_original/Makefile
	$(MAKE) -C $(REPO_ROOT)/out/zlib_original

$(REPO_ROOT)/out/libpng_original/Makefile: $(REPO_ROOT)/out/zlib_original/libz.a $(REPO_ROOT)/libpng/CMakeLists.txt
	mkdir -p $(REPO_ROOT)/out/libpng_original
	cd $(REPO_ROOT)/out/libpng_original && cmake -DCMAKE_C_FLAGS='-O3' -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(REPO_ROOT)/out/zlib_original/libz.a $(REPO_ROOT)/libpng

$(REPO_ROOT)/out/libpng_original/libpng16.a: $(REPO_ROOT)/out/libpng_original/Makefile
	$(MAKE) -C $(REPO_ROOT)/out/libpng_original

###########################################################################

build: $(REPO_ROOT)/out/test.so $(REPO_ROOT)/out/libpng_original/libpng16.a $(REPO_ROOT)/out/libpng/libpng16.a

test: build
	@echo "-------------------"
	@echo "Testing"
	@echo "-------------------"
	@echo "Basic Test"
	@echo "-------------------"
	$(RUN_WASM_SO) $(REPO_ROOT)/out/test.so
	$(RUN_WASM_SO) $(REPO_ROOT)/out/test_spectre.so
	$(REPO_ROOT)/check_mitigations.py --function_filter "guest_func_*" --function_exclude_filter "guest_func__start" --limit 10 $(REPO_ROOT)/out/test_spectre.asm
	$(REPO_ROOT)/check_mitigations.py --function_filter "guest_func_*" --function_exclude_filter "guest_func__start" --limit 10 $(REPO_ROOT)/out/test_spectre_so.asm
	@echo "-------------------"
	@echo "PNG Test"
	@echo "-------------------"
	cd libpng && $(REPO_ROOT)/out/libpng_original/pngtest
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(REPO_ROOT)/out/libpng/pngtest.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	$(REPO_ROOT)/check_mitigations.py --function_filter "guest_func_*" --function_exclude_filter "guest_func__start" --limit 10 $(REPO_ROOT)/out/libpng/pngtest_spectre.asm
	$(REPO_ROOT)/check_mitigations.py --function_filter "guest_func_*" --function_exclude_filter "guest_func__start" --limit 10 $(REPO_ROOT)/out/libpng/pngtest_spectre_so.asm
	@echo "-------------------"
	@echo "Tests completed successfully!"

clean:
	rm -rf $(REPO_ROOT)/out