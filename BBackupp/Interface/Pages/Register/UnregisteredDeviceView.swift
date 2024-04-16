//
//  UnregisteredDeviceView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import SwiftUI

struct UnregisteredDeviceView: View {
    let device: UnregisteredDevice

    @State var openRegisterSheet: Bool = false
    @StateObject var manager = devManager

    var alreadyRegistered: Bool {
        manager.devices.keys.contains(device.udid)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: device.deviceSystemIcon)
                    Text(device.productType)
                        .lineLimit(1)
                }
                .font(.system(.headline, design: .rounded))
                Text(device.trusted ? device.deviceName : device.udid)
                    .font(.footnote)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: alreadyRegistered ? "checkmark" : "arrow.right")
                .font(.system(.headline, design: .rounded))
        }
        .contentShape(Rectangle())
        .onTapGesture { openRegisterSheet = true }
        .sheet(isPresented: $openRegisterSheet) {
            RegisterDeviceSheetView(device: device)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .disabled(alreadyRegistered)
        .opacity(alreadyRegistered ? 0.5 : 1)
    }
}
