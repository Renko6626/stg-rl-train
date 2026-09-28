// A translated diagonal short line.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var step: fx = 0.75fx;
    if rank == RANK_NORMAL { step = 0.9fx; }
    else if rank == RANK_HARD { step = 1.05fx; }
    else if rank >= RANK_LUNATIC { step = 1.2fx; }
    var x0: fx = (rand(241) - 120) as fx;
    var y0: fx = (rand(61) + 60) as fx;
    var a0: angle = 35deg + (rand(20481) as angle);
    var lz: int = laser(15, x0, y0, a0, 120.0fx, 8.0fx, 45, 100, 12);
    for k in 0..100 {
        lz_origin(lz, x0 + (k as fx) * step, y0 + (k as fx) * (step / 3));
        wait(1);
    }
    wait(30);
}
