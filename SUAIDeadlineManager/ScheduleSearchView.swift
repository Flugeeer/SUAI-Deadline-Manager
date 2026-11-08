//
//  ScheduleSearchView.swift
//  ScheduleSearchView
//
//  Created by Vladislav Katashov on 06.11.2026.
//


import SwiftUI

/// Экран составного поиска по группе, преподавателю, кафедре и аудитории.
struct ScheduleSearchView: View {
    @ObservedObject var store: ScheduleStore
    let onApply: (ScheduleCriteria) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var criteria: ScheduleCriteria

    /// Начинает редактирование с фильтров, которые уже применены к расписанию.
    init(store: ScheduleStore, onApply: @escaping (ScheduleCriteria) -> Void) {
        self.store = store
        self.onApply = onApply
        _criteria = State(initialValue: store.currentCriteria)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    optionRow("Группа", icon: "person.3", selection: $criteria.group, options: store.catalog.groups)
                    optionRow("Преподаватель", icon: "person", selection: $criteria.teacher, options: store.catalog.teachers)
                    optionRow("Кафедра", icon: "building.columns", selection: $criteria.chair, options: store.catalog.chairs)
                    optionRow("Аудитория", icon: "door.left.hand.open", selection: $criteria.room, options: store.catalog.rooms)
                }

                
            }
            .navigationTitle("Поиск расписания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Показать") { onApply(criteria) }
                        .disabled(criteria.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// Создаёт строку перехода к универсальному выбору одного фильтра.
    private func optionRow(
        _ title: String,
        icon: String,
        selection: Binding<ScheduleOption?>,
        options: [ScheduleOption]
    ) -> some View {
        NavigationLink {
            OptionPickerView(title: title, options: options, selection: selection)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text(title)
                Spacer()
                Text(selection.wrappedValue?.name ?? "Не выбрано")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// Переиспользуемый список вариантов с локальным поиском по названию.
private struct OptionPickerView: View {
    let title: String
    let options: [ScheduleOption]
    @Binding var selection: ScheduleOption?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    /// Фильтрация выполняется локально, повторный сетевой запрос не требуется.
    private var filteredOptions: [ScheduleOption] {
        guard !searchText.isEmpty else { return options }
        return options.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if selection != nil {
                Button("Не выбрано") {
                    selection = nil
                    dismiss()
                }
                .foregroundStyle(.red)
            }

            ForEach(filteredOptions) { option in
                Button {
                    selection = option
                    dismiss()
                } label: {
                    HStack {
                        Text(option.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection == option {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Поиск")
    }
}
