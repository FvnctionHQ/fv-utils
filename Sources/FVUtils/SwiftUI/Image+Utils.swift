//
//  File.swift
//  
//
//  Created by Alex Linkow on 20.11.23.
//

import Foundation
import SwiftUI

public extension Image {
    init(systemNameWithFallback symbol: String, fallback: String = "triangle.circle") {
        if let _ = UIImage(systemName: symbol) {
            self.init(systemName: symbol)
        } else {
            self.init(systemName: fallback)
        }
    }
}
