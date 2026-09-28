---
name: commit-directly-on-main
description: stg-rl-train 里直接在 main 上提交和推送，不要自作主张开功能分支
metadata:
  node_type: memory
  type: feedback
  originSessionId: 382fe7d1-16bd-4ff6-a1e0-e327b85e1ca5
  modified: 2026-09-19T18:31:20.294Z
---

在 stg-rl-train 仓库里，提交直接落在 `main` 上、推 `origin main`，不要另开功能分支。

**Why:** 2026-09-20 我为实验 N1/N2 自己开了 `exp-n-motor-layer` 分支，用户明确说「你别搞分支，直接推 main 上也没错」。这是单人仓库，历史一直是线性地提交在 main 上；训练机靠 `git pull` 拿代码，多一个分支只会多一步 checkout、还可能拉错。

**How to apply:** 用户让提交时，留在 main 上分组 commit；用户让推时 `git push origin main`。提交与推送仍然要等用户开口（他会分别说「提交」和「推一下」）。
