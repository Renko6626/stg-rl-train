// 原创纯激光错峰带：核心两条横线留出竖向间隔，第三条边界线交替覆盖顶/底边。
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
    // A randomized five-slot phase offsets a coprime full-cycle sweep.
    // Draw separation first so both core-line centers remain in [0, 448].
    var phase: int = rand(5);
    wait(90);
    var wave: int = 0;
    while wave < wave_count {
        var separation: int = gap_base + rand(49);
        var slot: int = (wave * 5 + phase) % wave_count;
        var max_y0: int = 448 - separation;
        var base_y0: int = (max_y0 * slot) / (wave_count - 1);
        var y0: int = base_y0 + rand(33) - 16;
        if y0 < 0 { y0 = 0; }
        if y0 > max_y0 { y0 = max_y0; }
        _ = laser(6, -320.0fx, y0 as fx, 0deg, 640.0fx, width, warn, 210, 12);
        _ = laser(6, -320.0fx, (y0 + separation) as fx, 0deg, 640.0fx, width, warn, 210, 12);
        var edge_y: fx = 448.0fx;
        if wave % 2 == 1 { edge_y = 0.0fx; }
        _ = laser(6, -320.0fx, edge_y, 0deg, 640.0fx, width, warn, 210, 12);
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
