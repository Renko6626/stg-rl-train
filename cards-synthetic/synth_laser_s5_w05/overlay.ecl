// One short rotating segment with randomized initial orientation and spin direction.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var omega: angle = 48bam;
    if rank == RANK_NORMAL { omega = 64bam; }
    else if rank == RANK_HARD { omega = 96bam; }
    else if rank >= RANK_LUNATIC { omega = 128bam; }
    var a: angle = rand(65536) as angle;
    if rand(2) == 1 { omega = 0deg - omega; }
    var lz: int = laser(15, 0.0fx, 80.0fx, a, 240.0fx, 8.0fx, 45, 120, 12);
    lz_start(lz, 80.0fx);
    lz_omega(lz, omega);
    wait(210);
}
