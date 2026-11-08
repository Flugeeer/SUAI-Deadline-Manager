//
//  ContentView.swift
//  ContentView
//
//  Created by Vladislav Katashov on 06.11.2026.
//

import SwiftUI

/// Корневой экран приложения с основными разделами и логикой первого запуска.
struct ContentView: View {
    // Один экземпляр хранилища используется всеми экранами расписания.
    @StateObject private var scheduleStore = ScheduleStore()

    // Основная группа сохраняется в UserDefaults и восстанавливается после перезапуска.
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

            DeadlinesView()
                .tabItem {
                    Label("Дедлайны", systemImage: "checklist")
                }

            StudentAccountView()
                .tabItem {
                    Label("Личный кабинет", systemImage: "person.crop.circle")
                }
        }
        .tint(.blue)
        .task {
            // Сначала получаем актуальные идентификаторы групп с сайта ГУАП.
            await scheduleStore.loadCatalog()
            if primaryGroupID.isEmpty {
                showsOnboarding = true
            } else if let group = scheduleStore.option(id: primaryGroupID, in: scheduleStore.catalog.groups) {
                await scheduleStore.loadSchedule(for: ScheduleCriteria(group: group))
            } else {
                // Сохранённая группа могла исчезнуть после обновления расписания.
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

#Preview {
    ContentView()
}
