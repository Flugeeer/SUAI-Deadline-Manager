import Foundation

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var catalog = ScheduleCatalog()
    @Published private(set) var days: [ScheduleDay] = []
    @Published private(set) var catalogState: ScheduleLoadingState = .idle
    @Published private(set) var scheduleState: ScheduleLoadingState = .idle
    @Published private(set) var currentCriteria = ScheduleCriteria()

    private let service = ScheduleService()

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

    func loadSchedule(for criteria: ScheduleCriteria) async {
        guard !criteria.isEmpty else { return }
        currentCriteria = criteria
        scheduleState = .loading
        do {
            days = try await service.loadSchedule(for: criteria)
            scheduleState = .loaded
        } catch {
            scheduleState = .failed(Self.message(for: error))
        }
    }

    func option(id: String, in options: [ScheduleOption]) -> ScheduleOption? {
        options.first { $0.id == id }
    }

    private static func message(for error: Error) -> String {
        if (error as? URLError)?.code == .notConnectedToInternet {
            return "Нет подключения к интернету."
        }
        return "Не удалось получить данные с guap.ru. Попробуйте ещё раз."
    }
}
