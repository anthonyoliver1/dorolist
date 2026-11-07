import ActivityKit
import SwiftUI
import WidgetKit

private let focusColor = Color(red: 0.58, green: 0.84, blue: 0.76)
private let breakColor = Color(red: 0.91, green: 0.68, blue: 0.59)

@main
struct PomodoroLiveActivityBundle: WidgetBundle {
  var body: some Widget { PomodoroLiveActivity() }
}

struct PomodoroLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
      HStack(spacing: 16) {
        Image(systemName: "timer").font(.title2).foregroundStyle(tint(context))
        VStack(alignment: .leading, spacing: 5) {
          Text(status(context)).font(.subheadline.weight(.semibold))
          Text(context.state.taskTitle ?? "Doro List")
            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        Spacer(minLength: 8)
        Countdown(state: context.state).font(.system(size: 30, weight: .medium, design: .rounded))
          .foregroundStyle(tint(context)).frame(maxWidth: 112)
      }
      .padding(20)
      .activityBackgroundTint(Color(red: 0.08, green: 0.11, blue: 0.10))
      .activitySystemActionForegroundColor(.white)
      .foregroundStyle(.white)
      .widgetURL(URL(string: "doro-list://focus"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(status(context), systemImage: "timer")
            .font(.subheadline.weight(.semibold)).foregroundStyle(tint(context))
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(state: context.state).font(.title2.weight(.medium))
            .foregroundStyle(tint(context)).frame(maxWidth: 110)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.taskTitle ?? "Doro List")
            .font(.subheadline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Image(systemName: "timer").foregroundStyle(tint(context))
      } compactTrailing: {
        Countdown(state: context.state).font(.caption.weight(.medium))
          .foregroundStyle(tint(context)).frame(width: 50)
      } minimal: {
        Countdown(state: context.state).font(.system(size: 10, weight: .medium))
          .foregroundStyle(tint(context)).minimumScaleFactor(0.7)
      }
      .widgetURL(URL(string: "doro-list://focus"))
      .keylineTint(tint(context))
    }
  }

  private func tint(_ context: ActivityViewContext<PomodoroActivityAttributes>) -> Color {
    context.state.phase == "short" || context.state.phase == "long" ? breakColor : focusColor
  }

  private func status(_ context: ActivityViewContext<PomodoroActivityAttributes>) -> String {
    if #available(iOS 16.2, *), context.isStale { return "Etapa concluída" }
    return context.state.deadline == nil ? "\(context.state.phaseLabel) em pausa" : context.state.phaseLabel
  }
}

private struct Countdown: View {
  let state: PomodoroActivityAttributes.ContentState
  var body: some View {
    Group {
      if let deadline = state.deadline {
        Text(timerInterval: min(state.startedAt, deadline)...deadline,
             countsDown: true, showsHours: false)
      } else {
        Text(String(format: "%02d:%02d", state.remainingSeconds / 60, state.remainingSeconds % 60))
      }
    }.monospacedDigit().multilineTextAlignment(.trailing)
      .accessibilityLabel(state.deadline == nil ? "Tempo pausado" : "Tempo restante")
  }
}
