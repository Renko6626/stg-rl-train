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
