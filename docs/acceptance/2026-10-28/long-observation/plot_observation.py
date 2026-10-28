"""繪製 Windows 程序樹觀測資料，不把圖表當作通過判定。"""

import argparse
import csv
import json
import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Patch


def state(title: str) -> str:
    """解讀原生宿主標題。

    Args:
        title: 原生視窗標題。

    Returns:
        active、locked、obscured 或 other。
    """
    if title.endswith("Live metrics"):
        return "active"
    if " — locked — " in title:
        return "locked"
    if " — obscured — " in title:
        return "obscured"
    return "other"


def main() -> None:
    """將完整觀測的記憶體、CPU 及狀態區段輸出成 PNG。"""
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    directory = args.directory
    metadata = json.loads((directory / "samples.metadata.json").read_text(encoding="utf-8-sig"))
    if metadata["RunStatus"] != "COMPLETED":
        raise ValueError("量測尚未完整結束。")
    font_path = Path(os.environ["WINDIR"]) / "Fonts" / "msjh.ttc"
    if not font_path.is_file():
        raise FileNotFoundError("找不到圖表所需的微軟正黑體。")
    font = FontProperties(fname=str(font_path))
    plt.rcParams["font.family"] = font.get_name()
    with (directory / "samples.csv").open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) < 2:
        raise ValueError("樣本不足。")
    first = float(rows[0]["ElapsedSeconds"])
    minutes = [(float(row["ElapsedSeconds"]) - first) / 60 for row in rows]
    fig, axes = plt.subplots(2, 1, figsize=(11, 6.5), sharex=True)
    axes[0].plot(minutes, [int(row["PrivateBytes"]) / 1024**2 for row in rows], label="私有承諾記憶體", color="#167568")
    axes[0].plot(minutes, [int(row["WorkingSetBytes"]) / 1024**2 for row in rows], label="各程序 Working Set 加總", color="#536ab6")
    cpu_x, cpu_y = [], []
    for previous, current in zip(rows, rows[1:]):
        elapsed = float(current["ElapsedSeconds"]) - float(previous["ElapsedSeconds"])
        delta = float(current["CpuTimeSeconds"]) - float(previous["CpuTimeSeconds"])
        if previous["ProcessIds"] != current["ProcessIds"] or elapsed <= 0 or elapsed > 15 or delta < 0:
            continue
        cpu_x.append((float(current["ElapsedSeconds"]) - first) / 60)
        cpu_y.append(delta / elapsed / metadata["LogicalProcessorCount"] * 100)
    axes[1].plot(cpu_x, cpu_y, color="#2a638f", linewidth=1.0)
    for index, row in enumerate(rows[:-1]):
        mode = state(row["RootWindowTitle"])
        if mode == "locked":
            for ax in axes:
                ax.axvspan(minutes[index], minutes[index + 1], color="#71859b", alpha=0.10, linewidth=0)
        elif mode == "obscured":
            for ax in axes:
                ax.axvspan(minutes[index], minutes[index + 1], color="#d69b35", alpha=0.20, linewidth=0)
    axes[0].set_ylabel("記憶體（MiB）")
    axes[1].set_ylabel("整機 CPU 比例（%）")
    axes[1].set_xlabel("觀測時間（分鐘）")
    axes[1].set_xlim(0, minutes[-1])
    axes[0].legend(loc="upper right", frameon=False)
    axes[1].legend(handles=[Patch(facecolor="#71859b", alpha=0.18, label="locked 區段"), Patch(facecolor="#d69b35", alpha=0.3, label="obscured 區段")], loc="upper right", frameon=False)
    for ax in axes:
        ax.grid(axis="y", alpha=0.18)
        ax.set_ylim(bottom=0)
    fig.suptitle("Minimal：30 分鐘實機觀測（含 WebView2）", fontsize=15)
    fig.text(0.01, 0.01, "混合狀態／非純閒置環境；Working Set 可能重複計入共用頁面；圖表不等於無洩漏證明。", fontsize=9)
    fig.tight_layout(rect=(0, 0.04, 1, 0.95))
    output = directory / "resource-trend.png"
    fig.savefig(output, dpi=160)
    plt.close(fig)
    print(output)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit(f"無法繪製觀測圖：{error}") from None
