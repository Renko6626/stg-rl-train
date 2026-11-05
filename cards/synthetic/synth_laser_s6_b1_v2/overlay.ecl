// Two randomized diagonal rails crossing in the playfield.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    if rank == RANK_NORMAL { width = 6.5fx; }
    else if rank == RANK_HARD { width = 7.0fx; }
    else if rank >= RANK_LUNATIC { width = 8.0fx; }
    for round in 0..10 {
        var center: fx = (rand(81) - 40) as fx;
        var skew: angle = (rand(3642) as angle) - 10deg;
        _ = laser(15, center - 100.0fx, 80.0fx, 45deg + skew, 360.0fx, width, 60, 90, 12);
        _ = laser(15, center + 100.0fx, 80.0fx, 135deg - skew, 360.0fx, width, 60, 90, 12);
        wait(240);
    }
}
