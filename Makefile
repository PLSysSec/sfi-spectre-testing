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
WASM_CFLAGS_UNROLL_LOOPS=$(WASM_CFLAGS) -funroll-loops -mllvm --unroll-runtime -mllvm --unroll-runtime-epilog
WASM_LDFLAGS=-Wl,--export-all
WASM_LIBM=/opt/wasi-sdk/share/wasi-sysroot/lib/wasm32-wasi/libm.a
LUCET_COMMON_FLAGS=--bindings $(LUCET_SRC)/lucet-wasi/bindings.json --guard-size "4GiB" --min-reserved-size "4GiB" --max-reserved-size "4GiB"
LUCET_TRANSITION_FLAGS=--bindings $(REPO_ROOT)/transitions_benchmark/bindings.json $(LUCET_COMMON_FLAGS)
RUN_WASM_SO=$(LUCET_SRC)/target/debug/lucet-wasi --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" --dir /:/
ASLR=--spectre-mitigation-aslr
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

.PRECIOUS: %_spectre_strawman.so
%_spectre_strawman.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation strawman $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_loadlfence.so
%_spectre_loadlfence.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation loadlfence $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_sfi_sbxbreakout.so
%_spectre_sfi_sbxbreakout.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation sfi --spectre-stop-sbx-breakout $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cet_sbxbreakout.so
%_spectre_cet_sbxbreakout.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation cet --spectre-stop-sbx-breakout $< -o $@ && \
	objdump -d $@ > $@.asm

# Sfi - sbx & host poisoning uses PHT_TO_BTB and should use loop unrolled modules
# Cet - sbx poisoning should uses INTERLOCK and use loop unrolled modules
.PRECIOUS: %_spectre_sfi_sbxpoisoning.so
%_spectre_sfi_sbxpoisoning.so: %_unroll.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation sfi --spectre-stop-sbx-poisoning $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cet_sbxpoisoning.so
%_spectre_cet_sbxpoisoning.so: %_unroll.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation cet --spectre-stop-sbx-poisoning $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_sfi_hostpoisoning.so
%_spectre_sfi_hostpoisoning.so: %_unroll.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation sfi --spectre-stop-host-poisoning $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cet_hostpoisoning.so
%_spectre_cet_hostpoisoning.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation cet --spectre-stop-host-poisoning $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_sfi.so
%_spectre_sfi.so: %_unroll.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation sfi $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cet.so
%_spectre_cet.so: %_unroll.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation cet $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_sfiaslr.so
%_spectre_sfiaslr.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation sfiaslr $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_cetaslr.so
%_spectre_cetaslr.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-mitigation cetaslr $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_blade.so
%_spectre_blade.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-pht-mitigation blade --pinned-heap-reg $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_phttobtb.so
%_spectre_phttobtb.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-pht-mitigation phttobtb --pinned-heap-reg $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_spectre_interlock.so
%_spectre_interlock.so: %.wasm $(LUCET)
	$(LUCET) $(LUCET_COMMON_FLAGS) --spectre-pht-mitigation interlock --pinned-heap-reg $< -o $@ && \
	objdump -d $@ > $@.asm

.PRECIOUS: %_all
%_all: $(LUCET) %.clif \
				%.so \
				%_pinned.so \
				%_spectre_strawman.so \
				%_spectre_loadlfence.so \
				%_spectre_sfi_sbxbreakout.so \
				%_spectre_cet_sbxbreakout.so \
				%_spectre_sfi_sbxpoisoning.so \
				%_spectre_cet_sbxpoisoning.so \
				%_spectre_sfi_hostpoisoning.so \
				%_spectre_cet_hostpoisoning.so \
				%_spectre_sfi.so \
				%_spectre_cet.so \
				%_spectre_sfiaslr.so \
				%_spectre_cetaslr.so \
				%_spectre_blade.so \
				%_spectre_phttobtb.so \
				%_spectre_interlock.so
	touch $@

###########################################################################

$(OUT_DIR)/basic_test/test.wasm $(OUT_DIR)/basic_test/test_unroll.wasm: basic_test/test.cpp
	mkdir -p $(OUT_DIR)/basic_test
	$(WASM_CLANG)++ $(WASM_CFLAGS) $(WASM_LDFLAGS) $< -o $(OUT_DIR)/basic_test/test.wasm
	$(WASM_CLANG)++ $(WASM_CFLAGS_UNROLL_LOOPS) $(WASM_LDFLAGS) $< -o $(OUT_DIR)/basic_test/test_unroll.wasm

$(OUT_DIR)/basic_test/test_setup: $(OUT_DIR)/basic_test/test.wasm $(OUT_DIR)/basic_test/test_unroll.wasm $(OUT_DIR)/basic_test/test_all

###########################################################################

$(OUT_DIR)/zlib/Makefile: zlib/configure
	mkdir -p $(OUT_DIR)/zlib
	cd $(OUT_DIR)/zlib && CC=$(WASM_CLANG) AR=$(WASM_AR) RANLIB=$(WASM_RANLIB) CFLAGS='$(WASM_CFLAGS)' LDFLAGS='$(WASM_LDFLAGS)' $(REPO_ROOT)/zlib/configure

$(OUT_DIR)/zlib/libz.a: $(OUT_DIR)/zlib/Makefile
	$(MAKE) -C $(OUT_DIR)/zlib

$(OUT_DIR)/libpng/Makefile: $(OUT_DIR)/zlib/libz.a libpng/CMakeLists.txt
	mkdir -p $(OUT_DIR)/libpng
	cd $(OUT_DIR)/libpng && cmake -DCMAKE_C_COMPILER=$(WASM_CLANG) -DCMAKE_C_FLAGS='$(WASM_CFLAGS) -DPNG_NO_SETJMP=1' -DCMAKE_EXE_LINKER_FLAGS='$(WASM_LDFLAGS)' -DM_LIBRARY=$(WASM_LIBM) -DZLIB_INCLUDE_DIR=$(REPO_ROOT)/zlib -DZLIB_LIBRARY=$(OUT_DIR)/zlib/libz.a -DPNG_SHARED=0 $(REPO_ROOT)/libpng

$(OUT_DIR)/libpng/pngtest.wasm $(OUT_DIR)/libpng/pngtest_unroll.wasm: $(OUT_DIR)/libpng/Makefile
	$(MAKE) -C $(OUT_DIR)/libpng
	# Have to build pngtest manually
	$(WASM_CLANG) $(WASM_CFLAGS) $(WASM_LDFLAGS) libpng/pngtest.c -I $(OUT_DIR)/libpng/ -I zlib/ -o $(OUT_DIR)/libpng/pngtest.wasm -L $(OUT_DIR)/libpng -L $(OUT_DIR)/zlib -lpng -lz
	$(WASM_CLANG) $(WASM_CFLAGS_UNROLL_LOOPS) $(WASM_LDFLAGS) libpng/pngtest.c -I $(OUT_DIR)/libpng/ -I zlib/ -o $(OUT_DIR)/libpng/pngtest_unroll.wasm -L $(OUT_DIR)/libpng -L $(OUT_DIR)/zlib -lpng -lz

$(OUT_DIR)/libpng/pngtest_setup: $(OUT_DIR)/libpng/pngtest.wasm $(OUT_DIR)/libpng/pngtest_unroll.wasm $(OUT_DIR)/libpng/pngtest_all

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
	$(LUCET) $(LUCET_TRANSITION_FLAGS) --spectre-mitigation sfi --spectre-stop-sbx-breakout --spectre-disable-btbflush $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm_btb_oneway.so: $(OUT_DIR)/transitions_benchmark/transitions_wasm.wasm
	$(LUCET) $(LUCET_TRANSITION_FLAGS) --spectre-mitigation sfi --spectre-stop-sbx-breakout $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm_btb_twoway.so: $(OUT_DIR)/transitions_benchmark/transitions_wasm.wasm
	$(LUCET) $(LUCET_TRANSITION_FLAGS) --spectre-mitigation sfi --spectre-stop-sbx-breakout --spectre-stop-sbx-poisoning --spectre-stop-host-poisoning $< -o $@

$(OUT_DIR)/transitions_benchmark/transitions_wasm: $(OUT_DIR)/transitions_benchmark/transitions_wasm_stock.so \
													$(OUT_DIR)/transitions_benchmark/transitions_wasm_lfence.so \
													$(OUT_DIR)/transitions_benchmark/transitions_wasm_btb_oneway.so \
													$(OUT_DIR)/transitions_benchmark/transitions_wasm_btb_twoway.so
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

build: $(OUT_DIR) $(OUT_DIR)/basic_test/test_setup $(OUT_DIR)/libpng_original/png_test $(OUT_DIR)/libpng/pngtest_setup build_cettests

LOOPFLAGS=-funroll-loops -mllvm --unroll-runtime -mllvm --unroll-runtime-epilog
#  -funroll-loops -mllvm -unroll-threshold=1000  -mllvm -unroll-max-percent-threshold-boost=10000
#-mllvm -unroll-threshold=1 -mllvm -unroll-count=8
test_unrolling:
	$(WASM_CLANG)++ $(WASM_CFLAGS) $(LOOPFLAGS) $(WASM_LDFLAGS) basic_test/test.cpp -o $(OUT_DIR)/basic_test/test.wasm
	$(WABT_BINS_FOLDER)/wasm2wat $(OUT_DIR)/basic_test/test.wasm > $(OUT_DIR)/basic_test/test.wat
	$(WABT_BINS_FOLDER)/wasm-decompile $(OUT_DIR)/basic_test/test.wasm > $(OUT_DIR)/basic_test/test.wasm.decompile
	$(WABT_BINS_FOLDER)/wabt/bin/wasm2wat $(REPO_ROOT)/../lucet-spectre/benchmarks/shootout/build/lucet_unroll/module.wasm > $(OUT_DIR)/sightglass/module_unroll.wat
	$(WABT_BINS_FOLDER)/wabt/bin/wasm-decompile $(REPO_ROOT)/../lucet-spectre/benchmarks/shootout/build/lucet_unroll/module.wasm > $(OUT_DIR)/sightglass/module_unroll.wasm.decompile

run_tests:
	@echo "-------------------"
	@echo "Testing"
	@echo "-------------------"
	@echo "Basic Test"
	@echo "-------------------"
	# Stock
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_pinned.so
	# Lfence
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_strawman.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_loadlfence.so
	# Individual
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_sfi_sbxbreakout.so
	$(RUN_WASM_CET_SO) $(OUT_DIR)/basic_test/test_spectre_cet_sbxbreakout.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_sfi_sbxpoisoning.so
	$(RUN_WASM_CET_SO) $(OUT_DIR)/basic_test/test_spectre_cet_sbxpoisoning.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_sfi_hostpoisoning.so
	$(RUN_WASM_CET_SO) $(OUT_DIR)/basic_test/test_spectre_cet_hostpoisoning.so
	# Full
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_sfi.so
	$(RUN_WASM_CET_SO) $(OUT_DIR)/basic_test/test_spectre_cet.so
	# Probablistic
	$(RUN_WASM_SO) $(ASLR) $(OUT_DIR)/basic_test/test_spectre_sfiaslr.so
	$(RUN_WASM_CET_SO) $(ASLR) $(OUT_DIR)/basic_test/test_spectre_cetaslr.so
	# Some PHT protection primtives
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_blade.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_phttobtb.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_interlock.so
	@echo "-------------------"
	@echo "PNG Test"
	@echo "-------------------"
	-rm $(REPO_ROOT)/libpng/pngout.png
	# Native
	cd libpng && $(OUT_DIR)/libpng_original/pngtest && rm -rf $(REPO_ROOT)/libpng/pngout.png
	# Stock
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_pinned.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	# Lfence
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_strawman.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_loadlfence.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	# Individual
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_sfi_sbxbreakout.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_CET_SO) $(OUT_DIR)/libpng/pngtest_spectre_cet_sbxbreakout.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_sfi_sbxpoisoning.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_CET_SO) $(OUT_DIR)/libpng/pngtest_spectre_cet_sbxpoisoning.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_sfi_hostpoisoning.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_CET_SO) $(OUT_DIR)/libpng/pngtest_spectre_cet_hostpoisoning.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	# Full
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_sfi.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_CET_SO) $(OUT_DIR)/libpng/pngtest_spectre_cet.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	# Probablistic
	cd libpng && $(RUN_WASM_SO) $(ASLR) $(OUT_DIR)/libpng/pngtest_spectre_sfiaslr.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_CET_SO) $(ASLR) $(OUT_DIR)/libpng/pngtest_spectre_cetaslr.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	# Some PHT protection primtives
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_blade.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_phttobtb.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
	cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_interlock.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png
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

test_interlock: $(OUT_DIR)/basic_test/test.wasm $(OUT_DIR)/basic_test/test_unroll.wasm $(OUT_DIR)/basic_test/test_spectre_interlock.so $(OUT_DIR)/libpng/pngtest.wasm $(OUT_DIR)/libpng/pngtest_unroll.wasm $(OUT_DIR)/libpng/pngtest_spectre_interlock.so
	$(RUN_WASM_SO) $(OUT_DIR)/basic_test/test_spectre_interlock.so
	# cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_interlock.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png

test_mpk: $(OUT_DIR)/basic_test/test_unroll.wasm $(OUT_DIR)/basic_test/test_spectre_cet.so #  $(OUT_DIR)/libpng/pngtest_unroll.wasm $(OUT_DIR)/libpng/pngtest_spectre_cet.so
	$(RUN_WASM_CET_SO) $(OUT_DIR)/basic_test/test_spectre_cet.so
	# cd libpng && $(RUN_WASM_SO) $(OUT_DIR)/libpng/pngtest_spectre_interlock.so $(REPO_ROOT)/libpng/pngtest.png $(REPO_ROOT)/libpng/pngout.png && rm -rf $(REPO_ROOT)/libpng/pngout.png

run_transitions:
	if [ -x "$(shell command -v cpupower)" ]; then \
		sudo cpupower -c 0 frequency-set --min 2700MHz --max 2700MHz; \
	else \
		sudo cpufreq-set -c 0 --min 2700MHz --max 2700MHz; \
	fi
	cd $(OUT_DIR)/transitions_benchmark && taskset -c 0 ./transitions_app | tee $(REPO_ROOT)/../benchmarks/transitions_$(shell date --iso=seconds).txt

clean:
	rm -rf $(OUT_DIR)
