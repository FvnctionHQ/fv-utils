//
//  File.swift
//
//  Created by Alex Linkow on 20.11.23.
//

import Foundation
import Accelerate


public extension Array where Element == Float {
    func fastAverage() -> Float {
        guard !isEmpty else { return 0 }
        return vDSP.mean(self)
        
    }
}

public extension Array where Element == Double {
    func fastAverage() -> Double {
        guard !isEmpty else { return 0 }
        return vDSP.mean(self)
    }
}

public extension Array where Element: FloatingPoint {
    
    func average() -> Element {
        guard !self.isEmpty, let zero = Element(exactly: 0) else {
            return 0
        }

        let sum = self.reduce(zero, +)
        return sum / Element(self.count)
    }
}
