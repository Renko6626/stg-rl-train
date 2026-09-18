# 切分契约（split worker）

你负责**一关**：把 TH06 这一关的 ECL 切成转写单元，写出 `split.json`。你不写 `.ecl`。

## 你能动的

- **只写** 工作目录（cwd）里的 `split.json`（可以写草稿文件，但别写到 cwd 以外——写不进去）。
- 读：cwd 里的 `structure.md`（结构摘要）、prompt 里给的原文路径、`mapping.md`（§2.4 回调链、§9 段结构）。

## note 里别写错的几个点

`note` 是给转写 worker 看的摘要，写错会直接误导（第 5 关 w07 就被「直下 2.5」带偏过）：

- `move_velocity(a, s)` 的**第一参是角度、第二参是速度**（decomp `EclManager.cpp:330-335`），
  `0.0f` = 0° = **水平向右**，不是向下。拿不准就照抄原文，别翻译成人话。
- 同理 `move_rand(a0, a1)` 两参都是角度、`move_speed(s)` 只有速度。
- 帧号写「timeline 绝对帧」还是「块内帧」要写清楚。

## 单元是什么

| 类型 | id | 内容 |
|---|---|---|
| 小怪波 | `th06_s<关>_w01`、`w02`…（按时间顺序） | timeline 上一段连续的出怪（`enemy_create*`），不含 boss 登场 |
| 中 boss 段 | `th06_s<关>_mb1`、`mb2`… | 中 boss 的一个非符段或一张符卡 |
| boss 段 | `th06_s<关>_b1`、`b2`… | 关底 boss 的一个非符段或一张符卡（按实战出现顺序） |

一关里先登场的 boss 是中 boss（`mb`），关底的是 `b`。Stage 7（Extra）同理。

## 步骤

1. 读 `structure.md` 全文。timeline 表里 `**BOSS**` 是 boss 登场，`↓ 间隙 N 帧` 是出怪空档；sub 表列出每个 sub 的回调、符卡、激光。
2. **切波次**：
   - 每条非 boss 的 `enemy_create*` **恰好属于一个波次**，波次之间不重叠；
   - 一个编队（同一批 sub、间隔规律的一串出怪）不要拆开；间隙 ≥ 100 帧通常是波次边界，但要看编队；
   - `tail` = 最后一只怪出生后到它离场的帧数：读它的 sub，估算飞出屏幕或 `enemy_delete` 的时间（常见 200–400）；
   - **`120 + (t_end − t_start) + tail ≤ 3000`**，超了就拆；
   - 对话（`read_msg`/`wait_msg`）和 boss 登场不能落在波次范围内。
3. **切 boss 段**：从 timeline 上 boss 登场的 sub 出发，沿回调链走（mapping §9）：
   - `life_callback_sub` / `timer_callback_sub` / `death_callback_sub` / `enemy_interrupt_set` 都是**跳转**，每跳一次通常进入下一段；
   - 每段写：
     - `entry`：这一段的攻击从哪个 sub 开始（通常是回调目标 sub，它常常 `call` 宣言 sub + 模式 sub）；
     - `start_label`：boss 登场设置和首段攻击写在同一个 sub 里时，攻击从哪个 `+N` 起（如 `"+160"`），否则省略；
     - `parallel`：同一段里另外并行跑、但 entry 的 call 闭包够不着的 sub（少见），否则省略；
     - `ranks`：**回调按难度分叉**（如 `!NHL life_callback_sub("Sub26")` 但 `!E timer_callback_sub("Sub19")`），这段只在哪几档出现就写哪几档，必须是连续区间 `[lo, hi]`（0=E … 3=L；Stage 7 一律 `[4, 4]`）；不连续就拆成两个单元；
     - `time_limit`：这一段生效的 `timer_callback_threshold` 原值（**不要钳到 3000**），`time_limit_origin: "timer"`；阈值写在 entry 闭包以外的 sub 里（比如写在上一段设置回调的 sub），用 `timer_sub` 指明那个 sub；原文确实没有时间回调的，给估计值并写 `"estimated"`，在 `note` 里说依据；
     - `kind`：闭包里有 `spellcard_start` 是 `spell`（写 `spell_key`，即第 3 参的字符串），否则 `nonspell`；
     - `hp_threshold`：进入下一段的血量阈值（仅记录，可省略）。
   - **符卡练习入口 sub**（形如 `call("Sub32"); … life_callback_threshold(0); … call("宣言"); call("模式")`，见 mapping §9）不是实战段，不单列；但它们调用的宣言 / 模式 sub 必须出现在某个实战段的闭包里。
4. **标 skip**：`structure.md` 里标 `**含 laser**` / `**含 ex_ins_N**` / `**含 dialogue**` 的 sub 进了某个单元的闭包，该单元写 `"skip": "laser"`（或对应原因）。skip 的单元照样要列出来，只是不转写。
5. 写 `split.json`，然后**自检**直到通过：

   ```bash
   cd <训练仓> && PYTHONDONTWRITEBYTECODE=1 .venv/bin/python -m stgtranscribe.split_check <关> <cwd>/split.json
   ```

   它会逐条告诉你哪里不对（覆盖、重叠、时限、闭包、skip、符卡名）。**必须输出 `OK` 才算完成。**

## split.json 格式

```json
{
  "stage": 1,
  "waves": [
    {"id": "th06_s1_w01", "t_start": 100, "t_end": 1064, "tail": 300, "note": "Sub0/Sub2 两翼 + Sub3/Sub4 交替"},
    {"id": "th06_s1_w02", "t_start": 1174, "t_end": 1354, "tail": 300, "note": "随机位置小怪"}
  ],
  "bosses": [
    {"spawn_t": 1882, "spawn_sub": "Sub9", "phases": [
      {"id": "th06_s1_mb1", "kind": "nonspell", "entry": "Sub9", "start_label": "+160", "ranks": [0, 3],
       "time_limit": 1440, "time_limit_origin": "timer", "hp_threshold": 500, "note": "超时跳 Sub8 退场"},
      {"id": "th06_s1_mb2", "kind": "spell", "entry": "Sub10", "ranks": [2, 3], "time_limit": 1320,
       "time_limit_origin": "timer", "spell_key": "ST_ECLDATA1_SUB9_0", "skip": "laser"}
    ]}
  ]
}
```

（上例只示意字段，数值以你读到的原文为准。）

## 完成时

最后一条回复写：单元总数、各类型个数、skip 了哪些及原因、你拿不准的地方（写进对应单元的 `note`）。
