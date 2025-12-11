import AVFoundation
import SoundwaveCore

/// 播放 bundle 音频，支持播放/暂停/停止/seek，实时输出波形与频谱。
final class SpectrumHost: ObservableObject {
  @Published var status: String = "Idle"
  @Published var currentTime: TimeInterval = 0
  @Published var duration: TimeInterval = 0
  @Published var isPlaying: Bool = false
  @Published var waveform: [Float] = []
  @Published var spectrumData: [Float] = []

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let spectrum = SpectrumEngine(windowSize: 1024, windowType: .hann, powerSpectrum: true)
  private var audioFile: AVAudioFile?
  private var defaultFile: String
  private var tapInstalled = false
  private var timer: CADisplayLink?
  private var currentFrame: AVAudioFramePosition = 0

  init(defaultFile: String) {
    self.defaultFile = defaultFile
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: nil)
    configureAudioSession()
    installTapIfNeeded()
  }

  func load(fileName: String) {
    defaultFile = fileName
    stop()
    status = "Loading \(fileName)…"
    do {
      let url = try resolveURL(fileName: fileName)
      let file = try AVAudioFile(forReading: url)
      audioFile = file
      duration = TimeInterval(file.length) / file.processingFormat.sampleRate
      currentFrame = 0
      currentTime = 0
      waveform.removeAll()
      spectrumData.removeAll()
      status = "Ready: \(fileName)"
    } catch {
      status = "Failed: \(error.localizedDescription)"
    }
  }

  func play() {
    guard let file = audioFile else {
      load(fileName: defaultFile)
      return play()
    }
    do {
      if !engine.isRunning {
        try engine.start()
      }
      schedule(from: currentFrame, file: file)
      player.play()
      isPlaying = true
      status = "Playing \(defaultFile)"
      startTimer()
    } catch {
      status = "Failed: \(error.localizedDescription)"
    }
  }

  func pause() {
    player.pause()
    isPlaying = false
    stopTimer()
    status = "Paused"
  }

  func stop() {
    player.stop()
    engine.stop()
    isPlaying = false
    stopTimer()
    currentFrame = 0
    currentTime = 0
    status = "Stopped"
  }

  func seek(progress: Double) {
    guard let file = audioFile, duration > 0 else { return }
    let target = max(0.0, min(progress, 1.0))
    currentFrame = AVAudioFramePosition(Double(file.length) * target)
    currentTime = TimeInterval(currentFrame) / file.processingFormat.sampleRate
    if isPlaying {
      player.stop()
      schedule(from: currentFrame, file: file)
      player.play()
    }
  }

  private func schedule(from startFrame: AVAudioFramePosition, file: AVAudioFile) {
    player.stop()
    player.reset()
    let total = file.length
    guard startFrame < total else { return }
    let framesToPlay = AVAudioFrameCount(total - startFrame)
    engine.disconnectNodeOutput(player)
    engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
    engine.disconnectNodeOutput(engine.mainMixerNode)
    engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)

    player.scheduleSegment(
      file,
      startingFrame: startFrame,
      frameCount: framesToPlay,
      at: nil
    ) { [weak self] in
      DispatchQueue.main.async {
        self?.isPlaying = false
        self?.status = "Completed"
        self?.stopTimer()
      }
    }
  }

  private func startTimer() {
    stopTimer()
    timer = CADisplayLink(target: self, selector: #selector(onTick))
    timer?.add(to: .main, forMode: .common)
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  @objc private func onTick() {
    guard let file = audioFile, isPlaying else { return }
    currentTime = TimeInterval(currentFrame) / file.processingFormat.sampleRate
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
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true, options: [])
  }

  private func installTapIfNeeded() {
    guard !tapInstalled else { return }
    tapInstalled = true
    engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) {
      [weak self] buffer, _ in
      guard let self = self else { return }
      guard let channel = buffer.floatChannelData?.pointee else { return }
      let count = Int(buffer.frameLength)
      let samples = Array(UnsafeBufferPointer(start: channel, count: count))
      DispatchQueue.main.async {
        self.appendWaveform(samples)
        self.updateSpectrum(samples, sampleRate: Int(buffer.format.sampleRate))
        self.currentFrame += AVAudioFramePosition(count)
      }
    }
  }

  private func appendWaveform(_ samples: [Float]) {
    waveform.append(contentsOf: samples)
    if waveform.count > 2048 {
      waveform.removeFirst(waveform.count - 2048)
    }
  }

  private func updateSpectrum(_ samples: [Float], sampleRate: Int) {
    if let (bins, _) = spectrum.compute(samples: samples, sampleRate: sampleRate) {
      spectrumData = Array(bins.prefix(256))
    }
  }
}
