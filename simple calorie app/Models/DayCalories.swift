import Foundation
import CloudKit

struct DayCalories: Identifiable, Codable {
    let id: UUID
    let date: Date
    var calories: Int
    
    init(id: UUID = UUID(), date: Date, calories: Int) {
        self.id = id
        self.date = date
        self.calories = calories
    }
}
