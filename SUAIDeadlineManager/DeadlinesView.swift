import SwiftUI

/// Нативный список заданий из личного кабинета ГУАП.
struct DeadlinesView: View {
    @StateObject private var store = DeadlinesStore()
    @State private var browserMode: DeadlinesBrowserMode?

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .idle:
                    signInView
                case .loading:
                    ProgressView("Ожидаем данные личного кабинета…")
                case .failed(let message):
                    errorView(message)
                case .loaded:
                    store.items.isEmpty ? AnyView(emptyView) : AnyView(deadlinesList)
                }
            }
            .navigationTitle("Дедлайны")
            .toolbar {
                if store.state == .loaded {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            open(.capture)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Обновить дедлайны")

                        Button {
                            open(.fullPage)
                        } label: {
                            Image(systemName: "safari")
                        }
                        .accessibilityLabel("Открыть страницу заданий")
                    }
                }
            }
            .sheet(item: $browserMode, onDismiss: {
                if store.state == .loading {
                    store.finishPresentationWithoutResult()
                }
            }) { mode in
                DeadlineBrowserView(mode: mode) { snapshot in
                    store.apply(snapshot)
                }
            }
        }
    }

    private var signInView: some View {
        ContentUnavailableView {
            Label("Задания ГУАП", systemImage: "checklist")
        } description: {
            Text("Войдите через официальный личный кабинет, чтобы загрузить дедлайны.")
        } actions: {
            Button("Войти и загрузить") {
                open(.capture)
            }
            .buttonStyle(.borderedProminent)

            Button("Открыть страницу полностью") {
                open(.fullPage)
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Заданий не найдено", systemImage: "checkmark.circle")
        } description: {
            Text("Страница загрузилась, но доступных заданий сейчас нет.")
        } actions: {
            Button("Обновить") { open(.capture) }
                .buttonStyle(.borderedProminent)
            Button("Проверить на сайте") { open(.fullPage) }
                .buttonStyle(.bordered)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Не удалось загрузить дедлайны", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Повторить") { open(.capture) }
                .buttonStyle(.borderedProminent)
        }
    }

    private var deadlinesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(store.pageTitle)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(store.items) { item in
                    DeadlineCard(item: item)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func open(_ mode: DeadlinesBrowserMode) {
        store.beginLoading()
        browserMode = mode
    }
}

private struct DeadlineCard: View {
    let item: DeadlineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(item.title)
                    .font(.headline)
                Spacer(minLength: 8)
                if let status = item.status {
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.indigo)
                        .background(.indigo.opacity(0.1), in: Capsule())
                }
            }

            if let subject = item.subject {
                Label(subject, systemImage: "book.closed")
            }
            if let dueDate = item.dueDate {
                Label(dueDate, systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.red)
            }
            if let details = item.details, !details.isEmpty {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let source = item.sourceURL, let url = URL(string: source) {
                Link(destination: url) {
                    Label("Открыть задание", systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    DeadlinesView()
}
