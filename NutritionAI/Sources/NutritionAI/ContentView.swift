import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "camera.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("NutritionAI")
                .font(.title)
        }
        .padding()
    }
}
