// A seeded opposite diagonal pair with counter-signed continuous sweeps.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var omega: angle = 96bam;
    if rank >= RANK_LUNATIC { omega = 128bam; }
    for round in 0..5 {
        var x: fx = (rand(145) - 72) as fx;
        var y: fx = (rand(37) + 72) as fx;
        var a: angle = 45deg + (rand(5462) as angle);
        if rand(2) == 1 { a = 105deg + (rand(5462) as angle); }
        var sign: int = 1;
        if rand(2) == 1 { sign = -1; }
        var signed_omega: angle = omega;
        if sign == -1 { signed_omega = 0deg - omega; }
        var lz_a: int = laser(15, x, y, a, 320.0fx, 8.0fx, 45, 120, 12);
        var lz_b: int = laser(15, x, y, a + 180deg, 320.0fx, 8.0fx, 45, 120, 12);
        lz_omega(lz_a, signed_omega);
        lz_omega(lz_b, 0deg - signed_omega);
        wait(177);
        if lz_alive(lz_a) == 1 { lz_cancel(lz_a); }
        if lz_alive(lz_b) == 1 { lz_cancel(lz_b); }
        wait(183);
    }
}
