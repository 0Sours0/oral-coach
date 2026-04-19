import Foundation
import SwiftUI

@MainActor
final class NativeRecordsFeatureViewModel: ObservableObject {
  @Published var query = ""
  @Published private(set) var records: [LearningRecord] = []
  @Published private(set) var isLoading = false
  @Published var errorMessage: String?

  private let repository: any NativeRecordsRepository

  init(repository: any NativeRecordsRepository) {
    self.repository = repository
  }

  convenience init() {
    self.init(repository: NativeAppDependencies.shared.recordsRepository)
  }

  @MainActor
  func load() async {
    isLoading = true
    errorMessage = nil

    do {
      records = try await repository.fetchLearningRecords(matching: query)
    } catch {
      errorMessage = error.localizedDescription
      records = []
    }

    isLoading = false
  }

  @MainActor
  func reload() async {
    await load()
  }

  @MainActor
  func delete(_ record: LearningRecord) async {
    do {
      try await repository.deleteLearningRecord(id: record.id)
      records.removeAll { $0.id == record.id }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  var recordCountText: String {
    "\(records.count) records"
  }

  var emptyQueryTitle: String {
    query.isEmpty ? "No records yet" : "No matches found"
  }

  var emptyQueryMessage: String {
    if query.isEmpty {
      return "Learning records from voice messages and corrections will appear here."
    }
    return "Try a different expression or clear the search term."
  }
}
