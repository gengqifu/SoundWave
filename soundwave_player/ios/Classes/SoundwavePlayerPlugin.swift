import Flutter
import AVFoundation
import MediaToolbox
import AudioToolbox
import CoreMedia
import UIKit
import Accelerate
import SoundwaveCore

public class SoundwavePlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var methodChannel: FlutterMethodChannel?
  private var stateEventChannel: FlutterEventChannel?
  private var stateSink: FlutterEventSink?
  private var pcmEventChannel: FlutterEventChannel?
  private var pcmStreamHandler = StreamHandler()
  private var spectrumEventChannel: FlutterEventChannel?
  private var spectrumStreamHandler = StreamHandler()

  private var player: AVPlayer?
  private var timeObserver: Any?
  private var statusObserver: NSKeyValueObservation?
  private var timeControlObserver: NSKeyValueObservation?
  private var itemLoadedObserver: NSKeyValueObservation?
  private var interruptionObserver: NSObjectProtocol?
  private var routeObserver: NSObjectProtocol?
  private var backgroundObserver: NSObjectProtocol?
  private var foregroundObserver: NSObjectProtocol?
  private var audioTap: AudioTapProcessor?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SoundwavePlayerPlugin()
    instance.methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)

    instance.stateEventChannel = FlutterEventChannel(name: "\(eventPrefix)/state", binaryMessenger: registrar.messenger())
    instance.stateEventChannel?.setStreamHandler(instance)

    instance.pcmEventChannel = FlutterEventChannel(name: "\(eventPrefix)/pcm", binaryMessenger: registrar.messenger())
    instance.pcmEventChannel?.setStreamHandler(instance.pcmStreamHandler)

    instance.spectrumEventChannel = FlutterEventChannel(name: "\(eventPrefix)/spectrum", binaryMessenger: registrar.messenger())
    instance.spectrumEventChannel?.setStreamHandler(instance.spectrumStreamHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      setupPlayer()
      result(nil)
    case "load":
      guard let args = call.arguments as? [String: Any],
            let source = args["source"] as? String,
            let url = URL(string: source) else {
        result(FlutterError(code: "invalid_args", message: "source required", details: nil))
        return
      }
      let headers = (args["headers"] as? [String: Any])?.reduce(into: [String: String]()) {
        if let v = $1.value as? String { $0[$1.key] = v }
      }
      load(url: url, headers: headers)
      result(nil)
    case "play":
      player?.play()
      result(nil)
    case "pause":
      player?.pause()
      result(nil)
    case "stop":
      stop()
      result(nil)
    case "seek":
      let pos = (call.arguments as? [String: Any])?["positionMs"] as? Int ?? 0
      player?.seek(to: CMTime.makeMilliseconds(pos))
      result(nil)
    case "pushPcmFrame":
      // TODO: 连接原生 PCM ingress，目前占位 no-op。
      result(nil)
    case "subscribeWaveform":
      // TODO: 管理订阅计数，目前依赖 EventChannel.
      result(nil)
    case "subscribeSpectrum":
      // TODO: 管理订阅计数，目前依赖 EventChannel.
      result(nil)
    case "unsubscribeWaveform":
      result(nil)
    case "unsubscribeSpectrum":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setupPlayer() {
    stop()
    player = AVPlayer()
    player?.automaticallyWaitsToMinimizeStalling = true
    configureAudioSession()
    registerNotifications()
    pluginLog("player setup done")

    timeControlObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, change in
      guard let self = self else { return }
      switch player.timeControlStatus {
      case .waitingToPlayAtSpecifiedRate:
        self.emitState([
          "type": "buffering",
          "isBuffering": true,
          "bufferedMs": player.currentItem?.bufferedPositionMs ?? 0
        ])
      case .playing:
        self.emitState([
          "type": "resumed",
          "isBuffering": false,
          "positionMs": player.currentPositionMs,
          "bufferedMs": player.currentItem?.bufferedPositionMs ?? 0
        ])
      default:
        break
      }
      self.pluginLog("timeControlStatus=\(player.timeControlStatus.rawValue) pos=\(player.currentPositionMs)")
    }
  }

  private func load(url: URL, headers: [String: String]?) {
    let asset = AVURLAsset(url: url, options: headers != nil ? ["AVURLAssetHTTPHeaderFieldsKey": headers!] : nil)
    let item = AVPlayerItem(asset: asset)
    audioTap?.detach()
    audioTap = AudioTapProcessor(
      player: player,
      pcmSinkProvider: { [weak self] in self?.pcmStreamHandler.sink },
      spectrumSinkProvider: { [weak self] in self?.spectrumStreamHandler.sink }
    )
    audioTap?.attach(to: item)
    player?.replaceCurrentItem(with: item)
    pluginLog("load url=\(url.absoluteString)")

    statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
      guard let self = self else { return }
      switch item.status {
      case .failed:
        self.emitState([
          "type": "error",
          "message": item.error?.localizedDescription ?? "playback error"
        ])
      case .readyToPlay:
        self.emitState([
          "type": "state",
          "isPlaying": false,
          "durationMs": item.duration.toMilliseconds(),
          "bufferedMs": item.bufferedPositionMs
        ])
      default:
        break
      }
    }

    itemLoadedObserver = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
      guard let self = self else { return }
      self.emitState([
        "type": "buffering",
        "isBuffering": true,
        "bufferedMs": item.bufferedPositionMs
      ])
      self.pluginLog("buffering bufferedMs=\(item.bufferedPositionMs)")
    }

    addPeriodicTimeObserver()
  }

  private func addPeriodicTimeObserver() {
    removeTimeObserver()
    let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
      guard let self = self else { return }
      self.emitState([
        "type": "state",
        "isPlaying": self.player?.timeControlStatus == .playing,
        "positionMs": self.player?.currentPositionMs ?? 0,
        "bufferedMs": self.player?.currentItem?.bufferedPositionMs ?? 0,
        "durationMs": self.player?.currentItem?.duration.toMilliseconds() ?? 0
      ])
    }
  }

  private func emitState(_ dict: [String: Any?]) {
    pluginLog("state event \(dict)")
    stateSink?(dict)
  }

  private func removeTimeObserver() {
    if let observer = timeObserver {
      player?.removeTimeObserver(observer)
      timeObserver = nil
    }
  }

  private func stop() {
    removeTimeObserver()
    statusObserver = nil
    timeControlObserver = nil
    itemLoadedObserver = nil
    audioTap?.detach()
    audioTap = nil
    if let obs = interruptionObserver {
      NotificationCenter.default.removeObserver(obs)
      interruptionObserver = nil
    }
    if let obs = routeObserver {
      NotificationCenter.default.removeObserver(obs)
      routeObserver = nil
    }
    if let obs = backgroundObserver {
      NotificationCenter.default.removeObserver(obs)
      backgroundObserver = nil
    }
    if let obs = foregroundObserver {
      NotificationCenter.default.removeObserver(obs)
      foregroundObserver = nil
    }
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    pluginLog("stop called, player released")
  }

  // MARK: - FlutterStreamHandler
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stateSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stateSink = nil
    return nil
  }

  private static let methodChannelName = "soundwave_player"
  private static let eventPrefix = "soundwave_player/events"

  private func pluginLog(_ msg: String) {
    print("Soundwave[iOS]: \(msg)")
  }
}

private class StreamHandler: NSObject, FlutterStreamHandler {
  var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}

// MARK: - Audio tap for PCM bypass
private class AudioTapProcessor {
  private weak var player: AVPlayer?
  private var pcmSinkProvider: () -> FlutterEventSink?
  private var spectrumSinkProvider: () -> FlutterEventSink?

  private var tap: Unmanaged<MTAudioProcessingTap>?
  private var audioMix: AVAudioMix?
  private var channelCount: UInt32 = 0
  private var bytesPerFrame: UInt32 = 0
  private var sampleRate: Double = 0
  private var buffer = PcmFrameBuffer()
  // 使用全局串行队列，避免实例释放后队列被销毁导致异步访问野指针。
  private static let tapQueue = DispatchQueue(label: "soundwave.pcm.tap")
  private var timer: DispatchSourceTimer?
  private let maxFrames: Int = 60
  private let maxFramesPerTick: Int = 5
  private let tickMillis: Int = 33
  private func log(_ msg: String) {
    print("Soundwave[iOS]: \(msg)")
  }

  init(player: AVPlayer?, pcmSinkProvider: @escaping () -> FlutterEventSink?, spectrumSinkProvider: @escaping () -> FlutterEventSink?) {
    self.player = player
    self.pcmSinkProvider = pcmSinkProvider
    self.spectrumSinkProvider = spectrumSinkProvider
  }

  deinit {
    log("AudioTapProcessor deinit")
    stopTimer() // 确保在销毁时停止定时器
  }

  func attach(to item: AVPlayerItem) {
    detach()

    guard let track = item.asset.tracks(withMediaType: .audio).first else {
      log("no audio track for tap")
      return
    }

    var callbacks = MTAudioProcessingTapCallbacks(
      version: kMTAudioProcessingTapCallbacksVersion_0,
      clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
      init: tapInit,
      finalize: tapFinalize,
      prepare: tapPrepare,
      unprepare: tapUnprepare,
      process: tapProcess
    )

    var tapOut: Unmanaged<MTAudioProcessingTap>?
    let status = MTAudioProcessingTapCreate(kCFAllocatorDefault,
                                            &callbacks,
                                            kMTAudioProcessingTapCreationFlag_PostEffects,
                                            &tapOut)
    guard status == noErr, let tapOut else {
      return
    }
    tap = tapOut

    let params = AVMutableAudioMixInputParameters(track: track)
    params.audioTapProcessor = tapOut.takeUnretainedValue()
    let mix = AVMutableAudioMix()
    mix.inputParameters = [params]
    audioMix = mix
    item.audioMix = mix
  }

  func detach() {
    player?.currentItem?.audioMix = nil // 明确断开 AVPlayerItem 对 audioMix 的引用
    tap = nil
    audioMix = nil
    stopTimer()
    AudioTapProcessor.tapQueue.sync {
      buffer.reset()
    }
  }

  private func handleBuffer(_ data: UnsafeMutableRawPointer?, frames: CMItemCount) {
    guard let data,
          (pcmSinkProvider() != nil || spectrumSinkProvider() != nil),
          bytesPerFrame > 0,
          channelCount > 0,
          frames > 0 else { return }

    let samplesCount = Int(frames * CMItemCount(channelCount))
    let floatPtr = data.assumingMemoryBound(to: Float32.self)
    var samples = [Float](repeating: 0, count: samplesCount)
    for i in 0..<samplesCount {
      samples[i] = floatPtr[i]
    }

    AudioTapProcessor.tapQueue.async { [weak self] in
      guard let self else { return }
      let ts = self.player?.currentPositionMs ?? 0
      self.buffer.push(samples: samples, timestampMs: ts)
    }
  }

  private func onPrepare(maxFrames: CMItemCount, format: AudioStreamBasicDescription) {
    channelCount = format.mChannelsPerFrame
    bytesPerFrame = format.mBytesPerFrame
    sampleRate = format.mSampleRate
    buffer.reset()
    startTimer()
  }

  private func onUnprepare() {
    channelCount = 0
    bytesPerFrame = 0
    sampleRate = 0
    stopTimer()
    AudioTapProcessor.tapQueue.sync {
      buffer.reset()
    }
  }

  private func startTimer() {
    executeOnQueue {
      if self.timer != nil { return }
      let t = DispatchSource.makeTimerSource(queue: AudioTapProcessor.tapQueue)
      t.schedule(deadline: .now(), repeating: .milliseconds(self.tickMillis))
      t.setEventHandler { [weak self] in
        self?.drainAndSend()
      }
      t.resume()
      self.timer = t
    }
  }

  private func stopTimer() {
    executeOnQueue {
      guard let t = self.timer else { return }
      self.timer = nil // 先将引用置空，防止重入
      t.cancel() // 取消定时器
      t.setEventHandler {} // 清除事件处理器
    }
  }

  private func executeOnQueue(_ block: @escaping () -> Void) {
    AudioTapProcessor.tapQueue.async(execute: block)
  }

  private func drainAndSend() {
    let pcmSink = pcmSinkProvider()
    let spectrumSink = spectrumSinkProvider()
    if pcmSink == nil && spectrumSink == nil {
      buffer.reset()
      return
    }
    let batch = buffer.drain(maxFrames: maxFramesPerTick)
    let droppedBefore = buffer.droppedSinceLastDrain()
    if batch.isEmpty && droppedBefore == 0 { return }

    var pcmPayloads: [[String: Any]] = []
    var spectrumPayloads: [[String: Any]] = []

    for (index, frame) in batch.enumerated() {
      var pcmPayload: [String: Any] = [
        "sequence": frame.sequence,
        "timestampMs": frame.timestampMs,
        "samples": frame.samples.map { Double($0) }
      ]
      if index == 0 && droppedBefore > 0 {
        pcmPayload["droppedBefore"] = droppedBefore
      }
      pcmPayloads.append(pcmPayload)

      // TODO: 接入原生 KissFFT 结果（当前占位，无 spectrum 推送）。
    }

    let droppedPayload: [String: Any]? = {
      if batch.isEmpty && droppedBefore > 0 {
        return ["dropped": true, "droppedBefore": droppedBefore]
      }
      return nil
    }()

    DispatchQueue.main.async {
      if let droppedPayload = droppedPayload {
        pcmSink?(droppedPayload)
        spectrumSink?(droppedPayload)
      }
      for payload in pcmPayloads {
        pcmSink?(payload)
      }
      for payload in spectrumPayloads {
        spectrumSink?(payload)
      }
    }
  }

  // MARK: - Tap callbacks
  private let tapInit: MTAudioProcessingTapInitCallback = { tap, clientInfo, tapStorageOut in
    tapStorageOut.pointee = clientInfo
  }

  private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    _ = Unmanaged<AudioTapProcessor>.fromOpaque(storage).takeRetainedValue()
  }

  private let tapPrepare: MTAudioProcessingTapPrepareCallback = { tap, maxFrames, processingFormat in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let processor = Unmanaged<AudioTapProcessor>.fromOpaque(storage).takeUnretainedValue()
    processor.onPrepare(maxFrames: maxFrames, format: processingFormat.pointee)
  }

  private let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let processor = Unmanaged<AudioTapProcessor>.fromOpaque(storage).takeUnretainedValue()
    processor.onUnprepare()
  }

  private let tapProcess: MTAudioProcessingTapProcessCallback = { tap, numberFrames, flags, bufferListInOut, numberFramesOut, _ in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let processor = Unmanaged<AudioTapProcessor>.fromOpaque(storage).takeUnretainedValue()

    var localFlags: MTAudioProcessingTapFlags = 0
    var timeRange = CMTimeRange()
    numberFramesOut.pointee = 0

    let status = MTAudioProcessingTapGetSourceAudio(tap,
                                                    numberFrames,
                                                    bufferListInOut,
                                                    &localFlags,
                                                    &timeRange,
                                                    numberFramesOut)
    if status == noErr, numberFramesOut.pointee > 0 {
      let mutableList = UnsafeMutableAudioBufferListPointer(bufferListInOut)
      if let data = mutableList[0].mData {
        processor.handleBuffer(data, frames: numberFramesOut.pointee)
      }
    }
  }

  // TODO: 接入原生 KissFFT 结果。
}

// MARK: - Audio session & notifications
extension SoundwavePlayerPlugin {
  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback,
                              mode: .default,
                              options: [])
      try session.setActive(true)
    } catch {
      emitState(["type": "error", "message": "AudioSession failed: \(error.localizedDescription)"])
    }
  }

  private func registerNotifications() {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
    ) { [weak self] note in
      self?.handleInterruption(note)
    }
    routeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] note in
      guard let self = self,
            let reasonValue = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
      if reason == .oldDeviceUnavailable {
        self.emitState(["type": "focusLost", "message": "Audio route changed"])
        self.pluginLog("route change: oldDeviceUnavailable")
      }
    }
    backgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.emitState([
        "type": "focusLost",
        "message": "App entered background"
      ])
    }
    foregroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      self.emitState([
        "type": "resumedFromBackground",
        "positionMs": self.player?.currentPositionMs ?? 0,
        "bufferedMs": self.player?.currentItem?.bufferedPositionMs ?? 0
      ])
    }
  }

  private func handleInterruption(_ notification: Notification) {
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
    switch type {
    case .began:
      emitState(["type": "focusLost", "message": "Audio interrupted"])
      pluginLog("interruption began")
    case .ended:
      let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt).map {
        AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume)
      } ?? false
      if shouldResume {
        emitState([
          "type": "resumedFromBackground",
          "positionMs": player?.currentPositionMs ?? 0,
          "bufferedMs": player?.currentItem?.bufferedPositionMs ?? 0
        ])
        pluginLog("interruption ended, shouldResume")
      }
    @unknown default:
      break
    }
  }
}

private extension CMTime {
  func toMilliseconds() -> Int64 {
    if !isNumeric || seconds.isNaN { return 0 }
    return Int64(seconds * 1000.0)
  }

  static func makeMilliseconds(_ ms: Int) -> CMTime {
    return CMTimeMake(value: Int64(ms), timescale: 1000)
  }
}

private extension AVPlayer {
  var currentPositionMs: Int64 {
    return currentTime().toMilliseconds()
  }
}

private extension AVPlayerItem {
  var bufferedPositionMs: Int64 {
    guard let range = loadedTimeRanges.first?.timeRangeValue else { return 0 }
    let buffered = CMTimeAdd(range.start, range.duration)
    return buffered.toMilliseconds()
  }
}
