import BackgroundTasks
import EventKit
import UserNotifications
import SwiftUI
import Combine

class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()
    static let taskIdentifier = "com.calendaralarm.morningsync"

    private init() {}

    // MARK: - Registration

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleBackgroundSync(task: refreshTask)
        }
    }

    // MARK: - Schedule Next Morning Sync

    func scheduleMorningSyncIfEnabled() {
        let enabled = UserDefaults.standard.bool(forKey: "morningSyncEnabled")
        guard enabled else {
            cancelScheduledSync()
            return
        }

        let hour = UserDefaults.standard.integer(forKey: "morningSyncHour")
        let minute = UserDefaults.standard.integer(forKey: "morningSyncMinute")
        // Defaults: if both are 0 and user hasn't set, use 7:00 AM
        let syncHour = (hour == 0 && minute == 0 && !UserDefaults.standard.bool(forKey: "morningSyncTimeSet")) ? 7 : hour
        let syncMinute = (hour == 0 && minute == 0 && !UserDefaults.standard.bool(forKey: "morningSyncTimeSet")) ? 0 : minute

        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = syncHour
        components.minute = syncMinute
        components.second = 0

        guard var nextSync = Calendar.current.date(from: components) else { return }

        // If the time has already passed today, schedule for tomorrow
        if nextSync <= now {
            nextSync = Calendar.current.date(byAdding: .day, value: 1, to: nextSync)!
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = nextSync

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Morning sync scheduled for \(nextSync)")
        } catch {
            print("Failed to schedule morning sync: \(error.localizedDescription)")
        }
    }

    func cancelScheduledSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }

    // MARK: - Handle Background Sync

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule the next morning sync before doing work
        scheduleMorningSyncIfEnabled()

        let eventStore = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)

        guard status == .authorized || status == .fullAccess else {
            task.setTaskCompleted(success: false)
            return
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Fetch events
        let lookAheadDays = UserDefaults.standard.integer(forKey: "lookAheadDays")
        let days = lookAheadDays > 0 ? lookAheadDays : 7

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: now)!

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        // Load muted event IDs
        let mutedIDs: Set<String>
        if let saved = UserDefaults.standard.array(forKey: "mutedEventIDs") as? [String] {
            mutedIDs = Set(saved)
        } else {
            mutedIDs = []
        }

        // Remove old notifications and schedule new ones
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let alarmLeadTime = UserDefaults.standard.integer(forKey: "alarmLeadTimeMinutes")
        let soundEnabled = UserDefaults.standard.object(forKey: "alarmSoundEnabled") as? Bool ?? true

        var count = 0
        for ekEvent in events {
            guard !ekEvent.isAllDay else { continue }

            let eventId = ekEvent.eventIdentifier ?? UUID().uuidString
            guard !mutedIDs.contains(eventId) else { continue }

            let startDate = ekEvent.startDate ?? now
            let triggerDate = startDate.addingTimeInterval(-Double(alarmLeadTime * 60))
            guard triggerDate > now else { continue }
            guard count < 64 else { break }

            let content = UNMutableNotificationContent()
            content.title = "🔔 \(ekEvent.title ?? "Event")"

            let formatter = DateFormatter()
            formatter.timeStyle = .short
            content.subtitle = formatter.string(from: startDate)

            var bodyParts: [String] = []
            bodyParts.append("📅 \(ekEvent.calendar?.title ?? "Calendar")")
            if let loc = ekEvent.location, !loc.isEmpty { bodyParts.append("📍 \(loc)") }
            content.body = bodyParts.joined(separator: "\n")

            content.categoryIdentifier = "ALARM_CATEGORY"
            content.userInfo = ["eventId": eventId]
            content.interruptionLevel = .timeSensitive
            if soundEnabled { content.sound = .defaultCritical }

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "alarm_\(eventId)", content: content, trigger: trigger)
            center.add(request)

            count += 1
        }

        task.setTaskCompleted(success: true)
    }
}
