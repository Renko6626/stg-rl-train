// th06_s6_w02 —— 东方红魔乡 Stage 6 道中 第 2 波（纯装饰波，无弹）
// 原文：ecldata6.ecl.txt timeline 帧 1174–1204（行 2263–2270）+ sub Sub0（行 2–23）
const TIME_LIMIT: int = 2310;

// TH06 敌进过场地再出界即删（mapping §6.2）
async sub oob_guard() {
    var been_in: int = 0;
    loop {
        var inside: int = 0;
        if $self_x > -208.0fx && $self_x < 208.0fx && $self_y > -16.0fx && $self_y < 464.0fx { inside = 1; }
        if inside == 1 { been_in = 1; }
        if been_in == 1 && inside == 0 { die(); }
        wait(1);
    }
}

// Sub0（行 2–23）：不可见、不可交互的装饰敌，全程零弹。
//   set_int($I4, 18); Sub0_68: +40/+80/+120 各一次随机落点 + 粒子；jump_dec(0, Sub0_68, $I4)
//   每轮 120 帧（3×40），共 18 轮 ⇒ 出生后 2160 帧 enemy_delete(0)。
//   落点随机化（set_float_rand_bound($SELF_X,…) 等）只为粒子服务，mapping §11 粒子丢弃故一并丢弃。
async sub sub0() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);   // enemy_flag_invisible(1) + enemy_flag_interactable(0)（§8）
    spawn oob_guard();
    for k1 in 0..18 {
        wait(120);
    }
    die();                              // enemy_delete(0)，帧 2160
}

// 导演：开场缓冲 120 帧；原文四只同点 (160,-48)→x=-32，相隔 10 帧出（timeline 1174/1184/1194/1204）
async sub wave() {
    wait(120);
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, sub0);
    wait(10);
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, sub0);
    wait(10);
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, sub0);
    wait(10);
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, sub0);
    loop { wait(1); }
}

async sub director() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, wave, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 0.0fx, 1000, 0, 0, 0, director);
    loop { wait(600); }
}
