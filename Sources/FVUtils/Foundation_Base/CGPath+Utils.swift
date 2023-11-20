//
//  CGPath.swift
//
//  Created by Alex Linkow on 28.09.23.
//

import Foundation
import CoreGraphics


public extension CGPath {

  var points: [CGPoint] {

     var arrPoints: [CGPoint] = []

     self.applyWithBlock { element in

        switch element.pointee.type
        {
        case .moveToPoint, .addLineToPoint:
          arrPoints.append(element.pointee.points.pointee)

        case .addQuadCurveToPoint:
          arrPoints.append(element.pointee.points.pointee)
          arrPoints.append(element.pointee.points.advanced(by: 1).pointee)

        case .addCurveToPoint:
          arrPoints.append(element.pointee.points.pointee)
          arrPoints.append(element.pointee.points.advanced(by: 1).pointee)
          arrPoints.append(element.pointee.points.advanced(by: 2).pointee)

        default:
          break
        }
     }

    return arrPoints

  }
}
