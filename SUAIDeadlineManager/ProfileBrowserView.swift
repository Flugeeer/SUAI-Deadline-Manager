import SwiftUI
import WebKit

/// Экран официальной авторизации. JavaScript запускается только после перехода
/// с SSO обратно на закрытую страницу `pro.guap.ru/inside/...`.
struct ProfileBrowserView: View {
    let mode: ProfileBrowserMode
    let onSnapshot: (StudentProfileSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let profileURL = URL(string: "https://pro.guap.ru/inside/profile")!

    var body: some View {
        NavigationStack {
            ZStack {
                ProfileWebView(
                    url: profileURL,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                ) { snapshot in
                    onSnapshot(snapshot)
                    if mode == .capture {
                        dismiss()
                    }
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
            .navigationTitle(mode == .capture ? "Вход в ГУАП" : "Личный кабинет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

private struct ProfileWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onSnapshot: (StudentProfileSnapshot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Постоянное хранилище позволяет не входить заново при каждом открытии.
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
        var parent: ProfileWebView
        private var lastCapturedURL: URL?

        init(parent: ProfileWebView) {
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
                  url.path.hasPrefix("/inside/profile"),
                  url != lastCapturedURL else { return }

            lastCapturedURL = url
            extractProfile(from: webView)
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

        /// Собирает только видимые поля закрытой страницы профиля. Скрипт не
        /// выполняется на странице SSO и не обращается к полям логина или пароля.
        private func extractProfile(from webView: WKWebView) {
            webView.evaluateJavaScript(Self.profileExtractionScript) { [weak self] result, error in
                guard let self else { return }
                if let error {
                    self.parent.errorMessage = "Не удалось преобразовать профиль: \(error.localizedDescription)"
                    return
                }
                guard let json = result as? String,
                      let data = json.data(using: .utf8),
                      let snapshot = try? JSONDecoder().decode(StudentProfileSnapshot.self, from: data) else {
                    self.parent.errorMessage = "Страница открыта, но данные профиля не распознаны."
                    return
                }
                self.parent.onSnapshot(snapshot)
            }
        }

        private func show(error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            parent.isLoading = false
            parent.errorMessage = "Не удалось открыть личный кабинет. Проверьте интернет."
        }

        private static let profileExtractionScript = #"""
        (() => {
            const root = document.querySelector('main') || document.body;
            const clean = value => (value || '').replace(/\s+/g, ' ').trim();
            const candidates = [
                '[data-profile-name]', '.profile-name', '.user-name',
                'main h1', 'main h2', 'h1', 'h2'
            ];
            let displayName = 'Студент ГУАП';
            for (const selector of candidates) {
                const value = clean(root.querySelector(selector)?.textContent);
                if (value && value.length < 150) {
                    displayName = value;
                    break;
                }
            }

            const items = [];
            const seen = new Set();
            const add = (label, value) => {
                label = clean(label).replace(/:$/, '');
                value = clean(value);
                if (!label || !value || label === value || value.length > 500) return;
                const key = `${label}|${value}`;
                if (seen.has(key)) return;
                seen.add(key);
                items.push({ label, value });
            };

            root.querySelectorAll('table tr').forEach(row => {
                const cells = [...row.querySelectorAll(':scope > th, :scope > td')];
                if (cells.length >= 2) add(cells[0].textContent, cells.slice(1).map(x => x.textContent).join(' '));
            });

            root.querySelectorAll('dl').forEach(list => {
                list.querySelectorAll('dt').forEach(term => {
                    const description = term.nextElementSibling;
                    if (description?.tagName === 'DD') add(term.textContent, description.textContent);
                });
            });

            root.querySelectorAll('label').forEach(label => {
                const container = label.closest('.form-group, .mb-3, .row') || label.parentElement;
                const control = container?.querySelector('input:not([type="password"]), select, textarea, .form-control-plaintext');
                const value = control?.value || control?.textContent;
                add(label.textContent, value);
            });

            if (items.length === 0) {
                const lines = [...root.querySelectorAll('p, main li')]
                    .map(element => clean(element.textContent))
                    .filter((line, index, array) => line.length > 2 && line.length < 300 && array.indexOf(line) === index)
                    .slice(0, 30);
                lines.forEach((line, index) => add(`Информация ${index + 1}`, line));
            }

            const nameItem = items.find(item => /^(фио|фамилия.*имя|имя)$/i.test(item.label));
            if (nameItem) displayName = nameItem.value;
            if (/^(профиль|личный кабинет)$/i.test(displayName)) displayName = 'Студент ГУАП';

            return JSON.stringify({
                displayName,
                sections: [{ title: 'Данные профиля', items }]
            });
        })();
        """#
    }
}
