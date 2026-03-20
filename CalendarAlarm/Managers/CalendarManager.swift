import EventKit
import SwiftUI
import Combine

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var todayEvents: [CalendarEvent] = []
    @Published var isLoading = false

    @AppStorage("lookAheadDays") var lookAheadDays: Int = 7

    /// Event IDs the user has muted (alarm disabled)
    @Published var mutedEventIDs: Set<String> = []

    private static let mutedKey = "mutedEventIDs"
    private var refreshTimer: Timer?

    init() {
        loadMutedEvents()
        checkAuthorizationStatus()
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }

    func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.checkAuthorizationStatus()
                    if granted {
                        self?.fetchEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.checkAuthorizationStatus()
                    if granted {
                        self?.fetchEvents()
                    }
                }
            }
        }
    }

    // MARK: - Fetch Events

    func fetchEvents() {
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            return
        }

        isLoading = true

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endDate = Calendar.current.date(byAdding: .day, value: lookAheadDays, to: startOfToday)!
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: nil
        )

        let todayPredicate = eventStore.predicateForEvents(
            withStart: startOfToday,
            end: endOfToday,
            calendars: nil
        )

        let ekEvents = eventStore.events(matching: predicate)
        let ekTodayEvents = eventStore.events(matching: todayPredicate)

        DispatchQueue.main.async { [weak self] in
            self?.upcomingEvents = ekEvents
                .map { CalendarEvent.from(ekEvent: $0) }
                .sorted { $0.startDate < $1.startDate }

            self?.todayEvents = ekTodayEvents
                .map { CalendarEvent.from(ekEvent: $0) }
                .sorted { $0.startDate < $1.startDate }

            self?.isLoading = false
        }
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }

    func forceRefresh() {
        fetchEvents()
    }

    // MARK: - Muted Events

    private func loadMutedEvents() {
        if let saved = UserDefaults.standard.array(forKey: Self.mutedKey) as? [String] {
            mutedEventIDs = Set(saved)
        }
    }

    private func saveMutedEvents() {
        UserDefaults.standard.set(Array(mutedEventIDs), forKey: Self.mutedKey)
    }

    func isEventMuted(_ eventID: String) -> Bool {
        mutedEventIDs.contains(eventID)
    }

    func toggleMute(for eventID: String) {
        if mutedEventIDs.contains(eventID) {
            mutedEventIDs.remove(eventID)
        } else {
            mutedEventIDs.insert(eventID)
        }
        saveMutedEvents()
    }

    func setMute(_ muted: Bool, for eventID: String) {
        if muted {
            mutedEventIDs.insert(eventID)
        } else {
            mutedEventIDs.remove(eventID)
        }
        saveMutedEvents()
    }

    /// Events that have alarms enabled (not muted)
    var enabledEvents: [CalendarEvent] {
        upcomingEvents.filter { !mutedEventIDs.contains($0.id) }
    }
}

// Support iOS 17 full access status check
extension EKAuthorizationStatus {
    var isGranted: Bool {
        switch self {
        case .authorized:
            return true
        case .fullAccess:
            return true
        default:
            return false
        }
    }
}
