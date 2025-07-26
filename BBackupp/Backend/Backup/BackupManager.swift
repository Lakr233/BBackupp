//
//  BackupManager.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/10.
//

import AppKit
import AuxiliaryExecute
import Combine

let bakManager = BackupManager.shared

struct Backup: Identifiable {
    var id: String { repo.id + snapshot.id }

    let deviceID: Device.ID
    let repo: ResticRepo
    let snapshot: ResticRepo.Snapshot
}

class BackupManager: ObservableObject {
    fileprivate static let shared = BackupManager()

    var cancellables: Set<AnyCancellable> = []

    private var subCancellables: Set<AnyCancellable> = []
    private let subscribeRequest = PassthroughSubject<Void, Never>()

    @Published var tasks: [BackupTask] = [] {
        didSet { subscribeRequest.send() }
    }

    var runningTaskCount: Int {
        0
            + tasks.filter(\.executing).count
            + planTasks.filter(\.isRunning).count
    }

    @PublishedStorage(key: "wiki.qaq.plans", defaultValue: [:])
    var plans: [BackupPlan.ID: BackupPlan] {
        didSet { subscribeRequest.send() }
    }

    var automationEnabledPlans: [BackupPlan] {
        plans.values.filter(\.automation.enabled)
    }

    @Published var planTasks: [BackupPlanTask] = [] {
        didSet { subscribeRequest.send() }
    }

    @Published var backups: [Device.ID: [Backup]] = [:]

    @PublishedStorage(key: "wiki.qaq.backup.lastBackupAttempt", defaultValue: [:])
    var lastBackupAttempt: [Device.ID: Date]

    private init() {
        print("[*] core version \(BackupTask.mobileBackupVersion)")

        for plan in plans.values {
            reloadBackup(forDevice: plan.deviceID)
        }

        subscribeRequest
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.global(), latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.subscribeChilds() }
            .store(in: &cancellables)

        objectWillChange
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.global(), latest: true)
            .sink { [weak self] _ in self?.saveAll() }
            .store(in: &cancellables)

        subscribeChilds()
    }

    private func subscribeChilds() {
        subCancellables.forEach { $0.cancel() }
        subCancellables.removeAll()

        for task in tasks {
            task.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &subCancellables)
        }

        for plan in plans.values {
            plan.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &subCancellables)
        }

        for planTask in planTasks {
            planTask.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &subCancellables)
        }
    }

    func saveAll() {
        _plans.saveFromSubjectValueImmediately()
    }

    func reloadBackup(forDevice udid: Device.ID) {
        DispatchQueue.global().async {
            self._reloadBackup(forDevice: udid)
        }
    }

    private func _reloadBackup(forDevice udid: Device.ID) {
        let plans = bakManager.plans.values.filter { $0.deviceID == udid }
        guard !plans.isEmpty else { return }
        let backups = plans
            .map { plan in
                let snapshots = plan.resticRepo.listSnapshots()
                return snapshots.map {
                    Backup(deviceID: plan.deviceID, repo: plan.resticRepo, snapshot: $0)
                }
            }
            .flatMap(\.self)
            .sorted { $0.snapshot.date > $1.snapshot.date }
        print("[*] reload backup for \(udid) with \(backups.count) snapshots")
        DispatchQueue.main.async {
            bakManager.backups[udid] = backups
        }
    }

    func deleteBackup(_ backup: Backup) {
        assert(!Thread.isMainThread)
        print("[*] forget \(backup.snapshot.id) from \(backup.repo.location)")
        let recp = AuxiliaryExecute.spawn(
            command: Restic.executable,
            args: ["--json", "--retry-lock", "5h", "forget", backup.snapshot.id],
            environment: backup.repo.prepareEnv()
        )
        print("[*] forget \(backup.snapshot.id) returned \(recp.exitCode)")

        sleep(1)
        _reloadBackup(forDevice: backup.deviceID)
    }

    func cleanCompletedTasks() {
        tasks.removeAll { !$0.executing }
        planTasks.removeAll { !$0.isRunning }
    }
}

// MARK: - AUTOMATION

extension BackupManager {
    func backupRobotHeartBeat() {
        print("[*] robot heart beat")
        // the automatic backup happens here!
        for plan in automationEnabledPlans {
            DispatchQueue.global().async {
                self.backupCheckStart(plan)
            }
        }
    }

    private func backupCheckStart(_ plan: BackupPlan) {
        guard let device = devManager.devices[plan.deviceID] else {
            print("[*] skip \(plan.deviceID) because device not found in reg")
            return
        }

        for task in tasks where task.config.device.udid == plan.deviceID {
            guard task.executing else { continue }
            print("[*] skip \(plan.deviceID) because backup is running")
            return
        }
        for planTask in planTasks where planTask.context.device.udid == plan.deviceID {
            guard planTask.isRunning else { continue }
            print("[*] skip \(plan.deviceID) because backup is running")
        }

        guard let deviceRecord = amdManager.obtainDeviceInfo(udid: plan.deviceID) else {
            print("[*] skip \(plan.deviceID) because device not found")
            return
        }

        guard plan.needsBackup(record: deviceRecord) else {
            print("[*] skip \(plan.deviceID) because backup is not needed")
            return
        }

        // requires device unlocked
        // otherwise if user leave there devices charged at home it will fail of course
        guard !(deviceRecord.passwordProtected ?? true) else {
            print("[*] skip \(plan.deviceID) because device is locked")
            return
        }

        // now the config tells us it is ok to backup
        // but we need to check if there is already an attempt in a somehow short-term
        // for now let's just say whith in 18 hours
        // TODO: A Better Algorithem

        let lastAttempt = lastBackupAttempt[
            plan.deviceID,
            default: Date(timeIntervalSince1970: 0)
        ]
        guard Date().timeIntervalSince(lastAttempt) > 18 * 3600 else {
            print("[*] skip \(plan.deviceID) because backup is too frequent")
            return
        }

        print("[*] start backup for \(plan.deviceID)")
        DispatchQueue.main.async {
            self.lastBackupAttempt[plan.deviceID] = Date()
            let task = BackupPlanTask(plan: plan, device: device)
            self.planTasks.insert(task, at: 0)
            task.start()
        }
    }
}
