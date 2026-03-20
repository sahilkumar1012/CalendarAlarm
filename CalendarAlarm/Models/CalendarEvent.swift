import SwiftUI
import EventKit
import Combine

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarName: String
    let calendarColor: Color
    let location: String?
    let notes: String?
    let isAllDay: Bool

    var isHappeningNow: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var isUpcoming: Bool {
        return startDate > Date()
    }

    var timeUntilStart: TimeInterval {
        return startDate.timeIntervalSinceNow
    }

    var formattedTime: String {
        if isAllDay {
            return "All Day"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate)
    }

    var relativeTimeString: String {
        let interval = timeUntilStart
        if interval < 0 {
            return "Now"
        } else if interval < 60 {
            return "In less than a minute"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "In \(minutes) min\(minutes == 1 ? "" : "s")"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "In \(hours) hr\(hours == 1 ? "" : "s")"
        } else {
            let days = Int(interval / 86400)
            return "In \(days) day\(days == 1 ? "" : "s")"
        }
    }

    static func from(ekEvent: EKEvent) -> CalendarEvent {
        return CalendarEvent(
            id: ekEvent.eventIdentifier ?? UUID().uuidString,
            title: ekEvent.title ?? "Untitled Event",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            calendarName: ekEvent.calendar?.title ?? "Unknown",
            calendarColor: Color(cgColor: ekEvent.calendar?.cgColor ?? UIColor.systemBlue.cgColor),
            location: ekEvent.location,
            notes: ekEvent.notes,
            isAllDay: ekEvent.isAllDay
        )
    }
}
