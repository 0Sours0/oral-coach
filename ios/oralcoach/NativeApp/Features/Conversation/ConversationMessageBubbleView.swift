import SwiftUI

struct ConversationMessageBubbleView: View {
  let message: Message

  var body: some View {
    VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 6) {
      HStack {
        if message.isUserMessage { Spacer(minLength: 24) }

        VStack(alignment: .leading, spacing: 6) {
          Text(message.text)
            .font(.body)
            .foregroundStyle(message.role.conversationTextColor)
            .multilineTextAlignment(.leading)

          if let subtitle = message.conversationSubtitle {
            VStack(alignment: .leading, spacing: 4) {
              Text("Better way to say it")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.primary)
            }
            .padding(.top, 2)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
            )
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(message.role.conversationBubbleColor)
        )

        if !message.isUserMessage { Spacer(minLength: 24) }
      }

      HStack {
        if message.isUserMessage { Spacer(minLength: 0) }
        Text(Self.timestampFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.createdAt) / 1000)))
          .font(.caption2)
          .foregroundStyle(.secondary)
        if !message.isUserMessage { Spacer(minLength: 0) }
      }
    }
  }

  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
  }()
}
