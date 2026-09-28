// A translated origin traces a small square while the line rotates continuously.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    if rank == RANK_NORMAL { width = 8.0fx; }
    else if rank == RANK_HARD { width = 10.0fx; }
    else if rank >= RANK_LUNATIC { width = 12.0fx; }
    for round in 0..7 {
        var x: fx = ((rand(161) - 80) as fx);
        var y: fx = ((rand(81) + 80) as fx);
        var heading: angle = (rand(65536) as angle);
        var lz: int = laser(15, x, y, heading, 360.0fx, width, 60, 90, 12);
        lz_omega(lz, 96bam);
        wait(30);
        if lz_alive(lz) == 1 { lz_origin(lz, x + 32.0fx, y); }
        wait(30);
        if lz_alive(lz) == 1 { lz_origin(lz, x + 32.0fx, y + 24.0fx); }
        wait(30);
        if lz_alive(lz) == 1 { lz_origin(lz, x, y + 24.0fx); }
        wait(180);
    }
}
