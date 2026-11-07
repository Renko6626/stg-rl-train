// TH18 v1.00a st01bs::BossCard2, source505-696. Shell source t0=card124.
const TIME_LIMIT: int = 2222;
const SOURCE_LIMIT: int = 2100;

// Source STEP(30,1,c0,d0,angle-offset0,target-speed0), then ANGLE_ACCEL100.
// This single segment has fixed logical speed2.5, no concurrent modification or later logical-speed read.
// t0..29:2.5*(1-t/30); t30:0 then same-tick first +gain; t130:gain stops.
xformdef MAIN_MOTION(gain: fx) {
    @30 step_speed(0fx, 30);
    @100 set_accel(gain);
    set_accel(0fx);
}
sub emit_ring(a: angle, ox: fx, oy: fx, n: int, color: int, gain: fx) {
    sh_reset(0);
    sh_sprite(0, TH18_BALL2, color);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_angle(0, a, 0deg); // Source mode3; ang2 is layer rotation and M1 ignores it.
    sh_speed(0, 2.5fx, 0fx);
    sh_offset(0, ox, oy);
    sh_dist(0, -10fx); // ANIM a1 also retreats4*velocity; other birth-stage behavior omitted.
    sh_xform(0, MAIN_MOTION(gain));
    sh_fire(0); // M1 source layer-outer/ray-inner order equals target ring order.
}
sub main_group(a: angle, ox: fx, oy: fx, n: int, until: int) {
    for i in 0..7 {
        if $frame >= until { return; }
        var color: int = 2;
        if i == 0 { color = 4; }
        if i == 1 { color = 6; }
        if i == 2 { color = 8; }
        if i == 3 { color = 11; }
        if i == 4 { color = 13; }
        if i == 5 { color = 14; }
        var gain: fx = (1.2fx+(i as fx)*0.5fx)/100;
        emit_ring(a, ox, oy, n, color, gain);
        if i < 6 { card_wait(3); } // Last color has no trailing wait:18frames per group.
    }
}
async sub bubbles() {
    // Source async first runs next frame; no older async survives across the>=268frame cycle.
    var rank: int = global(GVAR_RANK);
    var n: int = 3;
    var delta: int = 5461; //30deg nearest BAM.
    if rank == 2 { n = 5; }
    if rank == 3 { n = 7; delta = 3641; } //20deg nearest BAM.
    var aim: angle = aim_player();
    sh_reset(1);
    sh_sprite(1, TH18_BUBBLE, 3);
    sh_count(1, 1, 1);
    sh_speed(1, 0.6fx, 0fx);
    sh_dist(1, -2.4fx);
    // Preserve source mode0 creation order:center,-1,+1,-2,+2,...
    for i in 0..n {
        var off: int = ((i+1)/2)*delta;
        if i%2 != 0 { off = -off; }
        sh_angle(1, aim+(off as angle), 0deg);
        sh_fire(1);
    }
    wait(60); // This async wait never blocks the main ring task or advances its movement helper.
}
async sub pattern() {
    wait(120);
    var until: int = $frame+SOURCE_LIMIT;
    set_self_int(1, until);
    set_self_int(0, 60);
    set_self_fx(0, 0fx);
    set_self_fx(1, 0fx);
    move_to(60, 0fx, 128fx, EASE_QUAD_OUT);
    var rank: int = global(GVAR_RANK);
    var n: int = 16;
    if rank == 0 { n = 12; }
    var groups: int = 3;
    var tail: int = 180;
    if rank == 1 { tail = 160; }
    if rank == 2 { groups = 6; tail = 100; }
    if rank == 3 { groups = 8; tail = 90; }
    wait(90);
    loop {
        if $frame >= until { return; }
        card_wait(60);
        for group in 0..groups {
            if $frame >= until { return; }
            var ox: fx = 0fx;
            var oy: fx = 0fx;
            if group < 2 {
                var u: fx = (rand(65536)-32768) as fx / 65536 + 0.5fx;
                if group == 0 { ox = u*64fx+32fx; }
                else { ox = u*(-64fx)-32fx; }
            } else {
                var signed_u: fx = (rand(65536)-32768) as fx / 32768;
                ox = signed_u*(-64fx);
                oy = 60fx;
            }
            var a: angle = 0deg;
            if group == 2 { a = aim_player(); } // Snapshot from boss, not from the offset origin.
            else { a = (rand(65536)-32768) as angle; }
            main_group(a, ox, oy, n, until);
            if $frame >= until { return; }
            if group == 2 && rank > 0 { spawn bubbles(); }
        }
        if $frame >= until { return; }
        card_move_rand();
        card_wait(tail);
    }
}
async sub boss_main() {
    set_invuln(65535);
    set_hitbox(24fx);
    set_hurtbox(20fx);
    spell_begin(0, 4, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    move_vel(0, 0deg, 0fx, EASE_LINEAR);
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 128fx, 2200, 0, 0, 0, boss_main);
    loop { wait(600); }
}
