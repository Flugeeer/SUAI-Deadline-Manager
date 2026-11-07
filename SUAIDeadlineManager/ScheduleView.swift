//
//  ScheduleView.swift
//  ScheduleView
//
//  Created by Vladislav Katashov on 06.11.2026.
//


import SwiftUI

/// Основной экран нативного расписания с обработкой загрузки, ошибок и пустого результата.
struct ScheduleView: View {
    @ObservedObject var store: ScheduleStore
    let primaryGroupID: String
    let primaryGroupName: String

    @State private var showsSearch = false

    var body: some View {
        NavigationStack {
            Group {
                switch store.scheduleState {
                case .idle, .loading:
                    loadingView
                case .failed(let message):
                    errorView(message)
                case .loaded:
                    if store.days.isEmpty {
                        emptyView
                    } else {
                        scheduleList
                    }
                }
            }
            .navigationTitle("Расписание")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        loadPrimaryGroup()
                    } label: {
                        Label(primaryGroupName.isEmpty ? "Моя группа" : primaryGroupName, systemImage: "house")
                    }
                    .disabled(primaryGroupID.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSearch = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Другой поиск")
                }
            }
            .sheet(isPresented: $showsSearch) {
                ScheduleSearchView(store: store) { criteria in
                    showsSearch = false
                    Task { await store.loadSchedule(for: criteria) }
                }
            }
            .refreshable {
                if !store.currentCriteria.isEmpty {
                    await store.loadSchedule(for: store.currentCriteria)
                }
            }
        }
    }

    /// Список дней и карточек занятий для текущего набора фильтров.
    private var scheduleList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                filterHeader

                ForEach(store.days) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(day.name)
                            .font(.title2.bold())
                            .foregroundStyle(day.name == "Вне сетки расписания" ? .orange : .primary)

                        ForEach(day.lessons) { lesson in
                            LessonCard(lesson: lesson)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    /// Кратко показывает, по каким параметрам сейчас загружено расписание.
    private var filterHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Сейчас показано")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(store.currentCriteria.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            Spacer()
            Button("Изменить") { showsSearch = true }
                .font(.subheadline)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Загружаем расписание…")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Расписание недоступно", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Повторить") {
                Task { await store.loadSchedule(for: store.currentCriteria) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Занятий не найдено", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Попробуйте изменить параметры поиска.")
        } actions: {
            Button("Изменить поиск") { showsSearch = true }
                .buttonStyle(.borderedProminent)
        }
    }

    /// Возвращает пользователя к группе, выбранной при первом запуске.
    private func loadPrimaryGroup() {
        guard let group = store.option(id: primaryGroupID, in: store.catalog.groups) else { return }
        Task { await store.loadSchedule(for: ScheduleCriteria(group: group)) }
    }
}

/// Карточка одного занятия с номером пары, временем, аудиторией и преподавателем.
private struct LessonCard: View {
    let lesson: ScheduleLesson

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 3) {
                Text(lesson.pairNumber ?? "—")
                    .font(.title2.bold())
                Text("пара")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let time = lesson.time {
                    Text(time.replacingOccurrences(of: "—", with: "\n"))
                        .font(.caption2.monospacedDigit())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(lesson.kind)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Spacer()
                    if lesson.week != .every {
                        Text(lesson.week == .upper ? "▲ верхняя" : "▼ нижняя")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(lesson.week == .upper ? .red : .blue)
                    }
                }

                Text(lesson.subject)
                    .font(.body.weight(.semibold))

                if let room = lesson.room {
                    Label(room, systemImage: "door.left.hand.open")
                }
                if let teacher = lesson.teacher {
                    Label(teacher, systemImage: "person")
                }
                if !lesson.groups.isEmpty {
                    Label(lesson.groups.joined(separator: ", "), systemImage: "person.3")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
