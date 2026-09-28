// Randomly spaced moving dual-line channel. rand() shares the base stream.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var speed: fx = 1.0fx;
    if rank == RANK_NORMAL { speed = 1.25fx; }
    else if rank == RANK_HARD { speed = 1.5fx; }
    else if rank >= RANK_LUNATIC { speed = 2.0fx; }
    for round in 0..7 {
        var center: fx = 1.0fx * (rand(37) - 18);
        var half_gap: fx = 1.0fx * (96 + rand(40));
        var left_x: fx = center - half_gap;
        var right_x: fx = center + half_gap;
        var left: int = laser(15, left_x, 72.0fx, 90deg, 416.0fx, 8.0fx, 45, 120, 12);
        var right: int = laser(15, right_x, 72.0fx, 90deg, 416.0fx, 8.0fx, 45, 120, 12);
        wait(45);
        for close_step in 0..32 {
            wait(1);
            left_x = left_x + speed;
            right_x = right_x - speed;
            if lz_alive(left) == 1 { lz_origin(left, left_x, 72.0fx); }
            if lz_alive(right) == 1 { lz_origin(right, right_x, 72.0fx); }
        }
        for pause_step in 0..8 { wait(1); }
        for open_step in 0..32 {
            wait(1);
            left_x = left_x - speed;
            right_x = right_x + speed;
            if lz_alive(left) == 1 { lz_origin(left, left_x, 72.0fx); }
            if lz_alive(right) == 1 { lz_origin(right, right_x, 72.0fx); }
        }
        wait(83);
    }
}
