//
//  ContentView.swift
//  host
//
//  Created by 耿启富 on 2025/12/11.
//

import SwiftUI

struct ContentView: View {
  @ObservedObject var host: SpectrumHost
  @State private var selectedFile: String = "sample.wav"

  private let audioFiles: [String] = [
    "sample.wav",
    "sample.mp3",
    "sine_1k.wav",
    "square_1k.wav",
    "saw_1k.wav",
    "sweep_20_20k.wav",
    "noise_white.wav",
    "noise_pink.wav",
    "silence.wav"
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("SoundWave iOS Host")
        .font(.title3)
        .bold()

      Picker("选择音频", selection: $selectedFile) {
        ForEach(audioFiles, id: \.self) { file in
          Text(file).tag(file)
        }
      }
      .pickerStyle(.menu)

      Button {
        host.start(fileName: selectedFile)
      } label: {
        HStack {
          Image(systemName: "play.fill")
          Text("播放所选音频")
        }
      }

      Text(host.status)
        .font(.subheadline)
        .multilineTextAlignment(.leading)

      Spacer()
    }
    .padding()
    .onAppear {
      host.start(fileName: selectedFile)
    }
  }
}

#Preview {
  ContentView(host: SpectrumHost(defaultFile: "sample.wav"))
}
