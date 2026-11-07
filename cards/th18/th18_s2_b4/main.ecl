// TH18 v1.00a st02bs::BossCard2/source540-695. Source t0=card124.
const TIME_LIMIT: int = 2522;
const SOURCE_LIMIT: int = 2400;

xformdef LEAF_MOTION(duration: int, omega: angle) {
    // Native300: ANGLE_ACCEL-end and ACCEL-end each rerun OFFSCREEN once before its expiry.
    // d<=219 and d+20<=239, so both extra passes precede clearing: same expiry as 298 updates.
    offscreen_keep(298);
    set_ang_vel(omega);
    set_accel(0.003fx);
    wait(duration);
    // Source ANGLE_ACCEL ends; ACCEL captures this angle once for its fixed vector.
    set_ang_vel(0bam);
    set_accel(0fx);
    @20 set_gravity(at_effect(-0.04fx*cos($self_angle)), at_effect(-0.04fx*sin($self_angle)));
    set_gravity(0fx, 0fx);
}
xformdef BIG_MOTION {
    // Single VELTIME, current-angle direction, no later logical-speed readers.
    @60 set_accel((0.8fx-3fx)/60);
    set_accel(0fx);
}
sub configure() {
    for id in 0..2 {
        sh_reset(id);
        sh_sprite(id, TH18_DROPLET, 10);
        sh_aim(id, 0);
        sh_ring(id, 1);
        sh_count(id, 16, 1);
        sh_angle(id, -90deg, 20deg);
        sh_speed(id, 1.5fx, 0fx);
        sh_dist(id, 26fx); // dist32 minus ANIM a1 retreat4*1.5.
        sh_offset(id, 0fx, -16fx);
    }
}
sub emit_pair(b: angle) {
    // Source616/617 and642/643 both write id0. The second write wins; id1 remains -90deg.
    sh_angle(0, -b, 20deg);
    var d0: int = 180+rand(65536)%40;
    var d1: int = 180+rand(65536)%40;
    sh_xform(0, LEAF_MOTION(d0, 164bam));
    sh_xform(1, LEAF_MOTION(d1, -164bam));
    sh_fire(0);
    sh_fire(1);
}
sub attack() {
    configure();
    var b: angle = (rand(65536)-32768) as angle;
    var count: int = 7;
    var interval: int = 15;
    var rank: int = global(GVAR_RANK);
    if rank == 0 { count = 3; }
    if rank == 2 { interval = 10; }
    if rank == 3 { interval = 8; }
    for j in 0..count {
        if $frame >= self_int(1) { return; }
        emit_pair(b);
        b = b+910bam; // .087266rad nearest BAM.
        card_wait(interval);
    }
    if rank >= 2 {
        sh_sprite(0, TH18_TALISMAN, 10); // Source638 only changes id0, id1 keeps droplet.
        var extra: int = 5;
        if rank == 3 { extra = 9; }
        for k in 0..extra {
            if $frame >= self_int(1) { return; }
            emit_pair(b);
            b = b+910bam;
            card_wait(interval);
        }
    }
}
async sub proximity() {
    sh_reset(2);
    sh_sprite(2, TH18_BIG_BALL2, 3);
    sh_aim(2, 1);
    sh_ring(2, 1);
    sh_count(2, 10, 1);
    sh_speed(2, 3fx, 0fx);
    sh_angle(2, 0deg, 30deg);
    sh_dist(2, -12fx); // ANIM a1 retreat4*3. Source has no etDist.
    sh_xform(2, BIG_MOTION);
    for j in 0..5000 {
        wait(30);
        if $frame >= self_int(1) { return; }
        if dist($player_x-$self_x, $player_y-$self_y) <= 200fx {
            sh_fire(2);
        }
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
    wait(90);
    // Source584/585 floatTime A is dead: no subsequent read in this attack.
    spawn proximity();
    loop {
        if $frame >= self_int(1) { return; }
        attack();
        card_wait(130);
        if $frame >= self_int(1) { return; }
        card_move_rand();
        card_wait(60);
    }
}
async sub boss_main() {
    set_invuln(65535);
    set_hitbox(24fx);
    set_hurtbox(20fx);
    spell_begin(0, 12, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    move_vel(0, 0deg, 0fx, EASE_LINEAR);
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 128fx, 2300, 0, 0, 0, boss_main);
    loop { wait(600); }
}
