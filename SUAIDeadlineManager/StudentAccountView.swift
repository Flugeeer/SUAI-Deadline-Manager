//
//  StudentAccountView.swift
//  StudentAccountView
//
//  Created by Vladislav Katashov on 06.11.2026.
//


import SafariServices
import SwiftUI

struct StudentAccountView: View {
    private let accountURL = URL(string: "https://pro.guap.ru/inside/profile")!

    @State private var showsAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Личный кабинет ГУАП")
                            .font(.title2.bold())
                    }

                    Button {
                        showsAccount = true
                    } label: {
                        Label("Открыть личный кабинет", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
            }
            .navigationTitle("Личный кабинет")
            .sheet(isPresented: $showsAccount) {
                SafariView(url: accountURL)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = .systemIndigo
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    StudentAccountView()
}
