import Foundation

struct ScheduleOption: Identifiable, Hashable, Codable {
    let id: String
    let name: String
}

struct ScheduleCatalog {
    var groups: [ScheduleOption] = []
    var teachers: [ScheduleOption] = []
    var chairs: [ScheduleOption] = []
    var rooms: [ScheduleOption] = []
}

struct ScheduleCriteria: Hashable {
    var group: ScheduleOption?
    var teacher: ScheduleOption?
    var chair: ScheduleOption?
    var room: ScheduleOption?

    var isEmpty: Bool {
        group == nil && teacher == nil && chair == nil && room == nil
    }

    var title: String {
        [group.map { "гр. \($0.name)" }, teacher?.name, chair?.name, room?.name]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

enum LessonWeek: String, Hashable {
    case every = "Каждую неделю"
    case upper = "Верхняя неделя"
    case lower = "Нижняя неделя"
}

struct ScheduleLesson: Identifiable, Hashable {
    let id = UUID()
    let pairNumber: String?
    let time: String?
    let week: LessonWeek
    let kind: String
    let subject: String
    let room: String?
    let chair: String?
    let teacher: String?
    let groups: [String]
}

struct ScheduleDay: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let lessons: [ScheduleLesson]
}

enum ScheduleLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
