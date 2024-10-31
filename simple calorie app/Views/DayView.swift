import SwiftUI

struct DayView: View {
    let date: Date
    @ObservedObject var store: CalorieStore
    let isSelected: Bool
    let onTap: (Date) -> Void
    
    var body: some View {
        let calories = store.entries.first {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }?.calories ?? 0
        
        let isToday = Calendar.current.isDateInToday(date)
        
        Button(action: { onTap(date) }) {
            Text(calories > 0 ? "\(calories)" : "\(Calendar.current.component(.day, from: date))")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(store.getColor(for: calories))
                .foregroundColor(calories > 1000 ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isToday ? Color.blue : (isSelected ? Color.black : Color.clear), 
                               lineWidth: isToday ? 3 : 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
