import SwiftUI

enum BNBUTheme {
    static let ink = Color(hex: 0x0B0B0C)
    static let paper = Color(hex: 0xF3F9FF)
    static let surface = Color.white
    static let muted = Color(hex: 0x4D6F8F)
    static let line = Color(hex: 0x0B0B0C)
    static let blue = Color(hex: 0x3A9DF6)
    static let blueLight = Color(hex: 0x7EBEFB)
    static let blueSoft = Color(hex: 0xE3F2FF)
    static let pale = Color(hex: 0xF7FAFD)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Double {
    var hourText: String {
        if rounded(.down) == self {
            return "\(Int(self))h"
        }
        return String(format: "%.1fh", self)
    }
}
