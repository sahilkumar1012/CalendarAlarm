import SwiftUI
import UIKit

struct AlarmView: View {
    let event: CalendarEvent

    @EnvironmentObject var alarmState: AlarmState
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var pulseScale: CGFloat = 1.0
    @State private var hapticTimer: Timer? = nil

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                Spacer()

                alarmIcon

                Spacer().frame(height: 30)

                Text(event.title)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .shadow(radius: 4)

                Spacer().frame(height: 12)

                Text(event.formattedTime)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))

                Spacer().frame(height: 8)

                Text(event.calendarName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(20)

                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                        Text(location)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 12)
                }

                Spacer()

                actionButtons

                Spacer().frame(height: 60)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
            startHaptics()
        }
        .onDisappear {
            stopHaptics()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.red.opacity(0.9),
                Color.red.opacity(0.7),
                Color.orange.opacity(0.8),
                Color.red.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Circle()
                .fill(Color.white.opacity(0.05))
                .scaleEffect(pulseScale * 2)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: pulseScale
                )
        )
        .ignoresSafeArea()
    }

    // MARK: - Alarm Icon

    private var alarmIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)

            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 180, height: 180)
                .scaleEffect(pulseScale * 1.1)

            Image(systemName: "bell.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .rotationEffect(.degrees(pulseScale > 1.05 ? 10 : -10))
                .animation(
                    .easeInOut(duration: 0.3).repeatForever(autoreverses: true),
                    value: pulseScale
                )
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Dismiss")
                        .fontWeight(.bold)
                }
                .font(.title3)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .padding(.horizontal, 40)

            Button {
                snooze()
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Snooze \(notificationManager.snoozeMinutes) min")
                }
                .font(.body)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Actions

    private func dismiss() {
        stopHaptics()
        withAnimation {
            alarmState.dismissAlarm()
        }
    }

    private func snooze() {
        stopHaptics()
        let snoozeEvent = CalendarEvent(
            id: event.id + "_snooze_\(Date().timeIntervalSince1970)",
            title: event.title,
            startDate: Date().addingTimeInterval(Double(notificationManager.snoozeMinutes * 60)),
            endDate: event.endDate,
            calendarName: event.calendarName,
            calendarColor: event.calendarColor,
            location: event.location,
            notes: event.notes,
            isAllDay: event.isAllDay
        )
        notificationManager.scheduleSingleAlarm(for: snoozeEvent)
        withAnimation {
            alarmState.dismissAlarm()
        }
    }

    // MARK: - Animations & Haptics

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }

    private func startHaptics() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            generator.notificationOccurred(.warning)
        }
    }

    private func stopHaptics() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}

#Preview {
    AlarmView(
        event: CalendarEvent(
            id: "preview",
            title: "Team Standup Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarName: "Work",
            calendarColor: .blue,
            location: "Conference Room A",
            notes: "Discuss sprint progress",
            isAllDay: false
        )
    )
    .environmentObject(AlarmState())
    .environmentObject(NotificationManager())
}
