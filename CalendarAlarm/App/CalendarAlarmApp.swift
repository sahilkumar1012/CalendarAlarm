import SwiftUI
import UserNotifications
import BackgroundTasks
import Combine

@main
struct CalendarAlarmApp: App {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var alarmState = AlarmState()

    init() {
        BackgroundSyncManager.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(calendarManager)
                    .environmentObject(notificationManager)
                    .environmentObject(alarmState)

                if alarmState.isAlarmActive, let event = alarmState.activeEvent {
                    AlarmView(event: event)
                        .environmentObject(alarmState)
                        .environmentObject(notificationManager)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: alarmState.isAlarmActive)
            .onAppear {
                setupNotificationDelegate()
                BackgroundSyncManager.shared.scheduleMorningSyncIfEnabled()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                calendarManager.fetchEvents()
                notificationManager.scheduleAlarms(
                    for: calendarManager.upcomingEvents,
                    mutedIDs: calendarManager.mutedEventIDs
                )
            }
        }
    }

    private func setupNotificationDelegate() {
        let delegate = AlarmNotificationDelegate(alarmState: alarmState, calendarManager: calendarManager)
        UNUserNotificationCenter.current().delegate = delegate
        AlarmNotificationDelegate.shared = delegate
    }
}

// MARK: - Alarm State
class AlarmState: ObservableObject {
    @Published var isAlarmActive = false
    @Published var activeEvent: CalendarEvent?

    func triggerAlarm(for event: CalendarEvent) {
        DispatchQueue.main.async {
            self.activeEvent = event
            self.isAlarmActive = true
        }
    }

    func dismissAlarm() {
        DispatchQueue.main.async {
            self.isAlarmActive = false
            self.activeEvent = nil
        }
    }
}

// MARK: - Notification Delegate
class AlarmNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static var shared: AlarmNotificationDelegate?

    private let alarmState: AlarmState
    private let calendarManager: CalendarManager

    init(alarmState: AlarmState, calendarManager: CalendarManager) {
        self.alarmState = alarmState
        self.calendarManager = calendarManager
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let eventId = notification.request.content.userInfo["eventId"] as? String
        if let event = calendarManager.upcomingEvents.first(where: { $0.id == eventId }) {
            alarmState.triggerAlarm(for: event)
        }
        completionHandler([.sound, .banner, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let eventId = response.notification.request.content.userInfo["eventId"] as? String

        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            if let event = calendarManager.upcomingEvents.first(where: { $0.id == eventId }) {
                let snoozeEvent = CalendarEvent(
                    id: event.id + "_snooze",
                    title: event.title,
                    startDate: Date().addingTimeInterval(5 * 60),
                    endDate: event.endDate,
                    calendarName: event.calendarName,
                    calendarColor: event.calendarColor,
                    location: event.location,
                    notes: event.notes,
                    isAllDay: event.isAllDay
                )
                NotificationManager().scheduleSingleAlarm(for: snoozeEvent)
            }
            alarmState.dismissAlarm()

        case "DISMISS_ACTION":
            alarmState.dismissAlarm()

        default:
            if let event = calendarManager.upcomingEvents.first(where: { $0.id == eventId }) {
                alarmState.triggerAlarm(for: event)
            }
        }

        completionHandler()
    }
}
