// 原创纯激光错峰带：核心两条竖线留出横向间隔，第三条边界线交替覆盖左右边。
async sub laser_pattern() {
    var rank: int = global(GVAR_RANK);
    var wave_count: int = 13;
    var period: int = 112;
    var warn: int = 90;
    var width: fx = 6.0fx;
    var gap_base: int = 120;

    if rank == 1 {
        wave_count = 14;
        period = 104;
        warn = 75;
        width = 8.0fx;
        gap_base = 104;
    }
    if rank == 2 {
        wave_count = 16;
        period = 90;
        warn = 60;
        width = 10.0fx;
        gap_base = 88;
    }
    if rank == 3 {
        wave_count = 18;
        period = 81;
        warn = 45;
        width = 12.0fx;
        gap_base = 72;
    }

    // phase_begin's pattern starts on the next task frame; this 90-frame lead
    // places the first group after the opening grace period.
    wait(90);
    var wave: int = 0;
    while wave < wave_count {
        // The modular sweep spans the playfield; per-wave jitter makes position
        // seed-dependent while keeping the full group in the horizontal bounds.
        var x0: int = -192 + ((wave * 97 + rand(17)) % 264);
        var separation: int = gap_base + rand(49);
        _ = laser(6, x0 as fx, -96.0fx, 90deg, 640.0fx, width, warn, 210, 12);
        _ = laser(6, (x0 + separation) as fx, -96.0fx, 90deg, 640.0fx, width, warn, 210, 12);
        var edge_x: fx = 192.0fx;
        if wave % 2 == 1 { edge_x = -192.0fx; }
        _ = laser(6, edge_x, -96.0fx, 90deg, 640.0fx, width, warn, 210, 12);
        wave = wave + 1;
        wait(period);
    }
    loop { wait(1); }
}

async sub boss_task() {
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_invuln(65535);
    phase_begin(0, laser_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000, 1, 0, 1, boss_task);
    loop { wait(1); }
}
