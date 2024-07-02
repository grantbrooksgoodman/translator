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
        let jsonEncoder = JSONEncoder()

        do {
            return try jsonEncoder.encode(hashFactors).encodedHash
        } catch {
            return Data().encodedHash
        }
    }
}
