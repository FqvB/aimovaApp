import SwiftUI

struct WindIndicatorView: View {
    let wind: WindData
    let isFailed: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .rotationEffect(.degrees(wind.windDirectionDegrees))
            Text(String(format: "%.0f mph", wind.windSpeedMph))
                .font(.caption2.bold())
            if isFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }
}
