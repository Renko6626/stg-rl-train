// Opposed flying rods: each pair advances toward the center on opposite axes.
// The seeded lateral jitter is real geometry variation, shared by both rods.
async sub synth_overlay() {
    wait(120);
    var round: int = 0;
    loop {
        var jitter: int = rand(17) - 8;
        var left_x: fx = (-92 + jitter) as fx;
        var right_x: fx = (92 - jitter) as fx;
        var left: int = laser(15, left_x, 78.0fx, 0deg, 0.0fx, 8.0fx, 45, 120, 12);
        var right: int = laser(15, right_x, 114.0fx, 180deg, 0.0fx, 8.0fx, 45, 120, 12);
        lz_speed(left, 2.5fx, 88.0fx);
        lz_speed(right, 2.5fx, 88.0fx);
        round = round + 1;
        if round >= 6 { return; }
        wait(210);
    }
}
