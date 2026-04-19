import SwiftUI

private enum ComposerInputMode {
  case text
  case voice
}

struct ConversationComposerView: View {
  @Binding var draftText: String
  let isSending: Bool
  let isRecording: Bool
  let isCallActive: Bool
  let isCallConnecting: Bool
  let onSendText: () -> Void
  let onMicPressBegin: () -> Void
  let onMicPressEnd: () -> Void
  let onCallTap: () -> Void

  @FocusState private var isTextFocused: Bool
  @State private var inputMode: ComposerInputMode = .text
  @State private var isMicPressed = false

  var body: some View {
    HStack(spacing: 10) {
      callButton

      switch inputMode {
      case .text:
        micToggleButton
        textRow
      case .voice:
        micHoldArea
        textToggleButton
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 16)
    .background(.ultraThinMaterial)
    .animation(.spring(duration: 0.28, bounce: 0.15), value: inputMode)
    .animation(.easeInOut(duration: 0.1), value: isRecording)
  }

  // MARK: - Call button

  private var callButton: some View {
    Button(action: onCallTap) {
      Image(systemName: callIconName)
        .font(.system(size: 18, weight: .semibold))
        .frame(width: 44, height: 44)
        .foregroundStyle(isCallActive ? .white : Color.green)
        .background(Circle().fill(isCallActive ? Color.red : Color.green.opacity(0.12)))
    }
    .buttonStyle(.plain)
    .disabled(isCallConnecting)
  }

  private var callIconName: String {
    if isCallConnecting { return "arrow.triangle.2.circlepath" }
    return isCallActive ? "phone.down.fill" : "phone.fill"
  }

  // MARK: - Mic toggle button (text mode, 44pt → tap to enter voice mode)

  private var micToggleButton: some View {
    Button {
      isTextFocused = false
      withAnimation(.spring(duration: 0.28, bounce: 0.15)) {
        inputMode = .voice
      }
    } label: {
      Image(systemName: "mic.fill")
        .font(.system(size: 18, weight: .semibold))
        .frame(width: 44, height: 44)
        .foregroundStyle(Color.blue)
        .background(Circle().fill(Color.blue.opacity(0.12)))
    }
    .buttonStyle(.plain)
    .disabled(isCallActive)
  }

  // MARK: - Text toggle button (voice mode, 44pt → tap to enter text mode)

  private var textToggleButton: some View {
    Button {
      withAnimation(.spring(duration: 0.28, bounce: 0.15)) {
        inputMode = .text
      }
    } label: {
      Text("Aa")
        .font(.system(size: 15, weight: .semibold))
        .frame(width: 44, height: 44)
        .foregroundStyle(Color.primary)
        .background(Circle().fill(Color(.secondarySystemBackground)))
    }
    .buttonStyle(.plain)
    .disabled(isRecording)
  }

  // MARK: - Mic hold area (voice mode, flex → long press to record)

  private var micHoldArea: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(isRecording ? Color.red.opacity(0.1) : Color(.secondarySystemBackground))

      HStack(spacing: 8) {
        if isRecording {
          Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
          Text("Recording...")
            .font(.subheadline)
            .foregroundStyle(.primary)
        } else {
          Image(systemName: "mic.fill")
            .font(.system(size: 15))
            .foregroundStyle(isMicPressed ? Color.red : Color.blue)
          Text(isMicPressed ? "Recording..." : "Hold to record")
            .font(.subheadline)
            .foregroundStyle(isMicPressed ? .primary : .secondary)
        }
        Spacer()
      }
      .padding(.horizontal, 14)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 46)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          guard !isMicPressed, !isCallActive, !isSending else { return }
          isMicPressed = true
          onMicPressBegin()
        }
        .onEnded { _ in
          guard isMicPressed else { return }
          isMicPressed = false
          onMicPressEnd()
        }
    )
    .disabled(isCallActive || isSending)
  }

  // MARK: - Text row (text mode, flex)

  private var textRow: some View {
    HStack(spacing: 8) {
      TextField("Message...", text: $draftText, axis: .vertical)
        .textFieldStyle(.plain)
        .font(.body)
        .lineLimit(1...4)
        .focused($isTextFocused)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
        )
        .disabled(isCallActive || isSending)

      if canShowSendButton {
        sendButton
      }
    }
  }

  private var canShowSendButton: Bool {
    isTextFocused || !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var sendButton: some View {
    let active = !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    return Button(action: onSendText) {
      Image(systemName: "arrow.up")
        .font(.system(size: 16, weight: .semibold))
        .frame(width: 44, height: 44)
        .foregroundStyle(active ? .white : .secondary)
        .background(Circle().fill(active ? Color.blue : Color(.tertiarySystemFill)))
    }
    .buttonStyle(.plain)
    .disabled(!active)
  }
}
