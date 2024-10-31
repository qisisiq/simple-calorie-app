//
//  MotivationalMessage.swift
//  simple calorie app
//
//  Created by luella on 10/31/24.
//

import SwiftUI
import CloudKit

struct MotivationalMessage: View {
    private let defaultMessages = [
        "wait until you're really hungry and then eat until you're really full",
        "stop thinking about food go do something else",
        "eating too many carbs will give you a yeast infection",
        "you can eat at a 40% calorie deficit and still maintain muscle mass if you eat 2.2g of protein per kg lean body mass",
        "eat soup",
        "take your supplements"
    ]
    
    @StateObject private var messageStore = MessageStore()
    @State private var currentMessageIndex = 0
    @State private var showingEditMessages = false
    @State private var newMessage = ""
    @State private var editingMessage: Message?
    
    private var allMessages: [String] {
        defaultMessages + messageStore.customMessages.map { $0.text }
    }
    
    var body: some View {
        VStack {
            Text(allMessages[currentMessageIndex])
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .onTapGesture {
                    withAnimation {
                        currentMessageIndex = (currentMessageIndex + 1) % allMessages.count
                    }
                }
                .onLongPressGesture {
                    showingEditMessages = true
                }
        }
        .sheet(isPresented: $showingEditMessages) {
            NavigationView {
                List {
                    Section("Default Messages") {
                        ForEach(defaultMessages, id: \.self) { message in
                            Text(message)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section("Custom Messages") {
                        ForEach(messageStore.customMessages) { message in
                            Text(message.text)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        messageStore.deleteMessage(message)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        editingMessage = message
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                        
                        HStack {
                            TextField("Add new message", text: $newMessage)
                            Button {
                                if !newMessage.isEmpty {
                                    messageStore.saveMessage(Message(text: newMessage))
                                    newMessage = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(newMessage.isEmpty)
                        }
                    }
                }
                .navigationTitle("Edit Messages")
                .navigationBarItems(trailing: Button("Done") {
                    showingEditMessages = false
                })
            }
            .presentationDetents([.large])
        }
        .sheet(item: $editingMessage) { message in
            NavigationView {
                Form {
                    TextField("Edit message", text: Binding(
                        get: { message.text },
                        set: { newValue in
                            if let index = messageStore.customMessages.firstIndex(where: { $0.id == message.id }) {
                                messageStore.updateMessage(at: index, with: newValue)
                            }
                        }
                    ))
                }
                .navigationTitle("Edit Message")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        editingMessage = nil
                    },
                    trailing: Button("Save") {
                        editingMessage = nil
                    }
                )
            }
            .presentationDetents([.medium])
        }
    }
}

class MessageStore: ObservableObject {
    @Published var customMessages: [Message] = []
    private let container: CKDatabase = {
        let container = CKContainer(identifier: "iCloud.com.luellasun.calorie-tracker")
        return container.privateCloudDatabase
    }()
    
    init() {
        loadFromLocalStorage()
        fetchMessages()
    }
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: "customMessages"),
           let decoded = try? JSONDecoder().decode([Message].self, from: data) {
            customMessages = decoded
        }
    }
    
    private func saveToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(customMessages) {
            UserDefaults.standard.set(encoded, forKey: "customMessages")
        }
    }
    
    func saveMessage(_ message: Message) {
        customMessages.append(message)
        saveToLocalStorage()
        
        let record = CKRecord(recordType: "Message", recordID: CKRecord.ID(recordName: message.id.uuidString))
        record.setValue(message.text, forKey: "text")
        
        container.save(record) { [weak self] _, error in
            if let error = error {
                print("Error saving message to CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteMessage(_ message: Message) {
        customMessages.removeAll { $0.id == message.id }
        saveToLocalStorage()
        
        let recordID = CKRecord.ID(recordName: message.id.uuidString)
        container.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("Error deleting message from CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    func updateMessage(at index: Int, with newText: String) {
        let message = customMessages[index]
        let updatedMessage = Message(id: message.id, text: newText)
        customMessages[index] = updatedMessage
        saveToLocalStorage()
        
        let record = CKRecord(recordType: "Message", recordID: CKRecord.ID(recordName: message.id.uuidString))
        record.setValue(newText, forKey: "text")
        
        container.save(record) { [weak self] _, error in
            if let error = error {
                print("Error updating message in CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchMessages() {
        let query = CKQuery(recordType: "Message", predicate: NSPredicate(value: true))
        
        container.perform(query, inZoneWith: nil) { [weak self] records, error in
            guard let records = records else { return }
            
            DispatchQueue.main.async {
                let messages = records.compactMap { record -> Message? in
                    guard let text = record["text"] as? String else { return nil }
                    return Message(id: UUID(uuidString: record.recordID.recordName) ?? UUID(), text: text)
                }
                self?.customMessages = messages
                self?.saveToLocalStorage()
            }
        }
    }
}
