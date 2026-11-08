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
    @State private var selectedDayName = Self.currentDayName
    @State private var showsOutsideGrid = false

    private static let weekdayNames = [
        "Понедельник", "Вторник", "Среда", "Четверг",
        "Пятница", "Суббота", "Воскресенье"
    ]

    private static let weekdayShort = [
        "Понедельник": "Пн", "Вторник": "Вт", "Среда": "Ср",
        "Четверг": "Чт", "Пятница": "Пт", "Суббота": "Сб",
        "Воскресенье": "Вс"
    ]
    

    /// Название сегодняшнего дня в том же формате, который использует сайт ГУАП.
    private static var currentDayName: String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let indexByCalendarWeekday = [6, 0, 1, 2, 3, 4, 5]
        return weekdayNames[indexByCalendarWeekday[weekday - 1]]
    }

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
                weekHeader
                daySelector
                selectedDaySection

                if let outsideGrid = store.days.first(where: { $0.name == "Вне сетки расписания" }) {
                    DisclosureGroup("Вне сетки расписания", isExpanded: $showsOutsideGrid) {
                        VStack(spacing: 10) {
                            ForEach(outsideGrid.lessons) { lesson in
                                LessonCard(lesson: lesson)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .tint(.orange)
                    .font(.headline)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    /// Показывает номер и тип недели, полученные вместе с расписанием.
    private var weekHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.blue)
            Text(store.weekContext.number.map { "\($0) неделя" } ?? "Текущая неделя")
                .fontWeight(.semibold)
            Spacer()
            if let week = store.weekContext.week {
                Text(week == .upper ? "▲ верхняя" : "▼ нижняя")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(week == .upper ? .red : .blue)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Горизонтальный переключатель дней; при открытии выбран сегодняшний день.
    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.weekdayNames, id: \.self) { dayName in
                    Button {
                        selectedDayName = dayName
                    } label: {
                        VStack(spacing: 3) {
                            Text(Self.weekdayShort[dayName] ?? dayName)
                                .font(.headline)
                            if dayName == Self.currentDayName {
                                Circle()
                                    .fill(selectedDayName == dayName ? .white : .blue)
                                    .frame(width: 4, height: 4)
                            } else {
                                Color.clear.frame(width: 4, height: 4)
                            }
                        }
                        .frame(width: 42, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedDayName == dayName ? .white : .primary)
                    .background(
                        selectedDayName == dayName ? Color.blue : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityLabel(dayName)
                }
            }
        }
    }

    /// Занятия выбранного дня, подходящие для текущей верхней или нижней недели.
    @ViewBuilder
    private var selectedDaySection: some View {
        let lessons = lessonsForSelectedDay
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDayName)
                .font(.title2.bold())

            if lessons.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сегодня занятий нет!")
                            .fontWeight(.semibold)
                        Text("Можно спать спокойно!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(lessons) { lesson in
                    LessonCard(lesson: lesson)
                }
            }
        }
    }

    private var lessonsForSelectedDay: [ScheduleLesson] {
        guard let day = store.days.first(where: { $0.name == selectedDayName }) else { return [] }
        guard let currentWeek = store.weekContext.week else { return day.lessons }
        return day.lessons.filter { $0.week == .every || $0.week == currentWeek }
    }

    /// Кратко показывает, по каким параметрам сейчас загружено расписание.
    private var filterHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
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
                        .foregroundStyle(.blue)
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
