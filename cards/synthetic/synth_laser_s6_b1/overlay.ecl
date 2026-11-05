// Randomized V-shaped pair; rank scales only the complete判定宽度.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    if rank == RANK_NORMAL { width = 6.5fx; }
    else if rank == RANK_HARD { width = 7.0fx; }
    else if rank >= RANK_LUNATIC { width = 8.0fx; }
    for round in 0..10 {
        var center_x: fx = (rand(161) - 80) as fx;
        var opening: angle = 15deg + (rand(3642) as angle);
        _ = laser(15, center_x, 80.0fx, 90deg - opening, 360.0fx, width, 60, 90, 12);
        _ = laser(15, center_x, 80.0fx, 90deg + opening, 360.0fx, width, 60, 90, 12);
        wait(240);
    }
}
