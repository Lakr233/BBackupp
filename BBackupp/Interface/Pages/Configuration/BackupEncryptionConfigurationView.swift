//
//  BackupEncryptionConfigurationView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/10.
//

import SwiftUI

struct BackupEncryptionConfigurationSheetView: View {
    let udid: Device.ID

    var body: some View {
        SheetPanelView("Configure") {
            BackupEncryptionConfigurationView(udid: udid)
        }
    }
}

struct BackupEncryptionConfigurationView: View {
    let spacing: CGFloat = 16
    let udid: Device.ID

    enum EncryptionStatus: String {
        case unknown
        case determining
        case enabled
        case disabled
    }

    @State var status: EncryptionStatus = .determining

    @State var openHint: Bool = false
    @State var openEnableInput: Bool = false
    @State var openDisableInput: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            control
        }
    }

    var icon: String {
        switch status {
        case .unknown:
            "questionmark.circle"
        case .determining:
            "hourglass"
        case .enabled:
            "checkmark.circle.fill"
        case .disabled:
            "xmark.circle.fill"
        }
    }

    var control: some View {
        Group {
            HStack {
                Text("Backup Encryption")
                    .lineLimit(1)
                    .bold()
                Spacer()
                ZStack {
                    Image(systemName: "circle.fill")
                        .opacity(0)
                    ForEach([icon], id: \.self) { _ in
                        Image(systemName: icon)
                            .foregroundStyle(status == .enabled ? .green : .primary)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.interactiveSpring.speed(0.5), value: icon)
            }
            Group {
                Text("Backup encryption is required for full backup with sensitive data including keychain.")
                Text("This password is independent from the device passcode.")
                    .underline()
                Text("If you forgot the password, you need to reset all settings on your device. [https://support.apple.com/108313](https://support.apple.com/108313)")
                HStack { buttons }
                Text("If this utility is not working, use the one in Finder instead.")
                    .underline()
            }
            .alert(isPresented: $openHint) {
                Alert(
                    title: Text("Request Sent"),
                    message: Text("Confirm changes on your device and then click done to refresh."),
                    dismissButton: .default(Text("Done")) { updateDeviceStatus() }
                )
            }
        }
        .onAppear { updateDeviceStatus() }
    }

    @ViewBuilder
    var buttons: some View {
        switch status {
        case .unknown:
            Button { updateDeviceStatus() } label: { Text("Check Again") }
        case .determining:
            Button("Determining") {}
                .disabled(true)
        case .enabled:
            Button { openDisableInput = true } label: {
                Text("Disable").foregroundStyle(.red)
            }
            .sheet(isPresented: $openDisableInput) {
                InputSheetView(
                    title: "Password",
                    message: "Password is required to disable encryption.",
                    isPassword: true
                ) { password in
                    amdManager.disableBackupPassword(udid: udid, currentPassword: password)
                    openHint = true
                }
            }
            Button { updateDeviceStatus() } label: { Text("Check Again") }
        case .disabled:
            Button { openEnableInput = true } label: {
                Text("Enable")
            }
            .sheet(isPresented: $openEnableInput) {
                InputSheetView(
                    title: "Password",
                    message: "Password is required to enable encryption.",
                    isPassword: true,
                    doubleCheck: true
                ) { password in
                    amdManager.enableBackupPassword(udid: udid, password: password)
                    openHint = true
                }
            }
            Button { updateDeviceStatus() } label: { Text("Check Again") }
        }
    }

    func updateDeviceStatus() {
        status = .determining
        DispatchQueue.global().async {
            var enabled: Bool? = nil
            if let read = amdManager.readFromLockdown(udid: udid, domain: "com.apple.mobile.backup", key: nil),
               let dic = read.value as? [String: Any],
               let value = dic["WillEncrypt"] as? Bool
            { enabled = value }
            sleep(1)
            DispatchQueue.main.async {
                guard let enabled else {
                    status = .unknown
                    return
                }
                status = enabled ? .enabled : .disabled
            }
        }
    }
}
