//
//  NotificationSetupView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import SwiftUI

struct NotificationSetupView: View {
    @Binding var provider: Device.Configuration.NotificationProvider
    @Binding var config: Device.Configuration.NotificationConfig

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            switch provider {
            case .none: buildForNone()
            case .bark: buildForBark()
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }

    func buildForNone() -> some View {
        Text("Unsupported")
    }

    @State var barkEndpoint: String = ""
    @State var barkGroup: String = ""
    @State var barkIcon: String = ""
    @State var barkSound: String = ""
    func buildForBark() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            UITemplate.buildSection(provider.interfaceText) {
                Group {
                    Text(provider.descriptionText)
                    Text("To setup this app on device, visit [https://github.com/Finb/Bark](https://github.com/Finb/Bark) for details.")
                }
            }
            Divider()
            UITemplate.buildSection("Required Field") {
                HStack {
                    Text("Endpoint").frame(width: 100, alignment: .trailing)
                    TextField("Endpoint", text: $barkEndpoint)
                        .onAppear { barkEndpoint = config["endpoint", default: ""] }
                        .onChange(of: barkEndpoint) { newValue in
                            config["endpoint"] = newValue
                        }
                }
            }
            Divider()
            UITemplate.buildSection("Optional") {
                Group {
                    HStack {
                        Text("Group").frame(width: 100, alignment: .trailing)
                        TextField("Group", text: $barkGroup)
                            .onAppear { barkGroup = config["group", default: ""] }
                            .onChange(of: barkGroup) { newValue in
                                config["group"] = newValue
                            }
                    }
                    HStack {
                        Text("Icon").frame(width: 100, alignment: .trailing)
                        TextField("Icon", text: $barkIcon)
                            .onAppear { barkIcon = config["icon", default: ""] }
                            .onChange(of: barkIcon) { newValue in
                                config["icon"] = newValue
                            }
                    }
                    HStack {
                        Text("Sound").frame(width: 100, alignment: .trailing)
                        TextField("Sound", text: $barkSound)
                            .onAppear { barkSound = config["sound", default: ""] }
                            .onChange(of: barkSound) { newValue in
                                config["sound"] = newValue
                            }
                    }
                }
            }
            .onAppear {
                if config["group"] == nil { config["group"] = Constants.appName }
                if config["icon"] == nil { config["icon"] = Constants.notificationAvatarUrl.absoluteString }
                if config["sound"] == nil { config["sound"] = "bell" }
            }
        }
        .frame(idealWidth: 600, maxWidth: .infinity, alignment: .leading)
    }
}
