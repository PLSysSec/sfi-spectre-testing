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
		out/$(1).wasm -o out/$(1).so

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--emit obj \
		--spectre-mitagations-enable \
		out/$(1).wasm -o out/$(1)_spectre.o && \
	objdump -d out/$(1)_spectre.o > out/$(1)_spectre.asm

	$(LUCET) \
		--bindings $(LUCET_SRC)/lucet-wasi/bindings.json \
		--guard-size "4GiB" \
		--min-reserved-size "4GiB" \
		--max-reserved-size "4GiB" \
		--spectre-mitagations-enable \
		out/$(1).wasm -o out/$(1)_spectre.so
endef

out/test.wasm: basic_test/test.cpp
	mkdir -p out && \
	/opt/wasi-sdk/bin/clang++ --sysroot /opt/wasi-sdk/share/wasi-sysroot/ -Wl,--export-all -O3 $< -o $@

out/test.so: out/test.wasm $(LUCET)
	$(call generate_lucet_obj_files,test)

build: out/test.so

test: build
	echo "-------------------" && \
	echo "Testing" && \
	echo "-------------------" && \
	$(LUCET_SRC)/target/debug/lucet-wasi ./out/test.so --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" && \
	$(LUCET_SRC)/target/debug/lucet-wasi ./out/test_spectre.so --heap-address-space "8GiB" --max-heap-size "4GiB" --stack-size "8MiB" && \
	echo "OK."

clean:
	rm -rf out