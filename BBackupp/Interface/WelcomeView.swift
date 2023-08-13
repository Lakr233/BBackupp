//
//  WelcomeView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

struct WelcomeView: View {
    let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()
    @State var dotAnimation: String = ""

    var body: some View {
        ZStack {
            VStack {
                Image("Avatar")
                    .resizable()
                    .antialiased(true)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80, alignment: .center)
                Text("Welcome to BBackupp")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Rectangle()
                    .frame(width: 100, height: 20, alignment: .center)
                    .opacity(0)
            }
            VStack {
                Spacer()
                HStack {
                    Text("Backup Scheduler is Running \(dotAnimation)")
                    Spacer()
                    Text("Made with love by @Lakr233 - v\(Constants.appVersion).b\(Constants.appBuildVersion)")
                        .onTapGesture {
                            NSWorkspace.shared.open(Constants.authorHomepageUrl)
                        }
                }
                .font(.system(.caption, design: .rounded, weight: .light))
                .opacity(0.75)
                .onReceive(timer) { _ in
                    switch dotAnimation {
                    case ".": dotAnimation = ".."
                    case "..": dotAnimation = "..."
                    case "...": dotAnimation = "...."
                    default: dotAnimation = "."
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    NSWorkspace.shared.open(Constants.projectUrl)
                } label: {
                    Label("Open GitHub", systemImage: "questionmark")
                }
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}
