// One randomized diagonal beam per round; random state is shared with the base script.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var spin: angle = 80bam;
    if rank >= RANK_LUNATIC { spin = 120bam; }
    for round in 0..6 {
        var x: fx = (rand(201) - 100) as fx;
        var a: angle = 45deg + (rand(8192) as angle);
        if rand(2) == 1 { a = 135deg - (rand(8192) as angle); }
        var omega: angle = spin;
        if rand(2) == 1 { omega = 0deg - spin; }
        var lz: int = laser(15, x, 80.0fx, a, 360.0fx, 8.0fx, 60, 120, 12);
        lz_omega(lz, omega);
        wait(300);
    }
}
