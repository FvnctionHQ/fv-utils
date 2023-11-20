//
//  Foundation+Utils.swift
//
//  Created by Alex Linkow on 16.11.23.
//

import Foundation




/** Ensures that `x` is in the range `[min, max]`. */
public func clamp<T: Comparable>(_ x: T, min: T, max: T) -> T {
  if x < min { return min }
  if x > max { return max }
  return x
}
public func coerceIn<T: Comparable>(_ x: T, min: T, max: T) -> T {
  return clamp(x, min: min, max: max)
}

