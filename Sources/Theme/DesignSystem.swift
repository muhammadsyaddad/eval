import SwiftUI

// MARK: - Eval Design System
// Aesthetic: Refined Dark Industrial — precision instrument meets privacy dashboard
// Warm amber accent on deep charcoal, monospaced timestamps, generous negative space

struct MPTheme {

    // MARK: - Color Palette

    struct Colors {
        // Backgrounds — layered depth
        static let bgPrimary = Color(hex: "0F1114")        // Deep void
        static let bgSecondary = Color(hex: "161920")       // Elevated surface
        static let bgTertiary = Color(hex: "1C2028")        // Card surface
        static let bgHover = Color(hex: "232830")           // Interactive hover

        // Accent — warm amber instrument glow
        static let accent = Color(hex: "E8A84C")            // Primary amber
        static let accentMuted = Color(hex: "E8A84C").opacity(0.15)
        static let accentSubtle = Color(hex: "E8A84C").opacity(0.08)

        // Text hierarchy
        static let textPrimary = Color(hex: "E8ECF4")       // High contrast
        static let textSecondary = Color(hex: "8B95A8")      // Muted descriptive
        static let textTertiary = Color(hex: "555F73")       // Subtle labels
        static let textInverse = Color(hex: "0F1114")        // On accent bg

        // Semantic
        static let success = Color(hex: "34D399")
        static let warning = Color(hex: "FBBF24")
        static let error = Color(hex: "F87171")
        static let info = Color(hex: "60A5FA")

        // Category colors (desaturated to match dark industrial tone)
        static let categoryAmber = Color(hex: "E8A84C")
        static let categoryTeal = Color(hex: "5EEAD4")
        static let categorySlate = Color(hex: "8B95A8")
        static let categoryRose = Color(hex: "FB7185")
        static let categoryEmerald = Color(hex: "34D399")
        static let categoryViolet = Color(hex: "A78BFA")
        static let categorySky = Color(hex: "60A5FA")
        static let categoryZinc = Color(hex: "71717A")

        // Borders & dividers
        static let border = Color(hex: "2A2F3A")
        static let borderSubtle = Color(hex: "1F2430")

        static func forCategory(_ category: ActivityCategory) -> Color {
            switch category {
            case .productivity: return categoryAmber
            case .communication: return categoryTeal
            case .browsing: return categorySlate
            case .entertainment: return categoryRose
            case .development: return categoryEmerald
            case .design: return categoryViolet
            case .writing: return categorySky
            case .other: return categoryZinc
            }
        }
    }

    // MARK: - Typography

    struct Typography {
        // Display — for hero numbers and summary stats
        static func display(_ size: CGFloat = 36) -> Font {
            .system(size: size, weight: .thin, design: .default)
        }

        // Heading
        static func heading(_ size: CGFloat = 18) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }

        // Body
        static func body(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        // Caption
        static func caption(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .medium, design: .default)
        }

        // Monospaced — for timestamps, metrics, technical data
        static func mono(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .regular, design: .monospaced)
        }

        // Monospaced bold
        static func monoBold(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .semibold, design: .monospaced)
        }

        // Label — uppercase tracking
        static func label(_ size: CGFloat = 10) -> Font {
            .system(size: size, weight: .bold, design: .default)
        }
    }

    // MARK: - Spacing

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    struct Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var padding: CGFloat = MPTheme.Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MPTheme.Colors.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MPTheme.Radius.md)
                    .stroke(MPTheme.Colors.border, lineWidth: 1)
            )
    }
}

struct GlowAccent: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: MPTheme.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 0)
    }
}

struct SectionLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(MPTheme.Typography.label())
            .foregroundColor(MPTheme.Colors.textTertiary)
            .tracking(1.5)
            .textCase(.uppercase)
    }
}

extension View {
    func cardStyle(padding: CGFloat = MPTheme.Spacing.lg) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func glowAccent() -> some View {
        modifier(GlowAccent())
    }

    func sectionLabel() -> some View {
        modifier(SectionLabel())
    }
}

// MARK: - Formatted Duration

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedHoursMinutes: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

// MARK: - Date Formatting

extension Date {
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }

    var dayOfWeek: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: self)
    }

    var fullDate: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: self)
    }

    var monthYear: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: self)
    }
}
