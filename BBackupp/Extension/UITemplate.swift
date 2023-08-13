//
//  UITemplate.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

enum UITemplate {
    typealias IsFirstButtonReturn = Bool
    typealias IsRightButtonReturn = Bool

    struct ThatSheetView: View {
        @Environment(\.dismiss) var dismiss
        let title: String
        let leftButton: String
        let rightButton: String
        let toolbar: (() -> (AnyView))?
        let createBody: () -> (AnyView)
        let complete: (IsRightButtonReturn) -> Void

        init(
            title: String,
            leftButton: String,
            rightButton: String,
            toolbar: (() -> (AnyView))? = nil,
            createBody: @escaping () -> (AnyView),
            complete: @escaping ((UITemplate.IsRightButtonReturn) -> Void)
        ) {
            self.title = title
            self.leftButton = leftButton
            self.rightButton = rightButton
            self.toolbar = toolbar
            self.createBody = createBody
            self.complete = complete
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if title.isEmpty, toolbar == nil {
                } else {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        if let toolbar { toolbar() }
                    }
                    Divider()
                }
                createBody().frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                HStack {
                    if !leftButton.isEmpty {
                        Button { complete(false) } label: { Text(leftButton) }
                    }
                    Spacer()
                    if !rightButton.isEmpty {
                        Button { complete(true) } label: { Text(rightButton) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .background(
                    Button("") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .opacity(0)
                )
            }
            .padding()
        }
    }

    static func makeSheet(
        title: String,
        leftButton: String = "Cancel",
        rightButton: String = "Done",
        toolbar: (() -> (AnyView))? = nil,
        body: @escaping () -> (AnyView),
        complete: @escaping (IsRightButtonReturn) -> Void
    ) -> some View {
        ThatSheetView(
            title: title,
            leftButton: leftButton,
            rightButton: rightButton,
            toolbar: toolbar,
            createBody: body,
            complete: complete
        )
    }

    struct ThatProgressView: View {
        @Binding var reason: String

        @State var pinReasonBeforeDismiss: String = ""
        var body: some View {
            ProgressView(pinReasonBeforeDismiss)
                .onAppear {
                    pinReasonBeforeDismiss = reason
                }
                .frame(width: 400, height: 200)
        }
    }

    static func makeProgress(text: Binding<String> = .constant("")) -> some View {
        ThatProgressView(reason: text)
    }

    static func makeConfirmation(
        message: String,
        firstButtonText: String = "Sure",
        secondButtonText: String = "Cancel",
        delay: Double = 0,
        onConfirm: @escaping (IsFirstButtonReturn) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = message
            alert.addButton(withTitle: firstButtonText)
            alert.addButton(withTitle: secondButtonText)
            guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
                return
            }
            alert.beginSheetModal(for: window) { resp in
                onConfirm(resp == .alertFirstButtonReturn)
            }
        }
    }

    static func makeErrorAlert(with error: Error, delay: Double = 0, completion: (() -> Void)? = nil) {
        makeErrorAlert(with: error.localizedDescription, delay: delay, completion: completion)
    }

    static func makeErrorAlert(with error: String, delay: Double = 0, completion: (() -> Void)? = nil) {
        makeAlert(withMessage: error, isError: true, delay: delay, completion: completion)
    }

    static func makeAlert(withMessage message: String, informativeText: String? = nil, isError: Bool = false, delay: Double = 0, completion: (() -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let alert = NSAlert()
            alert.alertStyle = isError ? .critical : .informational
            alert.messageText = message
            alert.informativeText = informativeText ?? ""
            alert.addButton(withTitle: "Done")
            guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
                return
            }

            alert.beginSheetModal(for: window) { _ in
                completion?()
            }
        }
    }

    static func requestToSave(filename: String, startDir: String? = nil, adjust: ((NSSavePanel) -> Void)? = nil, completion: @escaping (URL?) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem(block: {
                requestToSave(filename: filename, startDir: startDir, adjust: adjust, completion: completion)
            }))
            return
        }
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = filename
        if let directory = startDir {
            savePanel.directoryURL = URL(fileURLWithPath: directory)
        }
        adjust?(savePanel)
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
            completion(nil)
            return
        }
        savePanel.beginSheetModal(for: window) { response in
            assert(Thread.isMainThread)
            if response == .OK {
                completion(savePanel.url)
            } else {
                completion(nil)
            }
        }
    }

    static func buildSection(_ title: String, build: () -> (some View)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            build()
        }
    }

    static func askForInputText(
        title: String,
        message: String,
        confirmButton _: String = "Done",
        cancelButton _: String = "Cancel",
        placeholder: String,
        isPassword: Bool = false,
        onConfirm: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
            onConfirm(nil)
            return
        }

        if isPassword {
            let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            textField.placeholderString = placeholder
            alert.accessoryView = textField

            alert.beginSheetModal(for: window) { response in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        let inputText = textField.stringValue
                        onConfirm(inputText.isEmpty ? nil : inputText)
                    } else {
                        onConfirm(nil)
                    }
                }
            }
        } else {
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            textField.placeholderString = placeholder
            alert.accessoryView = textField

            alert.beginSheetModal(for: window) { response in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        let inputText = textField.stringValue
                        onConfirm(inputText.isEmpty ? nil : inputText)
                    } else {
                        onConfirm(nil)
                    }
                }
            }
        }
    }
}
