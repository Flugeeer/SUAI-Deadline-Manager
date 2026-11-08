import Foundation

/// Состояние нативной вкладки дедлайнов.
@MainActor
final class DeadlinesStore: ObservableObject {
    @Published private(set) var pageTitle = "Дедлайны"
    @Published private(set) var items: [DeadlineItem] = []
    @Published private(set) var state: DeadlinesLoadingState = .idle

    func beginLoading() {
        state = .loading
    }

    func apply(_ snapshot: DeadlinesSnapshot) {
        pageTitle = snapshot.pageTitle
        items = snapshot.items
        state = .loaded
    }

    func finishPresentationWithoutResult() {
        state = items.isEmpty ? .idle : .loaded
    }

    func fail(with message: String) {
        state = .failed(message)
    }
}
