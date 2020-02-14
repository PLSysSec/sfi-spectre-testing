.PHONY : build

.DEFAULT_GOAL := build

LUCET_SRC=$(shell realpath ../lucet-spectre/)
LUCET=$(LUCET_SRC)/target/debug/lucetc

define generate_lucet_obj_files =
	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit obj \
		out/$(1).wasm -o out/$(1).o && \
	objdump -d out/$(1).o > out/$(1).asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		out/$(1).wasm -o out/$(1).so && \
	objdump -d out/$(1).so > out/$(1)_so.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit obj \
		--spectre-mitigations-enable \
		out/$(1).wasm -o out/$(1)_spectre.o && \
	objdump -d out/$(1)_spectre.o > out/$(1)_spectre.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitigations-enable \
		out/$(1).wasm -o out/$(1)_spectre.so && \
	objdump -d out/$(1)_spectre.so > out/$(1)_spectre_so.asm
endef

out/test.wasm: basic_test/test.cpp
	mkdir -p out && \
	/opt/wasi-sdk/bin/clang++ --sysroot /opt/wasi-sdk/share/wasi-sysroot/ -Wl,--export-all -O3 $< -o $@

out/.build_ts: out/test.wasm $(LUCET)
	$(call generate_lucet_obj_files,test) && \
	touch out/.build_ts

build: out/.build_ts

test: build
	echo "-------------------" && \
	echo "Testing" && \
	echo "-------------------" && \
	$(LUCET_SRC)/target/debug/lucet-wasi ./out/test.so --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" && \
	$(LUCET_SRC)/target/debug/lucet-wasi ./out/test_spectre.so --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB"; \
	./check_mitigations.py --function_filter "guest_func_spec_*" ./out/test_spectre.asm; \
	./check_mitigations.py --function_filter "guest_func_spec_*" ./out/test_spectre_so.asm; \
	echo "OK."

clean:
	rm -rf out