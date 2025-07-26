//
//  RegisterSheetView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import ColorfulX
import SwiftUI

struct RegisterSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let timer = Timer
        .publish(every: 5, on: .main, in: .common)
        .autoconnect()

    @State var isScanning = false
    @State var deviceList: [UnregisteredDevice] = []

    let spacing: CGFloat = 16

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Register Device").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
            ZStack {
                if deviceList.isEmpty {
                    Image("computer_smartphone_connect")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100, alignment: .center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    ScrollView(.vertical) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 180, maximum: 180), spacing: spacing / 2)],
                            alignment: .leading,
                            spacing: spacing / 2
                        ) {
                            ForEach(deviceList) {
                                UnregisteredDeviceView(device: $0)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.interactiveSpring.speed(0.5), value: deviceList)
            .padding(spacing)
            Divider()
            HStack {
                Text(isScanning ? "Scanning Devices" : "Please connect your device via cable.")
                    .contentTransition(.numericText())
                    .animation(.interactiveSpring(), value: isScanning)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(spacing)
        }
        .frame(width: 450, height: 300)
        .background(background.ignoresSafeArea())
        .onReceive(timer) { _ in scan() }
        .task { scan() } // start scan before appearing for better animation result
    }

    @ViewBuilder
    var background: some View {
        if colorScheme == .light {
            Color.clear
        } else {
            ColorfulView(
                color: .constant(ColorfulPreset.jelly.colors.map(Color.init(_:))),
                speed: .constant(0.5)
            )
            .opacity(0.25)
        }
    }

    func scan() {
        isScanning = true
        var listCopy = deviceList
        DispatchQueue.global().async {
            let scan = amdManager
                .listDeviceIdentifiers()
                .compactMap { amdManager.obtainDeviceInfo(udid: $0, connection: .usb) }
                .compactMap { input -> UnregisteredDevice? in
                    guard let udid = input.uniqueDeviceID else { return nil }
                    return UnregisteredDevice(udid: udid, deviceRecord: input)
                }
            let existing = Set(listCopy.map(\.udid))
            for device in scan where !existing.contains(device.udid) {
                listCopy.append(device)
            }
            listCopy.sort { $0.udid < $1.udid }
            sleep(2)
            DispatchQueue.main.async {
                isScanning = false
                deviceList = listCopy
            }
        }
    }
}
