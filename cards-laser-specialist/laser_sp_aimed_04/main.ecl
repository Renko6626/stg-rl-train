async sub aimed_groups() {
    wait(90);
    var site: int = rand(3);
    loop {
        var rank: int = global(GVAR_RANK);
        var width: fx = 6.0fx;
        var warn: int = 90;
        var active: int = 150;
        if rank == 1 { width = 8.0fx; warn = 75; active = 170; }
        if rank == 2 { width = 10.0fx; warn = 60; active = 190; }
        if rank == 3 { width = 12.0fx; warn = 45; active = 210; }
        if spell_timer() <= warn + active + 62 { return; }

        var choice: int = rand(3);
        var offset: angle = 8deg;
        if choice == 1 { offset = 16deg; }
        if choice == 2 { offset = 24deg; }

        var x: fx = -184.0fx;
        if site == 1 { x = 0.0fx; }
        if site == 2 { x = 184.0fx; }

        var aimed: angle = atan2($player_y - 16.0fx, $player_x - x);
        _ = laser(2, x, 16.0fx, aimed, 640.0fx, width, warn, active, 12);
        _ = laser(2, x, 16.0fx, aimed - offset, 640.0fx, width, warn, active, 12);
        _ = laser(2, x, 16.0fx, aimed + offset, 640.0fx, width, warn, active, 12);

        if site == 0 { site = 1; }
        else if site == 1 { site = 2; }
        else { site = 0; }

        var gap: int = 72 + rand(19);
        wait(gap);
    }
}

async sub aimed_boss() {
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_invuln(65535);
    phase_begin(0, aimed_groups, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000, 1, 0, 1, aimed_boss);
    loop { wait(1); }
}
