//
//  DeviceReachableLabel.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import SwiftUI

struct DeviceReachableLabel: View {
    let udid: Device.ID

    enum Style {
        case icon
        case label
        case text
    }

    let style: Style
    init(udid: Device.ID, style: Style = .label) {
        self.udid = udid
        self.style = style
    }

    @State var isCheckingReachable = false
    @State var wireReachable = false
    @State var wirelessReachable = false

    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var reachableHint: String {
        if isCheckingReachable { return "Checking Connection" }
        if wireReachable { return "USB Connection" }
        if wirelessReachable { return "Wireless Connection" }
        return "Not Reachable"
    }

    var reachableHintIcon: String {
        if isCheckingReachable { return "hourglass" }
        if wireReachable { return "cable.connector" }
        if wirelessReachable { return "wifi" }
        return "cable.connector.slash"
    }

    var reachableHintIconColor: Color {
        if isCheckingReachable { return .gray }
        if wireReachable { return .green }
        if wirelessReachable { return .accent }
        return .red
    }

    @ViewBuilder
    var content: some View {
        switch style {
        case .icon: Image(systemName: reachableHintIcon)
        case .label: Label(reachableHint, systemImage: reachableHintIcon)
        case .text: Text(reachableHint)
        }
    }

    var body: some View {
        ForEach([udid], id: \.self) { udid in
            content
                .id(udid)
                .foregroundStyle(reachableHintIconColor)
                .onAppear {
                    wireReachable = false
                    wirelessReachable = false
                    checkReachable()
                }
                .onReceive(timer) { _ in checkReachable() }
        }
    }

    func checkReachable() {
        guard !isCheckingReachable else { return }
        isCheckingReachable = true
        let group = DispatchGroup()

        DispatchQueue.global().async {
            group.enter()
            var reachable = false
            defer { DispatchQueue.main.async {
                wireReachable = reachable
                group.leave()
            } }
            amdManager.requireDevice(udid: udid, connection: .usb) { device in
                guard let device else { return }
                amdManager.requireLockdownClient(device: device, handshake: true) { client in
                    guard client != nil else { return }
                    reachable = true
                }
            }
        }

        DispatchQueue.global().async {
            group.enter()
            var reachable = false
            defer { DispatchQueue.main.async {
                wirelessReachable = reachable
                group.leave()
            } }
            amdManager.requireDevice(udid: udid, connection: .net) { device in
                guard let device else { return }
                amdManager.requireLockdownClient(device: device, handshake: true) { client in
                    guard client != nil else { return }
                    reachable = true
                }
            }
        }

        DispatchQueue.global().async {
            group.wait()
            DispatchQueue.main.async {
                isCheckingReachable = false
            }
        }
    }
}
