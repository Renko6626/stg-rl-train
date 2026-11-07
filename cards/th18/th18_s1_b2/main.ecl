// TH18 v1.00a st01bs::BossCard1; source body354-434/helper496-504.
// Source t0 is pattern start +120; first fire +90; source window [0,2100).
// int slot0 and fx slots0/1 are owned by movement.ecl. No source reads depend on these slots.
const TIME_LIMIT: int = 2222;
const SOURCE_LIMIT: int = 2100;
const OPENING_BUFFER: int = 120;

xformdef CARD_ACCEL(gx: fx, gy: fx) {
    // Birth stage omitted by user policy; ACCEL begins at first target effect update for60ticks.
    @60 set_gravity(gx, gy);
    set_gravity(0fx, 0fx);
}
sub emit(aim: angle, color: int, n: int) {
    // Three independent configuration-time RANDF2 reads, shared by this n-bullet wave.
    var u: fx = (rand(65536)-32768) as fx / 32768;
    var accel: fx = 0.08fx+u*0.03fx;
    var u2: fx = (rand(65536)-32768) as fx / 32768;
    var accel_angle: angle = aim+((5461fx*u2) as int as angle);
    var u3: fx = (rand(65536)-32768) as fx / 32768;
    var center: angle = aim+((5461fx*u3) as int as angle)-180deg;
    var gx: fx = accel*cos(accel_angle);
    var gy: fx = accel*sin(accel_angle);
    // Bind one shared xform snapshot; emit one bullet at a time in source order.
    // Negative sh_dist preserves ANIM's -4*initial-speed displacement without per-bullet trig.
    sh_reset(0);
    sh_sprite(0, TH18_RING_BALL2, color);
    sh_count(0, 1, 1);
    sh_speed(0, 3fx, 0fx);
    sh_dist(0, -12fx);
    sh_xform(0, CARD_ACCEL(gx, gy));
    // Source alternating order, with parity resolved once to fit the frame instruction budget.
    // Odd:0,-1820,+1820,...; even:+910,-910,+2730,...
    var off: int = 0;
    var stride: int = -1820;
    var increment: int = -1820;
    if n%2 == 0 { off = 910; stride = 1820; increment = 0; }
    for i in 0..n {
        var a: angle = center+(off as angle);
        // ANIM a2 retreats 4*initial velocity; slowdown/no-hit window omitted by policy.
        sh_angle(0, a, 0deg);
        sh_fire(0);
        off = -off+increment;
        increment = stride-increment;
    }
}
sub volley(n: int, until: int) {
    var aim: angle = aim_player(); // BossCard1_at entry snapshot, entire105-frame helper.
    for group in 0..7 {
        var color: int = 2;
        if group == 0 { color = 4; }
        if group == 1 { color = 6; }
        if group == 2 { color = 8; }
        if group == 3 { color = 10; }
        if group == 4 { color = 13; }
        if group == 5 { color = 14; }
        for j in 0..3 {
            if $frame >= until { return; }
            emit(aim, color, n);
            card_wait(5);
        }
    }
}

async sub pattern() {
    wait(OPENING_BUFFER);
    var until: int = $frame+SOURCE_LIMIT;
    var rank: int = global(GVAR_RANK);
    var n: int = 2;
    if rank == 1 { n = 5; }
    if rank == 2 { n = 10; }
    if rank == 3 { n = 16; }
    // Source entry321-341: stop old velocity,60-frame QuadOut return to center, first fire at90.
    move_to(60, 0fx, 128fx, EASE_QUAD_OUT);
    wait(90);
    loop {
        if $frame >= until { move_vel(0, 0deg, 0fx, EASE_LINEAR); return; }
        card_move_rand();
        volley(n, until);
        if $frame >= until { move_vel(0, 0deg, 0fx, EASE_LINEAR); return; }
        card_wait(60);
    }
}
async sub boss_main() {
    set_invuln(65535);
    set_hitbox(24fx); // Source setHitbox(48,48): native ordinary circle uses width*0.5.
    set_hurtbox(20fx); // Source setHurtbox(40,40); damage disabled by training invulnerability.
    spell_begin(0, 0, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    move_vel(0, 0deg, 0fx, EASE_LINEAR);
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 128fx, 2100, 0, 0, 0, boss_main);
    loop { wait(600); }
}
