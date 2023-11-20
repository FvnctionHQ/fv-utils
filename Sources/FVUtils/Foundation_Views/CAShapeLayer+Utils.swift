//
//  CAShaperLayer+Helpers.swift
//
//  Created by Alex Linkow on 26.02.23.
//

import Foundation
import UIKit

public extension CAShapeLayer {
    
    func drawCircle(in rect: CGRect, with configuration: PathConfiguration) {
        
        let center = CGPoint(x: rect.maxX / 2, y: rect.maxY / 2)
        
        let longestSide = rect.height < rect.width ? rect.height : rect.width
        
        let circularPath = UIBezierPath(arcCenter: center, radius: (longestSide / 2) - (configuration.lineWidth / 2), startAngle: configuration.startAngle, endAngle: 2 * CGFloat.pi, clockwise: true)
        
        self.path = circularPath.cgPath
        self.fillColor = UIColor.clear.cgColor
        self.strokeColor = configuration.color.cgColor
        self.lineWidth = configuration.lineWidth
        self.lineCap = CAShapeLayerLineCap.round
        
        switch configuration.type {
        case .progress:
            self.strokeEnd = 0
        case .track:
            self.strokeEnd = 1
        case .custom(let value):
            self.strokeEnd = value
        }
    }
}

public struct PathConfiguration {
    let color: UIColor
    let lineWidth: CGFloat
    let startAngle: CGFloat
    let type: TrackType
}

public enum TrackType {
    case progress, track
    case custom(CGFloat)
}
