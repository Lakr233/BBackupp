//
//  MessageBoxView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import SwiftUI

struct MessageBoxView<Content: View>: View {
    let spacing: CGFloat = 16
    @Environment(\.dismiss) var dismiss

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Message").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
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
        .frame(width: 450)
    }
}
