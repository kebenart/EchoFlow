//
//  Item.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
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
