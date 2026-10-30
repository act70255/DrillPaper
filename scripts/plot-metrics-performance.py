"""以已分析的 RC 06 證據產生無視窗圖表，不接觸受測程序。"""

import csv
import json
import logging
from pathlib import Path
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def main() -> None:
    """讀取五組已完成分析，產生可分享的靜態驗收圖。

    Raises:
        ValueError: 必填路徑、量測或分析未完成。
        OSError: 證據讀取或圖檔寫入失敗。
    """
    if len(sys.argv) != 3:
        raise ValueError("必須指定證據根目錄與輸出 PNG 完整路徑。")
    root, output = Path(sys.argv[1]), Path(sys.argv[2])
    if not root.is_dir() or not output.is_absolute():
        raise ValueError("證據根目錄必須存在，輸出必須是完整路徑。")
    folders = ["minimal-single2", "DashboardSingle", "MinimalMulti", "DashboardMulti", "DashboardPaused"]
    summaries = [json.loads((root / folder / "summary.json").read_text(encoding="utf-8-sig")) for folder in folders]
    if any(not item["durationMet"] or item["collectionResult"] != "COMPLETED" for item in summaries):
        raise ValueError("尚有量測未完成，拒絕產生完整矩陣圖。")
    with (root / folders[0] / "resources.csv").open(encoding="utf-8-sig", newline="") as stream:
        rows = [{key: float(value) for key, value in row.items()} for row in csv.DictReader(stream)]
    minutes = [(row["seconds"] - rows[0]["seconds"]) / 60 for row in rows]
    plt.rcParams["font.sans-serif"] = ["Microsoft JhengHei", "DejaVu Sans"]
    plt.rcParams["axes.unicode_minus"] = False
    figure, axes = plt.subplots(2, 2, figsize=(13, 8), layout="constrained")
    axes[0, 0].plot(minutes, [row["private"] for row in rows], color="#245e9b", linewidth=1.4)
    axes[0, 0].set(title="Minimal 單目標：完整程序樣本的 Private Bytes", xlabel="量測時間（分鐘）", ylabel="合計 MiB")
    axes[0, 1].plot(minutes, [row["handles"] for row in rows], color="#245e9b", label="Handles")
    axes[0, 1].set(xlabel="量測時間（分鐘）", ylabel="Handles", title="Minimal 單目標：程序資源趨勢")
    right = axes[0, 1].twinx()
    right.plot(minutes, [row["threads"] for row in rows], color="#b26128", label="Threads")
    right.set_ylabel("Threads", color="#b26128")
    labels = ["Minimal\n單目標", "Dashboard\n單目標", "Minimal\n雙目標", "Dashboard\n雙目標", "Dashboard\n雙目標暫停"]
    positions = list(range(5))
    axes[1, 0].bar([value - 0.18 for value in positions], [item["cpuMeanPercent"] for item in summaries], width=0.36, label="時間加權平均", color="#245e9b")
    axes[1, 0].bar([value + 0.18 for value in positions], [item["cpuP95Percent"] for item in summaries], width=0.36, label="區間 p95", color="#7fb9ba")
    axes[1, 0].set(xticks=positions, xticklabels=labels, ylabel="整機容量 %（14 邏輯 CPU）", title="App 與已核實 WebView2 合計 CPU")
    axes[1, 0].legend(frameon=False)
    axes[1, 1].bar(positions, [item["privateMeanMiB"] for item in summaries], color="#245e9b")
    axes[1, 1].set(xticks=positions, xticklabels=labels, ylabel="平均合計 MiB", title="各情境 Private Bytes")
    for axis in axes.flat:
        axis.grid(axis="y", alpha=0.2)
        axis.set_axisbelow(True)
    figure.suptitle("RC 06 有限觀測：排除缺失樣本，不代表無洩漏或功率驗收", fontsize=15)
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=150)
    plt.close(figure)
    print(f"圖表已保存：{output}；matplotlib={matplotlib.__version__}")


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
        main()
    except Exception:
        diagnostic = Path(__file__).resolve().parent.parent / "artifacts/acceptance/rc06-plot-error.log"
        diagnostic.parent.mkdir(parents=True, exist_ok=True)
        logging.basicConfig(filename=diagnostic, encoding="utf-8", level=logging.ERROR)
        logging.exception("產生 RC 06 圖表失敗")
        print(f"錯誤：無法產生效能圖表，請確認五組分析都已完成。詳細日誌：{diagnostic}", file=sys.stderr)
        sys.exit(1)
