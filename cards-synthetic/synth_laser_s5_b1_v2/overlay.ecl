// Random-start horizontal beams sweep right during their active window.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    if rank == RANK_NORMAL { width = 8.0fx; }
    else if rank == RANK_HARD { width = 10.0fx; }
    else if rank >= RANK_LUNATIC { width = 12.0fx; }
    for round in 0..9 {
        var x: fx = (rand(121) - 180) as fx;
        var y: fx = (rand(121) + 190) as fx;
        var lz: int = laser(15, x, y, 0deg, 360.0fx, width, 45, 120, 12);
        wait(45);
        for move_step in 0..120 {
            wait(1);
            x = x + 2.0fx;
            if lz_alive(lz) == 1 { lz_origin(lz, x, y); }
        }
        wait(135);
    }
}
