//! Throwaway image runner. All simulation and state observation use public stg-core APIs.
use std::io::{self, BufWriter, Write};
use std::path::PathBuf;

use serde::Deserialize;
use serde_json::json;
use stg_core::ecl::image::{EclImage, EclValueType, EntryInit, ImageParts, SubInit, SubKind};
use stg_core::input::InputFrame;
use stg_core::step::{World, step};
use stg_core::tables::TABLES_V0;

#[derive(Deserialize)]
#[serde(rename_all = "lowercase")]
enum Kind {
    Root,
    Async,
    Call,
}

#[derive(Deserialize)]
#[serde(rename_all = "lowercase")]
enum Param {
    Int,
    Fx,
    Angle,
}

#[derive(Deserialize)]
struct Sub {
    entry: u32,
    kind: Kind,
    params: Vec<Param>,
}

#[derive(Deserialize)]
struct Entry {
    name: String,
    sub: u16,
}

#[derive(Deserialize)]
struct ImageInput {
    /// Source mode compiles this file; no prebuilt bytecode is used.
    ecl: Option<PathBuf>,
    #[serde(default)]
    code: Vec<u32>,
    #[serde(default)]
    subs: Vec<Sub>,
    #[serde(default)]
    entries: Vec<Entry>,
    #[serde(default)]
    root: u16,
    #[serde(default = "default_frames")]
    frames: u32,
    #[serde(default = "default_seed")]
    seed: u64,
    engine_ver: Option<u32>,
    #[serde(default)]
    watch_locals: Vec<u8>,
    #[serde(default)]
    watch_globals: Vec<u16>,
}

fn default_frames() -> u32 {
    160
}

fn default_seed() -> u64 {
    1
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let path = PathBuf::from(
        std::env::args_os()
            .nth(1)
            .ok_or("usage: th18-prototype-runner IMAGE_OR_SOURCE.json")?,
    );
    let input: ImageInput = serde_json::from_reader(std::fs::File::open(&path)?)?;
    if input.engine_ver.is_some_and(|v| v != stg_core::ENGINE_VER) {
        return Err(format!(
            "engine_ver mismatch: image {:?}, runner {}",
            input.engine_ver,
            stg_core::ENGINE_VER
        )
        .into());
    }
    if !input.watch_locals.is_empty() {
        return Err("watch_locals is unsupported by the public TaskPool API; export values via SYS_SET_VAR to slots 16..1023 and use watch_globals".into());
    }
    if input
        .watch_globals
        .iter()
        .any(|&i| usize::from(i) >= stg_core::world::GLOBALS_CAP)
    {
        return Err("watch_globals slot must be in 0..1023".into());
    }
    let image = if let Some(source) = &input.ecl {
        if !input.code.is_empty() || !input.subs.is_empty() || !input.entries.is_empty() {
            return Err("source mode cannot also contain bytecode/sub/entry tables".into());
        }
        let source = path
            .parent()
            .unwrap_or_else(|| std::path::Path::new("."))
            .join(source);
        let text = std::fs::read_to_string(&source)?;
        let filename = source.to_string_lossy();
        stg_ecl_compiler::lang::compile(&text, &filename).map_err(|errors| {
            errors
                .iter()
                .map(|e| e.render(&filename))
                .collect::<Vec<_>>()
                .join("\n")
        })?
    } else {
        EclImage::try_from_parts(ImageParts {
            code: input.code,
            subs: input
                .subs
                .into_iter()
                .map(|s| {
                    SubInit::new(
                        s.entry,
                        match s.kind {
                            Kind::Root => SubKind::Root,
                            Kind::Async => SubKind::Async,
                            Kind::Call => SubKind::CallOnly,
                        },
                        s.params
                            .into_iter()
                            .map(|p| match p {
                                Param::Int => EclValueType::Int,
                                Param::Fx => EclValueType::Fx,
                                Param::Angle => EclValueType::Angle,
                            })
                            .collect(),
                    )
                })
                .collect(),
            entries: input
                .entries
                .into_iter()
                .map(|e| EntryInit::new(e.name, e.sub))
                .collect(),
            root: Some(input.root),
            marks: Vec::new(),
            // This bytecode was lowered against these built-in tables.
            content_hash: TABLES_V0.content_hash,
        })
        .map_err(|e| format!("invalid image: {e:?}"))?
    };
    let mut world =
        World::new_game(input.seed, 0, &image).map_err(|e| format!("cannot start image: {e:?}"))?;
    let mut out = BufWriter::new(io::stdout().lock());
    for _ in 0..input.frames {
        let vm_frame = world.body.frame();
        step(&mut world, &TABLES_V0, &image, &InputFrame::empty(vm_frame));
        let frame = world.body.frame();
        let view = world.body.view();
        let pool = view.bullets();
        let bullets: Vec<_> = pool
            .iter_alive()
            .map(|i| {
                let (speed, angle) = pool.polar(i);
                json!({
                    "index": i, "generation": pool.generation_of(i),
                    "x_raw": pool.x()[i].raw(), "y_raw": pool.y()[i].raw(),
                    "vx_raw": pool.vx()[i].raw(), "vy_raw": pool.vy()[i].raw(),
                    "angle": angle.raw(), "speed_raw": speed.raw(),
                    "sprite": pool.sprite()[i], "radius_raw": pool.radius()[i].raw(),
                    "born_frame": pool.born_frame()[i],
                    "age": frame.wrapping_sub(pool.born_frame()[i]),
                    "delay": pool.delay()[i], "life": pool.life()[i],
                    "flags": pool.flags()[i], "transform_head": pool.transform_head()[i],
                    "xform_wait": pool.xform_wait()[i], "xform_next": pool.xform_next()[i]
                })
            })
            .collect();
        let globals: Vec<_> = input
            .watch_globals
            .iter()
            .map(|&slot| json!({"slot": slot, "value": view.globals()[usize::from(slot)]}))
            .collect();
        let fault_events: Vec<_> = world
            .frame_events()
            .iter()
            .filter(|e| e.kind == stg_core::events::EVT_TASK_FAULT)
            .map(|e| json!({"task": e.a_index, "code": e.data[0], "sub": e.data[1]}))
            .collect();
        let diag = view.diag();
        let player = &view.players()[0];
        serde_json::to_writer(
            &mut out,
            &json!({
                "engine_ver": stg_core::ENGINE_VER,
                "frame": frame, "vm_frame": vm_frame,
                "count": bullets.len(), "bullets": bullets,
                "tasks": world.tasks().iter_alive().count(), "globals": globals,
                "faults": diag.task_faults, "fault_events": fault_events,
                "contract_viol": diag.contract_viol, "pool_full": diag.pool_full,
                "checksum": format!("{:016x}", world.checksum()),
                "player": {"x_raw": player.x.raw(), "y_raw": player.y.raw(), "life_state": player.life_state}
            }),
        )?;
        writeln!(out)?;
        if diag.task_faults != 0
            || diag.contract_viol != 0
            || diag.pool_full.iter().any(|&n| n != 0)
        {
            out.flush()?;
            return Err(
                format!("VM diagnostics failed after frame {frame}; see final JSONL row").into(),
            );
        }
    }
    out.flush()?;
    Ok(())
}

fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("th18-prototype-runner: {e}");
            std::process::ExitCode::FAILURE
        }
    }
}
