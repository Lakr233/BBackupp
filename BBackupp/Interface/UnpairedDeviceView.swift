//
//  UnpairedDeviceView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

struct UnpairedDeviceView: View {
    @StateObject var device: Device
    @State var openDeviceInfo: Bool = false

    init(device: Device) {
        _device = .init(wrappedValue: device)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Image("smartphone_shimon_ninsyou_screen")
                .resizable()
                .antialiased(true)
                .aspectRatio(contentMode: .fill)
                .frame(width: 128, height: 128, alignment: .center)
            HStack {
                Button("Export Device Info") {
                    openDeviceInfo = true
                }
                .sheet(isPresented: $openDeviceInfo) {
                    DeviceInfoSheet(device: device, openSheet: $openDeviceInfo)
                }
                Button("Pair & Setup") {
                    appleDevice.sendPairRequest(udid: device.universalDeviceIdentifier)
                    UITemplate.makeAlert(
                        withMessage: "Please continue on device",
                        informativeText: "If nothing happens, disconnect your device and try and."
                    ) {
                        DispatchQueue.global().async {
                            deviceManager.scanDeviceStatus()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .navigationTitle("\(device.deviceName) - \(device.deviceRecord?.deviceClass ?? "Unknown Device Type")")
    }
}
