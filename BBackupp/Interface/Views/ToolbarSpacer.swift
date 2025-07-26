//
//  ToolbarSpacer.swift
//  BBackupp
//
//  Created by luca on 26.07.2025.
//

import SwiftUI

struct _ToolbarSpacer: ToolbarContent {
    var body: some ToolbarContent {
        #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                ToolbarSpacer()
            } else {
                ToolbarItem {
                    Button {} label: { Image(systemName: "circle.fill").opacity(0) }
                        .disabled(true)
                }
            }
        #else
            ToolbarItem {
                Button {} label: { Image(systemName: "circle.fill").opacity(0) }
                    .disabled(true)
            }
        #endif
    }
}
