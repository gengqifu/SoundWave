import Foundation
import os.lock

/// 线程安全的 PCM 队列，负责丢帧统计与顺序编号。
public final class PcmFrameBuffer {
    private var queue: [PcmFrame] = []
    private var sequence: Int64 = 0
    private var dropped: Int = 0
    private let maxQueueFrames: Int
    private var lock = os_unfair_lock()

    public init(maxQueueFrames: Int = 60) {
        self.maxQueueFrames = maxQueueFrames
    }

    public func push(samples: [Float], timestampMs: Int64) {
        guard !samples.isEmpty else { return }
        os_unfair_lock_lock(&lock)
        if queue.count >= maxQueueFrames {
            queue.removeFirst()
            dropped += 1
        }
        queue.append(PcmFrame(sequence: sequence, timestampMs: timestampMs, samples: samples))
        sequence &+= 1
        os_unfair_lock_unlock(&lock)
    }

    public func drain(maxFrames: Int) -> [PcmFrame] {
        guard maxFrames > 0 else { return [] }
        os_unfair_lock_lock(&lock)
        let count = min(maxFrames, queue.count)
        let slice = Array(queue.prefix(count))
        queue.removeFirst(count)
        os_unfair_lock_unlock(&lock)
        return slice
    }

    public func droppedSinceLastDrain() -> Int {
        os_unfair_lock_lock(&lock)
        let d = dropped
        dropped = 0
        os_unfair_lock_unlock(&lock)
        return d
    }

    public func reset() {
        os_unfair_lock_lock(&lock)
        queue.removeAll()
        sequence = 0
        dropped = 0
        os_unfair_lock_unlock(&lock)
    }
}
