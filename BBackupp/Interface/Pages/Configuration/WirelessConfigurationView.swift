//
//  WirelessConfigurationView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/10.
//

import SwiftUI

struct WirelessConfigurationSheetView: View {
    let udid: Device.ID

    var body: some View {
        SheetPanelView("Configure") {
            WirelessConfigurationView(udid: udid)
        }
    }
}

struct WirelessConfigurationView: View {
    let udid: Device.ID
    let spacing: CGFloat = 16

    enum WirelessStatus: String {
        case unknown
        case determining
        case enabled
        case disabled
    }

    @State var status: WirelessStatus = .determining
    @State var backupAddress: String = ""

    @State var openDisableWirelessConnectionAlert: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            control
            address
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
                Text("Wireless Connection")
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
                Text("This option can be enabled after pair your device to this computer. It is recommended to keep disabled if you dont trust current network.")
                Text("If you disabled this option, you will need a wire to enable it.")
                    .underline()
                HStack { buttons }
            }
        }
        .onAppear { updateDeviceStatus() }
    }

    @ViewBuilder
    var buttons: some View {
        switch status {
        case .unknown:
            Button {
                updateDeviceStatus()
            } label: {
                Text("Check Again")
            }
        case .determining:
            Button {
                updateDeviceStatus()
            } label: {
                Text("Determining")
            }
            .disabled(true)
        case .enabled:
            Button {
                openDisableWirelessConnectionAlert = true
            } label: {
                Text("Disable").foregroundStyle(.red)
            }
            .alert(isPresented: $openDisableWirelessConnectionAlert) {
                Alert(
                    title: Text("Disable Wireless Connection"),
                    message: Text("You will need a wire to enable it again."),
                    primaryButton: .destructive(Text("Disable")) {
                        amdManager.setDeviceWirelessConnectionEnabled(
                            udid: udid,
                            enabled: false
                        )
                        updateDeviceStatus()
                    },
                    secondaryButton: .cancel()
                )
            }
            Button {
                updateDeviceStatus()
            } label: {
                Text("Check Again")
            }
        case .disabled:
            Button {
                amdManager.setDeviceWirelessConnectionEnabled(
                    udid: udid,
                    enabled: true
                )
                updateDeviceStatus()
            } label: {
                Text("Enable")
            }
            Button {
                updateDeviceStatus()
            } label: {
                Text("Check Again")
            }
        }
    }

    var address: some View {
        Group {
            HStack {
                Text("Backup Address (Optional)")
                    .lineLimit(1)
                    .bold()
                Spacer()
                Image(systemName: "pencil.and.list.clipboard")
            }
            Text("You can set addresses to be used when device can not be found automatically. Currently, one **ipv4** address is supported.")

            Text("Does not guarantee to work, it is recommended to keep empty.")
                .underline()

            TextField("Address", text: $backupAddress)
                .monospaced()
                .frame(maxWidth: .infinity)
                .onAppear {
                    backupAddress = devManager.devices[udid]?
                        .possibleNetworkAddress
                        .joined(separator: "\n")
                        ?? ""
                }
                .onDisappear { saveBackupAddress() }
        }
    }

    func updateDeviceStatus() {
        status = .determining
        saveBackupAddress()
        DispatchQueue.global().async {
            let enabled = amdManager.isDeviceWirelessConnectionEnabled(udid: udid)
            sleep(1)
            DispatchQueue.main.async {
                status = enabled ?? false ? .enabled : .disabled
            }
        }
    }

    func saveBackupAddress() {
        devManager.devices[udid]?.possibleNetworkAddress = backupAddress
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
