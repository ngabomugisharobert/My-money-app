//
//  My_MoneyApp.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

@main
struct My_MoneyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
