// TH18 v1.00a BossCard1 only. int0=next-step, int1=source end, int2=source start, int3=sampled ray count; fx0/1=logical unit vector.
// All source wait(n) inside this attack must use card_wait(n), in the same owner task.
// No new task: emit uses the current position, phase5 then performs the next source movement tick.
sub card_arm_next_step() {
    var k: int = self_int(0)+1;
    set_self_int(0, k);
    var speed: fx = 0fx;
    if k < 60 { speed = 1.7fx*((60-k) as fx)/60; }
    var nx: fx = $self_x+self_fx(0)*speed;
    var ny: fx = $self_y+self_fx(1)*speed;
    if nx < -60fx { nx = -60fx; }
    if nx > 60fx { nx = 60fx; }
    if ny < 96fx { ny = 96fx; }
    if ny > 160fx { ny = 160fx; }
    move_vel_xy(0, nx-$self_x, ny-$self_y, EASE_LINEAR);
}
sub card_begin_angle(a: angle) {
    set_self_fx(0, cos(a));
    set_self_fx(1, sin(a));
    set_self_int(0, 0);
    card_arm_next_step();
}
sub card_move_rand() {
    // Source 405b90 = signed unit random * pi. Values below are unwrapped BAM ints.
    var r: int = rand(65536)-32768;
    var a: int = r/3;
    if $self_x < -30fx {
        a = r/3;
    } else if $self_x > 30fx {
        a = r/3+32768;
        if a > 32768 { a = a-65536; } // source explicitly normalizes this branch
    } else {
        a = r/4;
        var choose: int = rand(65536)%3; // source WORD modulo3, including its tiny bias
        if $player_x > $self_x {
            if choose == 0 { a = a+32768; }
        } else {
            if choose != 0 { a = a+32768; }
        }
        // Deliberately do not normalize this branch before the source fabs tests.
    }
    if $self_y < 112fx {
        if a < 0 { a = -a; }
    } else if $self_y > 144fx {
        if a < 0 { a = -a; }
        a = -a;
    }
    // Native +/-pi/2 guard, epsilon0.05rad. Nearest BAM boundaries (normal angle quantization).
    if a > -16906 && a < -15862 {
        if a < -16384 { a = -16906; } else { a = -15862; }
    } else if a > 15862 && a < 16906 {
        if a < 16384 { a = 15862; } else { a = 16906; }
    }
    card_begin_angle(a as angle);
}
sub card_wait(frames: int) {
    for i in 0..frames {
        wait(1);
        if $frame >= self_int(1) { move_vel(0, 0deg, 0fx, EASE_LINEAR); return; }
        card_arm_next_step();
    }
}
