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
  @State private var sliderValue: Double = 0

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
      Text("SoundWave Host")
        .font(.title2)
        .bold()

      Picker("选择音频", selection: $selectedFile) {
        ForEach(audioFiles, id: \.self) { file in
          Text(file).tag(file)
        }
      }
      .pickerStyle(.menu)
      .onChange(of: selectedFile) { newValue in
        host.load(fileName: newValue)
      }

      HStack(spacing: 12) {
        Button {
          host.play()
        } label: {
          Label("播放", systemImage: "play.fill")
        }
        Button {
          host.pause()
        } label: {
          Label("暂停", systemImage: "pause.fill")
        }
        Button {
          host.stop()
        } label: {
          Label("停止", systemImage: "stop.fill")
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Slider(
          value: Binding(
            get: {
              if host.duration <= 0 { return 0 }
              return host.currentTime / host.duration
            },
            set: { newVal in
              sliderValue = newVal
            }
          ),
          in: 0...1,
          onEditingChanged: { editing in
            if !editing {
              host.seek(progress: sliderValue)
            }
          }
        )
        Text("\(formatTime(host.currentTime)) / \(formatTime(host.duration))")
          .font(.caption)
      }

      Text(host.status)
        .font(.subheadline)

      VStack(alignment: .leading, spacing: 8) {
        Text("Waveform")
          .font(.headline)
        WaveformView(samples: host.waveform)
          .frame(height: 120)
          .background(Color.black.opacity(0.85))
          .cornerRadius(8)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Spectrum")
          .font(.headline)
        SpectrumView(magnitudes: host.spectrumData)
          .frame(height: 140)
          .background(Color.black.opacity(0.85))
          .cornerRadius(8)
      }

      Spacer()
    }
    .padding()
    .onAppear {
      host.load(fileName: selectedFile)
    }
  }

  private func formatTime(_ t: TimeInterval) -> String {
    guard t.isFinite && t > 0 else { return "00:00" }
    let intT = Int(t)
    return String(format: "%02d:%02d", intT / 60, intT % 60)
  }
}

#Preview {
  ContentView(host: SpectrumHost(defaultFile: "sample.wav"))
}
