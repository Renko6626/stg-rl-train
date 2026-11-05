// Short rods move down their fixed axes; alternating fixed origins, no aim or RNG.
async sub synth_overlay() {
    wait(120);
    var side: int = 0;
    for round in 0..6 {
        var x: fx = -80.0fx;
        if side == 1 { x = 80.0fx; }
        var lz: int = laser(15, x, 80.0fx, 90deg, 0.0fx, 8.0fx, 45, 120, 12);
        lz_speed(lz, 2.0fx, 96.0fx);
        side = 1 - side;
        wait(210);
    }
}
