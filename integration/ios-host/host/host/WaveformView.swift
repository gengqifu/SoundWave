import SwiftUI

struct WaveformView: View {
  let samples: [Float]

  var body: some View {
    GeometryReader { geo in
      let mid = geo.size.height / 2
      let count = samples.count
      let step = max(1, count / Int(geo.size.width))
      let points = stride(from: 0, to: count, by: step).map { idx -> CGPoint in
        let amp = CGFloat(samples[idx].clamped(to: -1...1)) * mid * 0.9
        return CGPoint(x: CGFloat(idx) / CGFloat(count) * geo.size.width, y: mid - amp)
      }
      Path { path in
        guard let first = points.first else { return }
        path.move(to: first)
        for p in points.dropFirst() {
          path.addLine(to: p)
        }
      }
      .stroke(Color.green, lineWidth: 2)
    }
  }
}

private extension Float {
  func clamped(to range: ClosedRange<Float>) -> Float {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
