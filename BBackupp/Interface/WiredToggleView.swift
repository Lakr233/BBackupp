//
//  WiredToggle.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import SwiftUI

struct WiredToggleView: View {
    @Binding var isOn: Bool
    var label: () -> AnyView
    var tapped: () -> Void

    var body: some View {
        Toggle(isOn: $isOn) { label() }
            .overlay {
                Button {
                    tapped()
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
    }
}
