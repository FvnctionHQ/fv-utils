//
//  Drawing+Utils.swift
//
//  Created by Alex Linkow on 13.03.23.
//

import Foundation
import UIKit

public extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(x - point.x, y - point.y)
    }
    
    func angleFromHorizontal(to point: CGPoint) -> Double {
        let angle = atan2(point.y - y, point.x - x)
        let deg = Swift.abs(angle * (180.0 / CGFloat.pi))
        return Double(round(100 * deg) / 100)
    }
    
    func devicePointConverted() -> CGPoint {
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait:
            return CGPoint(x: self.y, y: 1 - self.x)
        case .portraitUpsideDown:
            return CGPoint(x: 1 - self.y, y: self.x)
        case .landscapeLeft:
            return self
        case .landscapeRight:
            return CGPoint(x: 1 - self.x, y: 1 - self.y)
        default:
            // Fallback to system behavior
            return CGPoint.zero
        }
    }
}
