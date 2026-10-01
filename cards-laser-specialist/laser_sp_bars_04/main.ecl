const SPELL_BARS: int = 1;

async sub translated_bar(x0: fx, y0: fx, direction: angle, width: fx, length: fx,
                         warning: int, active: int, dx: fx, dy: fx) {
    var lz: int = laser(6, x0, y0, direction, length, width, warning, active, 12);
    wait(warning);
    var x: fx = x0;
    var y: fx = y0;
    for i in 0..active {
        if lz_alive(lz) == 1 {
            x = x + dx;
            y = y + dy;
            lz_origin(lz, x, y);
        }
        wait(1);
    }
}

async sub bars_pattern() {
    wait(90);
    var rank: int = global(GVAR_RANK);
    var warning: int = 90;
    var width: fx = 6.0fx;
    if rank == 1 { warning = 75; width = 8.0fx; }
    if rank == 2 { warning = 60; width = 10.0fx; }
    if rank == 3 { warning = 45; width = 12.0fx; }

    for batch in 0..16 {
        var joint: int = rand(4);
        var lateral: int = joint * 2 - 3;
        var active: int = 150 + joint * 20;
        var speed: fx = 0.8fx + joint as fx * 0.05fx;
        if rank == 1 { speed = 1.05fx + joint as fx * 0.05fx; }
        if rank == 2 { speed = 1.35fx + joint as fx * 0.05fx; }
        if rank == 3 { speed = 1.7fx + joint as fx * 0.1fx; }

        var lane_group: int = batch / 2;
        if batch % 2 == 1 { lane_group = (batch - 1) / 2; }
        var lane0: int = lane_group * 4;
        var lane1: int = lane0 + 1;
        var lane2: int = lane0 + 2;
        var lane3: int = lane0 + 3;
        var y0: fx = (lane0 * 448 / 31) as fx;
        var y1: fx = (lane1 * 448 / 31) as fx;
        var y2: fx = (lane2 * 448 / 31) as fx;
        var y3: fx = (lane3 * 448 / 31) as fx;
        var x0: fx = (-192 + lane0 * 384 / 31) as fx;
        var x1: fx = (-192 + lane1 * 384 / 31) as fx;
        var x2: fx = (-192 + lane2 * 384 / 31) as fx;
        var x3: fx = (-192 + lane3 * 384 / 31) as fx;
        if lane0 > 0 && lane0 < 31 { y0 = y0 + lateral as fx; x0 = x0 + lateral as fx; }
        if lane1 > 0 && lane1 < 31 { y1 = y1 + lateral as fx; x1 = x1 + lateral as fx; }
        if lane2 > 0 && lane2 < 31 { y2 = y2 + lateral as fx; x2 = x2 + lateral as fx; }
        if lane3 > 0 && lane3 < 31 { y3 = y3 + lateral as fx; x3 = x3 + lateral as fx; }

        var raw0: int = rand(81);
        var raw1: int = rand(81);
        var raw2: int = rand(81);
        var length0: fx = 40.0fx + raw0 as fx;
        var length1: fx = 40.0fx + raw1 as fx;
        var length2: fx = 40.0fx + raw2 as fx;
        var length3: fx = 40.0fx + ((raw0 + raw1 + raw2) % 81) as fx;
        var dx: fx = speed;
        var dy: fx = 0.0fx;
        if batch % 4 == 0 {
            spawn translated_bar(-180.0fx, y0, 0deg, width, length0, warning, active, dx, dy);
            spawn translated_bar(-180.0fx, y1, 0deg, width, length1, warning, active, dx, dy);
            spawn translated_bar(-180.0fx, y2, 0deg, width, length2, warning, active, dx, dy);
            spawn translated_bar(-180.0fx, y3, 0deg, width, length3, warning, active, dx, dy);
        } else if batch % 4 == 2 {
            dx = 0.0fx - speed;
            spawn translated_bar(180.0fx, y0, 180deg, width, length0, warning, active, dx, dy);
            spawn translated_bar(180.0fx, y1, 180deg, width, length1, warning, active, dx, dy);
            spawn translated_bar(180.0fx, y2, 180deg, width, length2, warning, active, dx, dy);
            spawn translated_bar(180.0fx, y3, 180deg, width, length3, warning, active, dx, dy);
        } else if batch % 4 == 1 {
            dx = 0.0fx;
            dy = speed;
            spawn translated_bar(x0, 0.0fx, 90deg, width, length0, warning, active, dx, dy);
            spawn translated_bar(x1, 0.0fx, 90deg, width, length1, warning, active, dx, dy);
            spawn translated_bar(x2, 0.0fx, 90deg, width, length2, warning, active, dx, dy);
            spawn translated_bar(x3, 0.0fx, 90deg, width, length3, warning, active, dx, dy);
        } else {
            dx = 0.0fx;
            dy = 0.0fx - speed;
            spawn translated_bar(x0, 448.0fx, 270deg, width, length0, warning, active, dx, dy);
            spawn translated_bar(x1, 448.0fx, 270deg, width, length1, warning, active, dx, dy);
            spawn translated_bar(x2, 448.0fx, 270deg, width, length2, warning, active, dx, dy);
            spawn translated_bar(x3, 448.0fx, 270deg, width, length3, warning, active, dx, dy);
        }
        wait(82 + joint * 2);
    }
    loop { wait(1); }
}

async sub boss() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, bars_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 300, 1, 1000, 1, boss);
    loop { wait(1); }
}
