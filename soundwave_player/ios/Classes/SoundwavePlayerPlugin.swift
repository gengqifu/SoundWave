import Flutter
import AVFoundation
import UIKit

public class SoundwavePlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var methodChannel: FlutterMethodChannel?
  private var stateEventChannel: FlutterEventChannel?
  private var stateSink: FlutterEventSink?

  private var player: AVPlayer?
  private var timeObserver: Any?
  private var statusObserver: NSKeyValueObservation?
  private var timeControlObserver: NSKeyValueObservation?
  private var itemLoadedObserver: NSKeyValueObservation?
  private var interruptionObserver: NSObjectProtocol?
  private var routeObserver: NSObjectProtocol?
  private var backgroundObserver: NSObjectProtocol?
  private var foregroundObserver: NSObjectProtocol?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SoundwavePlayerPlugin()
    instance.methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)

    instance.stateEventChannel = FlutterEventChannel(name: "\(eventPrefix)/state", binaryMessenger: registrar.messenger())
    instance.stateEventChannel?.setStreamHandler(instance)
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
    }
  }

  private func load(url: URL, headers: [String: String]?) {
    let asset = AVURLAsset(url: url, options: headers != nil ? ["AVURLAssetHTTPHeaderFieldsKey": headers!] : nil)
    let item = AVPlayerItem(asset: asset)
    player?.replaceCurrentItem(with: item)

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
}

// MARK: - Audio session & notifications
extension SoundwavePlayerPlugin {
  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback,
                              mode: .default,
                              options: [.allowAirPlay, .allowBluetooth, .mixWithOthers])
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
