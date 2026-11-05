// th06_s4_b1 —— 东方红魔乡 Stage 4 boss（帕秋莉·诺蕾姬）非符 1
// 原文：ecldata4.ecl.txt Sub27（+40 起循环）+ Sub32/28、Sub33/29、Sub34/30、Sub35/31（四向激光扫射）
//       + Sub36（随机游走 + 环弹齐射），段边界 timer_callback_threshold(2400)。
const TIME_LIMIT: int = 2400;
const BALL: int = 48;   // TH06 弹型 3 BALL（16px，色号原样）

// Sub27 move_bounds_set(32.0f, 48.0f, 352.0f, 144.0f) → 我方 (-160,48)-(160,144)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }
    if $self_x < bx0 + 96.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < by0 + 48.0fx && v < 0 { v = 0 - v; }
    if $self_y > by1 - 48.0fx && v > 0 { v = 0 - v; }
    var d: fx = spd * t / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);
}

// ex_ins_call(12,0)：遍历本敌每条活激光，用当前发射参数在「敌位置 + 沿激光方向 64px」开一次火（mapping §14.4）
sub ex_fire_one(lz: int) {
    if lz_alive(lz) == 1 {
        var a: angle = lz_angle(lz);
        sh_offset(0, 64.0fx * cos(a), 64.0fx * sin(a));
        sh_fire(0);
    }
}

// family A（$I0 == 0）：Sub32(E)/Sub33(N)/Sub34(H)/Sub35(L)
// 四向激光（±π/4、±3π/4），前四条转一方向、I0==mid 起再补四条反向转；ex_ins_call(12) 周期开火
sub attack_a(rank: int, i7: int) {
    var mid: int = 60;
    var lim: int = 120;
    var n: int = 180;
    var mod: int = 60;
    var warn: int = 30;
    var act_a: int = 70;
    var act_b: int = 90;
    var fade: int = 20;
    var d3: angle = -63bam;      // 0.0060415245f
    var d4: angle = 63bam;
    var ways: int = 1;
    var layers: int = 2;
    var s1: fx = 2.0fx;
    var fan: int = 0;
    if rank == RANK_NORMAL {                 // Sub33
        mod = 50; d3 = -71bam; d4 = 71bam;   // 0.006829549f
    } else if rank == RANK_HARD {            // Sub34
        mid = 50; lim = 100; n = 150; mod = 40;
        warn = 25; act_a = 58; act_b = 75; fade = 16;
        d3 = -85bam; d4 = 85bam; ways = 2; fan = 1;   // 0.008195459f
    } else if rank >= RANK_LUNATIC {         // Sub35
        mid = 46; lim = 93; n = 140; mod = 40;
        warn = 23; act_a = 54; act_b = 70; fade = 15;
        d3 = -92bam; d4 = 92bam; ways = 2; fan = 1; s1 = 2.5fx;   // 0.008780849f
    }
    // bullet_*_aimed(3, 2, ways, layers, s1, 1.2, 0, spread, 4)：shoot_disable 期间只配置、由 ex_ins_call(12) 开火
    sh_reset(0);
    sh_sprite(0, BALL, 2);
    sh_aim(0, 1);
    sh_offset(0, 0.0fx, -12.0fx);            // Sub27 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_count(0, ways, layers);
    sh_speed(0, s1, (1.2fx - s1) / layers);
    if fan == 0 {
        sh_ring(0, 1);
        sh_angle(0, 0deg, 0deg);
    } else {
        sh_ring(0, 0);
        sh_angle(0, 0deg, 1024bam);          // 0.09817477f = π/32
    }
    // laser_create(1, 6, a, 0.0, 64.0, 500.0, 500.0, 24.0, T0, T1, T2, 30, 14, 0)
    // 原点 = 敌位置 + shoot_offset(0,-12)；宽 24 → 12；速度 0 ⇒ len=en=500、start=max(64,500-500,0)=64
    var lz0: int = laser(6, $self_x, $self_y - 12.0fx, 8192bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz0, 64.0fx);
    var lz1: int = laser(6, $self_x, $self_y - 12.0fx, 24576bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz1, 64.0fx);
    var lz2: int = laser(6, $self_x, $self_y - 12.0fx, -24576bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz2, 64.0fx);
    var lz3: int = laser(6, $self_x, $self_y - 12.0fx, -8192bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz3, 64.0fx);
    var lz4: int = 0;
    var lz5: int = 0;
    var lz6: int = 0;
    var lz7: int = 0;
    var full: int = 0;
    var i0: int = 0;
    for k1 in 0..n {
        if i0 < lim {
            lz_rotate(lz0, d3); lz_rotate(lz1, d3); lz_rotate(lz2, d3); lz_rotate(lz3, d3);
        }
        if i0 == mid {
            lz4 = laser(6, $self_x, $self_y - 12.0fx, 8192bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz4, 64.0fx);
            lz5 = laser(6, $self_x, $self_y - 12.0fx, 24576bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz5, 64.0fx);
            lz6 = laser(6, $self_x, $self_y - 12.0fx, -24576bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz6, 64.0fx);
            lz7 = laser(6, $self_x, $self_y - 12.0fx, -8192bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz7, 64.0fx);
            full = 1;
        }
        if i0 >= mid {
            lz_rotate(lz4, d4); lz_rotate(lz5, d4); lz_rotate(lz6, d4); lz_rotate(lz7, d4);
        }
        if i7 != 0 {
            if i0 % mod == 0 {
                ex_fire_one(lz0); ex_fire_one(lz1); ex_fire_one(lz2); ex_fire_one(lz3);
                if full != 0 {
                    ex_fire_one(lz4); ex_fire_one(lz5); ex_fire_one(lz6); ex_fire_one(lz7);
                }
                sh_offset(0, 0.0fx, -12.0fx);    // 发完恢复原出弹口
            }
        }
        i0 = i0 + 1;
        wait(1);
    }
}

// family B（$I0 == 1）：Sub28(E)/Sub29(N)/Sub30(H)/Sub31(L)，与 A 同构、参数不同
sub attack_b(rank: int, i7: int) {
    var mid: int = 60;
    var lim: int = 120;
    var n: int = 180;
    var mod: int = 60;
    var warn: int = 30;
    var act_a: int = 70;
    var act_b: int = 90;
    var fade: int = 20;
    var d3: angle = 63bam;
    var d4: angle = -63bam;
    var ways: int = 8;
    var layers: int = 1;
    var s1: fx = 1.5fx;
    if rank == RANK_NORMAL {                 // Sub29
        mod = 50; d3 = 71bam; d4 = -71bam; ways = 10; s1 = 2.0fx;
    } else if rank == RANK_HARD {            // Sub30
        mid = 50; lim = 100; n = 150; mod = 40;
        warn = 25; act_a = 58; act_b = 75; fade = 16;
        d3 = 85bam; d4 = -85bam; ways = 14; s1 = 2.4fx;
    } else if rank >= RANK_LUNATIC {         // Sub31
        mid = 46; lim = 93; n = 140; mod = 40;
        warn = 23; act_a = 54; act_b = 70; fade = 15;
        d3 = 92bam; d4 = -92bam; ways = 10; layers = 2; s1 = 3.0fx;
    }
    sh_reset(0);
    sh_sprite(0, BALL, 2);
    sh_aim(0, 1);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_count(0, ways, layers);
    sh_speed(0, s1, (1.2fx - s1) / layers);
    sh_ring(0, 1);
    sh_angle(0, 0deg, 0deg);
    var lz0: int = laser(6, $self_x, $self_y - 12.0fx, 8192bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz0, 64.0fx);
    var lz1: int = laser(6, $self_x, $self_y - 12.0fx, 24576bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz1, 64.0fx);
    var lz2: int = laser(6, $self_x, $self_y - 12.0fx, -24576bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz2, 64.0fx);
    var lz3: int = laser(6, $self_x, $self_y - 12.0fx, -8192bam, 500.0fx, 12.0fx, warn, act_a, fade);
    lz_start(lz3, 64.0fx);
    var lz4: int = 0;
    var lz5: int = 0;
    var lz6: int = 0;
    var lz7: int = 0;
    var full: int = 0;
    var i0: int = 0;
    for k1 in 0..n {
        if i0 < lim {
            lz_rotate(lz0, d3); lz_rotate(lz1, d3); lz_rotate(lz2, d3); lz_rotate(lz3, d3);
        }
        if i0 == mid {
            lz4 = laser(6, $self_x, $self_y - 12.0fx, 8192bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz4, 64.0fx);
            lz5 = laser(6, $self_x, $self_y - 12.0fx, 24576bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz5, 64.0fx);
            lz6 = laser(6, $self_x, $self_y - 12.0fx, -24576bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz6, 64.0fx);
            lz7 = laser(6, $self_x, $self_y - 12.0fx, -8192bam, 500.0fx, 12.0fx, warn, act_b, fade);
            lz_start(lz7, 64.0fx);
            full = 1;
        }
        if i0 >= mid {
            lz_rotate(lz4, d4); lz_rotate(lz5, d4); lz_rotate(lz6, d4); lz_rotate(lz7, d4);
        }
        if i7 != 0 {
            if i0 % mod == 0 {
                ex_fire_one(lz0); ex_fire_one(lz1); ex_fire_one(lz2); ex_fire_one(lz3);
                if full != 0 {
                    ex_fire_one(lz4); ex_fire_one(lz5); ex_fire_one(lz6); ex_fire_one(lz7);
                }
                sh_offset(0, 0.0fx, -12.0fx);
            }
        }
        i0 = i0 + 1;
        wait(1);
    }
}

// Sub36 shoot_interval(40)：后台自动用当时弹型每 40 帧开一次火（mapping §4.3 写法 A）
// 原作首发 = S + n − 1（S = 执行 shoot_interval 的帧）；伴生任务出生当帧不跑，首跑已在 S+1，
// 故等 k−1 帧正好落在 S+k。停火守卫比的是 k 本身（k >= until），until 也从 S 算起。
async sub autoshoot(interval: int, until: int, ways: int, layers: int, s1: fx) {
    sh_reset(0);
    sh_sprite(0, BALL, 2);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, ways, layers);
    sh_speed(0, s1, (1.2fx - s1) / layers);
    sh_angle(0, 0deg, 0deg);
    var k: int = interval - 1;               // 非 delayed：首发偏移 39
    if k >= until { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

// Sub36：随机游走 90 帧 → 回中 (192,128) 90 帧；其间自动开环弹
// shoot_interval(40) 在原文 Sub36 T=0 执行，其时序与移动插值同帧起步：伴生任务必须在
// wander 之前 spawn，S 才等于 Sub36 起始帧（§4.3「在设定帧 S spawn」）。
sub sub36(rank: int, i7: int) {
    var ways: int = i7 + 12;                 // math_int_add($I0, $I7, 12/16/24)
    var layers: int = 3;
    var s1: fx = 2.5fx;
    if rank == RANK_NORMAL { ways = i7 + 16; layers = 4; s1 = 3.5fx; }
    else if rank == RANK_HARD { ways = i7 + 24; layers = 4; s1 = 3.5fx; }
    else if rank >= RANK_LUNATIC { ways = i7 + 24; layers = 4; s1 = 3.5fx; }
    spawn autoshoot(40, 180, ways, layers, s1);
    wander(2.5fx, 90);                       // T=0：自带 move_to(90,…)，非阻塞
    wait(90);                                // T=0..90 走完随机游走插值
    move_to(90, 0.0fx, 128.0fx, 2);          // T=90：move_position_time_decelerate(90, 192, 128)
    wait(90);                                // T=90..180
}

// Sub27 Sub27_1448 起的主循环：每轮 $I0 = $I7 mod 2 选 A/B 家族，随后 call Sub36
async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var i7: int = 0;
    var i0: int = 0;
    wait(60);                                // 开场缓冲：E 档首条激光生效落在 120 帧之后（原文进场滑行在段外，见 report）
    loop {
        i0 = i7 % 2;
        // 循环头 T=40；不匹配的 jump_neq(100/160/220, …) 瞬时把 time 置为跳转目标（不耗帧），
        // 故各档都只等 +60：E 40→100、N 100→160、H 160→220、L 220→280（§2.4）。
        wait(60);
        if i0 == 0 { attack_a(rank, i7); } else { attack_b(rank, i7); }
        // 原文攻击末尾 jump(280, Sub27_1964)：把 context time 设为绝对值 280。
        // 攻击是 blocking（body 跑 n 帧），结束后 context time 已 ≥280（E=280、N=340、H=370、L=420），
        // 故 jump 立即生效，Sub36 前不再有等待。之前多补的 wait 把已消耗的帧重复计了一次（返工修正）。
        sub36(rank, i7);
        i7 = i7 + 1;
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 0);        // Sub27 enemy_flag_collision(1)
    set_hitbox(16.0fx);                      // Sub26 enemy_set_hitbox(48, 56, 32) → 48/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    // Sub26 滑行终点 (192,128)（进场在段外）；非符起手 100+ 帧无弹
    _ = spawn_enemy(0.0fx, 128.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
