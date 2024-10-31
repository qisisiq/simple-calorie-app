import SwiftUI

struct CalorieInputView: View {
    let date: Date
    @ObservedObject var store: CalorieStore
    @Binding var isPresented: Bool
    @State private var calorieInput = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Calories", text: $calorieInput)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Enter Calories")
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") {
                    if let calories = Int(calorieInput) {
                        store.saveEntry(DayCalories(date: date, calories: calories))
                    }
                    isPresented = false
                }
            )
            .onAppear {
                // Set initial value if exists
                if let existingEntry = store.entries.first(where: { 
                    Calendar.current.isDate($0.date, inSameDayAs: date) 
                }) {
                    calorieInput = "\(existingEntry.calories)"
                }
            }
        }
    }
}
