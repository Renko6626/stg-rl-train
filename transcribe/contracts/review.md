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
3. 核外壳：`TIME_LIMIT`、`set_invuln(65535)`、段结束方式（非符 `phase_begin` / 符卡 `spell_begin`）、开场缓冲、小怪出界守卫。
4. 核 `report.md` 的「近似」是否如实（卡里有近似但没写 = 发现）。
5. **数值锚点（硬性，至少 3 轮）**：从原文**手算**某一轮弹在某帧的期望，用 harness 实测对照：

   ```bash
   <harness> run out --rank <r> --frames <F+10> --at <F>
   ```

   期望写具体数：「帧 F、rank r：新增 16 颗，速度 2.0 / 1.75 / 1.5，相邻角度差 4096bam，中轴指向自机」。
   实测抄 `--at` 表里对应的行。挑 **3 轮不同**的发弹（优先：多层的、带弹变换的、按难度变化的）；
   **`--at` 最多跑 4 次**——锚点选好再跑，别拿 harness 当搜索工具。
   卡帧对照：`pattern` 第 3 帧开始跑，`wait(N)` 后的开火在 `--at 3+N` 附近能看到（新弹下一帧可见）；波次卡的小怪还要加导演的 `wait(120)` 和出怪等待。
   **只读代码、没跑 `--at` 的审核一律无效。**

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
- **`verdict: "pass"` 的条件**：没有 critical / major，且 `volleys` ≥ 3 条且每条都有 `observed`。否则 `fail`。
- 发现写得让转写 worker 能直接改：原文哪一行、卡哪一行、期望多少、实际多少。

## 完成时

最后一条回复写：verdict、发现条数（按 severity）、3 轮锚点是否全部对上。
