import SwiftUI

struct ConversationModeSwitchView: View {
  @Binding var selectedMode: SessionMode

  var body: some View {
    HStack(spacing: 10) {
      ForEach(SessionMode.allCases) { mode in
        Button {
          selectedMode = mode
        } label: {
          HStack(spacing: 8) {
            Image(systemName: mode.conversationSystemImage)
            Text(mode.conversationTitle)
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(selectedMode == mode ? .white : .primary)
          .padding(.vertical, 10)
          .frame(maxWidth: .infinity)
          .background(
            Capsule(style: .continuous)
              .fill(selectedMode == mode ? Color.blue : Color(.secondarySystemBackground))
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

