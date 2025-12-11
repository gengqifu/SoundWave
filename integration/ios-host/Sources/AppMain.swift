import SwiftUI

@main
struct HostApp: App {
  private let spectrumHost = SpectrumHost()

  init() {
    spectrumHost.fileName = "sample.wav" // 可切换为 Resources 中的任意文件
    try? spectrumHost.start()
  }

  var body: some Scene {
    WindowGroup {
      ContentView(status: "Playing \(spectrumHost.fileName)")
    }
  }
}
