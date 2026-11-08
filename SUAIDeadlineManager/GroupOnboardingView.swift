//
//  GroupOnboardingView.swift
//  GroupOnboardingView
//
//  Created by Vladislav Katashov on 06.11.2026.
//


import SwiftUI

/// Обязательный выбор основной группы при первом запуске приложения.
struct GroupOnboardingView: View {
    @ObservedObject var store: ScheduleStore
    let onSelect: (ScheduleOption) -> Void

    @State private var searchText = ""

    /// Сужает уже загруженный каталог по введённому номеру группы.
    private var filteredGroups: [ScheduleOption] {
        guard !searchText.isEmpty else { return store.catalog.groups }
        return store.catalog.groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch store.catalogState {
                case .idle, .loading:
                    ProgressView("Загружаем список групп")
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Не удалось загрузить группы", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Повторить") { Task { await store.loadCatalog() } }
                            .buttonStyle(.borderedProminent)
                    }
                case .loaded:
                    List(filteredGroups) { group in
                        Button {
                            onSelect(group)
                        } label: {
                            HStack {
                                Text(group.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Номер группы")
                }
            }
            .navigationTitle("Выберите свою группу")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Text("Она будет открываться по умолчанию. Другие группы и преподавателей можно посмотреть в любой момент.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial)
            }
        }
        .task { await store.loadCatalog() }
    }
}
