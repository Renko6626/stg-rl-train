// A V pair with alternating opposite spin directions.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var spin: angle = 32bam;
    if rank == RANK_NORMAL { width = 6.5fx; spin = 48bam; }
    else if rank == RANK_HARD { width = 7.0fx; spin = 64bam; }
    else if rank >= RANK_LUNATIC { width = 8.0fx; spin = 80bam; }
    for round in 0..10 {
        var center_x: fx = (rand(161) - 80) as fx;
        var opening: angle = 20deg + (rand(2731) as angle);
        var left_spin: angle = spin;
        var right_spin: angle = 0deg - spin;
        if round % 2 == 1 {
            left_spin = 0deg - spin;
            right_spin = spin;
        }
        var left: int = laser(15, center_x, 80.0fx, 90deg - opening, 360.0fx, width, 60, 90, 12);
        var right: int = laser(15, center_x, 80.0fx, 90deg + opening, 360.0fx, width, 60, 90, 12);
        lz_omega(left, left_spin);
        lz_omega(right, right_spin);
        wait(240);
    }
}
