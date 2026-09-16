// th06_s2_w01 —— 东方红魔乡 Stage 2 道中开场第 1 波
// 原文：ecldata2 timeline 帧 240–654（Sub0–Sub4 循环出怪）；小怪 Sub0（:2-21）、Sub1（:23-40）、
//       Sub2（:42-61）、Sub3（:63-80）、Sub4（:82-101）
const TIME_LIMIT: int = 834;
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI 苦无（mapping §3）

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

// 小怪通用任务。kind 0 = Sub0/2/4，kind 1 = Sub1/3；until = 原文 shoot_interval(0) 的帧。
//   kind 0：`!N`/`!H` 写 offset_circle 4×1（shoot_disable 期只配置、不发），`!L` 写 circle 10×2；
//           `!NHL shoot_interval_delayed(180)` ⇒ N/H/L 各自动开火，E 一颗不发。
//   kind 1：`!L shoot_interval_delayed(180)` ⇒ 只有 Lunatic 开火（circle 10×2）；N/H/E 一颗不发。
// 全体 move_velocity(a, 3.0) + move_acceleration(-0.015) 全程逐帧积分（mapping §7.2）：
// 速度约 200 帧归零后转负，小怪反向飞回、由上边界出界，再由 oob_guard 删除。
async sub fairy(ang0: angle, kind: int, until: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = ang0;
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    var n: int = 0;
    var layers: int = 1;
    var s1: fx = 2.0fx;
    var s2: fx = 0.3fx;                    // 原文 s2 = 0.0f，代入前按 §4.2 钳到 0.3fx
    var base: angle = 0deg;
    if kind == 0 {
        // Sub0/2/4
        if rank == RANK_NORMAL || rank == RANK_HARD {
            n = 4; base = 45deg;            // !N/!H bullet_offset_circle_aimed(4,11,4,1,2.0,0,…,4)
        } else if rank >= RANK_LUNATIC {
            n = 10; layers = 2; s1 = 2.5fx; // !L bullet_circle_aimed(4,11,10,2,2.5,0,…,4)
        }
    } else {
        // Sub1/3
        if rank >= RANK_LUNATIC { n = 10; layers = 2; s1 = 2.5fx; }
    }
    move_vel(0, ang, spd, 0);
    var fires: int = 0;
    var next: int = 0;
    if n > 0 {
        fires = 1;
        sh_reset(0);
        sh_sprite(0, KUNAI, 11);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, n, layers);
        sh_speed(0, s1, (s2 - s1) / layers);
        sh_angle(0, base, 0deg);
        next = 180 - rand(180);            // shoot_interval_delayed(180)：首发 180−rand(180)
    }
    var t: int = 0;
    loop {
        // 原文 +until 处 shoot_interval(0) 先执行（同帧），排在它那一帧的自动射击被吃掉
        if fires == 1 && t == next && t < until {
            sh_fire(0);
            // until = 200 时若首轮 next ≤ 19，还会在 next + 180 打第二轮；否则到此为止
            if t + 180 < until { next = t + 180; } else { fires = 0; }
        }
        spd = spd + acc;                   // 逐帧积分，无 0 下限（TH06 mode 1）
        move_vel(0, ang, spd, 0);
        wait(1);
        t = t + 1;
    }
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 240)。每 6 帧一只，Sub0→Sub4 循环，共 70 只（14 轮 × 5）。
// 首只小怪任务首跑于卡帧 124，末只 538（main→director→wave 三层「出生当帧不跑」）。
async sub wave() {
    wait(120);
    for r in 0..14 {
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy(45deg, 0, 180));    wait(6);
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy(67.5deg, 1, 200));  wait(6);
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0, 200));    wait(6);
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy(112.5deg, 1, 200)); wait(6);
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy(135deg, 0, 200));
        if r < 13 { wait(6); }
    }
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
