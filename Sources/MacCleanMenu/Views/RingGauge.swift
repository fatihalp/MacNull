import SwiftUI

struct RingGauge: View {
    let value: Double
    let color: Color
    let center: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(center).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
    }
}
