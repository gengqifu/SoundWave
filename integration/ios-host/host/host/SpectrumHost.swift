import AVFoundation
import SoundwaveCore

/// 播放 bundle 音频并用 SoundwaveCore 计算一次频谱。
final class SpectrumHost: ObservableObject {
  @Published private(set) var status: String = "Idle"

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let spectrum = SpectrumEngine(windowSize: 1024, windowType: .hann, powerSpectrum: true)
  private var defaultFile: String

  init(defaultFile: String) {
    self.defaultFile = defaultFile
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: nil)
    configureAudioSession()
  }

  func start(fileName: String? = nil) {
    let targetFile = fileName ?? defaultFile
    defaultFile = targetFile
    status = "Loading \(targetFile)…"
    do {
      // 停止上一段播放，重置连接。
      player.stop()
      engine.stop()

      let url = try resolveURL(fileName: targetFile)
      let file = try AVAudioFile(forReading: url)
      let format = file.processingFormat
      guard let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(file.length)
      ) else {
        status = "PCM buffer alloc failed"
        return
      }
      try file.read(into: buffer)

      // 重新连接节点，确保输出链路和通道数匹配。
      engine.disconnectNodeOutput(player)
      engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
      engine.disconnectNodeOutput(engine.mainMixerNode)
      engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)

      try engine.start()
      player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
        DispatchQueue.main.async {
          self?.status = "Completed \(self?.defaultFile ?? "")"
          self?.engine.stop()
        }
      }
      player.play()

      // 取一帧计算频谱，确认 xcframework 链路正常。
      if let channelData = buffer.floatChannelData, buffer.frameLength > 0 {
        let samples = Array(
          UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength))
        )
        if let (bins, binHz) = spectrum.compute(samples: samples, sampleRate: Int(format.sampleRate)) {
          let top3 = bins.prefix(3).map { String(format: "%.4f", $0) }.joined(separator: ", ")
          status =
            "Playing \(targetFile) @\(Int(format.sampleRate))Hz · binHz \(String(format: "%.2f", binHz)) · top3 \(top3)"
          print("[Host] bins=\(bins.count) binHz=\(binHz) top3=\(top3)")
        } else {
          status = "Playing \(targetFile) @\(Int(format.sampleRate))Hz (spectrum empty)"
        }
      } else {
        status = "Playing \(targetFile) (no samples)"
      }
    } catch {
      status = "Failed: \(error.localizedDescription)"
    }
  }

  private func resolveURL(fileName: String) throws -> URL {
    let parts = fileName.split(separator: ".")
    let name = parts.dropLast().joined(separator: ".")
    let ext = parts.last.map(String.init) ?? ""
    if let url = Bundle.main.url(forResource: name, withExtension: ext) {
      return url
    }
    throw NSError(
      domain: "SpectrumHost",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: "Missing \(fileName) in bundle"]
    )
  }

  private func configureAudioSession() {
    #if os(iOS)
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try? session.setActive(true, options: [])
    #endif
  }
}
