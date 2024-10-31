import SwiftUI

struct CalendarGridView: View {
    let date: Date
    @ObservedObject var store: CalorieStore
    let onDateTap: (Date) -> Void
    
    private func getDaysInMonth(month: Int, year: Int) -> [Date?] {
        let calendar = Calendar.current
        
        // Create date components for the first day of the month
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let firstDayOfMonth = calendar.date(from: components) else { return [] }
        
        // Get the weekday of the first day (1 = Sunday, 2 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Get the number of days in the month
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        let numberOfDays = range.count
        
        // Convert weekday to 0-based index (0 = Monday, 6 = Sunday)
        let firstWeekdayIndex = (firstWeekday + 5) % 7
        
        // Create array with leading nil values for proper alignment
        var days: [Date?] = Array(repeating: nil, count: firstWeekdayIndex)
        
        // Add actual dates
        for day in 1...numberOfDays {
            components.day = day
            if let date = calendar.date(from: components) {
                days.append(date)
            }
        }
        
        // Add trailing nil values to complete the grid
        let remainingCells = 42 - days.count // 6 rows × 7 days
        days.append(contentsOf: Array(repeating: nil, count: remainingCells))
        
        return days
    }
    
    var body: some View {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
            ForEach(["M", "Tu", "W", "Th", "F", "S", "Su"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(getDaysInMonth(month: month, year: year), id: \.self) { date in
                if let date = date {
                    DayView(
                        date: date,
                        store: store,
                        isSelected: calendar.isDate(date, inSameDayAs: self.date),
                        onTap: onDateTap
                    )
                } else {
                    Color.clear
                }
            }
        }
        .padding()
    }
}
