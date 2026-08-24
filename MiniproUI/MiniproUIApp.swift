//
//  MiniproUIApp.swift
//  MiniproUI
//
//  Created by Pawel Kadluczka on 1/16/25.
//

import SwiftUI

@main
struct MiniproUIApp: App {
    init() {
        if UserDefaults.standard.libusbDebugLogging {
            setenv("LIBUSB_DEBUG", "4", 1)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Only applies to the first launch; after that the window frame is restored.
        .defaultSize(width: 1500, height: 900)
    }
}
