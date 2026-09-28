// Two delayed finite horizontal segments form a moving gate; synthetic color 15 identifies it.
async sub synth_overlay() {
    wait(120);
    for round in 0..6 {
        var y: fx = (rand(241) - 120) as fx;
        var speed: fx = 3.0fx;
        if rand(2) == 1 { speed = 4.0fx; }
        var right: int = laser(15, -220.0fx, y, 0deg, 0.0fx, 10.0fx, 50, 105, 12);
        var left: int = laser(15, 220.0fx, y, 180deg, 0.0fx, 10.0fx, 50, 105, 12);
        if lz_alive(right) == 1 { lz_speed(right, speed, 96.0fx); }
        if lz_alive(left) == 1 { lz_speed(left, speed, 96.0fx); }
        wait(260);
    }
}
