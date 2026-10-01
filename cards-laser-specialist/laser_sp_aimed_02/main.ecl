async sub aimed_pattern() {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var active: int = 150;
    var period: int = 110;
    var groups: int = 13;
    if rank == 1 { width = 8.0fx; warn = 75; active = 168; period = 105; groups = 14; }
    if rank == 2 { width = 10.0fx; warn = 60; active = 186; period = 99; groups = 15; }
    if rank == 3 { width = 12.0fx; warn = 45; active = 204; period = 95; groups = 15; }

    // The phase begins immediately; this wait supplies its 90-frame opening.
    wait(90);

    // Each central fan aims afresh, while every older line stays fixed.
    for wave in 0..groups {
        var center_x: fx = (-32 + rand(65)) as fx;
        var lz_left: int = laser(15, center_x, 64.0fx, 0deg, 576.0fx, width, warn, active, 12);
        lz_aim(lz_left, -22deg);
        wait(1);

        var lz_center: int = laser(15, center_x, 64.0fx, 0deg, 576.0fx, width, warn, active, 12);
        lz_aim(lz_center, 0deg);
        wait(1);

        var lz_right: int = laser(15, center_x, 64.0fx, 0deg, 576.0fx, width, warn, active, 12);
        lz_aim(lz_right, 22deg);
        wait(period - 2);
    }
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, aimed_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(1); }
}
