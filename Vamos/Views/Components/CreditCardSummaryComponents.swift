import SwiftUI

// MARK: - Atomic Components

/// FilledIcon - Emoji/SF Symbol in rounded rectangle
struct FilledIcon: View {
    let iconName: String
    let isSystemIcon: Bool
    let size: CGFloat
    
    init(systemName: String, size: CGFloat = 32) {
        self.iconName = systemName
        self.isSystemIcon = true
        self.size = size
    }
    
    init(emoji: String, size: CGFloat = 32) {
        self.iconName = emoji
        self.isSystemIcon = false
        self.size = size
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveAccentBlue(for: colorScheme).opacity(0.15))
                .frame(width: size, height: size)
            
            if isSystemIcon {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.6, weight: .medium))
                    .foregroundColor(Color.adaptiveAccentBlue(for: colorScheme))
            } else {
                Text(iconName)
                    .font(.system(size: size * 0.6))
            }
        }
    }
}

/// MoneyText - Styles ₹ values red (debit) / green (credit)
struct MoneyText: View {
    let amount: Decimal
    let isDebit: Bool
    let style: Style
    
    enum Style {
        case body
        case headline
        case title
        case large
        
        var font: Font {
            switch self {
            case .body:
                return .system(.body, design: .rounded).weight(.medium)
            case .headline:
                return .system(.headline, design: .rounded).weight(.semibold)
            case .title:
                return .system(.title3, design: .rounded).weight(.bold)
            case .large:
                return .system(.title, design: .rounded).weight(.bold)
            }
        }
    }
    
    init(_ amount: Decimal, isDebit: Bool, style: Style = .body) {
        self.amount = amount
        self.isDebit = isDebit
        self.style = style
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(formatAmount(amount))
            .font(style.font)
            .foregroundColor(isDebit ? 
                Color.adaptiveDebitRed(for: colorScheme) : 
                Color.adaptiveCreditGreen(for: colorScheme)
            )
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        
        return formatter.string(from: amount as NSNumber) ?? "₹\(amount)"
    }
}

/// TagBadge - Small tag for transaction categories
struct TagBadge: View {
    let text: String
    let color: Color
    
    init(_ text: String, color: Color = .accentBlue) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .foregroundColor(color)
    }
}

// MARK: - Molecular Components

/// Enhanced Pie Chart for Category Summary
struct CategoryPieChart: View {
    let categories: [CategoryData]
    let size: CGFloat
    @State private var animationProgress: Double = 0
    
    struct CategoryData: Identifiable {
        let id = UUID()
        let name: String
        let amount: Decimal
        let percentage: Double
        let color: Color
    }
    
    init(categories: [CategoryData], size: CGFloat = 120) {
        self.categories = categories
        self.size = size
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                let startAngle = calculateStartAngle(for: index)
                let endAngle = calculateEndAngle(for: index)
                
                PieSlice(
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(startAngle + (endAngle - startAngle) * animationProgress)
                )
                .fill(category.color)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func calculateStartAngle(for index: Int) -> Double {
        var angle: Double = -90 // Start from top
        for i in 0..<index {
            angle += categories[i].percentage * 3.6 // Convert percentage to degrees
        }
        return angle
    }
    
    private func calculateEndAngle(for index: Int) -> Double {
        return calculateStartAngle(for: index) + categories[index].percentage * 3.6
    }
}

/// Transaction Row for Credit Card Summary
struct CreditCardTransactionRow: View {
    let transaction: StatementTransaction
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd\nMMM" // "02\nMay" format
        
        // Parse the date string from transaction
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: transaction.date) {
            return formatter.string(from: date)
        }
        
        // Fallback to just showing the raw date
        return transaction.date
    }
    
    private var merchantName: String {
        // Extract clean merchant name
        if let derived = transaction.derived {
            return derived.merchant ?? transaction.description
        }
        return transaction.description
    }
    
    private var categoryName: String {
        transaction.derived?.category ?? "Other"
    }
    
    private var shouldShowUPIBadge: Bool {
        categoryName.lowercased().contains("upi") || 
        transaction.description.lowercased().contains("upi")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Date stack
            VStack(alignment: .leading, spacing: 0) {
                Text(formattedDate)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(width: 32)
            
            // Category icon
            CategoryIcon(category: categoryName)
            
            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(merchantName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
                    .lineLimit(1)
                
                if shouldShowUPIBadge {
                    Pill(label: "UPI", tint: .accentUPI)
                }
            }
            
            Spacer()
            
            // Amount
            Text("₹\(NSDecimalNumber(decimal: transaction.amount).intValue)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.accentRed)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    Color.adaptiveCardStroke(for: colorScheme),
                    lineWidth: 0.75
                )
                .fill(Color.adaptiveCardFillPlayful(for: colorScheme))
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Supporting Shape
struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Playful Components

/// CategoryIcon - Colorful icons with proper category mapping
struct CategoryIcon: View {
    let category: String
    @Environment(\.colorScheme) var colorScheme
    
    private var imageName: String {
        switch category.lowercased() {
        case "food & dining", "food":
            return "burger_icon_24x24"
        case "groceries":
            return "grocery_icon_24x24"
        case "upi":
            return "upi_icon_24x24"
        case "fuel", "transportation":
            return "fuel_icon_24x24"
        case "entertainment":
            return "burger_icon_24x24" // fallback to burger for now
        case "shopping":
            return "grocery_icon_24x24" // fallback to grocery for now
        case "health", "healthcare":
            return "burger_icon_24x24" // fallback to burger for now
        case "utilities":
            return "fuel_icon_24x24" // fallback to fuel for now
        case "travel":
            return "fuel_icon_24x24" // fallback to fuel for now
        default:
            return "burger_icon_24x24" // fallback icon
        }
    }
    
    private var iconColor: Color {
        switch category.lowercased() {
        case "food & dining", "food":
            return .accentFood
        case "groceries":
            return .accentGrocery
        case "upi":
            return .accentUPI
        case "fuel", "transportation":
            return .accentFuel
        default:
            return .accentOther
        }
    }
    
    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
            )
    }
}

/// Pill - UPI badge component with playful styling
struct Pill: View {
    var label: String
    var tint: Color = .accentUPI
    
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .foregroundColor(tint)
            .clipShape(Capsule())
    }
} 