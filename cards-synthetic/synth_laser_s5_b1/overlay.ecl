// A long horizontal beam descends one pixel per active frame, leaving a left channel.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    if rank == RANK_NORMAL { width = 8.0fx; }
    else if rank == RANK_HARD { width = 10.0fx; }
    else if rank >= RANK_LUNATIC { width = 12.0fx; }
    for round in 0..8 {
        var y: fx = (rand(61) + 220) as fx;
        var lz: int = laser(15, -90.0fx, y, 0deg, 300.0fx, width, 60, 120, 12);
        wait(60);
        for move_step in 0..120 {
            wait(1);
            y = y + 1.0fx;
            if lz_alive(lz) == 1 { lz_origin(lz, -90.0fx, y); }
        }
        wait(120);
    }
}
