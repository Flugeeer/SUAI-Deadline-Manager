import SwiftUI
import WebKit

/// Открывает официальную страницу заданий и, после авторизации, преобразует
/// её содержимое в модели для нативной вкладки «Дедлайны».
struct DeadlineBrowserView: View {
    let mode: DeadlinesBrowserMode
    let onSnapshot: (DeadlinesSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let tasksURL = URL(string: "https://pro.guap.ru/inside/student/tasks/")!

    var body: some View {
        NavigationStack {
            ZStack {
                DeadlineWebView(
                    url: tasksURL,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                ) { snapshot in
                    onSnapshot(snapshot)
                    if mode == .capture {
                        dismiss()
                    }
                }

                if isLoading {
                    ProgressView("Загружаем задания…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                if let errorMessage {
                    VStack {
                        Spacer()
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .padding()
                    }
                }
            }
            .navigationTitle(mode == .capture ? "Вход в ГУАП" : "Задания ГУАП")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

private struct DeadlineWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onSnapshot: (DeadlinesSnapshot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // То же постоянное хранилище используется экраном профиля.
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: DeadlineWebView
        private var lastCapturedURL: URL?

        init(parent: DeadlineWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            parent.isLoading = true
            parent.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            parent.isLoading = false

            guard let url = webView.url,
                  url.host == "pro.guap.ru",
                  url.path.hasPrefix("/inside/student/tasks"),
                  url != lastCapturedURL else { return }

            lastCapturedURL = url
            // Некоторые элементы страницы могут добавляться клиентским JavaScript.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.extractDeadlines(from: webView)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            show(error: error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
            show(error: error)
        }

        /// Скрипт выполняется только на закрытой странице заданий, не на SSO.
        private func extractDeadlines(from webView: WKWebView) {
            webView.evaluateJavaScript(Self.deadlineExtractionScript) { [weak self] result, error in
                guard let self else { return }
                if let error {
                    self.parent.errorMessage = "Не удалось прочитать задания: \(error.localizedDescription)"
                    return
                }
                guard let json = result as? String,
                      let data = json.data(using: .utf8),
                      let snapshot = try? JSONDecoder().decode(DeadlinesSnapshot.self, from: data) else {
                    self.parent.errorMessage = "Страница открыта, но список заданий не распознан."
                    return
                }
                self.parent.onSnapshot(snapshot)
            }
        }

        private func show(error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            parent.isLoading = false
            parent.errorMessage = "Не удалось открыть задания. Проверьте подключение к интернету."
        }

        private static let deadlineExtractionScript = #"""
        (() => {
            const root = document.querySelector('main') || document.body;
            const clean = value => (value || '').replace(/\s+/g, ' ').trim();
            const key = value => clean(value).toLowerCase();
            const items = [];
            const seen = new Set();

            const findValue = (record, words) => {
                for (const [label, value] of Object.entries(record)) {
                    if (words.some(word => key(label).includes(word))) return clean(value);
                }
                return '';
            };

            const add = ({ title, subject = '', dueDate = '', status = '', details = '', sourceURL = '' }) => {
                title = clean(title);
                if (!title || title.length > 500) return;
                const identity = `${title}|${clean(subject)}|${clean(dueDate)}`;
                if (seen.has(identity)) return;
                seen.add(identity);
                items.push({
                    id: identity,
                    title,
                    subject: clean(subject) || null,
                    dueDate: clean(dueDate) || null,
                    status: clean(status) || null,
                    details: clean(details) || null,
                    sourceURL: sourceURL || null
                });
            };

            // Основной вариант: серверная таблица со строкой заголовков.
            root.querySelectorAll('table').forEach(table => {
                const headers = [...table.querySelectorAll('thead th')].map(cell => clean(cell.textContent));
                const rows = table.querySelectorAll('tbody tr').length
                    ? table.querySelectorAll('tbody tr')
                    : table.querySelectorAll('tr');

                rows.forEach((row, rowIndex) => {
                    const cells = [...row.querySelectorAll(':scope > th, :scope > td')];
                    if (cells.length < 2 || (!headers.length && rowIndex === 0 && cells.every(cell => cell.tagName === 'TH'))) return;
                    const record = {};
                    cells.forEach((cell, index) => {
                        record[headers[index] || `Поле ${index + 1}`] = clean(cell.textContent);
                    });
                    const title = findValue(record, ['задани', 'работ', 'назван', 'тема']) || clean(cells[0].textContent);
                    const subject = findValue(record, ['дисцип', 'предмет', 'курс']);
                    const dueDate = findValue(record, ['срок', 'дата сда', 'до ']);
                    const status = findValue(record, ['статус', 'сдан', 'выполн']);
                    const ignored = new Set([title, subject, dueDate, status].filter(Boolean));
                    const details = Object.entries(record)
                        .filter(([, value]) => value && !ignored.has(value))
                        .map(([label, value]) => `${label}: ${value}`)
                        .join(' · ');
                    const link = row.querySelector('a[href]')?.href || '';
                    add({ title, subject, dueDate, status, details, sourceURL: link });
                });
            });

            // Запасной вариант для карточной или списочной разметки.
            if (items.length === 0) {
                const blocks = [...root.querySelectorAll('.card, .list-group-item, article')]
                    .filter(block => !block.parentElement?.closest('.card, .list-group-item, article'));
                blocks.forEach(block => {
                    const title = clean(block.querySelector('h1, h2, h3, h4, h5, h6, .card-title, a[href]')?.textContent);
                    const lines = clean(block.innerText).split(/\n+/).map(clean).filter(Boolean);
                    const dueDate = lines.find(line => /(срок|до |дата).*\d{1,2}[.\/-]\d{1,2}/i.test(line)) ||
                        lines.find(line => /\d{1,2}[.\/-]\d{1,2}[.\/-]\d{2,4}/.test(line)) || '';
                    const subject = lines.find(line => /(дисциплина|предмет|курс)\s*:/i.test(line)) || '';
                    const status = lines.find(line => /(статус|сдано|выполнено|просрочено)/i.test(line)) || '';
                    const details = lines.filter(line => ![title, dueDate, subject, status].includes(line)).slice(0, 6).join(' · ');
                    add({ title, subject, dueDate, status, details, sourceURL: block.querySelector('a[href]')?.href || '' });
                });
            }

            // Последний вариант: ссылки на отдельные задания.
            if (items.length === 0) {
                root.querySelectorAll('a[href*="task"]').forEach(link => {
                    const container = link.closest('tr, li, .row, div') || link;
                    add({ title: link.textContent, details: container.textContent, sourceURL: link.href });
                });
            }

            const pageTitle = clean(root.querySelector('h1, h2')?.textContent) || 'Дедлайны ГУАП';
            return JSON.stringify({ pageTitle, items });
        })();
        """#
    }
}
