//
//  hostApp.swift
//  host
//
//  Created by 耿启富 on 2025/12/11.
//

import SwiftUI

@main
struct hostApp: App {
  @StateObject private var host = SpectrumHost(defaultFile: "sample.wav")

  var body: some Scene {
    WindowGroup {
      ContentView(host: host)
    }
  }
}
