import SwiftUI

struct ContentView: View {
    @StateObject private var scheduleStore = ScheduleStore()
    @AppStorage("primaryGroupID") private var primaryGroupID = ""
    @AppStorage("primaryGroupName") private var primaryGroupName = ""
    @State private var showsOnboarding = false

    var body: some View {
        TabView {
            ScheduleView(
                store: scheduleStore,
                primaryGroupID: primaryGroupID,
                primaryGroupName: primaryGroupName
            )
                .tabItem {
                    Label("Расписание", systemImage: "calendar")
                }

            DeadlinesPlaceholderView()
                .tabItem {
                    Label("Дедлайны", systemImage: "checklist")
                }
        }
        .tint(.indigo)
        .task {
            await scheduleStore.loadCatalog()
            if primaryGroupID.isEmpty {
                showsOnboarding = true
            } else if let group = scheduleStore.option(id: primaryGroupID, in: scheduleStore.catalog.groups) {
                await scheduleStore.loadSchedule(for: ScheduleCriteria(group: group))
            } else {
                primaryGroupID = ""
                primaryGroupName = ""
                showsOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            GroupOnboardingView(store: scheduleStore) { group in
                primaryGroupID = group.id
                primaryGroupName = group.name
                showsOnboarding = false
                Task {
                    await scheduleStore.loadSchedule(for: ScheduleCriteria(group: group))
                }
            }
            .interactiveDismissDisabled()
        }
    }
}

private struct DeadlinesPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Дедлайны появятся здесь", systemImage: "checkmark.circle")
            } description: {
                Text("На следующем этапе сюда можно добавить лабораторные работы, сроки сдачи и напоминания.")
            }
            .navigationTitle("Дедлайны")
        }
    }
}

#Preview {
    ContentView()
}
