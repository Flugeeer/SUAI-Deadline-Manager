import Foundation

/// Одно задание, извлечённое из закрытой страницы личного кабинета.
struct DeadlineItem: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subject: String?
    let dueDate: String?
    let status: String?
    let details: String?
    let sourceURL: String?
}

/// Результат преобразования страницы `/inside/student/tasks/`.
struct DeadlinesSnapshot: Codable, Hashable {
    let pageTitle: String
    let items: [DeadlineItem]
}

enum DeadlinesLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum DeadlinesBrowserMode: String, Identifiable {
    case capture
    case fullPage

    var id: String { rawValue }
}
