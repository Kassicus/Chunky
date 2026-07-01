//
//  Item.swift
//  chunky
//
//  Created by Kason Suchow on 7/1/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
