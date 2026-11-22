import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let pitch = Color(hex: 0x2E7D32)
    static let home = Color(hex: 0x1565C0)
    static let away = Color(hex: 0xC62828)
    static let arrow = Color(hex: 0xFFEB3B)
    static let ballOutline = Color(hex: 0x212121)
    static let barBackground = Color.black.opacity(0.45)
}

/// A rounded button used in the top and bottom bars. 44 pt tall so it is easy to hit.
struct BarButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.18))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
