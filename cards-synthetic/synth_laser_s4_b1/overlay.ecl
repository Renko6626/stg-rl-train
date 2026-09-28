// A single randomized origin aims at the player at birth; the lock stays fixed.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    if rank == RANK_NORMAL { width = 8.0fx; }
    else if rank == RANK_HARD { width = 10.0fx; }
    else if rank >= RANK_LUNATIC { width = 12.0fx; }
    for round in 0..9 {
        var x: fx = (rand(201) - 100) as fx;
        var y: fx = (rand(101) + 70) as fx;
        var lz: int = laser(15, x, y, 0deg, 400.0fx, width, 60, 45, 12);
        lz_aim(lz, 0deg);
        wait(240);
    }
}
