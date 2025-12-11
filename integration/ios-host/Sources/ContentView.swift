import SwiftUI

struct ContentView: View {
  let status: String
  var body: some View {
    VStack(spacing: 12) {
      Text("SoundWave iOS Host")
        .font(.headline)
      Text(status)
        .font(.subheadline)
    }
    .padding()
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(status: "Preview")
  }
}
