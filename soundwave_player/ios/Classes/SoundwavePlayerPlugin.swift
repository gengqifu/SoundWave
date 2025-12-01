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
      player?.seek(to: CMTime(milliseconds: pos))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setupPlayer() {
    stop()
    player = AVPlayer()
    player?.automaticallyWaitsToMinimizeStalling = true

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

private extension CMTime {
  func toMilliseconds() -> Int64 {
    if !isNumeric || seconds.isNaN { return 0 }
    return Int64(seconds * 1000.0)
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
