const BEAM_LEN: fx = 640.0fx;
const LINE_T: fx = -150.0fx;
const INV_SQRT2: fx = 0.7071fx;
const MOVE_FRAMES: int = 180;
const ACTIVE_FRAMES: int = 180;

async sub translated_corridor(direction: int, midpoint: fx, wave: int, waves: int) {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var warning: int = 90;
    var pitch: fx = 72.0fx;
    var speed: fx = 0.72fx;

    if rank == 1 {
        width = 8.0fx;
        warning = 75;
        pitch = 64.0fx;
        speed = 0.80fx;
    }
    if rank == 2 {
        width = 10.0fx;
        warning = 60;
        pitch = 58.0fx;
        speed = 0.90fx;
    }
    if rank == 3 {
        width = 12.0fx;
        warning = 45;
        pitch = 56.0fx;
        speed = 1.00fx;
    }

    // One shared normal offset preserves the fixed corridor width. The inclusive
    // integer draw gives a common center shift in [-24, 24] pixels. The first
    // and last wave use the corresponding endpoint to sweep both corner limits.
    var shift: fx = (rand(49) - 24) as fx;
    if wave == 0 {
        shift = -24.0fx;
    }
    if wave == waves - 1 {
        shift = 24.0fx;
    }
    var normal_center: fx = midpoint + shift - speed * MOVE_FRAMES / 2;
    if direction == -1 {
        normal_center = midpoint + shift + speed * MOVE_FRAMES / 2;
    }
    var half_pitch: fx = pitch / 2;
    var q1: fx = normal_center - half_pitch;
    var q2: fx = normal_center + half_pitch;
    var x1: fx = INV_SQRT2 * (LINE_T - q1);
    var y1: fx = INV_SQRT2 * (LINE_T + q1);
    var x2: fx = INV_SQRT2 * (LINE_T - q2);
    var y2: fx = INV_SQRT2 * (LINE_T + q2);
    var lz1: int = laser(4, x1, y1, 45deg, BEAM_LEN, width, warning, ACTIVE_FRAMES, 12);
    var lz2: int = laser(10, x2, y2, 45deg, BEAM_LEN, width, warning, ACTIVE_FRAMES, 12);

    // Move both origins continuously along the 135-degree normal; neither beam
    // rotates or jumps. One update per frame across the full active interval.
    var dq: fx = speed * direction;
    wait(warning);
    for frame in 0..MOVE_FRAMES {
        q1 = q1 + dq;
        q2 = q2 + dq;
        x1 = INV_SQRT2 * (LINE_T - q1);
        y1 = INV_SQRT2 * (LINE_T + q1);
        x2 = INV_SQRT2 * (LINE_T - q2);
        y2 = INV_SQRT2 * (LINE_T + q2);
        lz_origin(lz1, x1, y1);
        lz_origin(lz2, x2, y2);
        wait(1);
    }
    loop { wait(1); }
}

async sub laser_pattern() {
    var rank: int = global(GVAR_RANK);
    var waves: int = 17;
    var period: int = 84;
    var center_min: fx = -8.0fx;
    var center_max: fx = 329.0fx;
    if rank == 1 {
        waves = 18;
        period = 78;
        center_max = 324.0fx;
    }
    if rank == 2 {
        waves = 20;
        period = 72;
        center_min = 0.0fx;
        center_max = 316.0fx;
    }
    if rank == 3 {
        waves = 22;
        period = 66;
        center_min = 8.0fx;
        center_max = 309.0fx;
    }
    var direction: int = 1;
    if rand(2) == 0 {
        direction = -1;
    }
    wait(90);
    for wave in 0..waves {
        var midpoint: fx = center_min + (center_max - center_min) * wave / (waves - 1);
        spawn translated_corridor(direction, midpoint, wave, waves);
        direction = direction * -1;
        wait(period);
    }
    loop { wait(1); }
}

async sub fixed_boss() {
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_invuln(65535);
    phase_begin(0, laser_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1, 0, 0, 1, fixed_boss);
    loop { wait(1); }
}
