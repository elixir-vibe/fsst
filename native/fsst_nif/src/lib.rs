use fsst::Compressor;
use rustler::types::binary::{Binary, OwnedBinary};
use rustler::{Env, NifResult, Resource, ResourceArc};
use std::io::Write;

struct FsstTable {
    compressor: Compressor,
}

#[rustler::resource_impl]
impl Resource for FsstTable {}

#[rustler::nif]
fn train(samples: Vec<Binary>) -> NifResult<ResourceArc<FsstTable>> {
    if samples.is_empty() {
        return Err(rustler::Error::BadArg);
    }

    let values: Vec<&[u8]> = samples.iter().map(|sample| sample.as_slice()).collect();
    let compressor = Compressor::train(&values);

    Ok(ResourceArc::new(FsstTable { compressor }))
}

#[rustler::nif]
fn compress<'a>(env: Env<'a>, table: ResourceArc<FsstTable>, input: Binary) -> NifResult<Binary<'a>> {
    let compressed = table.compressor.compress(input.as_slice());
    Ok(binary_from_vec(env, compressed))
}

#[rustler::nif]
fn decompress<'a>(env: Env<'a>, table: ResourceArc<FsstTable>, input: Binary) -> NifResult<Binary<'a>> {
    let decompressed = table.compressor.decompressor().decompress(input.as_slice());
    Ok(binary_from_vec(env, decompressed))
}

fn binary_from_vec<'a>(env: Env<'a>, bytes: Vec<u8>) -> Binary<'a> {
    let mut binary = OwnedBinary::new(bytes.len()).unwrap();
    binary.as_mut_slice().write_all(&bytes).unwrap();
    binary.release(env)
}

rustler::init!("Elixir.FSST.Native");
