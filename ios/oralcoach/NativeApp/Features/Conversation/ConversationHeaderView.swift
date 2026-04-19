import SwiftUI

struct ConversationHeaderView: View {
  let personaName: String
  let sessionTitle: String
  let statusText: String
  let onStartNewConversation: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text(sessionTitle)
          .font(.title2.weight(.semibold))
          .foregroundStyle(.primary)
        Text(personaName)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      HStack(spacing: 8) {
        Text(statusText)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            Capsule(style: .continuous)
              .fill(Color(.secondarySystemBackground))
          )

        Button(action: onStartNewConversation) {
          Label("New", systemImage: "plus")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
              Capsule(style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
      }
    }
  }
}
