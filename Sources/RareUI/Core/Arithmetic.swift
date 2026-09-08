//
//  Arithmetic.swift
//  Small numeric helpers shared across components, each matching the JavaScript
//  operator it stands in for rather than the Swift one that looks like it.
//

import Foundation

/// A true modulo, always returning a value with the sign of the divisor.
///
/// Swift's `%` and JavaScript's both take the sign of the dividend, so `-1 % 10` is
/// `-1` in each. Upstream writes `((n % m) + m) % m` wherever it needs a wheel to wrap,
/// and this is that. The counter's digit wheels and the matrix orb's ripples both
/// depend on it staying positive across the wrap.
///
/// - Parameters:
///   - value: The dividend.
///   - modulus: The divisor. Must not be zero.
/// - Returns: `value` reduced into `0..<modulus`.
public func rareUIMod(_ value: Double, _ modulus: Double) -> Double {
    let remainder = value.truncatingRemainder(dividingBy: modulus)
    return (remainder + modulus).truncatingRemainder(dividingBy: modulus)
}

/// Confines a value to a range, treating a value that is not finite as the low end.
///
/// The fallback matters: upstream reaches for this to keep a caller supplied duration
/// or count usable, and a NaN that slipped through would otherwise poison every
/// comparison downstream of it.
///
/// - Parameters:
///   - value: The value to confine.
///   - low: The lowest acceptable value.
///   - high: The highest acceptable value.
/// - Returns: The confined value.
public func rareUIClamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
    guard value.isFinite else { return low }
    return min(high, max(low, value))
}
