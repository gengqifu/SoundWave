import Foundation

public struct PcmFrame {
    public let sequence: Int64
    public let timestampMs: Int64
    public let samples: [Float]

    public init(sequence: Int64, timestampMs: Int64, samples: [Float]) {
        self.sequence = sequence
        self.timestampMs = timestampMs
        self.samples = samples
    }
}
