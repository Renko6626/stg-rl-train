const LASER_COLOR_A: int = 2;
const LASER_COLOR_B: int = 5;

async sub stagger_pattern() {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var active: int = 150;
    var separation: fx = 112.0fx;
    if rank == 1 {
        width = 8.0fx;
        active = 170;
        separation = 96.0fx;
    }
    if rank == 2 {
        width = 10.0fx;
        active = 190;
        separation = 80.0fx;
    }
    if rank >= 3 {
        width = 12.0fx;
        active = 210;
        separation = 68.0fx;
    }

    var warn: int = 90;
    if rank == 1 { warn = 75; }
    if rank == 2 { warn = 60; }
    if rank >= 3 { warn = 45; }

    wait(90);
    var wave: int = 0;
    while wave < 19 {
        // Eight broad diagonal phases cover three interior height bands.
        // Each wave randomizes its interior origin and BAM angle before warning begins.
        var phase: int = wave % 8;
        var center_x: fx = (-136 + rand(136)) as fx;
        var center_y: fx = (224 + rand(65)) as fx;
        var theta: angle = 45deg;
        if phase == 1 { theta = 135deg; }
        if phase == 2 {
            center_y = (288 + rand(65)) as fx;
            theta = 45deg;
        }
        if phase == 3 {
            center_y = (288 + rand(65)) as fx;
            theta = 135deg;
        }
        if phase == 4 {
            center_y = (320 + rand(72)) as fx;
            theta = 315deg;
        }
        if phase == 5 {
            center_y = (320 + rand(72)) as fx;
            theta = 225deg;
        }
        if phase == 6 {
            center_y = (256 + rand(65)) as fx;
            theta = 315deg;
        }
        if phase == 7 {
            center_y = (256 + rand(65)) as fx;
            theta = 225deg;
        }
        // rand(9102)-4551 is [-4551,4551) BAM, about ±25 degrees.
        theta = theta + ((rand(9102) - 4551) as angle);
        var color: int = LASER_COLOR_A;
        if phase % 2 == 1 {
            center_x = rand(136) as fx;
            color = LASER_COLOR_B;
        }
        var dx: fx = separation / 2 * cos(theta + 90deg);
        var dy: fx = separation / 2 * sin(theta + 90deg);
        var x1: fx = center_x - dx;
        var y1: fx = center_y - dy;
        var x2: fx = center_x + dx;
        var y2: fx = center_y + dy;
        var first: int = laser(color, x1, y1, theta, 640.0fx, width, warn, active, 12);
        var second: int = laser(color, x2, y2, theta, 640.0fx, width, warn, active, 12);
        wave = wave + 1;
        if wave < 19 { wait(72); }
    }
    loop { wait(1); }
}

async sub fixed_boss() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_hitbox(0.0fx);
    set_hurtbox(0.0fx);
    phase_begin(0, stagger_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 100000, 0, 0, 1, fixed_boss);
    loop { wait(1); }
}
