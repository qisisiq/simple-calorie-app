import SwiftUI
import CloudKit

class CalorieStore: ObservableObject {
    @Published var entries: [DayCalories] = []
    @AppStorage("calorieGoal") var calorieGoal: Int = 1200
    private let container = CKContainer.default().privateCloudDatabase
    
    init() {
        fetchEntries()
    }
    
    func getColor(for calories: Int) -> Color {
        let difference = calories - calorieGoal
        switch difference {
        case ..<0: return .gray
        case 0..<100: return .green
        case 100..<200: return .yellow
        case 200..<500: return .orange
        case 500..<1000: return .red
        default: return .black
        }
    }
    
    func saveEntry(_ entry: DayCalories) {
        if let index = entries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        syncToCloud(entry)
    }
    
    private func syncToCloud(_ entry: DayCalories) {
        let record = CKRecord(recordType: "DayCalories")
        record.setValue(entry.id.uuidString, forKey: "id")
        record.setValue(entry.date, forKey: "date")
        record.setValue(entry.calories, forKey: "calories")
        
        container.save(record) { record, error in
            if let error = error {
                print("Error saving to CloudKit: \(error)")
            }
        }
    }
    
    private func fetchEntries() {
        let query = CKQuery(recordType: "DayCalories", predicate: NSPredicate(value: true))
        
        container.perform(query, inZoneWith: nil) { [weak self] records, error in
            guard let records = records, error == nil else {
                print("Error fetching from CloudKit: \(error?.localizedDescription ?? "")")
                return
            }
            
            DispatchQueue.main.async {
                self?.entries = records.compactMap { record in
                    guard let idString = record["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let date = record["date"] as? Date,
                          let calories = record["calories"] as? Int
                    else { return nil }
                    
                    return DayCalories(id: id, date: date, calories: calories)
                }
            }
        }
    }
}
