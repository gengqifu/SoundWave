import AVFoundation
import SoundwaveCore

/// 简单示例：播放 bundle 内的 sample.wav，并用 SoundwaveCore 计算频谱。
final class SpectrumHost {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let spectrum = SpectrumEngine(windowSize: 1024, windowType: .hann, powerSpectrum: true)

  init() {
    engine.attach(player)
    let main = engine.mainMixerNode
    engine.connect(player, to: main, format: nil)
  }

  func start() throws {
    guard let url = Bundle.main.url(forResource: "sample", withExtension: "wav") else {
      throw NSError(domain: "SpectrumHost", code: -1, userInfo: [NSLocalizedDescriptionKey: "missing sample.wav"])
    }
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let frameCount = UInt32(file.length)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      throw NSError(domain: "SpectrumHost", code: -2, userInfo: [NSLocalizedDescriptionKey: "buffer alloc failed"])
    }
    try file.read(into: buffer)

    try engine.start()
    player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
      self?.engine.stop()
    }
    player.play()

    // 拉取前 1 帧做频谱演示（单声道/双声道均取 channel 0）
    if let channelData = buffer.floatChannelData, buffer.frameLength > 0 {
      let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
      if let spec = spectrum.compute(samples: samples, sampleRate: Int(format.sampleRate)) {
        let top3 = spec.prefix(3).map { String(format: "%.4f", $0) }.joined(separator: ", ")
        print("bins=\(spec.count) top3=\(top3)")
      }
    }
  }
}
