//
//  NotificationService.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 06.02.26.
//

import Foundation
import UserNotifications
import AppKit
import OSLog

/// Service responsible for managing user notifications
@MainActor
@Observable
final class NotificationService: NSObject {

    // MARK: - Constants

    private enum NotificationIdentifier {
        static let categoryRecordingSaved = "RECORDING_SAVED"
        static let categoryRecordingFailed = "RECORDING_FAILED"
        static let actionShowInFinder = "SHOW_IN_FINDER"
    }

    private enum UserInfoKey {
        static let folderURL = "folderURL"
    }

    // MARK: - Properties

    private let settings: SettingsStore
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture",
        category: "NotificationService"
    )

    // MARK: - Initialization

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        setupNotificationDelegate()
        registerNotificationCategories()
        requestNotificationPermission()
    }

    // MARK: - Setup

    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    private func registerNotificationCategories() {
        // Action to show recording in Finder
        let showInFinderAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionShowInFinder,
            title: AppText.value("Show in Finder", "在访达中显示", language: .current),
            options: [.foreground]
        )

        // Category for successful recording with action
        let recordingSavedCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryRecordingSaved,
            actions: [showInFinderAction],
            intentIdentifiers: []
        )

        // Category for failed recording (no actions needed)
        let recordingFailedCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryRecordingFailed,
            actions: [],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            recordingSavedCategory,
            recordingFailedCategory
        ])
    }

    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                if granted {
                    logger.info("Notification permission granted")
                } else {
                    logger.warning("Notification permission denied")
                }
            } catch {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Public Methods

    /// Sends a notification for a successfully saved recording
    /// - Parameter fileURL: The URL of the saved recording file
    func sendRecordingSavedNotification(fileURL: URL) {
        registerNotificationCategories()
        let language = settings.appLanguage
        let content = UNMutableNotificationContent()
        content.title = AppText.value("Recording Saved", "录制已保存", language: language)
        content.body = AppText.value(
            "Your recording has been saved to \(fileURL.lastPathComponent)",
            "录制文件已保存到 \(fileURL.lastPathComponent)",
            language: language
        )
        content.sound = .default
        content.categoryIdentifier = NotificationIdentifier.categoryRecordingSaved

        // Store the folder URL for opening when notification is clicked
        let folderURL = fileURL.deletingLastPathComponent()
        content.userInfo = [UserInfoKey.folderURL: folderURL.path()]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                logger.info("Recording saved notification sent")
            } catch {
                logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    /// Sends a notification for a failed recording
    /// - Parameter error: The error that caused the recording to fail
    func sendRecordingFailedNotification(error: Error) {
        registerNotificationCategories()
        let language = settings.appLanguage
        let content = UNMutableNotificationContent()
        content.title = AppText.value("Recording Failed", "录制失败", language: language)
        content.body = AppText.value(
            "Your recording could not be saved: \(error.localizedDescription)",
            "无法保存录制文件：\(error.localizedDescription)",
            language: language
        )
        content.sound = .default
        content.categoryIdentifier = NotificationIdentifier.categoryRecordingFailed

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                logger.info("Recording failed notification sent")
            } catch {
                logger.error("Failed to send failure notification: \(error.localizedDescription)")
            }
        }
    }

    /// Sends a notification when recording stopped unexpectedly
    /// - Parameter error: Optional error that caused the stop
    func sendRecordingStoppedNotification(error: Error?) {
        registerNotificationCategories()
        let language = settings.appLanguage
        let content = UNMutableNotificationContent()
        content.title = AppText.value("Recording Stopped", "录制已停止", language: language)

        if let error {
            content.body = AppText.value(
                "Recording stopped unexpectedly: \(error.localizedDescription)",
                "录制意外停止：\(error.localizedDescription)",
                language: language
            )
        } else {
            content.body = AppText.value("Recording stopped unexpectedly", "录制意外停止", language: language)
        }

        content.sound = .default
        content.categoryIdentifier = NotificationIdentifier.categoryRecordingFailed

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                logger.info("Recording stopped notification sent")
            } catch {
                logger.error("Failed to send stopped notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    private func openFolderInFinder(path: String) {
        _ = settings.startAccessingOutputDirectory()
        defer { settings.stopAccessingOutputDirectory() }
        let url = URL(filePath: path)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        switch response.actionIdentifier {
        case NotificationIdentifier.actionShowInFinder,
            UNNotificationDefaultActionIdentifier where await categoryIdentifier == NotificationIdentifier.categoryRecordingSaved:
            // User tapped the notification or the "Show in Finder" action
            if let folderPath = await userInfo[UserInfoKey.folderURL] as? String {
                await MainActor.run {
                    openFolderInFinder(path: folderPath)
                }
            }

        default:
            break
        }
    }
}
