//
//  Color.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/12.
//

import SwiftUI

public extension Color {
    #if os(macOS)
        static let background = Color(NSColor.windowBackgroundColor)
        static let secondaryBackground = Color(NSColor.underPageBackgroundColor)
        static let tertiaryBackground = Color(NSColor.controlBackgroundColor)
    #else
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    #endif
}
