//
//  Duration+Extensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension Duration {
    var milliseconds: Double {
        (Double(components.seconds) * 1000) + (Double(components.attoseconds) * 1e-15)
    }
}
