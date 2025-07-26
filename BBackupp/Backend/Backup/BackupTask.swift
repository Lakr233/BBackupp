//
//  BackupTask.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/8.
//

import AppKit
import AppleMobileDeviceLibrary
import AuxiliaryExecute
import Combine

private let dateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter
}()

private let ignoredKeywords = [
    "Receiving files",
]

class BackupTask: ObservableObject, Identifiable {
    var id: UUID = .init()
    let date: Date = .init()

    struct Configuration: Codable, CopyableCodable {
        let device: Device
        let useNetwork: Bool
        let useStoreBase: URL
        let useIncrementBackup: Bool
    }

    let config: Configuration
    let queue = DispatchQueue(label: "wiki.qaq.backup")
    var cancellable: Set<AnyCancellable> = []
    init(config: Configuration) {
        self.config = config.codableCopy()!
        throttledSubject
            .throttle(for: .seconds(0.2), scheduler: DispatchQueue.global(), latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellable)
    }

    struct Log: Identifiable {
        var id: UUID = .init()
        let date: Date = .init()
        let text: String
    }

    var output: [Log] = [] {
        didSet { throttledSubject.send() }
    }

    let throttledSubject = PassthroughSubject<Void, Never>()

    var overall: Progress = .init() {
        didSet {
            guard current != oldValue else { return }
            throttledSubject.send()
        }
    }

    var current: Progress = .init() {
        didSet {
            guard current != oldValue else { return }
            throttledSubject.send()
        }
    }

    private let currentSubject = PassthroughSubject<Progress, Never>()

    enum BackupError: Error {
        case unknown
        case deviceNotFound
        case interrupted
        case unexpectedExitCode
        case terminated
    }

    @Published var error: BackupError? = nil

    enum BackupStatus {
        case initialized
        case executing
        case completed
    }

    @Published var status: BackupStatus = .initialized
    var executing: Bool { status == .executing || pid != nil }
    var completed: Bool { [.completed].contains(status) }
    var success: Bool { error == nil }

    @Published var pid: pid_t? = nil
    @Published var recp: AuxiliaryExecute.ExecuteReceipt? = nil

    private var logFile: FileHandle?

    func start(_ completion: (() -> Void)? = nil) {
        guard status == .initialized else { return }
        status = .executing
        queue.async {
            self.executeStart()
            completion?()
        }
    }

    func terminate() {
        error = .terminated
        defer { decodeOutput("Terminated by request.\n") }
        guard let pid else { return }
        terminateSubprocess(pid)
    }

    private func withMainActor(_ exec: @escaping () -> Void) {
        if Thread.isMainThread { exec() }
        else { DispatchQueue.main.asyncAndWait { exec() } }
    }

    private func executeStart() {
        assert(!Thread.isMainThread)

        overall.totalUnitCount = 100
        current.totalUnitCount = 100

        try? FileManager.default.createDirectory(
            at: config.useStoreBase,
            withIntermediateDirectories: true
        )
        let logFilePath = logDir
            .appendingPathComponent("Backup-\(config.device.udid)-\(dateFormatter.string(from: Date()))")
            .appendingPathExtension("log")
            .path
        FileManager.default.createFile(atPath: logFilePath, contents: nil)
        logFile = .init(forWritingAtPath: logFilePath)

        let args = config.decodeBinaryCommand()
        decodeOutput("\(Self.mobileBackupExecutable)\n")
        decodeOutput("Core Version: \(Self.mobileBackupVersion)\n")
        decodeOutput("Core Command: \(args)\n")

        defer {
            sleep(1)
            decodeOutput("\n\n\n")
            completeWrite()
            withMainActor {
                self.pid = nil
                if self.overall.completedUnitCount != self.overall.totalUnitCount {
                    self.overall.totalUnitCount = 100
                    self.overall.completedUnitCount = 100
                }
                self.status = .completed
            }
            try? logFile?.close()
        }

        decodeOutput("starting command...\n")
        let recp = AuxiliaryExecute.spawn(
            command: Self.mobileBackupExecutable,
            args: args,
            environment: [:],
            timeout: -1
        ) { pid in
            self.withMainActor { self.pid = pid }
        } output: { output in
            self.decodeOutput(output)
        }
        decodeOutput("\n\n\n")
        decodeOutput("Execution returned: \(recp.exitCode)\n")

        withMainActor {
            self.decodeReceipt(recp)
        }
    }

    // MARK: OUTPUT HANDLER

    private func decodeReceipt(_ recp: AuxiliaryExecute.ExecuteReceipt) {
        overall.totalUnitCount = 100
        overall.completedUnitCount = 100
        self.recp = recp
        status = .completed
        if recp.exitCode != 0, error == nil {
            error = .unexpectedExitCode
        }
    }

    private var buffer = ""
    private func decodeOutput(_ output: String) {
        writeOutput(output)

        buffer += output
        buffer = buffer.replacingOccurrences(of: "\r", with: "\n")
        guard buffer.contains("\n") else { return }
        var lineBuffer = ""
        let copyBuffer = buffer
        buffer = ""
        for char in copyBuffer {
            if char == "\n" || char == "\r" {
                decodeLine(lineBuffer)
                lineBuffer = ""
            } else {
                lineBuffer.append(char)
            }
        }
        if !lineBuffer.isEmpty { buffer = lineBuffer }
    }

    private func decodeLine(_ input: String) {
        let line = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }

        // overall progress found
        if line.hasPrefix("["), line.contains("]"), line.hasSuffix("Finished") {
            guard let cutA = line.components(separatedBy: "]").last?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let cutB = cutA.components(separatedBy: "%").first,
                  let value = Int(cutB),
                  value >= 0, value <= 100
            else { return }
            let prog = Progress(totalUnitCount: 100)
            prog.completedUnitCount = Int64(value)
            guard overall != prog else { return }
            withMainActor { self.overall = prog }
            return
        }

        // partial progress found
        if line.hasPrefix("["), line.contains("]"), line.contains("("), line.contains(")"), line.contains("/") {
            guard let cutA = line.components(separatedBy: "(").last,
                  let currentValue = cutA.components(separatedBy: "/").first,
                  let cutB = line.components(separatedBy: ")").first,
                  let totalValue = cutB.components(separatedBy: "/").last,
                  let curr = SizeDecoder.decode(currentValue),
                  let total = SizeDecoder.decode(totalValue)
            else { return }
            let prog = Progress(totalUnitCount: Int64(total))
            prog.completedUnitCount = Int64(curr)
            guard current != prog else { return }
            withMainActor { self.current = prog }
            return
        }

        for keyword in ignoredKeywords where line.contains(keyword) {
            return
        }

        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSLog("[BackupTask] \(id) \(line)")
        withMainActor { self.output.append(.init(text: line)) }
    }

    private var outputWriteBuffer = [String]()
    private var outputWriteDedup: String?
    private func writeOutput(_ output: String) {
        for char in output {
            if char == "\n" {
                outputWriteBuffer.append("")
                continue
            }
            if char == "\r" {
                if outputWriteBuffer.count > 0 {
                    outputWriteBuffer.removeLast()
                    outputWriteBuffer.append("")
                }
                continue
            }
            if outputWriteBuffer.isEmpty { outputWriteBuffer.append("") }
            outputWriteBuffer[outputWriteBuffer.count - 1].append(char)
        }
        completeWrite(keepLast: 1)
    }

    private func completeWrite(keepLast: Int = 0) {
        while outputWriteBuffer.count > keepLast {
            let firstLine = outputWriteBuffer.removeFirst()
            if outputWriteDedup == firstLine { continue }
            outputWriteDedup = firstLine
            try? logFile?.write(contentsOf: firstLine.data(using: .utf8) ?? Data())
            try? logFile?.write(contentsOf: "\n".data(using: .utf8) ?? Data())
        }
    }
}

extension BackupTask {
    static let defaultBase = documentDir.appendingPathComponent("Backups")
    static let mobileBackupExecutable = Bundle.main.url(forAuxiliaryExecutable: "MobileBackup")!.path
    static let mobileBackupVersion: String = {
        var stdout = AuxiliaryExecute.spawn(
            command: mobileBackupExecutable,
            args: ["-v"]
        ).stdout
        if stdout.hasPrefix("idevicebackup2") {
            stdout.removeFirst("idevicebackup2".count)
        }
        stdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return stdout
    }()
}

//    idevicebackup2 -u udid -n backup . --full
//
//    Backup directory is "."
//    Started "com.apple.mobilebackup2" service on port 55620.
//    Negotiated Protocol Version 2.1
//    Starting backup...
//    Backup will be unencrypted.
//    Requesting backup from device...
//    Full backup mode.
//    [==================================================] 100% Finished
//    [==================================================] 100% Finished
//    Sending 'udid/Status.plist' (189 Bytes)
//    Sending 'udid/Manifest.plist' (133.1 KB)
//    Sending 'udid/Manifest.db' (24.3 MB)
//    Received 16722 files from device.
//    Backup Successful.

extension BackupTask.Configuration {
    func decodeBinaryCommand() -> [String] {
        var ans = [String]()
        ans += ["-u", device.udid]
        if useNetwork { ans += ["-n"] }
        ans += ["backup"]
        ans += [useStoreBase.path]
        if !useIncrementBackup { ans += ["--full"] }
        return ans
    }
}
