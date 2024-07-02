//
//  Array+Extensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension Array {
    func itemAt(_ index: Int) -> Element? {
        guard index > -1, count > index else { return nil }
        return self[index]
    }
}
