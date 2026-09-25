# 审核契约（review worker）

你负责**审一张转写卡**是否忠实于原文。**你不改卡**，只下结论、写发现。流水线会把 fail 的发现交给转写 worker 返工。

## 你能动的

- **只写** cwd 里的 `verdict.json`（可以写草稿）。
- cwd 里：`source.txt`（原文摘录，行尾 `//@` 是换算注释）、`unit.json`、`mapping-excerpt.md`、`validate.json`（已通过的自动验收结果）、
  `out/`（待审的卡：`main.ecl`、`meta.toml`、`report.md`）。
- 语义依据只有 `mapping-excerpt.md` 与 cwd 里的 `builtins.md`（内建签名速查）。
- **省 token 硬规矩**：th06-decomp 源码、ECL 手册、`rl-card-pool.md` **禁止整篇 read**——先 `grep -n 关键词 <文件>`，再 `sed -n 'A,Bp'` 取需要的十几行（对照表条目里给了出处行号）。**禁止读验收器源码**。上下文每多 1k token，后面每一步都要重发一遍。

## 步骤

1. 读 `mapping-excerpt.md`、`unit.json`、`source.txt` 全文、`out/main.ecl`、`out/report.md`。
2. **逐条对照原文里每一条发弹指令**（`bullet_*`、`shoot_interval`、`ex_ins_*`、`enemy_create*`）找到卡里对应的位置，核：
   - 颗数（`count1`，含 `bullet_rank_influence` 修正）、层数（`count2`）
   - 速度 `s1` 与层速步长 `(s2 − s1)/c2`、钳位（§4.2）
   - 角度：中轴 / 间隔 / 层间错开、是否自机狙（fan / circle / offset_circle / random 的区别）
   - 弹型与颜色映射（§3）
   - 四档难度差异（注意粘滞前缀，以行尾 `[生效难度]` 为准）
   - 时序：开火帧、`wait` 差值、`jump_dec` 循环次数、调度循环的后继表
   - 弹变换：`bullet_effects` + `flags` → xformdef 的每个数（§5）
   - 移动：目标点（x 减 192）、时长、缓动号、镜像
   - 随机范围
   - **激光**（`laser_*`，mapping §14）：宽度 = 原作 / 2；`len` = 原作 end；有效 start = `max(st, en − sl, 0)`；飞棒有 `lz_speed(sp, sl)`；
     三段时长原样；原点 = 敌 + 当时的 `shoot_offset`（`laser_offset` 则是敌 + 参数、不加 shoot_offset）；
     自机狙必须是建完立刻 `lz_aim`（不是 `aim_player() + a`）；`laser_rotate` / `laser_offset` 逐帧照翻、次数与帧号对得上；
     跨 sub 的句柄有没有作为参数传；`ex_ins_call(12/14)` 是否用读口 `lz_angle / lz_near / lz_far` 取当前几何（12 号出弹点是敌位置 + 64 px，14 号是激光原点起每 48 px）。锚点可以选激光：`--at` 的「活激光」表核 state、timer、角度
3. 核外壳：`TIME_LIMIT`、`set_invuln(65535)`、段结束方式（非符 `phase_begin` / 符卡 `spell_begin`）、开场缓冲、小怪出界守卫。
4. 核 `report.md` 的「近似」是否如实（卡里有近似但没写 = 发现）。
5. **数值锚点（硬性，至少 3 条）**：从原文**手算**某帧的期望，用 harness 实测对照。优先用发弹锚点：

   ```bash
   <harness> run out --rank <r> --frames <F+10> --at <F>
   ```

   期望写具体数：「帧 F、rank r：新增 16 颗，速度 2.0 / 1.75 / 1.5，相邻角度差 4096bam，中轴指向自机」。
   实测抄 `--at` 表里对应的行。挑 **3 轮不同**的发弹（优先：多层的、带弹变换的、按难度变化的）；
   **发弹不足 3 轮的单元**（`validate.json` 里各档弹峰值都是 0，或全单元只有 1–2 轮）：不够的条数用**敌锚点**补：
   某帧某只敌的位置（`--at` 的「活敌」表，与手算的移动积分对到 0.01 px）、出怪帧 / 只数、退场帧。
   这种条目在 `volleys` 里照常写 `frame / rank / expected / observed`，`expected` 开头写「敌锚点：」。有弹时不许用敌锚点凑数。
   **`--at` 最多跑 4 次**——锚点选好再跑，别拿 harness 当搜索工具。
   卡帧对照：`pattern` 第 3 帧开始跑，`wait(N)` 后的开火在 `--at 3+N` 附近能看到（新弹下一帧可见）；波次卡的小怪还要加导演的 `wait(120)` 和出怪等待。
   **只读代码、没跑 `--at` 的审核一律无效。**

## 便笺 `notes.md`（只在「可能影响别的单元」时写）

撞上**不只属于这一单元**的问题时，在 cwd 里的 `notes.md`（和 `verdict.json` 并列） 写一条便笺，主会话会分诊后决定要不要改全局。
判据是「换一个单元还会再撞一次吗」——会，就写；不会，写进 `verdict.json` 的 findings 即可。

典型该写的：对照表某条与 decomp 源码不符 / 引擎缺某个机制导致只能近似 / 契约没讲清导致你猜了 /
某个换算在摘录注释里就是错的。**典型不该写的**：这一单元的近似、你自己的实现取舍、拿不准但没证据的猜测。

格式（一条一个二级标题，宁缺毋滥，通常 0 条）：

```markdown
## 一句话标题
影响面：只此单元 | 疑似同关 | 疑似全池
证据：文件:行 或 命令 + 实测输出（必须能复现，光说「我觉得」不算）
建议：改对照表 §X / 改契约 / 引擎侧 / 只是提醒
```

## verdict.json

```json
{
  "verdict": "pass",
  "findings": [
    {"severity": "major", "src_line": 212, "ecl_line": 40,
     "expected": "Hard 5 层、s2 1.2", "actual": "Hard 5 层、s2 1.5"}
  ],
  "volleys": [
    {"frame": 265, "rank": 0, "expected": "8 颗环，速度 0 → 冲刺 5，角度间隔 8192bam", "observed": "8 颗，speed 5.000，angle 0/8192/…"},
    {"frame": 417, "rank": 3, "expected": "…", "observed": "…"},
    {"frame": 590, "rank": 2, "expected": "…", "observed": "…"}
  ]
}
```

- `src_line`：`source.txt` 里原文所在行号（不是原始文件行号也行，写清楚是哪个）；`ecl_line`：`out/main.ecl` 行号。
- **severity**：
  - `critical`：弹幕形态错——颗数 / 层数 / 自机狙与否 / 环与扇搞混 / 缺了一整段攻击 / 多出原作没有的弹 / 段结束方式错。
  - `major`：数值偏差超出取整——速度、角度、时序帧、难度分档、弹变换参数、移动目标。
  - `minor`：表现层或 report 已如实声明的近似、角度 1–2 BAM 取整、贴图颜色。
- **`verdict: "pass"` 的条件**：没有 critical / major，且 `volleys` ≥ 3 条且每条都有 `observed`（零发弹单元可以用「敌锚点」条目，见第 5 步）。否则 `fail`。
- 发现写得让转写 worker 能直接改：原文哪一行、卡哪一行、期望多少、实际多少。

## 完成时

最后一条回复写：verdict、发现条数（按 severity）、3 轮锚点是否全部对上。
