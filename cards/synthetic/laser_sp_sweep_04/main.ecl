async sub left_sweep() {
    var rank: int = global(GVAR_RANK);
    var warn: int = 90;
    var omega: int = 36;
    if rank >= 1 { warn = 75; omega = 48; }
    if rank >= 2 { warn = 60; omega = 60; }
    if rank >= 3 { warn = 45; omega = 72; }

    var x: fx = (-174 + rand(25)) as fx;
    var y: fx = (100 + rand(251)) as fx;
    var base: angle = 34deg;
    if rank >= 1 { base = 42deg; }
    if rank >= 2 { base = 50deg; }
    if rank >= 3 { base = 58deg; }
    var theta: angle = base + (rand(5461) - 2730) as angle;
    var lz: int = laser(2, x, y, theta, 390.0fx, (6 + rank * 2) as fx, warn, 180, 12);
    wait(warn);
    lz_omega(lz, (0 - omega) as angle);
    wait(180);
}

async sub right_sweep() {
    var rank: int = global(GVAR_RANK);
    var warn: int = 90;
    var omega: int = 36;
    if rank >= 1 { warn = 75; omega = 48; }
    if rank >= 2 { warn = 60; omega = 60; }
    if rank >= 3 { warn = 45; omega = 72; }

    var x: fx = (150 + rand(25)) as fx;
    var y: fx = (150 + rand(151)) as fx;
    var theta: angle = 165deg + (rand(5461) - 2730) as angle;
    var lz: int = laser(5, x, y, theta, 390.0fx, (6 + rank * 2) as fx, warn, 180, 12);
    wait(warn);
    lz_omega(lz, omega as angle);
    wait(180);
}

async sub sweep_pattern() {
    var rank: int = global(GVAR_RANK);
    var repeat_wait: int = 103;
    if rank >= 1 { repeat_wait = 104; }
    if rank >= 2 { repeat_wait = 105; }
    if rank >= 3 { repeat_wait = 107; }
    wait(88);
    for round in 0..10 {
        spawn left_sweep();
        wait(44);
        spawn right_sweep();
        wait(repeat_wait);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, sweep_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000, 0, 0, 0, boss_main);
    loop { wait(1); }
}
