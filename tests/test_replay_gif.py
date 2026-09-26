"""评测局操作回放：缓冲解码与 RawObs 对齐、GIF 帧时长、端到端出图（需 stg-engine 弹图集）。"""
import pytest
import torch
from PIL import Image

from conftest import small_cfg
from stgtrain import replay_gif as R
from stgtrain.cards import compile_cards, discover
from stgtrain.envwrap import EnvWrapper
from stgtrain.registry import load_builtins
from stgtrain.train import make_run_dir, train
from stgtranscribe import preview


def test_decode_env_matches_rawobs(cfg):
    import stg_rl

    load_builtins()
    cards = discover(cfg["env"]["cards_dir"])
    images = compile_cards(cards)
    envw = EnvWrapper(cfg, images, [stg_rl.Start("example_ring", 0, 2)], torch.device("cpu"), seed=5,
                      num_envs=3, mirror=False)
    obs = envw.reset()
    for _ in range(90):
        obs, _info = envw.step(torch.zeros(3, dtype=torch.int64))
    for i in range(3):
        f = R.decode_env(envw.buf, i)
        n = len(f.bullets)
        assert n > 0, "example_ring 90 帧后应有弹"
        got = torch.tensor([[b.x, b.y] for b in f.bullets])
        assert torch.allclose(got, obs.bullets[i, :n, :2]), "不镜像时缓冲解码的弹坐标应与 RawObs 一致"
        assert f.player == pytest.approx(tuple(obs.player_xy[i].tolist()))


def test_decode_lasers_matches_rawobs_and_renders():
    import math

    import stg_rl

    from conftest import FIXTURES
    from stgtrain.envwrap import LASER_COLS

    load_builtins()
    C = {name: k for k, name in enumerate(LASER_COLS)}
    images = compile_cards(discover(FIXTURES / "laser_cards"))
    envw = EnvWrapper(small_cfg(), images, [stg_rl.Start("example_laser", 0, 2)], torch.device("cpu"), seed=5,
                      num_envs=3, mirror=False)
    envw.reset()
    for _ in range(140):
        obs, _info = envw.step(torch.zeros(3, dtype=torch.int64))
    seen = 0
    for i in range(3):
        lz = R.decode_env(envw.buf, i).lasers
        k = int(obs.lasers_mask[i].sum())
        assert len(lz) == k
        seen += k
        for j, l in enumerate(lz):
            row = obs.lasers[i, j]
            assert (l.ox, l.oy, l.start, l.end) == pytest.approx(
                (row[C["x"]].item(), row[C["y"]].item(), row[C["start"]].item(), row[C["end"]].item()), abs=1e-4)
            assert math.radians(l.deg) == pytest.approx(row[C["angle"]].item(), abs=1e-4)
            assert l.width == pytest.approx(2 * row[C["half_h"]].item()) and l.state == int(row[C["state"]])
    assert seen > 0
    im = preview.draw_lasers(Image.new("RGB", (preview.FIELD_W, preview.FIELD_H + preview.HEADER_H)),
                             R.decode_env(envw.buf, 0).lasers)
    assert im.getbbox() is not None or not R.decode_env(envw.buf, 0).lasers


def test_laser_warn_display_ramps_by_t_active():
    """t_active 30 → 细线、0 → 近全宽（换算成 preview 的 warn / timer）。"""
    def width(t):
        return preview.laser_display(preview.Laser(0, 0, 0, 0, 100, 20.0, 0, R.LASER_RAMP - t, R.LASER_RAMP, 2, 13))[0]
    assert width(30) == pytest.approx(1.2) and width(0) == pytest.approx(20.0) and width(15) < width(5)


def test_gif_durations_average_to_real_time():
    d = R.gif_durations(n=6, frames_per_image=2)   # 2 帧 = 33.3 ms，GIF 只有 10 ms 精度
    assert all(x % 10 == 0 for x in d) and sum(d) == 200


@pytest.mark.skipif(not preview.atlas_path().exists(), reason="没有 stg-engine 弹图集")
def test_replay_gif_end_to_end(tmp_path):
    cfg = small_cfg(run={"total_updates": 1, "ckpt_every": 1, "eval_every": 1})
    run_dir = make_run_dir(tmp_path, "ck")
    train(cfg, run_dir, pack_result=False)
    out = tmp_path / "replay"
    assert R.main([str(run_dir / "checkpoints" / "best.pt"), "--device", "cpu", "--cards", "example_ring",
                   "--episodes", "0,2", "--max-frames", "120", "--every", "4", "--out", str(out)]) == 0
    gifs = sorted(out.glob("*.gif"))
    assert [g.name for g in gifs] == ["example_ring_r2_e0.gif", "example_ring_r2_e2.gif"]
    im = Image.open(gifs[0])
    assert im.size == (preview.FIELD_W, preview.FIELD_H + preview.HEADER_H + R.HUD_H) and im.n_frames >= 20
