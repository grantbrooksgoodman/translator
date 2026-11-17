//
//  EncodedHashableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

protocol EncodedHashable {
    var hashFactors: [String] { get }
}

extension EncodedHashable {
    var encodedHash: String {
        do {
            return try JSONEncoder().encode(hashFactors).encodedHash
        } catch {
            return Data().encodedHash
        }
    }
}
