import SwiftUI

struct SpectrumView: View {
  let magnitudes: [Float]

  var body: some View {
    GeometryReader { geo in
      let count = min(magnitudes.count, 128)
      let barWidth = geo.size.width / CGFloat(max(count, 1))
      HStack(alignment: .bottom, spacing: 0) {
        ForEach(0..<count, id: \.self) { idx in
          let v = max(magnitudes[idx], 1e-6)
          let db = 20 * log10(v)
          let norm = CGFloat((db + 60) / 60).clamped(to: 0...1)
          Rectangle()
            .fill(Color.blue)
            .frame(width: barWidth, height: norm * geo.size.height)
        }
      }
    }
  }
}

private extension CGFloat {
  func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
