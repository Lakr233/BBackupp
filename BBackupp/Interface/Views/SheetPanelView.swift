//
//  SheetPanelView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/10.
//

import SwiftUI

struct SheetPanelView<Content: View>: View {
    let spacing: CGFloat = 16
    @Environment(\.dismiss) var dismiss

    let title: String
    let width: CGFloat
    init(_ title: String = "", width: CGFloat = 450, viewBuilder: () -> Content) {
        self.title = title
        self.width = width
        content = viewBuilder()
    }

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if !title.isEmpty {
                HStack {
                    Text(title).bold()
                    Spacer()
                }
                .padding(spacing)
                Divider()
            }
            VStack(alignment: .leading, spacing: 8) {
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(spacing)
            Divider()
            HStack {
                Spacer()
                Button("OK") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(spacing)
        }
        .frame(width: width)
    }
}
