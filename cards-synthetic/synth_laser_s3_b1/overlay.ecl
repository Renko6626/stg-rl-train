// Two randomized vertical rails close and reopen a channel; random draws share the base RNG.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var speed: fx = 1.0fx;
    if rank == RANK_NORMAL { speed = 1.25fx; }
    else if rank == RANK_HARD { speed = 1.5fx; }
    else if rank >= RANK_LUNATIC { speed = 2.0fx; }
    for round in 0..7 {
        var center: fx = 1.0fx * (rand(21) - 10);
        var half_gap: fx = 1.0fx * (120 + rand(31));
        var left_x: fx = center - half_gap;
        var right_x: fx = center + half_gap;
        var left: int = laser(15, left_x, 80.0fx, 90deg, 400.0fx, 8.0fx, 45, 120, 12);
        var right: int = laser(15, right_x, 80.0fx, 90deg, 400.0fx, 8.0fx, 45, 120, 12);
        wait(45);
        for close_step in 0..40 {
            wait(1);
            left_x = left_x + speed;
            right_x = right_x - speed;
            if lz_alive(left) == 1 { lz_origin(left, left_x, 80.0fx); }
            if lz_alive(right) == 1 { lz_origin(right, right_x, 80.0fx); }
        }
        for pause_step in 0..10 { wait(1); }
        for open_step in 0..40 {
            wait(1);
            left_x = left_x - speed;
            right_x = right_x + speed;
            if lz_alive(left) == 1 { lz_origin(left, left_x, 80.0fx); }
            if lz_alive(right) == 1 { lz_origin(right, right_x, 80.0fx); }
        }
        wait(75);
    }
}
