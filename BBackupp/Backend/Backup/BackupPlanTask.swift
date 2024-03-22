//
//  BackupPlanTask.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import ApplePackage
import AuxiliaryExecute
import Combine
import Foundation

class BackupPlanTask: ObservableObject, Identifiable {
    var id: UUID = .init()

    let created: Date = .init()
    let context: Context
    let tasks: [TaskItem]

    private(set) var cancellables: Set<AnyCancellable> = []

    @Published var isRunning: Bool = false

    var progress: Progress {
        let overallProgress = Progress()
        for task in tasks {
            overallProgress.totalUnitCount += 100
            switch task.progress {
            case let .doing(progress):
                overallProgress.completedUnitCount += Int64(100 * progress.fractionCompleted)
            case .done, .failed:
                overallProgress.completedUnitCount += 100
            default: break
            }
        }
        return overallProgress
    }

    var completed: Bool {
        tasks.allSatisfy {
            switch $0.progress {
            case .pending, .doing: false
            case .done, .failed: true
            }
        }
    }

    var errors: [TaskItem.BackupTaskError] {
        tasks.compactMap {
            if case let .failed(error) = $0.progress {
                error
            } else { nil }
        }
    }

    init(plan: BackupPlan, device: Device) {
        context = .init(plan: plan, device: device)
        tasks = TaskItem.TaskName.allCases.compactMap { $0.createTask(from: plan) }

        for task in tasks {
            task.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }

    var title: String {
        "\(context.plan.name) - \(context.device.deviceName)"
    }

    func start() {
        assert(Thread.isMainThread)
        let queue = DispatchQueue(label: "wiki.qaq.backup.plan.task")
        queue.async { self.exec() }
    }

    private let finalizeLock = NSLock()

    func terminate() {
        finalizeLock.lock()
        defer { finalizeLock.unlock() }
        assert(Thread.isMainThread)
        for task in tasks {
            task.terminationHandler()
            switch task.progress {
            case .pending: task.progress = .failed(reason: .userTerminated)
            case .doing: task.progress = .failed(reason: .userTerminated)
            default: break
            }
        }
    }

    private func exec() {
        guard !isRunning else { return }
        assert(!Thread.isMainThread)
        withMainActor { self.isRunning = true }
        defer { withMainActor { self.isRunning = false } }

        sleep(1)

        context.begin()
        context.write("[BackupPlanTask] begin \(id)\n")

        defer { context.complete() }

        context.plan.notification.send(message: "[\(context.plan.name)] A backup was initialized.") { _ in }

        // execute step by steps
        for task in tasks {
            defer { sleep(1) }
            task.execute(withContext: context)
            if case .failed = task.progress { break }
        }

        finalizeLock.lock()
        defer { finalizeLock.unlock() }

        context.write("[BackupPlanTask] finalizing \(id)\n")

        // if terminated by user, it is already marked
        for task in tasks {
            defer { task.updateOnMain {} }
            switch task.progress {
            case .pending: task.progress = .failed(reason: .previousFailure)
            case .doing: task.progress = .failed(reason: .previousFailure)
            default: break
            }
        }

        context.write("[BackupPlanTask] completed \(id) with \(errors.count) error(s)\n")
        if errors.isEmpty {
            context.plan.notification.send(message: "[\(context.plan.name)] Backup completed.") { _ in }
        } else {
            context.plan.notification.send(message: "[\(context.plan.name)] Backup completed with error(s).") { _ in }
        }
    }

    func withMainActor(_ task: @escaping () -> Void) {
        if Thread.isMainThread {
            task()
        } else {
            DispatchQueue.main.asyncAndWait { task() }
        }
    }
}

extension BackupPlanTask {
    class Context {
        let plan: BackupPlan
        let device: Device
        let storeAccounts: [AppStoreBackend.Account]

        let tempBackupDir: URL

        private let logFile: URL
        private var logFileHandler: FileHandle?

        var useNetwork: Bool = true

        init(plan: BackupPlan, device: Device) {
            self.plan = plan.codableCopy()!
            self.device = device.codableCopy()!
            storeAccounts = AppStoreBackend.shared.accounts.map { $0.codableCopy()! }
            tempBackupDir = appSetting.tempBackupBase
                .appendingPathComponent("\(plan.id)")
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MMdd-HHmmss"
            logFile = logDir
                .appendingPathComponent("BackupPlan-\(plan.id)-\(dateFmt.string(from: Date()))")
                .appendingPathExtension("log")
        }

        func write(_ log: String) {
            assert(logFileHandler != nil)
            guard let data = log.data(using: .utf8) else { return }
            logFileHandler?.write(data)
        }

        func begin() {
            try? FileManager.default.createDirectory(at: tempBackupDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.removeItem(at: logFile)
            FileManager.default.createFile(atPath: logFile.path, contents: nil, attributes: nil)
            logFileHandler = FileHandle(forWritingAtPath: logFile.path)

            assert(logFileHandler != nil)

            if useNetwork {
                amdManager.requireDevice(udid: device.udid, connection: .usb) { dev in
                    guard dev != nil else { return }
                    useNetwork = false
                }
            }
            if useNetwork, !plan.automation.deviceWirelessConnectionEnabled {
                useNetwork = false
            }
            write("using \(useNetwork ? "network" : "usb") connection\n")
        }

        func complete() {
            try? logFileHandler?.close()
            logFileHandler = nil
        }
    }
}

extension BackupPlanTask {
    class TaskItem: ObservableObject, Identifiable {
        let id: UUID = .init()

        let name: TaskName
        var progress: StepProgress
        var message: String = ""

        var assocatedObject: Any?
        var pids = Set<pid_t>()
        lazy var terminationHandler: (() -> Void) = {
            self.updateOnMain {
                for pid in self.pids {
                    terminateSubprocess(pid)
                }
                self.progress = .failed(reason: .userTerminated)
            }
        }

        init(name: TaskName, progress: StepProgress = .pending, assocatedObject: AnyObject? = nil) {
            self.name = name
            self.progress = progress
            self.assocatedObject = assocatedObject
        }
    }
}

// MARK: - TASK ITEM

extension BackupPlanTask.TaskItem: Equatable {
    static func == (lhs: BackupPlanTask.TaskItem, rhs: BackupPlanTask.TaskItem) -> Bool {
        true
            || lhs.id == rhs.id
            || lhs.name == rhs.name
            || lhs.progress == rhs.progress
    }
}

extension BackupPlanTask.TaskItem {
    enum TaskName: String, CaseIterable, Equatable {
        case setup
        case receiveBackup
        case receiveApplicationPackage

        case setupAnalyze // unpack
        case receiveAnalyze // call analyze

        case makingSnapshot
        case cleaning
        case verifyingBackup

        var title: String {
            switch self {
            case .setup: "Setup Backup"
            case .receiveBackup: "Perform Backup"
            case .receiveApplicationPackage: "Download App Packages"
            case .setupAnalyze: "Setup Analyze"
            case .receiveAnalyze: "Perform Analyze"
            case .makingSnapshot: "Create Snapshot"
            case .cleaning: "Clean Old Snapshots"
            case .verifyingBackup: "Verify Backup"
            }
        }
    }

    enum BackupTaskError: Error {
        case fileSystemError
        case resticRepoError
        case backupError
        case invalidResponse
        case network
        case userTerminated
        case previousFailure
        case verificationFailed
        case unknow
    }

    enum StepProgress: Equatable {
        case pending
        case doing(progress: Progress)
        case done
        case failed(reason: BackupTaskError)
    }
}

extension BackupPlanTask.TaskItem.BackupTaskError {
    var interfaceText: String {
        switch self {
        case .fileSystemError: "File System Error"
        case .resticRepoError: "Restic Repository Error"
        case .backupError: "Backup Error"
        case .network: "Network Error"
        case .invalidResponse: "Invalid Response"
        case .userTerminated: "User Terminated"
        case .previousFailure: "Previous Step Failure"
        case .verificationFailed: "Verification Failed"
        case .unknow: "Unknown Error"
        }
    }
}

// MARK: - CREATE TASK

extension BackupPlanTask.TaskItem.TaskName {
    func createTask(from plan: BackupPlan) -> BackupPlanTask.TaskItem? {
        switch self {
        case .setup: prepareAsSetup()
        case .receiveBackup: prepareAsReceiveBackup()
        case .receiveApplicationPackage: prepareAsReceiveApplicationPackage(plan)
        case .setupAnalyze: prepareAsSetupAnalyze(plan)
        case .receiveAnalyze: prepareAsReceiveAnalyze(plan)
        case .makingSnapshot: prepareAsMakingSnapshot()
        case .cleaning: prepareAsCleaning()
        case .verifyingBackup: prepareAsVerifyingBackup()
        }
    }

    func prepareAsSetup() -> BackupPlanTask.TaskItem? {
        .init(name: .setup)
    }

    func prepareAsReceiveBackup() -> BackupPlanTask.TaskItem? {
        .init(name: .receiveBackup)
    }

    func prepareAsReceiveApplicationPackage(_ plan: BackupPlan) -> BackupPlanTask.TaskItem? {
        if plan.appStoreConnect.enabled {
            .init(name: .receiveApplicationPackage)
        } else { nil }
    }

    func prepareAsSetupAnalyze(_ plan: BackupPlan) -> BackupPlanTask.TaskItem? {
        _ = plan
        return nil
//        if plan.analyzer.enabled {
//            .init(name: .setupAnalyze)
//        } else { nil }
    }

    func prepareAsReceiveAnalyze(_ plan: BackupPlan) -> BackupPlanTask.TaskItem? {
        _ = plan
        return nil
//        if plan.analyzer.enabled {
//            .init(name: .receiveAnalyze)
//        } else { nil }
    }

    func prepareAsMakingSnapshot() -> BackupPlanTask.TaskItem? {
        .init(name: .makingSnapshot)
    }

    func prepareAsCleaning() -> BackupPlanTask.TaskItem? {
        .init(name: .cleaning)
    }

    func prepareAsVerifyingBackup() -> BackupPlanTask.TaskItem? {
        .init(name: .verifyingBackup)
    }
}

// MARK: - EXECUTE TASK

extension BackupPlanTask.TaskItem {
    func execute(withContext context: BackupPlanTask.Context) {
        print("[BackupPlanTask.TaskItem] execute \(name)")
        if [.setup, .cleaning, .verifyingBackup].contains(name) { } else {
            context.plan.notification.send(
                message: "[\(context.plan.name)] Executing plan step: \(name.title)"
            ) { _ in }
        }
        switch name {
        case .setup: executeAsSetup(withContext: context)
        case .receiveBackup: executeAsReceiveBackup(withContext: context)
        case .receiveApplicationPackage: executeAsReceiveApplicationPackage(withContext: context)
        case .setupAnalyze: executeAsSetupAnalyze(withContext: context)
        case .receiveAnalyze: executeAsReceiveAnalyze(withContext: context)
        case .makingSnapshot: executeAsMakingSnapshot(withContext: context)
        case .cleaning: executeAsCleaning(withContext: context)
        case .verifyingBackup: executeAsVerifyingBackup(withContext: context)
        }
    }

    @discardableResult
    private func beginStep(totalUnitCount: Int64) -> Progress {
        let progress = Progress(totalUnitCount: totalUnitCount)
        updateOnMain { self.progress = .doing(progress: progress) }
        return progress
    }

    private func completeStep(stepError: BackupTaskError?) {
        updateOnMain {
            self.message = ""
            self.terminationHandler = {}
            guard case .doing = self.progress else { return }
            if let stepError { self.progress = .failed(reason: stepError) }
            else { self.progress = .done }
        }
    }

    func updateOnMain(_ task: @escaping () -> Void) {
        if Thread.isMainThread {
            task()
            objectWillChange.send()
        } else {
            DispatchQueue.main.asyncAndWait {
                task()
                self.objectWillChange.send()
            }
        }
    }

    func update(completedUnitCount: Int64, total: Int64? = nil) {
        updateOnMain {
            guard case let .doing(progress) = self.progress else { return }
            progress.completedUnitCount = completedUnitCount
            if let total { progress.totalUnitCount = total }
            self.objectWillChange.send()
        }
    }

    func update(addingCompletedUnitCount: Int64) {
        guard case let .doing(progress) = progress else { return }
        update(completedUnitCount: progress.completedUnitCount + addingCompletedUnitCount)
    }

    func executeAsSetup(withContext context: BackupPlanTask.Context) {
        beginStep(totalUnitCount: 2)
        var stepError: BackupTaskError? = nil
        defer { completeStep(stepError: stepError) }

        // restic repo check
        let env = context.plan.resticRepo.prepareEnv()
        let checkRecp = AuxiliaryExecute.spawn(
            command: Restic.executable,
            args: ["--json", "--retry-lock", "5h", "stats"],
            environment: env,
            setPid: { self.pids.insert($0) }
        ) // looking for {"total_size":0,"snapshots_count":0}
        guard checkRecp.stdout.contains("total_size") else {
            stepError = .resticRepoError
            return
        }
        update(completedUnitCount: 1)

        // backup dir check
        do {
            if !FileManager.default.fileExists(atPath: context.tempBackupDir.path) {
                try FileManager.default.createDirectory(
                    atPath: context.tempBackupDir.path,
                    withIntermediateDirectories: true
                )
            }
        } catch {
            context.write(error.localizedDescription + "\n")
            stepError = .fileSystemError
        }

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(context.plan)
            try data.write(to: context.tempBackupDir.appendingPathComponent("Plan.plist"))
            let deviceData = try encoder.encode(context.device)
            try deviceData.write(to: context.tempBackupDir.appendingPathComponent("Device.plist"))
        } catch {
            context.write(error.localizedDescription + "\n")
            stepError = .fileSystemError
        }
        update(completedUnitCount: 1)
    }

    func executeAsReceiveBackup(withContext context: BackupPlanTask.Context) {
        beginStep(totalUnitCount: 100)
        var stepError: BackupTaskError? = nil
        defer { completeStep(stepError: stepError) }

        var cancellables: Set<AnyCancellable> = []

        let sem = DispatchSemaphore(value: 0)
        let task = BackupTask(config: .init(
            device: context.device,
            useNetwork: context.useNetwork,
            useStoreBase: context.tempBackupDir,
            useIncrementBackup: true
        ))
        assocatedObject = task

        let origTerminate = terminationHandler
        terminationHandler = {
            task.terminate()
            origTerminate()
        }

        var previousSendProgressPercent = 0

        task.objectWillChange
            .receive(on: DispatchQueue.global())
            .sink {
                self.update(
                    completedUnitCount: task.overall.completedUnitCount,
                    total: task.overall.totalUnitCount
                )
                let nowProgressPercent = Int(task.overall.fractionCompleted * 100)
                if (nowProgressPercent - previousSendProgressPercent) > 20 {
                    previousSendProgressPercent = nowProgressPercent
                    if context.plan.notification.sendProgressPercent {
                        context.plan.notification.send(
                            message: "[\(context.plan.name)] Receiving backup data: \(nowProgressPercent)%"
                        ) { _ in }
                    }
                }
                self.updateOnMain { self.message = task.output.last?.text ?? "" }
            }
            .store(in: &cancellables)
        DispatchQueue.main.async {
            task.start { sem.signal() }
        }
        sem.wait()

        let output = task.output
            .sorted { $0.date < $1.date }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")
        context.write(output)

        if task.error != nil { stepError = .backupError }
    }

    func executeAsReceiveApplicationPackage(withContext context: BackupPlanTask.Context) {
        beginStep(totalUnitCount: 100)
        var stepError: BackupTaskError? = nil
        defer { completeStep(stepError: stepError) }

        var executingTask: DownloadSeed? = nil
        let origTerminate = terminationHandler
        terminationHandler = {
            executingTask?.terminate()
            origTerminate()
        }

        var apps: AnyCodableDictionary? = nil

        for _ in 0 ..< 3 {
            if let appsList = amdManager.listApplications(
                udid: context.device.udid,
                connection: context.useNetwork ? .net : .usb
            ) {
                apps = appsList
                break
            }
        }

        guard let apps else {
            context.write("error: unable to query application data from device\n")
            stepError = .invalidResponse
            return
        }

        struct DownloadRequest {
            let account: String
            let bundleIdentifier: String
        }
        var requests = [DownloadRequest]()

        let availableAccount = Set(context.storeAccounts.map { $0.email.lowercased() })

        for (bundleIdentifier, value) in apps {
            guard !bundleIdentifier.isEmpty,
                  let value = value.value as? [String: AnyCodable],
                  let iTunesMetadataData = value["iTunesMetadata"]?.value as? Data,
                  let object = try? PropertyListSerialization.propertyList(
                      from: iTunesMetadataData,
                      format: nil
                  ) as? [String: Any]
            else {
                context.write("error: unable to decode application data from device\n")
                if context.plan.appStoreConnect.ignoreFailure { continue }
                stepError = .invalidResponse
                return
            }

            var account: String? = nil

            if account == nil,
               let downloadInfo = object["com.apple.iTunesStore.downloadInfo"] as? [String: Any],
               let accountInfo = downloadInfo["accountInfo"] as? [String: Any],
               let getAccount = accountInfo["AppleID"] as? String,
               !getAccount.isEmpty
            { account = getAccount }

            if account == nil,
               let getAccount = object["apple-id"] as? String,
               !getAccount.isEmpty
            { account = getAccount }

            guard let account else {
                context.write("error: application data does not hold an Apple ID, ignoring\n")
                if context.plan.appStoreConnect.ignoreFailure { continue }
                stepError = .invalidResponse
                return
            }

            guard availableAccount.contains(account.lowercased()) else {
                context.write("error: unknown Apple ID \(account)\n")
                if context.plan.appStoreConnect.ignoreFailure { continue }
                stepError = .invalidResponse
                return
            }

            context.write("will request download of \(bundleIdentifier) from \(account)\n")
            requests.append(.init(account: account, bundleIdentifier: bundleIdentifier))
        }

        guard !requests.isEmpty else { return }

        let targetDir = context.tempBackupDir
            .appendingPathComponent("Applications")
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        // list content of targetdir, for unneeded files, remove later
        var unwantedContents: Set<String> = Set((
            try? FileManager
                .default
                .contentsOfDirectory(atPath: targetDir.path)
        ) ?? [])

        update(completedUnitCount: 0, total: Int64(requests.count))

        let httpClient = HTTPClient(urlSession: URLSession.shared)
        let itunesClient = iTunesClient(httpClient: httpClient)
        let storeClient = StoreClient(httpClient: httpClient)

        for request in requests {
            guard case .doing = progress else { return }
            defer { update(addingCompletedUnitCount: 1) }

            let account = context
                .storeAccounts
                .first { $0.email.lowercased() == request.account.lowercased() }
            guard let account else { continue } // won't happen

            updateOnMain { self.message = "looking for package \(request.bundleIdentifier)..." }

            var storeItem: StoreResponse.Item? = nil
            for _ in 0 ..< 3 {
                guard let app = try? itunesClient.lookup(
                    bundleIdentifier: request.bundleIdentifier,
                    region: account.countryCode
                ), let item = try? storeClient.item(
                    identifier: String(app.identifier),
                    directoryServicesIdentifier: account.storeResponse.directoryServicesIdentifier
                )
                else { continue }
                storeItem = item
            }

            guard let storeItem else {
                context.write("error: package \(request.bundleIdentifier) failed to communicate with App Store\n")
                if context.plan.appStoreConnect.ignoreFailure { continue }
                stepError = .invalidResponse
                return
            }

            let name = "\(request.bundleIdentifier)-\(storeItem.md5).ipa"
            unwantedContents.remove(name)

            let targetFile = targetDir.appendingPathComponent(name)

            if FileManager.default.fileExists(atPath: targetFile.path) {
                context.write("package \(request.bundleIdentifier) already exists, skipping\n")
                continue
            }

            // now list if any ipa start with \(request.bundleIdentifier)-
            // this means it is outdated and should be removed
            let targetDirContents = try? FileManager.default.contentsOfDirectory(atPath: targetDir.path)
            for file in targetDirContents ?? [] {
                guard file.hasPrefix("\(request.bundleIdentifier)-") else { continue }
                try? FileManager.default.removeItem(at: targetDir.appendingPathComponent(file))
            }

            for _ in 0 ... 3 {
                let seed = DownloadSeed(url: storeItem.url, toFile: targetFile)
                let sem = DispatchSemaphore(value: 0)
                seed.onCompletion = {
                    sem.signal()
                }
                seed.onProgress = { progress in
                    let value = Int(progress.fractionCompleted * 100)
                    let byteFmt = ByteCountFormatter()
                    byteFmt.allowedUnits = [.useAll]
                    byteFmt.countStyle = .file
                    let total = byteFmt.string(fromByteCount: progress.totalUnitCount)
                    let completed = byteFmt.string(fromByteCount: progress.completedUnitCount)
                    self.updateOnMain { self.message = "\(request.bundleIdentifier) \(total) \(completed) \(value)" }
                }
                executingTask = seed
                defer { executingTask = nil }
                updateOnMain { self.message = "downloading \(request.bundleIdentifier)..." }
                seed.start()
                sem.wait()

                // retry until complete
                if seed.receipt?.exitCode == 0 { break } else { sleep(3) }
            }

            guard FileManager.default.fileExists(atPath: targetFile.path) else {
                context.write("error: failed to download package \(request.bundleIdentifier)\n")
                stepError = .network
                return
            }

            updateOnMain { self.message = "\(request.bundleIdentifier) building package..." }

            let signatureClient = SignatureClient(fileManager: .default, filePath: targetFile.path)
            do {
                try signatureClient.appendMetadata(item: storeItem, email: account.email)
                try signatureClient.appendSignature(item: storeItem)
            } catch {
                context.write("error: failed to process package \(request.bundleIdentifier) \(error.localizedDescription)\n")
                // this error is not ignorable
                stepError = .fileSystemError
                return
            }

            context.write("package \(request.bundleIdentifier) downloaded\n")
        }

        for file in unwantedContents {
            context.write("removing unwanted file \(file)")
            try? FileManager.default.removeItem(at: targetDir.appendingPathComponent(file))
        }
    }

    func executeAsSetupAnalyze(withContext _: BackupPlanTask.Context) {
        fatalError("not implemented")
    }

    func executeAsReceiveAnalyze(withContext _: BackupPlanTask.Context) {
        fatalError("not implemented")
    }

    func executeAsMakingSnapshot(withContext context: BackupPlanTask.Context) {
        beginStep(totalUnitCount: 100)
        var stepError: BackupTaskError? = nil
        defer { completeStep(stepError: stepError) }

        let orig = terminationHandler
        terminationHandler = {
            orig()
            (self.assocatedObject as? ResticBackup)?.terminate()
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: context.tempBackupDir.path)
            for item in contents where item.hasPrefix(".") {
                try FileManager.default.removeItem(at: context.tempBackupDir.appendingPathComponent(item))
            }
        } catch {
            context.write("error: failed to clean up temp dir \(error.localizedDescription)\n")
            stepError = .fileSystemError
            return
        }

        context.write("creating snapshot with content of dir \(context.tempBackupDir.path)")
        let task = ResticBackup(repo: context.plan.resticRepo, dir: context.tempBackupDir)
        assocatedObject = task

        let sem = DispatchSemaphore(value: 0)
        task.onCompletion = {
            sem.signal()
        }
        task.onProgress = { progress in
            self.update(completedUnitCount: progress.completedUnitCount, total: progress.totalUnitCount)
            self.updateOnMain {
                let byteFmt = ByteCountFormatter()
                byteFmt.allowedUnits = [.useAll]
                byteFmt.countStyle = .file
                let total = byteFmt.string(fromByteCount: progress.totalUnitCount)
                let completed = byteFmt.string(fromByteCount: progress.completedUnitCount)
                self.message = "Creating snapshot \(completed) \(total)"
            }
        }
        task.start()
        sem.wait()

        guard let recp = task.receipt else {
            context.write("error: missing restic process receipt")
            stepError = .resticRepoError
            return
        }
        context.write(recp.stdout)
        context.write(recp.stderr)
        context.write("restic backup returned \(recp.exitCode)")

        if recp.exitCode != 0 { stepError = .resticRepoError }
    }

    func executeAsCleaning(withContext context: BackupPlanTask.Context) {
        beginStep(totalUnitCount: 1)
        var stepError: BackupTaskError? = nil
        defer { completeStep(stepError: stepError) }

        terminationHandler = {} // not allowed

        context.write("cleaning up old snapshots")

        let snapshots = context.plan.resticRepo.listSnapshots()
        context.write("found \(snapshots.count) snapshots")

        let removeList = context.plan.automation
            .backupKeepOption
            .examSnapshotsReturnRemoving(snapshots)
        context.write("removing \(removeList.count) snapshots")

        for remove in removeList {
            context.write("forgetting snapshot \(remove)")
            updateOnMain { self.message = "forgetting snapshot \(remove)" }
            let recp = AuxiliaryExecute.spawn(
                command: Restic.executable,
                args: ["--json", "--retry-lock", "5h", "forget", remove],
                environment: context.plan.resticRepo.prepareEnv()
            )
            context.write(recp.stdout)
            context.write(recp.stderr)

            guard recp.exitCode == 0 else {
                context.write("error: unexpected exit code \(recp.exitCode)")
                stepError = .resticRepoError
                return
            }
            context.write("restic forgot returned \(recp.exitCode)")
        }

        context.write("cleaning up snapshots")
        updateOnMain { self.message = "cleaning up snapshots..." }
        let recp = AuxiliaryExecute.spawn(
            command: Restic.executable,
            args: ["--json", "--retry-lock", "5h", "prune"],
            environment: context.plan.resticRepo.prepareEnv()
        )
        context.write(recp.stdout)
        context.write(recp.stderr)

        context.write("restic prune returned \(recp.exitCode)")
        guard recp.exitCode == 0 else {
            context.write("error: unexpected exit code \(recp.exitCode)")
            stepError = .resticRepoError
            return
        }
    }

    func executeAsVerifyingBackup(withContext context: BackupPlanTask.Context) {
        beginStep(totalUnitCount: 1)
        var stepError: BackupTaskError? = nil
        defer { completeStep(stepError: stepError) }

        context.write("verifying backup")

        let status = context.tempBackupDir
            .appendingPathComponent(context.plan.deviceID)
            .appendingPathComponent("Status")
            .appendingPathExtension("plist")

        guard let data = try? Data(contentsOf: status),
              let dic = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let snapshotState = dic["SnapshotState"] as? String,
              snapshotState == "finished"
        else {
            context.write("error: backup verification failed")
            stepError = .verificationFailed
            return
        }

        update(addingCompletedUnitCount: 1)
        context.write("backup verification passed")

        bakManager.reloadBackup(forDevice: context.plan.deviceID)
    }
}
