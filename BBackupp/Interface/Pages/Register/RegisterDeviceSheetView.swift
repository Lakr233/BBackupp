//
//  RegisterDeviceSheetView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import AppleMobileDeviceLibrary
import ColorfulX
import SwiftUI

struct RegisterDeviceSheetView: View {
    let device: UnregisteredDevice

    let spacing: CGFloat = 16
    @Environment(\.dismiss) var dismiss

    @State var pairRecord: PairRecord? = nil
    @State var openPairHint = false
    @State var openImportDialog = false
    @State var openWirelessSetupPanel = false
    @State var openBackupEncryptionSetupPanel = false

    var completed: Bool {
        if pairRecord == nil { return false }
        return true
    }

    let timer = Timer
        .publish(every: 3, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Register Device").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
            content.padding(spacing)
            Divider()
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Register") {
                    guard let pairRecord, let deviceRecord = device.deviceRecord else {
                        return
                    }
                    let device = Device(
                        udid: device.udid,
                        deviceRecord: deviceRecord,
                        pairRecord: pairRecord,
                        extra: .init(),
                        possibleNetworkAddress: []
                    )
                    devManager.register(device: device)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!completed)
            }
            .padding(spacing)
        }
        .frame(width: 450)
        .onReceive(timer) { _ in checkPairRecord() }
    }

    var content: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Group {
                RegisterStepHeaderView(
                    title: "Connect to Device",
                    optional: false,
                    completed: true
                )
                Text("\(Image(systemName: device.deviceSystemIcon)) \(device.productType) \(device.deviceRecord?.productVersion ?? "?") \(device.udid)")
            }

            Group {
                RegisterStepHeaderView(
                    title: "Verify Ownership",
                    optional: false,
                    completed: pairRecord != nil
                )
                Text("Please trust this computer on your device.")
                HStack {
                    Button("Pair Device") {
                        amdManager.sendPairRequest(udid: device.udid, connection: .usb)
                        openPairHint = true
                    }
                    .sheet(isPresented: $openPairHint) {
                        MessageBoxView {
                            Group {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Pair request has been sent to device.").bold()
                                }
                                Text("Please check the device screen for confirmation.")
                                Text("If you don't see the confirmation prompt, disconnect the device from your computer and try again.")
                            }
                        }
                    }
                    Button("Import Pair Record") {
                        openImportDialog = true
                    }
                    .fileImporter(
                        isPresented: $openImportDialog,
                        allowedContentTypes: [.propertyList],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case let .success(success):
                            guard let url = success.first else { return }
                            readPairRecord(from: url)
                        case .failure: break
                        }
                    }
                }
                .disabled(pairRecord != nil)
                .onAppear { checkPairRecord() }
                .onChange(of: pairRecord) { newValue in
                    if newValue != nil {
                        openPairHint = false
                        openImportDialog = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func checkPairRecord() {
        guard pairRecord == nil else { return }
        guard let record = amdManager.obtainPairRecord(udid: device.udid),
              let ourRecord = PairRecord(record, udid: device.udid)
        else { return }
        pairRecord = ourRecord
    }

    func readPairRecord(from url: URL) {
        print("[*] reading data from \(url.path)")
        do {
            let data = try Data(contentsOf: url)
            let pair = try PropertyListDecoder().decode(PairRecord.self, from: data)
            enum ImportError: Error { case deviceNotFound }

            let binaryData = pair.propertyListBinaryData as NSData
            let ret = usbmuxd_save_pair_record_with_device_id(
                pair.udid,
                0,
                binaryData.bytes,
                UInt32(binaryData.length)
            )
            print("[*] usbmuxd_save_pair_record_with_device_id: \(ret)")
            amdManager.sendPairRequest(udid: pair.udid)
            checkPairRecord()
        } catch {
            print(error)
        }
    }
}
