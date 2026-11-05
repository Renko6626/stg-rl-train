// Two randomized vertical gates start thirty frames apart each round.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    if rank == RANK_NORMAL { width = 8.0fx; }
    else if rank == RANK_HARD { width = 10.0fx; }
    else if rank >= RANK_LUNATIC { width = 12.0fx; }
    for round in 0..9 {
        var x1: fx = (rand(321) - 160) as fx;
        var lz1: int = laser(15, x1, -20.0fx, 90deg, 500.0fx, width, 45, 90, 12);
        wait(30);
        var x2: fx = (rand(321) - 160) as fx;
        var lz2: int = laser(15, x2, -20.0fx, 90deg, 500.0fx, width, 45, 90, 12);
        wait(270);
        if lz_alive(lz1) == 1 { lz_cancel(lz1); }
        if lz_alive(lz2) == 1 { lz_cancel(lz2); }
    }
}
