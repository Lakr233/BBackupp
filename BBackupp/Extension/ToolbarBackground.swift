//
//  ToolbarBackground.swift
//  BBackupp
//
//  Created by luca on 26.07.2025.
//

import SwiftUI

extension View {
    @ViewBuilder func hideToolbarBackground() -> some View {
        if #available(macOS 15.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .automatic)
        } else {
            self
        }
    }
}
