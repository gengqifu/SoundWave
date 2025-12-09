#!/usr/bin/env swift
import Foundation
import Accelerate

struct Reference: Decodable {
    let spectrum: [Double]
    let peak_bin: Int
    let peak_mag: Double
    let nfft: Int
    let fs: Double
    let window: String
    let norm: String
    let signal: String
}

func hann(_ n: Int, N: Int) -> Double {
    return 0.5 * (1.0 - cos(2.0 * Double.pi * Double(n) / Double(N - 1)))
}

func windowEnergy(N: Int) -> Double {
    (0..<N).reduce(0.0) { $0 + pow(hann($1, N: N), 2.0) }
}

func generateSignal(kind: String, N: Int, fs: Double) -> [Double] {
    switch kind {
    case "single":
        let f = 1000.0
        return (0..<N).map { n in sin(2.0 * Double.pi * f * Double(n) / fs) }
    case "double":
        let f1 = 440.0, f2 = 880.0
        return (0..<N).map { n in
            let t = Double(n) / fs
            return sin(2.0 * Double.pi * f1 * t) + sin(2.0 * Double.pi * f2 * t)
        }
    case "white":
        var rng = SeededGenerator(seed: 42)
        return (0..<N).map { _ in Double.random(in: -1...1, using: &rng) }
    case "sweep":
        let f0 = 20.0, f1 = 18000.0
        let ratio = f1 / f0
        return (0..<N).map { n in
            let t = Double(n) / fs
            let f = f0 * pow(ratio, t * fs / Double(N))
            return sin(2.0 * Double.pi * f * t)
        }
    default:
        return Array(repeating: 0.0, count: N)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

func fftMagnitude(_ samples: [Double]) -> [Double] {
    let N = samples.count
    var real = samples
    var imag = [Double](repeating: 0.0, count: N)
    guard let setup = vDSP_create_fftsetupD(vDSP_Length(log2(Double(N))), FFTRadix(FFT_RADIX2)) else {
        return []
    }
    real.withUnsafeMutableBufferPointer { realBuf in
        imag.withUnsafeMutableBufferPointer { imagBuf in
            var splitComplex = DSPDoubleSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
            vDSP_fft_zipD(setup, &splitComplex, 1, vDSP_Length(log2(Double(N))), FFTDirection(FFT_FORWARD))
        }
    }
    vDSP_destroy_fftsetupD(setup)
    let half = N / 2 + 1
    var mag = [Double](repeating: 0.0, count: half)
    for k in 0..<half {
        let r = real[k]
        let i = imag[k]
        mag[k] = sqrt(r * r + i * i)
    }
    return mag
}

func compare(ref: [Double], got: [Double]) -> (l2: Double, max: Double, peakBin: Int, peakMag: Double) {
    let n = min(ref.count, got.count)
    var l2 = 0.0
    var maxErr = 0.0
    for i in 0..<n {
        let diff = abs(ref[i] - got[i])
        l2 += diff * diff
        if diff > maxErr { maxErr = diff }
    }
    var peakMag = 0.0
    var peakBin = 0
    for (i, v) in got.enumerated() {
        if v > peakMag {
            peakMag = v
            peakBin = i
        }
    }
    return (sqrt(l2), maxErr, peakBin, peakMag)
}

func main() {
    guard CommandLine.arguments.count > 1 else {
        print("Usage: fft_vdsp_compare.swift <reference.json>")
        exit(1)
    }
    let path = CommandLine.arguments[1]
    guard let data = FileManager.default.contents(atPath: path),
          let ref = try? JSONDecoder().decode(Reference.self, from: data) else {
        print("Failed to read reference \(path)")
        exit(1)
    }
    let samples = generateSignal(kind: ref.signal, N: ref.nfft, fs: ref.fs)
    let win = (0..<ref.nfft).map { hann($0, N: ref.nfft) }
    let eWin = windowEnergy(N: ref.nfft)
    var windowed = [Double](repeating: 0.0, count: ref.nfft)
    for i in 0..<ref.nfft { windowed[i] = samples[i] * win[i] }
    let mag = fftMagnitude(windowed)
    let norm = 2.0 / (Double(ref.nfft) * eWin)
    let normMag = mag.map { $0 * norm }

    let result = compare(ref: ref.spectrum, got: normMag)
    print("Signal: \(ref.signal)")
    print("Peak bin/mag (got): \(result.peakBin) / \(result.peakMag)")
    print("L2 error: \(result.l2) Max error: \(result.max)")
    let threshold = 1e-3
    if result.l2 > threshold || result.max > threshold {
        print("ERROR: exceeds threshold \(threshold)")
        exit(2)
    } else {
        print("OK: within threshold \(threshold)")
    }
}

main()
