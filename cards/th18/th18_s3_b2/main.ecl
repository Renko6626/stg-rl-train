// st03bs.ecl.txt:512-622. Source t0=card124; first burst source90=card214.
const TIME_LIMIT: int = 2522;
const SOURCE_LIMIT: int = 2400;
const TH18_RICE: int = 480;

xformdef CLOUD(e: angle, f: angle) {
    // Native on_tick handler reentry consumes OFFSCREEN 5 extra times at finite boundaries.
    offscreen_keep(195);
    @30 set_gravity(at_effect((1.5fx-$self_speed)/30*cos($self_angle)),
                    at_effect((1.5fx-$self_speed)/30*sin($self_angle)));
    @10 set_gravity(0fx, 0fx);
    @30 set_gravity(at_effect((0.5fx/30)*cos(aim_player()+e)),
                    at_effect((0.5fx/30)*sin(aim_player()+e)));
    @30 set_gravity(at_effect((-1.97fx/30)*cos($self_angle)),
                    at_effect((-1.97fx/30)*sin($self_angle)));
    @30 set_gravity(at_effect((1.97fx/30)*cos(aim_player()+f)),
                    at_effect((1.97fx/30)*sin(aim_player()+f)));
    // Last VELTIME follows current vector. Signed polar speed preserves crossing through zero.
    // Its source logical speed has endpoints 2 -> 1, independently of actual vector magnitude.
    @64 set_accel(-0.0083333333fx);
    @1 set_accel(-0.0166666667fx); // age194: OFFSCREEN end reenters VELTIME once before integration
    @54 set_accel(-0.0083333333fx);
    stop_fx(); // age249: 120 VELTIME updates completed, including the doubled update at194
}
sub burst(offset: angle) {
    var rank: int = global(GVAR_RANK);
    var n: int = 20;
    if rank == 1 { n = 60; }
    if rank == 2 { n = 45; }
    if rank == 3 { n = 55; }
    var d: angle = rand(65536) as angle;
    var e: angle = rand(65536) as angle;
    sh_reset(0);
    sh_sprite(0, TH18_RICE, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 7, 1);
    for j in 0..n {
        // Source increments D/E before the first emission, not after.
        var g: angle = d+(((j+1)*65536/(n*7)) as angle);
        var a: angle = e+(((j+1)*65536/n) as angle);
        sh_angle(0, g, 0deg);
        sh_xform(0, CLOUD(a, a+offset));
        sh_dist(0, -6fx); // ANIM a1 retreats four times this layer's original 1.5 speed.
        sh_speed(0, 1.5fx, 0fx);
        sh_fire(0);
        if rank >= 2 {
            // Same 7 initial angles, zero-speed source layer; no retreat and no RNG consumption.
            sh_dist(0, 0fx);
            sh_speed(0, 0fx, 0fx);
            sh_fire(0);
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
    var offset: angle = 90deg;
    loop {
        if $frame >= self_int(1) { return; }
        burst(offset);
        offset = -offset;
        card_wait(120);
        if $frame >= self_int(1) { return; }
        card_move_rand();
        card_wait(120);
    }
}
async sub boss_main() {
    set_invuln(65535);
    set_hitbox(24fx);
    set_hurtbox(20fx);
    spell_begin(0, 20, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    move_vel(0, 0deg, 0fx, EASE_LINEAR);
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 128fx, 2300, 0, 0, 0, boss_main);
    loop { wait(600); }
}
