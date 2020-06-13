#![feature(llvm_asm)]

use lucet_runtime::{self, DlModule, Limits, MmapRegion, Module, Region, RunResult};
use lucet_runtime_internals::{
    lucet_hostcall
};
use lucet_runtime_internals::vmctx::{Vmctx};
use lucet_wasi::{self, WasiCtxBuilder};
use std::sync::Arc;
use std::time::Instant;
use std::io::stdout;
use std::io::Write;

#[lucet_hostcall]
#[no_mangle]
pub extern "C" fn hostcall_get_value(_vmctx: &mut Vmctx) -> u32 {
    return 42;
}

fn start_tests_on_lib(test: &str, lib: &str, iterations: u64) {
    let module = DlModule::load(lib).expect("module can be loaded");

    let min_globals_size = module.initial_globals_size();
    let globals_size = ((min_globals_size + 4096 - 1) / 4096) * 4096;

    let region = MmapRegion::create(
        1,
        &Limits {
            heap_memory_size: 4 * 1024 * 1024 * 2024,
            heap_address_space_size: 8 * 1024 * 1024 * 2024,
            stack_size: 128 * 1024,
            globals_size,
            signal_stack_size: 128 * 1024,
        },
    )
    .expect("region can be created");

    let args: Vec<&str> = Vec::new();
    let mut ctx = WasiCtxBuilder::new();
    ctx.args(args.iter());
    ctx.inherit_stdio();
    ctx.inherit_env();

    let mut inst = region
        .new_instance_builder(module as Arc<dyn Module>)
        .with_embed_ctx(ctx.build().expect("WASI ctx can be created"))
        .build()
        .expect("instance can be created");

    inst.run_start().expect("Wasm start function runs");

    println!("============\n");
    println!("Testing: {}\n", test);

    for round in 0..2 {
        if round == 0 {
            println!("------------");
            println!("Warmup round");
            println!("------------");
        } else {
            println!("------------");
            println!("Results");
            println!("------------");
        }

        let start = Instant::now();
        for _i in 0..iterations {
            match inst.run("test_func_invocation", &[]) {
                // normal termination implies 0 exit code
                Ok(RunResult::Returned(_)) => 0,
                _ => panic!("Error running function in : {}", lib),
            };
        }
        let end = Instant::now();
        let avg: f64 = ((end - start).as_nanos() as f64) / (iterations as f64);
        println!("Invoke took {} nanoseconds", avg);
        let _ = stdout().flush();

        match inst.run("host_call_invocation", &[]) {
            // normal termination implies 0 exit code
            Ok(RunResult::Returned(_)) => 0,
            _ => panic!("Error running function in : {}", lib),
        };
    }
}

#[no_mangle]
pub extern "C" fn beginTest(iterations: u64) {
    lucet_runtime::lucet_internal_ensure_linked();
    lucet_wasi::export_wasi_funcs();

    start_tests_on_lib("Stock:", "./transitions_wasm_stock.so", iterations);
    start_tests_on_lib("Lfence:", "./transitions_wasm_lfence.so", iterations);
    start_tests_on_lib("BTBOneWay:", "./transitions_wasm_btb_oneway.so", iterations);
    start_tests_on_lib("BTBTwoWay:", "./transitions_wasm_btb_twoway.so", iterations);
    println!("Successful");
}
