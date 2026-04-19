import SwiftUI

struct NativeRecordDetailFeatureScreen: View {
  let record: LearningRecord

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        headerCard
        detailCard(title: "Chinese explanation", body: record.cnExplanation)
        detailCard(title: "Scenario", body: record.scenario.isEmpty ? "Not specified" : record.scenario)
        detailCard(title: "Your original line", body: record.userOriginal, accent: .secondary)
        detailCard(title: "Better expression", body: record.assistantBetterExpression, accent: .accentColor)
      }
      .padding(16)
    }
    .navigationTitle("Detail")
    .navigationBarTitleDisplayMode(.inline)
    .background(Color(uiColor: .systemGroupedBackground))
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(record.expression)
        .font(.title2.weight(.semibold))
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 10) {
        Label(record.nativeCreatedAtDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
        if !record.sessionId.isEmpty {
          Label("Session \(record.sessionId)", systemImage: "rectangle.stack")
        }
      }
      .font(.caption)
      .foregroundStyle(.white.opacity(0.8))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(
      LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private func detailCard(title: String, body: String, accent: Color = .primary) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .tracking(0.6)

      Text(body)
        .font(.body)
        .foregroundStyle(accent)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

#if DEBUG
struct NativeRecordDetailFeatureScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      NativeRecordDetailFeatureScreen(
        record: LearningRecord(
          id: "record-preview",
          sessionId: "session-preview",
          messageId: "message-preview",
          expression: "What do you do?",
          cnExplanation: "问对方做什么工作。",
          scenario: "conversation",
          userOriginal: "What's your job?",
          assistantBetterExpression: "What do you do?",
          createdAt: 1_710_000_000_000
        )
      )
    }
  }
}
#endif
