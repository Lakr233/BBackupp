//
//  Constants.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import Foundation

enum Constants {
    static let appName = "BBackupp"
    static let copyrightNotice = "Copyright © 2024 Lakr Aream. All Rights Reserved."
    static let projectUrl = URL(string: "https://github.com/Lakr233/BBackupp")!
    static let notificationAvatarUrl = URL(string: "https://github.com/Lakr233/BBackupp/blob/main/Resource/Avatar/Robot.png?raw=true")!
    static let authorHomepageUrl = URL(string: "https://twitter.com/@Lakr233")!
    static let appAvatarURL = URL(string: "https://github.com/Lakr233/BBackupp/releases/download/storage.resources/Avatar.png")!

    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    static let appBuildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

    static let licenseFile: URL = Bundle.main.url(forResource: "License", withExtension: "txt")!

    static let systemBackupLocation = URL(fileURLWithPath: "/")
        .appendingPathComponent("Users")
        .appendingPathComponent(NSUserName())
        .appendingPathComponent("Library")
        .appendingPathComponent("Application Support")
        .appendingPathComponent("MobileSync")
        .appendingPathComponent("Backup")

    static let helpForgetBackupPassword = URL(string: "https://support.apple.com/HT213037")!
}
