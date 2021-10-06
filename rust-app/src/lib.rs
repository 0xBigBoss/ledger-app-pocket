#![no_std]
#![allow(incomplete_features)]
#![feature(const_generics)]
#![feature(str_internals)]
#![cfg_attr(all(target_os = "nanos", test), no_main)]
#![cfg_attr(target_os = "nanos", feature(custom_test_frameworks))]
#![reexport_test_harness_main = "test_main"]
#![cfg_attr(target_os = "nanos", test_runner(nanos_sdk::sdk_test_runner))]

pub use ledger_log::*;

#[cfg(all(target_os = "nanos", test))]
#[no_mangle]
extern "C" fn sample_main() {
    use nanos_sdk::exit_app;
    test_main();
    exit_app(0);
}

pub mod interface;
pub mod utils;

#[cfg(all(target_os = "nanos"))]
pub mod crypto_helpers;
#[cfg(all(target_os = "nanos"))]
pub mod implementation;

#[cfg(all(target_os = "nanos", test))]
use core::panic::PanicInfo;
/// In case of runtime problems, return an internal error and exit the app
#[cfg(all(target_os = "nanos", test))]
#[inline]
#[cfg_attr(all(target_os = "nanos", test), panic_handler)]
pub fn exiting_panic(info: &PanicInfo) -> ! {
    //let mut comm = io::Comm::new();
    //comm.reply(io::StatusWords::Panic);
    error!("Panicking: {:?}\n", info);
    nanos_sdk::exit_app(1)
}

// Custom type used to implement tests
//#[cfg(all(target_os = "nanos", test))]
//use nanos_sdk::TestType;
