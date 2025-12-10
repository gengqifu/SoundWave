import Foundation

public final class SpectrumEngine {
    public enum WindowType: Int32 {
        case hann = 0
        case hamming = 1
    }

    public let windowSize: Int
    public let windowType: WindowType
    public let powerSpectrum: Bool

    public init(windowSize: Int = 1024,
                windowType: WindowType = .hann,
                powerSpectrum: Bool = true) {
        self.windowSize = windowSize
        self.windowType = windowType
        self.powerSpectrum = powerSpectrum
    }

    public func compute(samples: [Float], sampleRate: Int) -> (bins: [Float], binHz: Double)? {
        guard !samples.isEmpty, sampleRate > 0 else { return nil }
        var outPtr: UnsafeMutablePointer<Float>?
        var outLen: Int = 0
        var outBinHz: Float = 0
        let code = samples.withUnsafeBufferPointer { buf -> Int32 in
            return sw_fft_compute(buf.baseAddress,
                                  buf.count,
                                  Int32(sampleRate),
                                  Int32(windowSize),
                                  windowType.rawValue,
                                  powerSpectrum,
                                  &outPtr,
                                  &outLen,
                                  &outBinHz)
        }
        guard code == 0, let ptr = outPtr, outLen > 0 else {
            if let ptr = outPtr { sw_fft_free(ptr) }
            return nil
        }
        let bins = Array(UnsafeBufferPointer(start: ptr, count: outLen))
        sw_fft_free(ptr)
        return (bins, Double(outBinHz))
    }
}
