// TH18 v1.00a st02bs::BossCard1/source371-539. Source t0=card124.
const TIME_LIMIT: int = 2222;
const SOURCE_LIMIT: int = 2100;

xformdef LEAF_MOTION(omega: angle) {
    offscreen_keep(200); // Source515: b0 finite offscreen protection; independent of polar motion.
    set_ang_vel(omega);
    @200 set_accel(0.012fx);
    set_ang_vel(0bam);
    set_accel(0fx);
}
sub sample_count() {
    var rank: int = global(GVAR_RANK);
    var start: int = 3;
    var delta: int = 2;
    if rank == 1 { delta = 3; }
    if rank >= 2 { start = 5; }
    // Source floatTime0 starts at source90, writes start immediately, then advances at frame tail.
    // Positive values: _S(start+delta*elapsed/2100) is exactly this integer floor.
    var elapsed: int = $frame-self_int(2)-90;
    set_self_int(3, start+delta*elapsed/2100);
}
sub configure(omega: angle) {
    sh_reset(0);
    sh_sprite(0, TH18_DROPLET, 10);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_speed(0, 1.5fx, 0fx);
    sh_dist(0, 26fx); // Source dist32, ANIM a1 retreat4*1.5; rest of birth stage omitted.
    sh_offset(0, 0fx, -16fx);
    sh_xform(0, LEAF_MOTION(omega));
}
sub emit_fan(center: angle, n: int) {
    // Preserve source fixed-fan creation order for both odd and even N.
    for i in 0..n {
        var off: int = ((i+1)/2)*3641; //20deg nearest BAM.
        if n%2 == 0 { off = (2*(i/2)+1)*3641/2; }
        if i%2 != 0 { off = -off; }
        sh_angle(0, center+(off as angle), 0deg);
        sh_fire(0);
    }
}
sub sync_helper(n: int, turn: int, omega: angle, interval: int) {
    configure(omega);
    for j in 0..15 {
        if $frame >= self_int(1) { return; }
        emit_fan((-16384-j*turn) as angle, n);
        card_wait(interval); // Includes last emission's wait, and only this main task advances movement.
    }
}
async sub async_helper(n: int, turn: int, omega: angle, interval: int) {
    // n is copied at source call time; target/source async both first run on the following frame.
    configure(omega);
    for j in 0..15 {
        if $frame >= self_int(1) { return; }
        emit_fan((-16384-j*turn) as angle, n);
        wait(interval); // Includes trailing wait; never advances shared movement a second time.
    }
}
async sub pattern() {
    wait(120);
    set_self_int(2, $frame);
    set_self_int(1, $frame+SOURCE_LIMIT);
    set_self_int(0, 60);
    set_self_fx(0, 0fx);
    set_self_fx(1, 0fx);
    move_to(60, 0fx, 128fx, EASE_QUAD_OUT);
    var rank: int = global(GVAR_RANK);
    var gap: int = 30;
    var interval: int = 5;
    var turn: int = 4005; // Source C=.383972rad (~22deg).
    if rank == 0 { gap = 60; turn = 3459; } // Source C=.331613rad (~19deg).
    if rank == 2 { interval = 4; }
    if rank == 3 { interval = 3; }
    wait(90);
    loop {
        if $frame >= self_int(1) { return; }
        sample_count();
        spawn async_helper(self_int(3), turn, 164bam, interval);
        card_wait(gap);
        if $frame >= self_int(1) { return; }
        sample_count();
        sync_helper(self_int(3), -turn, -164bam, interval);
        if $frame >= self_int(1) { return; }
        card_move_rand();
        sample_count();
        spawn async_helper(self_int(3), -turn, -164bam, interval);
        card_wait(gap);
        if $frame >= self_int(1) { return; }
        sample_count();
        sync_helper(self_int(3), turn, 164bam, interval);
        if $frame >= self_int(1) { return; }
        card_move_rand();
    }
}
async sub boss_main() {
    set_invuln(65535);
    set_hitbox(24fx);
    set_hurtbox(20fx);
    spell_begin(0, 8, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    move_vel(0, 0deg, 0fx, EASE_LINEAR);
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 128fx, 2300, 0, 0, 0, boss_main);
    loop { wait(600); }
}
