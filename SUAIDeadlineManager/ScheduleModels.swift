//
//  ScheduleModels.swift
//  ScheduleModels
//
//  Created by Vladislav Katashov on 06.11.2026.
//


import Foundation

/// Один доступный вариант фильтра с идентификатором из HTML-формы ГУАП.
struct ScheduleOption: Identifiable, Hashable, Codable {
    let id: String
    let name: String
}

/// Все варианты фильтрации, загруженные со страницы расписания.
struct ScheduleCatalog {
    var groups: [ScheduleOption] = []
    var teachers: [ScheduleOption] = []
    var chairs: [ScheduleOption] = []
    var rooms: [ScheduleOption] = []
}

/// Набор выбранных пользователем фильтров. Фильтры разрешено сочетать.
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

/// Периодичность занятия относительно верхней и нижней учебной недели.
enum LessonWeek: String, Hashable {
    case every = "Каждую неделю"
    case upper = "Верхняя неделя"
    case lower = "Нижняя неделя"
}

/// Нормализованное занятие, полученное из одного HTML-блока расписания.
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

/// Учебный день и относящиеся к нему занятия.
struct ScheduleDay: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let lessons: [ScheduleLesson]
}

/// Номер и тип текущей учебной недели по данным страницы ГУАП.
struct ScheduleWeekContext: Hashable {
    let number: Int?
    let week: LessonWeek?

    static let unknown = ScheduleWeekContext(number: nil, week: nil)
}

/// Полный результат разбора страницы: занятия и контекст текущей недели.
struct ScheduleResponse {
    let days: [ScheduleDay]
    let weekContext: ScheduleWeekContext
}

/// Состояние асинхронной загрузки каталога или расписания.
enum ScheduleLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
