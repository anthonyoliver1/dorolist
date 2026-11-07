import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct PomodoroActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var sessionId: String
    var phase: String
    var phaseLabel: String
    var taskTitle: String?
    var totalSeconds: Int
    var remainingSeconds: Int
    var startedAt: Date
    var deadline: Date?
  }
}
