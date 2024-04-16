//
//  ExportPairRecordView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/7.
//

import SwiftUI

struct ExportPairRecordSheetView: View {
    let udid: Device.ID

    var body: some View {
        SheetPanelView("Export") {
            ExportPairRecordView(udid: udid)
        }
    }
}

struct ExportPairRecordView: View {
    let udid: Device.ID
    let spacing: CGFloat = 16

    var pairRecrod: PairRecord? {
        devManager.devices[udid]?.pairRecord
    }

    var recordFingerPrint: String {
        pairRecrod?.fingerprint ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack {
                Text("Pair Record")
                    .lineLimit(1)
                    .bold()
                Spacer()
                Image(systemName: "cable.coaxial")
            }
            Text("Your pair record contains the key to access your device. It is recommended to keep it safe.")
            Text("Leaked pair record will allow unauthorized access without your notice.")
                .underline()
            Button {
                guard let pairRecrod else { return }
                NSApp.beginSavePanel { panel in
                    panel.setup(
                        title: "Export Pair Record",
                        nameFieldStringValue: "PairRecord-\(udid).plist"
                    )
                } completion: { url in
                    try? FileManager.default.removeItem(at: url)
                    try? pairRecrod.propertyListBinaryData.write(to: url)
                }
            } label: {
                Text("Export Pair Record")
                    .foregroundStyle(.red)
            }
            Text("\(recordFingerPrint.uppercased())")
                .font(.system(.footnote, design: .monospaced))
                .opacity(0.5)
        }
    }
}
