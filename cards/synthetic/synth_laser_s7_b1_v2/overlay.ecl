// Randomized three-segment fan of finite rods; synthetic color 15 identifies this overlay.
async sub synth_overlay() {
    wait(120);
    for round in 0..6 {
        var base: angle = 78deg + (rand(6553) as angle);
        var y: fx = (rand(161) - 80) as fx;
        var speed: fx = 2.0fx;
        if rand(2) == 1 { speed = 3.0fx; }
        var left: int = laser(15, -96.0fx, y, base - 12deg, 0.0fx, 8.0fx, 45, 100, 12);
        var mid: int = laser(15, 0.0fx, y, base, 0.0fx, 8.0fx, 45, 100, 12);
        var right: int = laser(15, 96.0fx, y, base + 12deg, 0.0fx, 8.0fx, 45, 100, 12);
        if lz_alive(left) == 1 { lz_speed(left, speed, 72.0fx); }
        if lz_alive(mid) == 1 { lz_speed(mid, speed, 72.0fx); }
        if lz_alive(right) == 1 { lz_speed(right, speed, 72.0fx); }
        wait(240);
    }
}
