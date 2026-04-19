import SwiftUI

struct ConversationFeatureRootView: View {
  @StateObject private var threadStore: ConversationThreadStore
  @StateObject private var voiceMessageViewModel: VoiceMessageConversationViewModel
  @StateObject private var realtimeCallViewModel: RealtimeCallConversationViewModel
  @StateObject private var viewModel: ConversationFeatureViewModel

  @MainActor
  init() {
    self.init(dependencies: NativeAppDependencies.shared.conversationFeatureDependencies)
  }

  init(dependencies: ConversationFeatureDependencies) {
    let threadStore = ConversationThreadStore()
    let voiceMessageViewModel = VoiceMessageConversationViewModel(
      threadStore: threadStore,
      dependencies: dependencies
    )
    let realtimeCallViewModel = RealtimeCallConversationViewModel(
      threadStore: threadStore,
      dependencies: dependencies
    )
    _threadStore = StateObject(wrappedValue: threadStore)
    _voiceMessageViewModel = StateObject(wrappedValue: voiceMessageViewModel)
    _realtimeCallViewModel = StateObject(wrappedValue: realtimeCallViewModel)
    _viewModel = StateObject(
      wrappedValue: ConversationFeatureViewModel(
        dependencies: dependencies,
        threadStore: threadStore,
        voiceMessageViewModel: voiceMessageViewModel,
        realtimeCallViewModel: realtimeCallViewModel
      )
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      ConversationHeaderView(
        personaName: threadStore.personaName,
        sessionTitle: threadStore.threadTitle,
        statusText: threadStore.statusText,
        onStartNewConversation: {
          Task { await viewModel.startNewConversation() }
        }
      )
      .padding(.horizontal, 16)
      .padding(.top, 12)

      ConversationMessageListView(
        messages: threadStore.messages,
        lastMessageID: threadStore.lastMessageID
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onTapGesture {
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder),
          to: nil, from: nil, for: nil
        )
      }

      ConversationComposerView(
        draftText: Binding(
          get: { threadStore.draftText },
          set: { threadStore.draftText = $0 }
        ),
        isSending: viewModel.isSending,
        isRecording: voiceMessageViewModel.isRecording,
        isCallActive: viewModel.isCallActive,
        isCallConnecting: viewModel.isCallConnecting,
        onSendText: {
          Task { await viewModel.sendDraft() }
        },
        onMicPressBegin: {
          Task { await viewModel.micPressBegin() }
        },
        onMicPressEnd: {
          Task { await viewModel.micPressEnd() }
        },
        onCallTap: {
          Task { await viewModel.callButtonTapped() }
        }
      )
    }
    .background(
      LinearGradient(
        colors: [
          Color(.systemBackground),
          Color(.secondarySystemBackground).opacity(0.45)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
    .task {
      await viewModel.loadIfNeeded()
    }
  }
}

#if DEBUG
struct ConversationFeatureRootView_Previews: PreviewProvider {
  static var previews: some View {
    ConversationFeatureRootView(dependencies: .preview)
  }
}
#endif
