// Random horizontal two-line vertical warning gate.
async sub synth_overlay() {
    wait(120);
    for round in 0..9 {
        var slot: int = rand(5);
        var x: fx = -120.0fx;
        if slot == 1 { x = -60.0fx; }
        else if slot == 2 { x = 0.0fx; }
        else if slot == 3 { x = 60.0fx; }
        else if slot == 4 { x = 120.0fx; }
        _ = laser(15, x, 40.0fx, 90deg, 360.0fx, 10.0fx, 60, 90, 12);
        _ = laser(15, x + 72.0fx, 40.0fx, 90deg, 360.0fx, 10.0fx, 60, 90, 12);
        wait(210);
    }
}
