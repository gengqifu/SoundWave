#!/usr/bin/env python3
"""
生成跨端 FFT 参考数据（Hann 窗、nfft=1024、归一化 2/(N*E_window)、fs=44.1k）。
支持单频/双频/白噪/扫频四类信号，输出 JSON 便于 Android/iOS 比对。
"""
from __future__ import annotations

import argparse
import json
import math
from typing import List


def hann(n: int, N: int) -> float:
    return 0.5 * (1.0 - math.cos(2.0 * math.pi * n / float(N - 1)))


def energy_of_window(N: int) -> float:
    return sum(hann(i, N) ** 2 for i in range(N))


def generate_signal(kind: str, N: int, fs: float) -> List[float]:
    t = [i / fs for i in range(N)]
    if kind == "single":
        f = 1000.0
        return [math.sin(2 * math.pi * f * ti) for ti in t]
    if kind == "double":
        f1, f2 = 440.0, 880.0
        return [math.sin(2 * math.pi * f1 * ti) + math.sin(2 * math.pi * f2 * ti) for ti in t]
    if kind == "white":
        import random

        rng = random.Random(42)
        return [rng.uniform(-1, 1) for _ in range(N)]
    if kind == "sweep":
        f0, f1 = 20.0, 18000.0
        out = []
        for ti in t:
            f = f0 * ((f1 / f0) ** (ti * fs / N))
            out.append(math.sin(2 * math.pi * f * ti))
        return out
    raise ValueError(f"unsupported signal kind: {kind}")


def fft_real(signal: List[float]) -> List[complex]:
    try:
        import numpy as np  # type: ignore

        return np.fft.rfft(np.array(signal, dtype=np.float64)).tolist()
    except ModuleNotFoundError:
        # 纯 Python O(N^2) 退化实现，N=1024 时仍可接受
        import cmath

        N = len(signal)
        out = []
        for k in range(N // 2 + 1):
            s = 0j
            for n, x in enumerate(signal):
                s += x * cmath.exp(-2j * cmath.pi * k * n / N)
            out.append(s)
        return out


def compute_spectrum(signal: List[float], N: int) -> dict:
    win = [hann(i, N) for i in range(N)]
    e_win = energy_of_window(N)
    windowed = [signal[i] * win[i] for i in range(N)]
    fft = fft_real(windowed)
    norm = 2.0 / (N * e_win)
    mag = [abs(c) * norm for c in fft]
    peak_bin = max(range(len(mag)), key=lambda k: mag[k])
    return {
        "spectrum": mag,
        "peak_bin": int(peak_bin),
        "peak_mag": float(mag[peak_bin]),
        "nfft": N,
        "fs": 44100.0,
        "window": "hann",
        "norm": "2/(N*E_window)",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--signal", choices=["single", "double", "white", "sweep"], required=True)
    parser.add_argument("--nfft", type=int, default=1024)
    parser.add_argument("--fs", type=float, default=44100.0)
    parser.add_argument("--output", type=str, help="输出 JSON 路径（留空输出到 stdout）")
    args = parser.parse_args()

    sig = generate_signal(args.signal, args.nfft, args.fs)
    payload = compute_spectrum(sig, args.nfft)
    payload["signal"] = args.signal
    text = json.dumps(payload, indent=2)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)


if __name__ == "__main__":
    main()
