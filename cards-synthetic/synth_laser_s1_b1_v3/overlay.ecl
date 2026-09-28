// Alternating diagonal warning line: direction changes every round.
async sub synth_overlay() {
    wait(120);
    var heading: angle = 45deg;
    for round in 0..9 {
        var slot: int = rand(5);
        var x: fx = -120.0fx;
        if slot == 1 { x = -60.0fx; }
        else if slot == 2 { x = 0.0fx; }
        else if slot == 3 { x = 60.0fx; }
        else if slot == 4 { x = 120.0fx; }
        _ = laser(15, x, 60.0fx, heading, 420.0fx, 8.0fx, 60, 90, 12);
        if heading == 45deg {
            heading = 135deg;
        } else {
            heading = 45deg;
        }
        wait(210);
    }
}
