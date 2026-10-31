import Foundation

/// Foundation's value formatting avoids shared mutable formatters and respects INR grouping.
enum DemoMoney {
    static func format(_ amount: Double) -> String {
        amount.formatted(.currency(code: "INR").locale(Locale(identifier: "en_IN")))
    }
}
