import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var alarmState: AlarmState

    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        Group {
            if !calendarManager.authorizationStatus.isGranted || !notificationManager.isAuthorized {
                PermissionsView()
            } else {
                mainContent
            }
        }
        .onAppear {
            if calendarManager.authorizationStatus.isGranted {
                calendarManager.fetchEvents()
            }
        }
    }

    @State private var isSyncing = false

    private var mainContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                statsHeader

                // Sync Calendar Button
                syncButton

                // Event List
                EventListView()
                    .environmentObject(calendarManager)
                    .environmentObject(notificationManager)
            }
            .navigationTitle("Calendar Alarm")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(calendarManager)
                    .environmentObject(notificationManager)
            }
        }
    }

    private var syncButton: some View {
        Button {
            syncCalendar()
        } label: {
            HStack(spacing: 10) {
                if isSyncing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(isSyncing ? "Syncing..." : "Sync Calendar")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSyncing ? Color.gray : Color.blue)
            .cornerRadius(12)
        }
        .disabled(isSyncing)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func syncCalendar() {
        isSyncing = true
        calendarManager.forceRefresh()

        // Brief delay to show the syncing state and let events load
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            notificationManager.scheduleAlarms(
                for: calendarManager.upcomingEvents,
                mutedIDs: calendarManager.mutedEventIDs
            )
            isSyncing = false
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "calendar",
                value: "\(calendarManager.todayEvents.count)",
                label: "Today",
                color: .blue
            )

            StatCard(
                icon: "bell.fill",
                value: "\(notificationManager.scheduledCount)",
                label: "Alarms Set",
                color: .orange
            )

            StatCard(
                icon: "clock",
                value: nextEventTime,
                label: "Next Event",
                color: .green
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var nextEventTime: String {
        guard let next = calendarManager.upcomingEvents.first(where: { $0.isUpcoming }) else {
            return "—"
        }
        return next.relativeTimeString
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

#Preview {
    ContentView()
        .environmentObject(CalendarManager())
        .environmentObject(NotificationManager())
        .environmentObject(AlarmState())
}
