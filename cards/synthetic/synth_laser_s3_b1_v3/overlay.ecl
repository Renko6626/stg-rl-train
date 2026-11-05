// Delayed horizontal sweep: each random-height line waits after its warning phase.
async sub synth_overlay() {
    wait(180);
    for round in 0..5 {
        var y: fx = 150.0fx + 1.0fx * rand(181);
        var start_x: fx = -220.0fx;
        var sweep: int = laser(15, start_x, y, 0deg, 280.0fx, 8.0fx, 60, 90, 12);
        wait(15);
        for delay_step in 0..15 { wait(1); }
        for move_step in 0..88 {
            wait(1);
            start_x = start_x + 5.0fx;
            if lz_alive(sweep) == 1 { lz_origin(sweep, start_x, y); }
        }
        wait(82);
    }
}
