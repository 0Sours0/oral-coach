import SwiftUI

@MainActor
struct NativeSettingsFeatureScreen: View {
  @StateObject private var viewModel: NativeSettingsFeatureViewModel

  @MainActor
  init() {
    self.init(viewModel: NativeSettingsFeatureViewModel())
  }

  init(viewModel: NativeSettingsFeatureViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        heroCard
        personaSection
        settingsSection
      }
      .padding(16)
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.large)
    .background(Color(uiColor: .systemGroupedBackground))
    .task {
      if viewModel.personas.isEmpty {
        await viewModel.load()
      }
    }
    .refreshable {
      await viewModel.reload()
    }
    .alert(
      "Settings error",
      isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { if !$0 { viewModel.errorMessage = nil } }
      ),
      actions: {
        Button("OK", role: .cancel) { viewModel.errorMessage = nil }
      },
      message: {
        Text(viewModel.errorMessage ?? "Unknown error")
      }
    )
  }

  private var heroCard: some View {
    NativeSettingsHeroCard(
      persona: viewModel.activePersona,
      settings: viewModel.settings
    )
  }

  private var personaSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Personas", subtitle: "Identity comes first. Teaching stays secondary.")

      ForEach(viewModel.personas) { persona in
        NativePersonaCardView(
          persona: persona,
          isExpanded: viewModel.expandedPersonaID == persona.id,
          onExpand: { viewModel.togglePersonaExpansion(id: persona.id) },
          onSelect: { Task { await viewModel.selectPersona(id: persona.id) } }
        )
      }
    }
  }

  private var settingsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "Learning policy", subtitle: "These controls tune how the persona teaches.")

      NativeOptionGroup(
        title: "Teacher style",
        subtitle: "How the coach feels in conversation",
        selection: viewModel.settings.teacherStyle.title,
        options: NativeTeacherStyle.allCases.map { ($0.title, $0) },
        onSelect: viewModel.updateTeacherStyle
      )

      NativeOptionGroup(
        title: "Correction level",
        subtitle: "How aggressively English gets fixed",
        selection: viewModel.settings.correctionLevel.title,
        options: NativeCorrectionLevel.allCases.map { ($0.title, $0) },
        onSelect: viewModel.updateCorrectionLevel
      )

      NativeOptionGroup(
        title: "Chinese usage",
        subtitle: "Chinese only when explicitly needed",
        selection: viewModel.settings.chineseRatio.title,
        options: NativeChineseRatio.allCases.map { ($0.title, $0) },
        onSelect: viewModel.updateChineseRatio
      )

      NativeOptionGroup(
        title: "TTS voice",
        subtitle: "Voice used for synthesized replies",
        selection: viewModel.settings.ttsVoice.title,
        options: NativeTTSVoice.allCases.map { ($0.title, $0) },
        onSelect: viewModel.updateTTSVoice
      )

      NativeStepperCard(
        title: "Recent message count",
        subtitle: "How much context the model sees",
        value: viewModel.settings.recentMessageCount,
        range: 3...10,
        onChange: viewModel.updateRecentMessageCount
      )
    }
  }

  private func sectionHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.headline)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct NativeSettingsHeroCard: View {
  let persona: PersonaProfile?
  let settings: NativeLearningSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Active persona")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

          Text(persona?.name ?? "No persona selected")
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)

          Text(persona?.bio ?? "Persona metadata will appear here once the repository is connected.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 8) {
          Label(settings.teacherStyle.title, systemImage: "person.text.rectangle")
            .font(.caption.weight(.semibold))
          Label(settings.ttsVoice.title, systemImage: "speaker.wave.2.fill")
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.accentColor)
      }

      Text("English correction is a habit layered onto identity, not the identity itself.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [
          Color.accentColor.opacity(0.18),
          Color(uiColor: .secondarySystemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

private struct NativePersonaCardView: View {
  let persona: PersonaProfile
  let isExpanded: Bool
  let onExpand: () -> Void
  let onSelect: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: onExpand) {
        HStack(alignment: .top, spacing: 12) {
          Circle()
            .fill(Color.accentColor.opacity(0.14))
            .frame(width: 38, height: 38)
            .overlay(
              Text(String(persona.name.prefix(1)))
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            )

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(persona.name)
                .font(.headline)
              if persona.isActive == 1 {
                Text("Current")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Color.accentColor)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.accentColor.opacity(0.12))
                  .clipShape(Capsule())
              }
            }

            Text(persona.bio)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(isExpanded ? nil : 2)
          }

          Spacer(minLength: 8)

          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(alignment: .leading, spacing: 10) {
          labeledBlock(title: "Personality", value: persona.personality)
          labeledBlock(title: "Speaking style", value: persona.speakingStyle)
          labeledBlock(title: "Teaching style", value: persona.teachingStyle)
          labeledBlock(title: "Behavior rules", value: persona.behaviorRules)

          Button(action: onSelect) {
            Text(persona.isActive == 1 ? "Current persona" : "Switch to this persona")
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(persona.isActive == 1 ? Color.gray.opacity(0.16) : Color.accentColor)
              .foregroundStyle(persona.isActive == 1 ? Color.secondary : Color.white)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(persona.isActive == 1)
        }
      }
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func labeledBlock(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased())
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.footnote)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct NativeOptionGroup<T: Hashable>: View {
  let title: String
  let subtitle: String
  let selection: String
  let options: [(String, T)]
  let onSelect: (T) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(options, id: \.0) { option in
          Button {
            onSelect(option.1)
          } label: {
            Text(option.0)
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .padding(.horizontal, 12)
              .background(selection == option.0 ? Color.accentColor : Color(uiColor: .tertiarySystemBackground))
              .foregroundStyle(selection == option.0 ? .white : .primary)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

private struct NativeStepperCard: View {
  let title: String
  let subtitle: String
  let value: Int
  let range: ClosedRange<Int>
  let onChange: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Stepper(value: Binding(
        get: { value },
        set: { onChange($0) }
      ), in: range) {
        HStack {
          Text("Messages kept in context")
          Spacer()
          Text("\(value)")
            .foregroundStyle(Color.accentColor)
        }
      }
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

#if DEBUG
struct NativeSettingsFeatureScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      NativeSettingsFeatureScreen(
        viewModel: NativeSettingsFeatureViewModel(repository: NativeSettingsPreviewRepository())
      )
    }
  }
}
#endif
