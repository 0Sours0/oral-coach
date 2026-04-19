import SwiftUI

struct ConversationMessageListView: View {
  let messages: [Message]
  let lastMessageID: NativeAppID?

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(messages) { message in
            ConversationMessageBubbleView(message: message)
              .id(message.id)
          }

          Color.clear
            .frame(height: 12)
            .id("thread-bottom")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: lastMessageID) { _, _ in
        withAnimation(.easeOut(duration: 0.25)) {
          proxy.scrollTo("thread-bottom", anchor: .bottom)
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
        withAnimation(.easeOut(duration: 0.25)) {
          proxy.scrollTo("thread-bottom", anchor: .bottom)
        }
      }
    }
  }
}

