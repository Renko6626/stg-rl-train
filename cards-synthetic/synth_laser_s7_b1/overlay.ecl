// One randomized short rod per cycle; origin, angle and speed use shared engine RNG.
async sub synth_overlay() {
    wait(120);
    for round in 0..7 {
        var x: fx = (rand(201) - 100) as fx;
        var a: angle = 60deg + (rand(10923) as angle);
        var speed: fx = 2.0fx;
        if rand(2) == 1 { speed = 3.0fx; }
        var lz: int = laser(15, x, 80.0fx, a, 0.0fx, 8.0fx, 45, 120, 12);
        if lz_alive(lz) == 1 { lz_speed(lz, speed, 96.0fx); }
        wait(210);
    }
}
