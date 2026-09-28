// Rotating short segments: each segment gets a seeded angle and rotates in place.
async sub synth_overlay() {
    wait(120);
    var round: int = 0;
    loop {
        var jitter: int = rand(25) - 12;
        var rot: angle = ((round * 16384 + jitter * 64) as angle);
        var lz: int = laser(15, 0.0fx, 96.0fx, rot, 112.0fx, 8.0fx, 45, 120, 12);
        lz_omega(lz, 96bam);
        round = round + 1;
        if round >= 6 { return; }
        wait(210);
    }
}
