import SwiftUI
import CloudKit

class CalorieStore: ObservableObject {
    @Published var entries: [DayCalories] = []
    @AppStorage("calorieGoal") var calorieGoal: Int = 1200
    private let container: CKDatabase = {
        let container = CKContainer(identifier: "iCloud.com.luellasun.calorie-tracker")
        return container.privateCloudDatabase
    }()
    
    init() {
        loadFromLocalStorage()
        fetchEntries()
    }
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: "savedEntries"),
           let decoded = try? JSONDecoder().decode([DayCalories].self, from: data) {
            entries = decoded
        }
    }
    
    private func saveToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "savedEntries")
        }
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
        
        saveToLocalStorage()
        
        let recordID = CKRecord.ID(recordName: entry.id.uuidString)
        let record = CKRecord(recordType: "DayCalories", recordID: recordID)
        record.setValue(entry.date, forKey: "date")
        record.setValue(entry.calories, forKey: "calories")
        
        container.save(record) { _, _ in }
    }
    
    private func fetchEntries() {
        let query = CKQuery(recordType: "DayCalories", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 100
        
        var fetchedEntries: [DayCalories] = []
        
        operation.recordMatchedBlock = { [weak self] recordID, result in
            switch result {
            case .success(let record):
                guard let date = record["date"] as? Date,
                      let calories = record["calories"] as? Int else {
                    return
                }
                
                let entry = DayCalories(
                    id: UUID(uuidString: recordID.recordName) ?? UUID(),
                    date: date,
                    calories: calories
                )
                fetchedEntries.append(entry)
                
            case .failure:
                break
            }
        }
        
        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.mergeEntries(cloudEntries: fetchedEntries)
                case .failure:
                    break
                }
            }
        }
        
        container.add(operation)
    }
    
    private func mergeEntries(cloudEntries: [DayCalories]) {
        var entriesByDate: [Date: DayCalories] = [:]
        for entry in entries {
            let calendar = Calendar.current
            if let date = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: entry.date)) {
                entriesByDate[date] = entry
            }
        }
        
        for cloudEntry in cloudEntries {
            let calendar = Calendar.current
            if let date = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: cloudEntry.date)) {
                entriesByDate[date] = cloudEntry
            }
        }
        
        entries = Array(entriesByDate.values)
        saveToLocalStorage()
    }
}
