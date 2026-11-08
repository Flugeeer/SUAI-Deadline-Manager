import Foundation

/// Одно подписанное значение из личного кабинета.
struct StudentProfileItem: Codable, Hashable, Identifiable {
    var id: String { "\(label)|\(value)" }
    let label: String
    let value: String
}

/// Логическая группа данных профиля для отображения отдельной карточкой.
struct StudentProfileSection: Codable, Hashable, Identifiable {
    var id: String { title }
    let title: String
    let items: [StudentProfileItem]
}

/// Снимок открытой страницы профиля, уже преобразованный в нативные модели.
struct StudentProfileSnapshot: Codable, Hashable {
    let displayName: String
    let sections: [StudentProfileSection]
}

enum ProfileBrowserMode: String, Identifiable {
    case capture
    case fullCabinet

    var id: String { rawValue }
}
