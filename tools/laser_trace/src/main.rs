use std::{env, fs, path::Path, process::ExitCode};

use stg_core::{ecl::image::EclImage, input::InputFrame, step::World, tables::TABLES_V0};

fn compile(card: &Path) -> Result<EclImage, String> {
    let source = card.join("main.ecl");
    let text =
        fs::read_to_string(&source).map_err(|e| format!("read {}: {e}", source.display()))?;
    stg_ecl_compiler::lang::compile_units(&[("main.ecl".to_string(), text)]).map_err(|errors| {
        errors
            .iter()
            .map(|(_, error)| error.render("main.ecl"))
            .collect::<Vec<_>>()
            .join("\n")
    })
}

fn arg_value(args: &[String], name: &str) -> Result<String, String> {
    let index = args
        .iter()
        .position(|arg| arg == name)
        .ok_or_else(|| format!("missing {name}"))?;
    args.get(index + 1)
        .cloned()
        .ok_or_else(|| format!("missing value for {name}"))
}

fn number<T: std::str::FromStr>(args: &[String], name: &str) -> Result<T, String> {
    arg_value(args, name)?
        .parse()
        .map_err(|_| format!("invalid {name}"))
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("laser-trace: {error}");
            ExitCode::FAILURE
        }
    }
}

fn fx(raw: i32) -> f64 {
    f64::from(raw) / 65536.0
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() == 1 || args.iter().any(|arg| arg == "--help") {
        println!("laser-trace CARD --rank RANK --seed SEED --frames FRAMES");
        return Ok(());
    }
    let card = Path::new(&args[1]);
    let rank: i32 = number(&args, "--rank")?;
    let seed: u64 = number(&args, "--seed")?;
    let frames: u32 = number(&args, "--frames")?;
    let image = compile(card)?;
    let mut world =
        World::new_game(seed, rank, &image).map_err(|error| format!("new_game: {error:?}"))?;
    let mut previous = std::collections::BTreeSet::new();

    for _ in 0..frames {
        let input = InputFrame::empty(world.frame());
        stg_core::step(&mut world, &TABLES_V0, &image, &input);
        let view = world.view();
        let lasers = view.lasers();
        let current: Vec<(usize, u16)> = lasers
            .iter_alive()
            .map(|index| (index, lasers.generation_of(index)))
            .collect();
        let frame = world.frame();
        let id_json = |(index, generation): (usize, u16)| {
            format!("{{\"index\":{index},\"generation\":{generation}}}")
        };
        let spawned = current
            .iter()
            .copied()
            .filter(|id| !previous.contains(id))
            .map(id_json)
            .collect::<Vec<_>>();
        let expired = previous
            .iter()
            .copied()
            .filter(|id| !current.contains(id))
            .map(id_json)
            .collect::<Vec<_>>();
        let mut rows = Vec::with_capacity(current.len());
        for &(index, generation) in &current {
            rows.push(format!(
                "{{\"id\":{{\"index\":{index},\"generation\":{generation}}},\"state\":{},\"width\":{},\"x\":{},\"y\":{},\"angle\":{},\"start\":{},\"end\":{},\"speed\":{},\"omega\":{}}}",
                lasers.state()[index],
                fx(lasers.width()[index].raw()),
                fx(lasers.ox()[index].raw()),
                fx(lasers.oy()[index].raw()),
                f64::from(lasers.angle()[index].raw()) * (360.0 / 65536.0),
                fx(lasers.start()[index].raw()),
                fx(lasers.end()[index].raw()),
                fx(lasers.speed()[index].raw()),
                lasers.omega()[index],
            ));
        }
        let diag = view.diag();
        let pool_full: u32 = diag.pool_full.iter().sum();
        let bullets = view.bullets().iter_alive().count();
        let enemies = view.enemies().iter_alive().count();
        let player_alive = view
            .players()
            .first()
            .is_some_and(|player| player.life_state == stg_core::player::LIFE_ALIVE);
        let segment_events = world
            .frame_events()
            .iter()
            .filter(|event| {
                [
                    stg_core::events::EVT_PHASE_ENDED,
                    stg_core::events::EVT_SPELL_CAPTURED,
                    stg_core::events::EVT_SPELL_FAILED,
                    stg_core::events::EVT_STAGE_CLEARED,
                ]
                .contains(&event.kind)
            })
            .map(|event| format!("{{\"kind\":{}}}", event.kind))
            .collect::<Vec<_>>();
        println!(
            "{{\"rank\":{rank},\"seed\":{seed},\"frame\":{frame},\"lasers\":[{}],\"spawned\":[{}],\"expired\":[{}],\"bullet_count\":{bullets},\"enemy_count\":{enemies},\"player_alive\":{player_alive},\"segment_events\":[{}],\"diagnostics\":{{\"task_faults\":{},\"contract_viol\":{},\"pool_full\":{pool_full},\"hits_ovf\":{},\"events_ovf\":{},\"reqs_dropped\":{}}}}}",
            rows.join(","),
            spawned.join(","),
            expired.join(","),
            segment_events.join(","),
            diag.task_faults,
            diag.contract_viol,
            diag.hits_overflow,
            diag.events_overflow,
            diag.reqs_dropped,
        );
        previous.clear();
        previous.extend(current);
    }
    Ok(())
}
