.PHONY : build

.DEFAULT_GOAL := build

REPO_ROOT=$(shell realpath ./)
LUCET_SRC=$(shell realpath ../lucet-spectre/)
LUCET=$(LUCET_SRC)/target/debug/lucetc
WASM_CLANG=/opt/wasi-sdk/bin/clang
WASM_AR=/opt/wasi-sdk/bin/ar
WASM_RANLIB=/opt/wasi-sdk/bin/ranlib
WASM_CFLAGS=--sysroot /opt/wasi-sdk/share/wasi-sysroot/ -O3
WASM_LDFLAGS=-Wl,--export-all
WASM_LIBM=/opt/wasi-sdk/share/wasi-sysroot/lib/wasm32-wasi/libm.a

define generate_lucet_obj_files =
	RUST_BACKTRACE=1 $(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit clif \
		out/$(1).wasm -o out/$(1).clif

	RUST_BACKTRACE=1 $(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit obj \
		out/$(1).wasm -o out/$(1).o && \
	objdump -d out/$(1).o > out/$(1).asm

	RUST_BACKTRACE=1 $(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		out/$(1).wasm -o out/$(1).so && \
	objdump -d out/$(1).so > out/$(1)_so.asm

	RUST_BACKTRACE=1 $(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit obj \
		--spectre-mitigations-enable \
		out/$(1).wasm -o out/$(1)_spectre.o && \
	objdump -d out/$(1)_spectre.o > out/$(1)_spectre.asm

	RUST_BACKTRACE=1 $(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigations-enable \
		out/$(1).wasm -o out/$(1)_spectre.so && \
	objdump -d out/$(1)_spectre.so > out/$(1)_spectre_so.asm
endef

###########################################################################

out/test.wasm: basic_test/test.cpp
	mkdir -p out && \
	$(WASM_CLANG)++ $(WASM_CFLAGS) $(WASM_LDFLAGS) $< -o $@

out/test.so: out/test.wasm
	$(call generate_lucet_obj_files,test)

###########################################################################

out/zlib/Makefile: zlib/configure
	mkdir -p out/zlib
	cd out/zlib && CC=$(WASM_CLANG) AR=$(WASM_AR) RANLIB=$(WASM_RANLIB) CFLAGS='$(WASM_CFLAGS)' LDFLAGS='$(WASM_LDFLAGS)' $(REPO_ROOT)/zlib/configure

out/zlib/libz.a: out/zlib/Makefile
	$(MAKE) -C out/zlib

out/libpng/Makefile: out/zlib/libz.a ./libpng/CMakeLists.txt
	mkdir -p out/libpng
	cd out/libpng && cmake -DCMAKE_C_COMPILER=$(WASM_CLANG) -DCMAKE_C_FLAGS='$(WASM_CFLAGS) -DPNG_NO_SETJMP=1' -DCMAKE_EXE_LINKER_FLAGS='$(WASM_LDFLAGS)' -DM_LIBRARY=$(WASM_LIBM) -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(REPO_ROOT)/out/zlib/libz.a -DPNG_SHARED=0 $(REPO_ROOT)/libpng

out/libpng/libpng.a: out/libpng/Makefile
	$(MAKE) -C out/libpng
	# Have to build pngtest manually
	$(WASM_CLANG) $(WASM_CFLAGS) $(WASM_LDFLAGS) ./libpng/pngtest.c -I out/libpng/ -I zlib/ -o out/libpng/pngtest.wasm -L out/libpng -L out/zlib -lpng -lz
	$(call generate_lucet_obj_files,libpng/pngtest)

###########################################################################

out/zlib_original/Makefile: zlib/configure
	mkdir -p out/zlib_original
	cd out/zlib_original && CFLAGS='-O3' $(REPO_ROOT)/zlib/configure

out/zlib_original/libz.a: out/zlib_original/Makefile
	$(MAKE) -C out/zlib_original

out/libpng_original/Makefile: out/zlib_original/libz.a ./libpng/CMakeLists.txt
	mkdir -p out/libpng_original
	cd out/libpng_original && cmake -DCMAKE_C_FLAGS='-O3' -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(REPO_ROOT)/out/zlib_original/libz.a $(REPO_ROOT)/libpng

out/libpng_original/libpng.a: out/libpng_original/Makefile
	$(MAKE) -C out/libpng_original

###########################################################################

out/.build_ts: out/test.so out/libpng/libpng.a
	touch out/.build_ts

build: out/.build_ts

test: build
	@echo "-------------------"
	@echo "Testing"
	@echo "-------------------"
	@echo "Basic Test"
	@echo "-------------------"
	$(LUCET_SRC)/target/debug/lucet-wasi ./out/test.so --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB"
	$(LUCET_SRC)/target/debug/lucet-wasi ./out/test_spectre.so --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB"
	./check_mitigations.py --function_filter "guest_func_spec_*" ./out/test_spectre.asm
	./check_mitigations.py --function_filter "guest_func_spec_*" ./out/test_spectre_so.asm
	@echo "PNG Test"
	@echo "-------------------"
	cd libpng && ../out/libpng_original/pngtest
	cd libpng && $(LUCET_SRC)/target/debug/lucet-wasi  ../out/libpng/pngtest.so --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" --dir $(REPO_ROOT)/libpng/:$(REPO_ROOT)/libpng/
	@echo "OK."

clean:
	rm -rf out