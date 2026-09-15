# RL 卡池

一张卡 = 一个子目录（`main.ecl` + 可选 `meta.toml`）。写作约束见 stg-engine 仓 `docs/rl-card-pool.md`。
评测留出卡在 `eval/splits.toml` 里列出；其余卡全部用于训练。

## 东方原作转写卡（`th06_*`）

`th06_*` 目录是东方红魔乡（© 上海アリス幻樂団 / ZUN）ECL 弹幕的**转写**：只含按原作数值重写的本引擎 `.ecl` 脚本与元数据，
不含原作的程序、贴图、音频或 ECL 原文。依东方 Project 二次创作规约，非商用，出处写在每张卡 `meta.toml` 的 `origin` / `source_ref`。
转写流程与对照表见 `transcribe/README.md`。
