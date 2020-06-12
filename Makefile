.PHONY : build build_cettests run_tests check_asm test test_cet clean build_transitions run_transitions

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
LUCET_COMMON_FLAGS=--bindings $(LUCET_SRC)/lucet-wasi/bindings.json --guard-size "4GiB" --min-reserved-size "4GiB" --max-reserved-size "4GiB"
LUCET_TRANSITION_FLAGS=--bindings $(REPO_ROOT)/transitions_benchmark/bindings.json $(LUCET_COMMON_FLAGS)
RUN_WASM_SO_NOASLR=$(LUCET_SRC)/target/debug/lucet-wasi --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" --dir /:/
RUN_WASM_SO=$(RUN_WASM_SO_NOASLR) --spectre-mitigation-aslr
WABT_BINS_FOLDER=$(REPO_ROOT)/../../wabt/bin

# Note this makefile uses the CET binaries only if REALLY_USE_CET is defined
ifdef REALLY_USE_CET
	RUN_WASM_CET_SO=$(LUCET_SRC)/target-cet/debug/lucet-wasi --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" --dir /:/
	CET_CFLAGS:=-fcf-protection=full
else
	RUN_WASM_CET_SO=$(LUCET_SRC)/target/debug/lucet-wasi --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" --dir /:/
	CET_CFLAGS:=
endif

export RUST_BACKTRACE=1
CET_CC := $(shell \
	if [ -e "$$(command -v gcc-9)" ]; then \
		echo gcc-9; \
	else \
		echo "gcc"; \
	fi \
)

.PRECIOUS: %.clif
%.clif: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --emit clif $< -o $@

.PRECIOUS: %.so
%.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_pinned.so
%_pinned.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --pinned-heap-reg $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_strawman.o
%_spectre_strawman.o: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation strawman --emit obj $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_strawman.so
%_spectre_strawman.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation strawman $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_loadlfence.o
%_spectre_loadlfence.o: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation loadlfence --emit obj $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_loadlfence.so
%_spectre_loadlfence.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation loadlfence $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_sfi.o
%_spectre_sfi.o: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation sfi --emit obj $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_sfi.so
%_spectre_sfi.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation sfi $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cet.o
%_spectre_cet.o: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation cet --emit obj $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cet.so
%_spectre_cet.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation cet $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_blade.so
%_spectre_blade.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-pht-mitigation blade --pinned-heap-reg $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_phttobtb.so
%_spectre_phttobtb.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-pht-mitigation phttobtb --pinned-heap-reg $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cfi.so
%_spectre_cfi.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-pht-mitigation cfi --pinned-heap-reg $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_all
%_all: $(LUCET) %.clif %.so %_pinned.so %_spectre_strawman.o %_spectre_strawman.so %_spectre_loadlfence.o %_spectre_loadlfence.so %_spectre_sfi.o %_spectre_sfi.so %_spectre_cet.o %_spectre_cet.so %_spectre_blade.so %_spectre_phttobtb.so %_spectre_cfi.so
	touch $@

###########################################################################

$(OUT_DIR)/basic_test/test.wasm: basic_test/test.cpp
	mkdir -p $(OUT_DIR)/basic_test && \
	$(WASM_CLANG)++ $(WASM_CFLAGS) $(WASM_LDFLAGS) $< -o $@

$(OUT_DIR)/basic_test/test_setup: $(OUT_DIR)/basic_test/test.wasm $(OUT_DIR)/basic_test/test_all

###########################################################################

$(OUT_DIR)/zlib/Makefile: zlib/configure
	mkdir -p $(OUT_DIR)/zlib
	cd $(OUT_DIR)/zlib && CC=$(WASM_CLANG) AR=$(WASM_AR) RANLIB=$(WASM_RANLIB) CFLAGS='$(WASM_CFLAGS)' LDFLAGS='$(WASM_LDFLAGS)' $(REPO_ROOT)/zlib/configure

$(OUT_DIR)/zlib/libz.a: $(OUT_DIR)/zlib/Makefile
	$(MAKE) -C $(OUT_DIR)/zlib

$(OUT_DIR)/libpng/Makefile: $(OUT_DIR)/zlib/libz.a libpng/CMakeLists.txt
	mkdir -p $(OUT_DIR)/libpng
	cd $(OUT_DIR)/libpng && cmake -DCMAKE_C_COMPILER=$(WASM_CLANG) -DCMAKE_C_FLAGS='$(WASM_CFLAGS) -DPNG_NO_SETJMP=1' -DCMAKE_EXE_LINKER_FLAGS='$(WASM_LDFLAGS)' -DM_LIBRARY=$(WASM_LIBM) -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(OUT_DIR)/zlib/libz.a -DPNG_SHARED=0 $(REPO_ROOT)/libpng

$(OUT_DIR)/libpng/pngtest.wasm: $(OUT_DIR)/libpng/Makefile
	$(MAKE) -C $(OUT_DIR)/libpng
	# Have to build pngtest manually
	$(WASM_CLANG) $(WASM_CFLAGS) $(WASM_LDFLAGS) libpng/pngtest.c -I $(OUT_DIR)/libpng/ -I zlib/ -o $(OUT_DIR)/libpng/pngtest.wasm -L $(OUT_DIR)/libpng -L $(OUT_DIR)/zlib -lpng -lz

$(OUT_DIR)/libpng/pngtest_setup: $(OUT_DIR)/libpng/pngtest.wasm $(OUT_DIR)/libpng/pngtest_all

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

$(OUT_DIR)/cet_test/cet_status: cet_test/cet_status.c
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror $(CET_CFLAGS) -g cet_test/cet_status.c -o $@

$(OUT_DIR)/cet_test/cet_branch_test: cet_test/cet_branch_helper.c cet_test/cet_branch_test.c
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror $(CET_CFLAGS) -g cet_test/cet_branch_test.c -S -o $@.s
	$(CET_CC) -Wall -Werror $(CET_CFLAGS) -g cet_test/cet_branch_test.c -o $@ && \
	objdump -D -f -s $@ > $@.asm && \
	readelf -a -n $@ > $@.readelf
	$(CET_CC) -Wall -Werror -g cet_test/cet_branch_test.c -o $@_nocet && \
	objdump -D -f -s $@_nocet > $@_nocet.asm && \
	readelf -a -n $@_nocet > $@_nocet.readelf


$(OUT_DIR)/cet_test/cet_branch_test_dl_helper.so: cet_test/cet_branch_helper.c
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror $(CET_CFLAGS) -g -shared -fPIC $< -o $@

$(OUT_DIR)/cet_test/nocet_branch_test_dl_helper.so: cet_test/nocet_branch_helper.c
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror -g -shared -fPIC $< -o $@

$(OUT_DIR)/cet_test/cet_branch_test_dl: $(OUT_DIR)/cet_test/cet_branch_test_dl_helper.so cet_test/cet_branch_test_dl.c
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror $(CET_CFLAGS) -g cet_test/cet_branch_test_dl.c -ldl -o $@

$(OUT_DIR)/cet_test/cet_branch_test_dl_nocetmain: $(OUT_DIR)/cet_test/cet_branch_test_dl_helper.so cet_test/cet_branch_test_dl.c
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror -g cet_test/cet_branch_test_dl.c -ldl -o $@

$(OUT_DIR)/cet_test/cet_branch_test_two_dl: $(OUT_DIR)/cet_test/cet_branch_test_dl_helper.so $(OUT_DIR)/cet_test/nocet_branch_test_dl_helper.so cet_test/cet_branch_test_two_dl.c
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror $(CET_CFLAGS) -g cet_test/cet_branch_test_two_dl.c -ldl -o $@

$(OUT_DIR)/cet_test/cet_branch_test_asm: cet_test/cet_branch_test_asm.s
	mkdir -p $(OUT_DIR)/cet_test
	$(CET_CC) -Wall -Werror -g $< -o $@ && \
	objdump -D -f -s $@ > $@.asm && \
	readelf -a -n $@ > $@.readelf
	$(CET_CC) -Wall -Werror $(CET_CFLAGS) -g $< -o $@2 && \
	objdump -D -f -s $@2 > $@2.asm && \
	readelf -a -n $@2 > $@2.readelf

###########################################################################

$(OUT_DIR)/transitions_benchmark/transitions_wasm.wasm: transitions_benchmark/wasmcode.c
	mkdir -p $(OUT_DIR)/transitions_benchmark
	$(WASM_CLANG) $(WASM_CFLAGS) $(WASM_LDFLAGS) -Wl,--allow-undefined $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm_stock.so: $(OUT_DIR)/transitions_benchmark/transitions_wasm.wasm
	$(LUCET) $(LUCET_TRANSITION_FLAGS) $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm_lfence.so: $(OUT_DIR)/transitions_benchmark/transitions_wasm.wasm
	$(LUCET) $(LUCET_TRANSITION_FLAGS) --spectre-mitigation sfi --spectre-only-sandbox-isolation $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm_coreswitch.so: $(OUT_DIR)/transitions_benchmark/transitions_wasm.wasm
	$(LUCET) $(LUCET_TRANSITION_FLAGS) --spectre-mitigation sfi --spectre-disable-btbflush $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm_coreswitchbtb.so: $(OUT_DIR)/transitions_benchmark/transitions_wasm.wasm
	$(LUCET) $(LUCET_TRANSITION_FLAGS) --spectre-mitigation sfi $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm: $(OUT_DIR)/transitions_benchmark/transitions_wasm_stock.so \
													$(OUT_DIR)/transitions_benchmark/transitions_wasm_lfence.so \
													$(OUT_DIR)/transitions_benchmark/transitions_wasm_coreswitch.so \
													$(OUT_DIR)/transitions_benchmark/transitions_wasm_coreswitchbtb.so
	touch $@

.PHONY: $(OUT_DIR)/transitions_benchmark/release/libtransitions.so
$(OUT_DIR)/transitions_benchmark/release/libtransitions.so:
	cd transitions_benchmark/transitions_lib && CARGO_TARGET_DIR="$(OUT_DIR)/transitions_benchmark/" cargo build --release

$(OUT_DIR)/transitions_benchmark/transitions_app: transitions_benchmark/app.c $(OUT_DIR)/transitions_benchmark/release/libtransitions.so
	mkdir -p $(OUT_DIR)/transitions_benchmark
	gcc transitions_benchmark/app.c -Wl,-rpath=$(OUT_DIR)/transitions_benchmark/release/ -L $(OUT_DIR)/transitions_benchmark/release/ -ltransitions -o $@

###########################################################################

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

build_cettests: $(OUT_DIR)/cet_test/cet_branch_test $(OUT_DIR)/cet_test/cet_branch_test_dl $(OUT_DIR)/cet_test/cet_branch_test_dl_nocetmain $(OUT_DIR)/cet_test/cet_branch_test_two_dl $(OUT_DIR)/cet_test/cet_branch_test_asm

build_transitions: $(OUT_DIR)/transitions_benchmark/transitions_app $(OUT_DIR)/transitions_benchmark/transitions_wasm

build: $(OUT_DIR) $(OUT_DIR)/basic_test/test_setup $(OUT_DIR)/libpng_original/png_test $(OUT_DIR)/libpng/pngtest_setup build_cettests build_transitions

test_phtbtb: $(OUT_DIR)/basic_test/test.wasm $(OUT_DIR)/basic_test/test_spectre_phttobtb.so $(OUT_DIR)/libpng/pngtest.wasm $(OUT_DIR)/libpng/pngtest_spectre_phttobtb.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_phttobtb.so
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_phttobtb.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png

test_cfi: $(OUT_DIR)/basic_test/test.wasm $(OUT_DIR)/basic_test/test_spectre_cfi.so $(OUT_DIR)/libpng/pngtest.wasm $(OUT_DIR)/libpng/pngtest_spectre_cfi.so
	$(RUN_WASM_SO_NOASLR) $(OUT_DIR)/basic_test/test_spectre_cfi.so
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_cfi.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png

#  -funroll-loops -mllvm -unroll-threshold=1000  -mllvm -unroll-max-percent-threshold-boost=10000
LOOPFLAGS=-funroll-loops -mllvm -unroll-threshold=1 -unroll-partial-threshold=4 -mllvm -unroll-count=4
test_unrolling:
	$(WASM_CLANG)++ $(WASM_CFLAGS) $(LOOPFLAGS) $(WASM_LDFLAGS) basic_test/test.cpp -o $(OUT_DIR)/basic_test/test.wasm
	$(WABT_BINS_FOLDER)/wasm2wat $(OUT_DIR)/basic_test/test.wasm > $(OUT_DIR)/basic_test/test.wat
	$(WABT_BINS_FOLDER)/wasm-decompile $(OUT_DIR)/basic_test/test.wasm > $(OUT_DIR)/basic_test/test.wasm.decompile

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
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_blade.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_phttobtb.so
	$(RUN_WASM_CET_SO) $(OUT_DIR)/basic_test/test_spectre_cet.so
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
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_blade.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_phttobtb.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_CET_SO) $(OUT_DIR)/libpng/pngtest_spectre_cet.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png
	-rm $(REPO_ROOT)/libpng/pngout.png
	@echo "-------------------"

test: run_tests
	@echo "Tests completed successfully!"

test_cet: build_cettests
	$(OUT_DIR)/cet_test/cet_branch_test
	cd $(OUT_DIR)/cet_test/ && ./cet_branch_test_dl
	cd $(OUT_DIR)/cet_test/ && ./cet_branch_test_dl_nocetmain
	cd $(OUT_DIR)/cet_test/ && ./cet_branch_test_two_dl
	@echo "$(OUT_DIR)/cet_test/cet_branch_test_asm"
	@$(OUT_DIR)/cet_test/cet_branch_test_asm; if [ $$? -eq 0 ]; then echo "CET assembly: invalid jump succeeded..."; else echo "CET assembly: caught invalid jump!"; fi

run_transitions:
	# Need to set frequency on all cores as core switching sets affinities to either 0 or 1..7
	if [ -x "$(shell command -v cpupower)" ]; then \
		sudo cpupower -c 0,1,2,3,4,5,6,7 frequency-set --min 2700MHz --max 2700MHz; \
	else \
		sudo cpufreq-set -c 0,1,2,3,4,5,6,7 --min 2700MHz --max 2700MHz; \
	fi
	cd $(OUT_DIR)/transitions_benchmark && taskset -c 0 ./transitions_app | tee $(REPO_ROOT)/../benchmarks/transitions_$(shell date --iso=seconds).txt

clean:
	rm -rf $(OUT_DIR)
