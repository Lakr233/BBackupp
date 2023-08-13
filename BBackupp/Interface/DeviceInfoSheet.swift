//
//  DeviceInfoSheet.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

struct DeviceInfoSheet: View {
    @State var device: Device
    @Binding var openSheet: Bool

    var body: some View {
        deviceInfoSheet
    }

    var deviceInfoSheet: some View {
        UITemplate.makeSheet(
            title: "Device Info",
            leftButton: "Export",
            rightButton: "Done"
        ) {
            AnyView(deviceInfoBody)
        } complete: { isRightButtonReturn in
            if isRightButtonReturn {
                openSheet = false
            } else {
                UITemplate.requestToSave(
                    filename: "\(device.deviceName).plist"
                ) { url in
                    guard let url else { return }
                    try? device.deviceRecord?.plistData?.write(to: url)
                }
            }
        }
    }

    var deviceInfoBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(device.deviceRecord?.xml ?? "Unable to parse device information.")
                .font(.system(.body, design: .monospaced, weight: .regular))
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(idealWidth: 555, idealHeight: 233)
    }
}
