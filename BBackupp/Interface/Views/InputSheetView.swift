//
//  InputSheetView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/7.
//

import SwiftUI

struct InputSheetView: View {
    let spacing: CGFloat = 16
    @Environment(\.dismiss) var dismiss

    let title: String
    let message: String
    let isPassword: Bool
    let doubleCheck: Bool
    let width: CGFloat

    init(
        title: String,
        message: String = "",
        isPassword: Bool = false,
        doubleCheck: Bool = false,
        width: CGFloat = 400,
        onConfirm: @escaping (String) -> Void
    ) {
        self.title = title
        self.message = message
        self.isPassword = isPassword
        self.doubleCheck = doubleCheck
        self.width = width
        self.onConfirm = onConfirm
    }

    let onConfirm: (String) -> Void

    @State var text: String = ""
    @State var doubleCheckText: String = ""

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
            VStack(alignment: .leading, spacing: spacing) {
                if !message.isEmpty {
                    Text(message).frame(maxWidth: .infinity, alignment: .leading)
                }
                if isPassword {
                    SecureField("", text: $text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onSubmit { confirmCheckSend() }
                } else {
                    TextField("", text: $text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onSubmit { confirmCheckSend() }
                }
                if doubleCheck {
                    Text("Please enter the same value again").frame(maxWidth: .infinity, alignment: .leading)
                    if isPassword {
                        SecureField("", text: $doubleCheckText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onSubmit { confirmCheckSend() }
                    } else {
                        TextField("", text: $doubleCheckText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onSubmit { confirmCheckSend() }
                    }
                }
            }
            .padding(spacing)
            Divider()
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("OK") { confirmCheckSend() }
                    .disabled(doubleCheck && doubleCheckText != text)
            }
            .padding(spacing)
        }
        .frame(width: width)
        .onAppear { text = "" }
    }

    func confirmCheckSend() {
        guard !(doubleCheck && doubleCheckText != text) else { return }
        dismiss()
        onConfirm(text)
    }
}
