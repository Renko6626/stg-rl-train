// A short diagonal segment translating along a second seeded diagonal.
async sub synth_overlay() {
    wait(120);
    var a: angle = rand(65536) as angle;
    var drift: angle = rand(65536) as angle;
    var sx: fx = ((rand(97) - 48) as fx);
    var sy: fx = (64 + rand(33)) as fx;
    var lz: int = laser(15, sx, sy, a, 144.0fx, 8.0fx, 45, 96, 12);
    for k in 0..96 {
        wait(1);
        if lz_alive(lz) == 1 {
            var t: fx = k as fx;
            lz_origin(lz, sx + t * cos(drift), sy + t * sin(drift));
        }
    }
}
