"""Plot measured cadence screening results and same-round ONNX cost."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from request_execution import sha


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("report", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    a = ap.parse_args()
    d = json.loads(a.report.read_text())
    intervals = d["intervals"]
    cohorts = [("all", "Overall", "#26374a"), ("ordinary", "Ordinary", "#008b81"),
               ("lasers", "Lasers", "#d26932")]
    values = [d["arms"][f"{mode}-i{i}"]["summaries"][k]["survival"] * 100
              for mode in ("deploy", "free") for i in intervals for k,_,_ in cohorts]
    low = max(0, math.floor(min(values) / 10) * 10 - 10)
    with plt.rc_context({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False}):
        fig, axes = plt.subplots(1, 3, figsize=(14, 4.5), constrained_layout=False)
        for ax, mode, title in zip(axes[:2], ("deploy", "free"),
                                   ("AUTO: boss + pressure switching", "Free dodge")):
            for key, label, color in cohorts:
                y = [d["arms"][f"{mode}-i{i}"]["summaries"][key]["survival"] * 100 for i in intervals]
                ax.plot(intervals, y, "o-", color=color, label=label, linewidth=1.8, markersize=5)
            ax.set(title=title, ylabel="Pass rate (%)", ylim=(low, 101))
            ax.legend(frameon=False, fontsize=9)
        ax = axes[2]
        cost = [d["onnx_benchmark"]["benchmark"][str(i)]["median_ms_per_game_frame"] for i in intervals]
        ax.plot(intervals, cost, "o-", color="#596db6", linewidth=1.8)
        for x, y in zip(intervals, cost):
            ax.annotate(f"{y:.2f}", (x, y), xytext=(0, 7), textcoords="offset points", ha="center", fontsize=9)
        ax.set(title="ONNX: ORT 1.22, CPU single thread", ylabel="ONNX work per game frame (ms)", ylim=(0, max(cost)*1.18))
        for ax in axes:
            ax.set_xticks(intervals)
            ax.set_xlabel("Inference interval (game frames)")
            ax.grid(axis="y", color="#dfe4e8", linewidth=.7)
            ax.set_axisbelow(True)
        fig.suptitle("T8 inference cadence screening", fontsize=15, x=.06, ha="left", y=.98)
        fig.text(.06, .025, "13 original cards; Hard/Lunatic; 16 episodes/card/rank; seed 12345. Lines connect measured points; interval 5 was not tested.", fontsize=9, color="#52606d")
        fig.subplots_adjust(left=.06, right=.98, top=.84, bottom=.18, wspace=.30)
        a.out.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(a.out, dpi=170, metadata={"Description": f"Source: {a.report}, SHA256 {sha(a.report)}"})
        plt.close(fig)
    print(a.out)


if __name__ == "__main__":
    main()
