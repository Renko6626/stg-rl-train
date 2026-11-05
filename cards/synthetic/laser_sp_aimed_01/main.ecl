async sub aimed_pattern() {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var active: int = 150;
    var period: int = 110;
    var groups: int = 13;
    if rank == 1 { width = 8.0fx; warn = 75; active = 166; period = 105; groups = 14; }
    if rank == 2 { width = 10.0fx; warn = 60; active = 184; period = 99; groups = 15; }
    if rank == 3 { width = 12.0fx; warn = 45; active = 202; period = 95; groups = 15; }

    // The phase begins immediately; this wait supplies its 90-frame opening.
    wait(90);

    // Side pair plus direct center line; each freezes its one-time aim result.
    for wave in 0..groups {
        var left_inner_x: fx = (-80 + rand(33) - 16) as fx;
        var lz_left_inner: int = laser(15, left_inner_x, 64.0fx, 0deg, 560.0fx, width, warn, active, 12);
        lz_aim(lz_left_inner, 18deg);
        wait(1);

        var center_x: fx = (-16 + rand(33)) as fx;
        var lz_center: int = laser(15, center_x, 64.0fx, 0deg, 560.0fx, width, warn, active, 12);
        lz_aim(lz_center, 0deg);
        wait(1);

        var right_inner_x: fx = (80 + rand(33) - 16) as fx;
        var lz_right_inner: int = laser(15, right_inner_x, 64.0fx, 0deg, 560.0fx, width, warn, active, 12);
        lz_aim(lz_right_inner, -18deg);
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
