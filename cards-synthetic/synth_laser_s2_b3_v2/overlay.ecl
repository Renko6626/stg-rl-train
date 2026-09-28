// One seeded diagonal line whose origin translates and reflects during its lifetime.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var step: fx = 0.75fx;
    if rank >= RANK_LUNATIC { step = 1.0fx; }
    for round in 0..6 {
        var x: fx = (rand(193) - 96) as fx;
        var y: fx = (rand(49) + 64) as fx;
        var a: angle = 30deg + (rand(5462) as angle);
        if rand(2) == 1 { a = 120deg + (rand(5462) as angle); }
        var dir: int = 1;
        if rand(2) == 1 { dir = -1; }
        var lz: int = laser(15, x, y, a, 360.0fx, 8.0fx, 60, 120, 12);
        for tick in 0..192 {
            if lz_alive(lz) == 1 {
                x = x + step * dir;
                if x > 120.0fx { x = 120.0fx; dir = -1; }
                if x < -120.0fx { x = -120.0fx; dir = 1; }
                lz_origin(lz, x, y);
            }
            wait(1);
        }
        wait(108);
    }
}
