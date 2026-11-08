import SwiftUI

/// Нативное представление профиля, полученного после официальной авторизации ГУАП.
struct StudentAccountView: View {
    @State private var snapshot: StudentProfileSnapshot?
    @State private var browserMode: ProfileBrowserMode?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    if let snapshot {
                        profileHeader(snapshot)

                        ForEach(snapshot.sections) { section in
                            profileSection(section)
                        }

                        Button {
                            browserMode = .capture
                        } label: {
                            Label("Обновить данные", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            browserMode = .fullCabinet
                        } label: {
                            Label("Открыть полный кабинет", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        signedOutView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Профиль")
            .sheet(item: $browserMode) { mode in
                ProfileBrowserView(mode: mode) { newSnapshot in
                    snapshot = newSnapshot
                }
            }
        }
    }

    private var signedOutView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text("Профиль ГУАП")
                    .font(.title2.bold())
            }
            
            Button {
                browserMode = .capture
            } label: {
                Label("Загрузить профиль", systemImage: "person.badge.key")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func profileHeader(_ snapshot: StudentProfileSnapshot) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.displayName)
                    .font(.title3.bold())
                Label("Авторизация ГУАП", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Spacer()
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func profileSection(_ section: StudentProfileSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.headline)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

            if section.items.isEmpty {
                Text("На странице не найдено доступных полей.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    StudentAccountView()
}
