// st05bs.ecl.txt:511-682. Source t0 = target frame124.
const TIME_LIMIT: int = 3122;
const SOURCE_LIMIT: int = 3000;
const TH18_STAR_R: int = 608; // type16, radius4, raw colors2/4.

// No later EX reads the original independent logical speed after this VELTIME.
// Temporary angle is restored in the same xform tick, before movement/collision.
xformdef STAR(wait_frames: int, delta: fx) {
    wait(wait_frames);
    set_angle(at_effect(aim_player()+(((rand(65536)-32768)*1820/32768) as angle)));
    set_gravity(at_effect(delta*cos($self_angle)), at_effect(delta*sin($self_angle)));
    set_angle(270deg);
    @120 add_speed(0fx);
    set_gravity(0fx, 0fx);
}
sub emit_at(x: fx, y: fx, color: int) {
    var delay: int = 200+rand(65536)%120;
    var target: fx = 1.5fx+((rand(65536)-32768) as fx)/65536;
    // ANIM a1 retreat4*0.01=0.04; other ordinary birth behavior omitted.
    _ = fire(TH18_STAR_R, color, x, y+0.04fx, 0.01fx, 270deg,
             STAR(delay, (target-0.01fx)/120), none);
}
// flag303 makes the source helper noninteractive and disables offscreen retirement.
// Local coordinates preserve those semantics without target enemy OOB retirement.
async sub child(x: fx, y: fx, a0: int, a1: int, a2: int, a3: int, color: int) {
    var start: int = a0;
    var finish: int = a1;
    var s0: fx = 2fx;
    var s1: fx = 1fx;
    for t in 0..480 {
        if $frame >= self_int(2) { return; }
        // Source async first runs one frame after child start and sees first movement tick.
        if t > 0 && (t-1)%5 == 0 { emit_at(x,y,color); }
        var seg: int = t/120;
        if seg == 1 { start = a1; finish = a2; s0 = 1fx; s1 = 2fx; }
        if seg == 2 { start = a2; finish = a3; s0 = 2fx; s1 = 1fx; }
        if seg == 3 { start = a3; finish = a0; s0 = 1fx; s1 = 4fx; }
        var d: int = finish-start;
        if d > 32768 { d = d-65536; }
        if d < -32768 { d = d+65536; }
        var k: int = t%120+1;
        var u: fx = (k as fx)/120;
        var f: fx = u*u; // source mode1=t^2 for angle and speed.
        var a: angle = (start+d*k*k/14400) as angle;
        var speed: fx = s0+(s1-s0)*f;
        x = x+cos(a)*speed;
        y = y+sin(a)*speed;
        wait(1);
    }
}
sub wave(reverse: int, color: int, n: int) {
    var base: int = -16384;
    if global(GVAR_RANK) == 0 { base = -24576; }
    var delta: int = 29127; //160deg
    if reverse != 0 { delta = -30948; } //-170deg
    var a0: int = base;
    var a1: int = base+delta;
    for i in 0..n {
        spawn child($self_x,$self_y,a0,a1,a0,a1,color);
        a0 = a0+65536/n;
        a1 = a1+65536/n;
        if a0 > 32768 { a0 = a0-65536; }
        if a0 < -32768 { a0 = a0+65536; }
        if a1 > 32768 { a1 = a1-65536; }
        if a1 < -32768 { a1 = a1+65536; }
    }
}
async sub pattern() {
    wait(120);
    set_self_int(2, $frame+SOURCE_LIMIT);
    set_self_int(0, 60);
    set_self_fx(0, 0fx);
    set_self_fx(1, 0fx);
    move_to(60, 0fx, 128fx, EASE_QUAD_OUT);
    var rank: int = global(GVAR_RANK);
    var n: int = 5;
    var gap1: int = 400;
    var gap2: int = 500;
    if rank == 0 { n = 3; gap1 = 600; gap2 = 600; }
    if rank == 1 { gap1 = 500; }
    if rank == 3 { gap2 = 400; }
    wait(90);
    loop {
        if $frame >= self_int(2) { return; }
        wave(0, 2, n);
        card_wait(gap1);
        card_move_rand();
        card_wait(60);
        if $frame >= self_int(2) { return; }
        var color: int = 2;
        if rank >= 2 { color = 4; }
        wave(1, color, n);
        card_wait(gap2);
        card_move_rand();
        card_wait(60);
    }
}
async sub boss_main() {
    set_invuln(65535);
    set_hitbox(24fx);
    set_hurtbox(20fx);
    spell_begin(0, 44, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    move_vel(0, 0deg, 0fx, EASE_LINEAR);
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 128fx, 100000, 0, 0, 0, boss_main);
    loop { wait(600); }
}
