// Static warning fence: one 400px vertical line, alternating sides each cycle.
async sub synth_overlay() {
    wait(120);
    var side: int = 0;
    for round in 0..9 {
        var x: fx = -70.0fx;
        if side == 1 { x = 70.0fx; }
        _ = laser(15, x, 80.0fx, 90deg, 400.0fx, 8.0fx, 60, 90, 12);
        side = 1 - side;
        wait(210);
    }
}
