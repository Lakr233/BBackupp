//
//  PairInstructionView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

struct PairInstructionView: View {
    @Binding var openSheet: Bool
    @State var openProgress: Bool = false

    var body: some View {
        UITemplate.makeSheet(
            title: "Pair Device",
            leftButton: "Cancel",
            rightButton: "Scan Now"
        ) {
            AnyView(sheet)
        } complete: { confirmed in
            if confirmed {
                scanNew()
            } else {
                openSheet = false
            }
        }
        .sheet(isPresented: $openProgress) {
            UITemplate.makeProgress(text: .constant("Scanning Devices"))
        }
    }

    var sheet: some View {
        VStack(alignment: .center, spacing: 12) {
            Image("computer_smartphone_connect")
                .resizable()
                .antialiased(true)
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60, alignment: .center)
            Text("Connect your device via a cable.")
                .font(.system(.headline, design: .rounded, weight: .bold))
            HStack {
                Text("💡")
                Text("For untrusted devices, use a cable to connect. When it appears in the sidebar, select it to setup.")
            }
            .font(.system(.body, design: .rounded, weight: .regular))
        }
        .padding(.vertical)
        .frame(width: 400)
    }

    func scanNew() {
        openProgress = true
        DispatchQueue.global().async {
            let prevCount = deviceManager.devices.count
            deviceManager.scanDeviceStatus()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                openProgress = false
                if deviceManager.devices.count > prevCount {
                    openSheet = false
                }
            }
        }
    }
}
