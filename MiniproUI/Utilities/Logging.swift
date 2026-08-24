//
//  Logging.swift
//  Visual Minipro
//

import Foundation
import os

extension Logger {
    /// Unified logging groups messages by subsystem, so use the app's own
    /// bundle identifier: `log stream --predicate 'subsystem == "..."'`.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "VisualMinipro"

    init(category: String) {
        self.init(subsystem: Logger.subsystem, category: category)
    }
}
