import SwiftUI

struct ContentView: View {
    @StateObject private var store = CalorieStore()
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingCalorieInput = false
    @State private var showingGoalInput = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Button(action: { showingDatePicker = true }) {
                            Text(selectedDate, format: .dateTime.month(.wide).year())
                                .font(.title)
                                .foregroundColor(.primary)
                        }
                        
                        CalendarGridView(
                            date: selectedDate,
                            store: store,
                            onDateTap: { date in
                                selectedDate = date
                                showingCalorieInput = true
                            }
                        )
                        
                        HStack {
                            Text("Daily Calorie Goal:")
                            Button("\(store.calorieGoal)") {
                                showingGoalInput = true
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                
                MotivationalMessage()
                    .padding(.bottom, 8)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingDatePicker) {
                DatePicker(
                    "Select Month",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingCalorieInput) {
                CalorieInputView(
                    date: selectedDate,
                    store: store,
                    isPresented: $showingCalorieInput
                )
            }
            .sheet(isPresented: $showingGoalInput) {
                GoalInputView(
                    store: store,
                    isPresented: $showingGoalInput
                )
            }
        }
    }
}
