//
//  GoalInputView.swift
//  simple calorie app
//
//  Created by luella on 10/30/24.
//

import SwiftUI

struct GoalInputView: View {
    @ObservedObject var store: CalorieStore
    @Binding var isPresented: Bool
    @State private var goalInput = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Daily Calorie Goal", text: $goalInput)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Set Calorie Goal")
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") {
                    if let goal = Int(goalInput) {
                        store.calorieGoal = goal
                    }
                    isPresented = false
                }
            )
            .onAppear {
                goalInput = "\(store.calorieGoal)"
            }
        }
    }
}
