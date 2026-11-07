import ActivityKit
import Flutter
import UIKit

// Preserve cold-start links until the Flutter navigation is ready.
final class LiveActivityLinkRouter {
  static var pending = false
  static var onOpenFocus: (() -> Void)?

  @discardableResult static func open(_ url: URL) -> Bool {
    guard url.scheme == "doro-list", url.host == "focus" else { return false }
    if let callback = onOpenFocus { callback() } else { pending = true }
    return true
  }
}

final class PomodoroLiveActivityPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel

  private init(channel: FlutterMethodChannel) { self.channel = channel }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "doro_list/pomodoro_live_activity", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PomodoroLiveActivityPlugin(channel: channel), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      LiveActivityLinkRouter.onOpenFocus = { [channel] in
        channel.invokeMethod("openFocus", arguments: nil)
      }
      let pending = LiveActivityLinkRouter.pending
      LiveActivityLinkRouter.pending = false
      result(pending)
    case "sync":
      guard #available(iOS 16.1, *) else { result(nil); return }
      let data = call.arguments as? [String: Any]
      Task { @MainActor in
        do {
          try await PomodoroLiveActivityManager.sync(data)
          result(nil)
        } catch {
          result(FlutterError(code: "live_activity", message: error.localizedDescription, details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

@available(iOS 16.1, *)
@MainActor
private enum PomodoroLiveActivityManager {
  static func sync(_ data: [String: Any]?) async throws {
    let activities = Activity<PomodoroActivityAttributes>.activities
    guard let data = data else {
      for activity in activities { await end(activity) }
      return
    }
    guard let sessionId = data["sessionId"] as? String,
          let phase = data["phase"] as? String,
          let label = data["phaseLabel"] as? String,
          let total = data["totalSeconds"] as? Int, total > 0, total <= 10800,
          let start = data["startedAt"] as? NSNumber else { return }
    let deadline = (data["deadline"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
    let remaining = (data["remainingSeconds"] as? Int) ?? total
    let state = PomodoroActivityAttributes.ContentState(
      sessionId: sessionId, phase: phase, phaseLabel: String(label.prefix(60)),
      taskTitle: (data["taskTitle"] as? String).map { String($0.prefix(160)) },
      totalSeconds: total, remainingSeconds: remaining,
      startedAt: Date(timeIntervalSince1970: start.doubleValue / 1000), deadline: deadline)
    // Expired restored sessions must not create another countdown.
    if let deadline, deadline <= Date() {
      for activity in activities { await end(activity) }
      return
    }
    if let activity = activities.first(where: {
      $0.activityState != .ended && $0.activityState != .dismissed
    }) {
      if #available(iOS 16.2, *) {
        await activity.update(ActivityContent(state: state, staleDate: deadline))
      } else {
        await activity.update(using: state)
      }
      for other in activities where other.id != activity.id { await end(other) }
    } else if deadline != nil,
              UIApplication.shared.applicationState == .active,
              ActivityAuthorizationInfo().areActivitiesEnabled {
      if #available(iOS 16.2, *) {
        _ = try Activity.request(attributes: PomodoroActivityAttributes(),
                                 content: ActivityContent(state: state, staleDate: deadline), pushType: nil)
      } else {
        _ = try Activity.request(attributes: PomodoroActivityAttributes(), contentState: state, pushType: nil)
      }
    }
  }

  static func end(_ activity: Activity<PomodoroActivityAttributes>) async {
    if #available(iOS 16.2, *) {
      await activity.end(nil, dismissalPolicy: .immediate)
    } else {
      await activity.end(dismissalPolicy: .immediate)
    }
  }
}
