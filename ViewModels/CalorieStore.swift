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
        print("CalorieStore: Initializing and fetching entries")
        // Load from local storage first
        loadFromLocalStorage()
        // Then try to fetch from CloudKit
        fetchEntries()
    }
    
    // Local storage functions
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: "savedEntries"),
           let decoded = try? JSONDecoder().decode([DayCalories].self, from: data) {
            entries = decoded
            print("CalorieStore: Loaded \(entries.count) entries from local storage")
        }
    }
    
    private func saveToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "savedEntries")
            print("CalorieStore: Saved entries to local storage")
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
        print("CalorieStore: Saving entry for date \(entry.date) with calories \(entry.calories)")
        
        // Update local storage
        if let index = entries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }) {
            entries[index] = entry
            print("CalorieStore: Updated existing entry")
        } else {
            entries.append(entry)
            print("CalorieStore: Added new entry")
        }
        
        // Save to UserDefaults
        saveToLocalStorage()
        
        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: entry.id.uuidString)
        let record = CKRecord(recordType: "DayCalories", recordID: recordID)
        record.setValue(entry.date, forKey: "date")
        record.setValue(entry.calories, forKey: "calories")
        
        // Try to save to CloudKit
        container.save(record) { [weak self] record, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CalorieStore: Error saving to CloudKit: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        print("CalorieStore: CloudKit error code: \(ckError.errorCode)")
                    }
                } else {
                    print("CalorieStore: Successfully saved to CloudKit")
                }
            }
        }
    }
    
    private func fetchEntries() {
        print("CalorieStore: Starting to fetch entries from CloudKit")
        
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
                    print("CalorieStore: Failed to parse record data")
                    return
                }
                
                let entry = DayCalories(
                    id: UUID(uuidString: recordID.recordName) ?? UUID(),
                    date: date,
                    calories: calories
                )
                fetchedEntries.append(entry)
                print("CalorieStore: Found entry for date \(date) with calories \(calories)")
                
            case .failure(let error):
                print("CalorieStore: Error fetching record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("CalorieStore: Successfully fetched \(fetchedEntries.count) entries from CloudKit")
                    // Merge CloudKit entries with local entries
                    self?.mergeEntries(cloudEntries: fetchedEntries)
                case .failure(let error):
                    print("CalorieStore: Error fetching entries: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        print("CalorieStore: CloudKit error code: \(ckError.errorCode)")
                    }
                }
            }
        }
        
        container.add(operation)
    }
    
    private func mergeEntries(cloudEntries: [DayCalories]) {
        // Create a dictionary of existing entries by date
        var entriesByDate: [Date: DayCalories] = [:]
        for entry in entries {
            let calendar = Calendar.current
            if let date = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: entry.date)) {
                entriesByDate[date] = entry
            }
        }
        
        // Merge cloud entries
        for cloudEntry in cloudEntries {
            let calendar = Calendar.current
            if let date = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: cloudEntry.date)) {
                entriesByDate[date] = cloudEntry
            }
        }
        
        // Convert back to array
        entries = Array(entriesByDate.values)
        
        // Save merged entries to local storage
        saveToLocalStorage()
    }
}
