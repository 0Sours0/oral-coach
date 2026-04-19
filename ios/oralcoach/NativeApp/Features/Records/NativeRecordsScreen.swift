import SwiftUI

@MainActor
struct NativeRecordsFeatureScreen: View {
  @StateObject private var viewModel: NativeRecordsFeatureViewModel

  @MainActor
  init() {
    self.init(viewModel: NativeRecordsFeatureViewModel())
  }

  init(viewModel: NativeRecordsFeatureViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      Section {
        NativeRecordsSummaryCard(
          title: "Expression archive",
          subtitle: viewModel.query.isEmpty ? "All saved learning records" : "Filtered by “\(viewModel.query)”",
          countText: viewModel.recordCountText
        )
        .listRowBackground(Color.clear)
      }

      if viewModel.isLoading {
        Section {
          HStack(spacing: 12) {
            ProgressView()
            Text("Loading records...")
          }
        }
      } else if viewModel.records.isEmpty {
        Section {
          ContentUnavailableView(
            viewModel.emptyQueryTitle,
            systemImage: "bookmark.slash",
            description: Text(viewModel.emptyQueryMessage)
          )
          .padding(.vertical, 16)
          .listRowBackground(Color.clear)
        }
      } else {
        Section("Learning records") {
          ForEach(viewModel.records) { record in
            NavigationLink {
              NativeRecordDetailFeatureScreen(record: record)
            } label: {
              NativeRecordRowView(record: record)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) {
                Task { await viewModel.delete(record) }
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
          }
        }
      }
    }
    .navigationTitle("Records")
    .navigationBarTitleDisplayMode(.large)
    .searchable(text: $viewModel.query, prompt: "Search expressions")
    .refreshable {
      await viewModel.reload()
    }
    .task(id: viewModel.query) {
      await viewModel.load()
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
    .alert(
      "Records error",
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
}

private struct NativeRecordsSummaryCard: View {
  let title: String
  let subtitle: String
  let countText: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text(countText.uppercased())
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.accentColor)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.accentColor.opacity(0.12))
          .clipShape(Capsule())
      }
    }
    .padding(.vertical, 4)
  }
}

private struct NativeRecordRowView: View {
  let record: LearningRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Text(record.expression)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(2)

        Spacer(minLength: 8)

        Text(record.nativeCreatedAtDate.formatted(date: .abbreviated, time: .shortened))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text(record.cnExplanation)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      if !record.scenario.isEmpty {
        Label(record.scenario, systemImage: "bubble.left.and.bubble.right")
          .font(.caption)
          .foregroundStyle(Color.accentColor)
          .labelStyle(.titleAndIcon)
      }
    }
    .padding(.vertical, 4)
  }
}

#if DEBUG
struct NativeRecordsFeatureScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      NativeRecordsFeatureScreen(
        viewModel: NativeRecordsFeatureViewModel(repository: NativeRecordsPreviewRepository())
      )
    }
  }
}
#endif
