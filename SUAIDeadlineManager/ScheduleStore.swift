//
//  ScheduleStore.swift
//  ScheduleStore
//
//  Created by Vladislav Katashov on 06.11.2026.
//


import Foundation

/// Центральное состояние расписания, безопасно публикуемое только из главного потока.
@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var catalog = ScheduleCatalog()
    @Published private(set) var days: [ScheduleDay] = []
    @Published private(set) var weekContext: ScheduleWeekContext = .unknown
    @Published private(set) var catalogState: ScheduleLoadingState = .idle
    @Published private(set) var scheduleState: ScheduleLoadingState = .idle
    @Published private(set) var currentCriteria = ScheduleCriteria()

    private let service = ScheduleService()

    /// Загружает каталог один раз и позволяет повторить запрос после ошибки.
    func loadCatalog() async {
        guard catalogState != .loading, catalog.groups.isEmpty else { return }
        catalogState = .loading
        do {
            let catalog = try await service.loadCatalog()
            guard !catalog.groups.isEmpty else { throw URLError(.cannotParseResponse) }
            self.catalog = catalog
            catalogState = .loaded
        } catch {
            catalogState = .failed(Self.message(for: error))
        }
    }

    /// Загружает расписание, сохраняя критерии для обновления жестом pull-to-refresh.
    func loadSchedule(for criteria: ScheduleCriteria) async {
        guard !criteria.isEmpty else { return }
        currentCriteria = criteria
        scheduleState = .loading
        do {
            let response = try await service.loadSchedule(for: criteria)
            days = response.days
            weekContext = response.weekContext
            scheduleState = .loaded
        } catch {
            scheduleState = .failed(Self.message(for: error))
        }
    }

    /// Восстанавливает полный объект фильтра по сохранённому идентификатору.
    func option(id: String, in options: [ScheduleOption]) -> ScheduleOption? {
        options.first { $0.id == id }
    }

    /// Преобразует техническую сетевую ошибку в понятное сообщение интерфейса.
    private static func message(for error: Error) -> String {
        if (error as? URLError)?.code == .notConnectedToInternet {
            return "Нет подключения к интернету."
        }
        return "Не удалось получить данные с guap.ru. Попробуйте ещё раз."
    }
}
