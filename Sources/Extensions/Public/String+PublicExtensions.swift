//
//  String+PublicExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension String: EncodedHashable {
    public var hashFactors: [String] { [self] }
}
