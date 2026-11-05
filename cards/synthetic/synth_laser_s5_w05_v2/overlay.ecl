// Near-end gap rotating line: only the far 180px is active.
async sub synth_overlay() {
    wait(120);
    var rank: int = global(GVAR_RANK);
    var omega: angle = 40bam;
    if rank == RANK_NORMAL { omega = 56bam; }
    else if rank == RANK_HARD { omega = 80bam; }
    else if rank >= RANK_LUNATIC { omega = 112bam; }
    var a: angle = rand(65536) as angle;
    if rand(2) == 1 { omega = 0deg - omega; }
    var lz: int = laser(15, 0.0fx, 80.0fx, a, 300.0fx, 8.0fx, 45, 120, 12);
    lz_start(lz, 120.0fx);
    lz_omega(lz, omega);
    wait(210);
}
