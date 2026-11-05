// Staggered pair of short diagonal rods.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var speed: fx = 2.0fx;
    if rank == RANK_NORMAL { speed = 2.5fx; }
    else if rank == RANK_HARD { speed = 3.0fx; }
    else if rank >= RANK_LUNATIC { speed = 4.0fx; }
    var x0: fx = (rand(241) - 120) as fx;
    var y0: fx = (rand(61) + 60) as fx;
    var a0: angle = 45deg + (rand(8192) as angle);
    var lz0: int = laser(15, x0, y0, a0, 0.0fx, 8.0fx, 45, 90, 12);
    lz_speed(lz0, speed, 96.0fx);
    wait(20);
    var x1: fx = (rand(241) - 120) as fx;
    var y1: fx = (rand(61) + 60) as fx;
    var a1: angle = 135deg - (rand(8192) as angle);
    var lz1: int = laser(15, x1, y1, a1, 0.0fx, 8.0fx, 45, 90, 12);
    lz_speed(lz1, speed, 96.0fx);
    wait(150);
}
