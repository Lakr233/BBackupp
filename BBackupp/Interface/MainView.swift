//
//  ContentView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/10.
//

import AppleMobileDevice
import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationView {
            List {
                SidebarView()
            }
            .listStyle(.sidebar)
            .navigationTitle(Constants.appName)
            WelcomeView()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        with: nil
                    )
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.leading")
                }
            }
        }
    }
}
