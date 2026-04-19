import SwiftUI

struct WaveformView: View {
    let level: Float
    private let barCount = 20

    var body: some View {
        Canvas { context, size in
            let barWidth = size.width / CGFloat(barCount * 2 - 1)
            let maxHeight = size.height * 0.85
            let baseline = size.height / 2

            for i in 0..<barCount {
                let x = CGFloat(i) * (barWidth * 2)
                // Vary bar heights pseudo-randomly based on level
                let seed = sin(Double(i) * 1.7 + Double(level) * 10)
                let normalised = CGFloat((seed + 1) / 2) * CGFloat(level)
                let height = max(2, normalised * maxHeight)

                let rect = CGRect(
                    x: x,
                    y: baseline - height / 2,
                    width: barWidth,
                    height: height
                )
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                context.fill(path, with: .color(.white.opacity(0.9)))
            }
        }
        .animation(.smooth(duration: 0.1), value: level)
    }
}
