//
//  MotivationalMessage.swift
//  simple calorie app
//
//  Created by luella on 10/31/24.
//

import SwiftUI
import CloudKit

struct MotivationalMessage: View {
    @StateObject private var messageStore = MessageStore()
    @State private var currentMessageIndex = 0
    @State private var showingEditMessages = false
    @State private var newMessage = ""
    @State private var editingMessageText: [UUID: String] = [:]  // Track editing state per message
    @AppStorage("com.luellasun.calorie-tracker.hasLaunchedBefore") private var hasLaunchedBefore = false
    
    var body: some View {
        VStack {
            Text(messageStore.messages.isEmpty ? "Press here to add a motivational message" : messageStore.messages[currentMessageIndex].text)
                .font(.caption)
                .foregroundColor(messageStore.messages.isEmpty ? .clear : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !messageStore.messages.isEmpty {
                        withAnimation {
                            currentMessageIndex = (currentMessageIndex + 1) % messageStore.messages.count
                        }
                    }
                }
                .onLongPressGesture {
                    showingEditMessages = true
                }
        }
        .sheet(isPresented: $showingEditMessages) {
            NavigationView {
                List {
                    Section("Messages") {
                        ForEach(messageStore.messages) { message in
                            if let editingText = editingMessageText[message.id] {
                                // Editing mode
                                HStack {
                                    TextField("Message", text: Binding(
                                        get: { editingText },
                                        set: { editingMessageText[message.id] = $0 }
                                    ))
                                    
                                    Button("Save") {
                                        if let index = messageStore.messages.firstIndex(where: { $0.id == message.id }) {
                                            messageStore.updateMessage(at: index, with: editingText)
                                            editingMessageText.removeValue(forKey: message.id)
                                        }
                                    }
                                    
                                    Button("Cancel") {
                                        editingMessageText.removeValue(forKey: message.id)
                                    }
                                }
                            } else {
                                // Display mode
                                Text(message.text)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            messageStore.deleteMessage(message)
                                            if currentMessageIndex >= messageStore.messages.count {
                                                currentMessageIndex = max(0, messageStore.messages.count - 1)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            editingMessageText[message.id] = message.text
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .onTapGesture {
                                        editingMessageText[message.id] = message.text
                                    }
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
        .onAppear {
            if !hasLaunchedBefore {
                let defaultMessages = [
                    "wait until you're really hungry and then eat until you're really full",
                    "stop thinking about food go do something else",
                    "eating too many carbs will give you a yeast infection",
                    "you can eat at a 40% calorie deficit and still maintain muscle mass if you eat 2.2g of protein per kg lean body mass",
                    "eat soup",
                    "take your supplements"
                ]
                for message in defaultMessages {
                    messageStore.saveMessage(Message(text: message))
                }
                hasLaunchedBefore = true
            }
        }
    }
}

class MessageStore: ObservableObject {
    @Published var messages: [Message] = []
    private let container: CKDatabase = {
        let container = CKContainer(identifier: "iCloud.com.luellasun.calorie-tracker")
        return container.privateCloudDatabase
    }()
    
    init() {
        loadFromLocalStorage()  // Load local data first
        fetchMessages()         // Then fetch from CloudKit
    }
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: "messages"),
           let decoded = try? JSONDecoder().decode([Message].self, from: data) {
            DispatchQueue.main.async {
                self.messages = decoded
            }
        }
    }
    
    private func saveToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: "messages")
            UserDefaults.standard.synchronize()  // Force synchronization
        }
    }
    
    func saveMessage(_ message: Message) {
        DispatchQueue.main.async {
            self.messages.append(message)
            self.saveToLocalStorage()
        }
        
        let record = CKRecord(recordType: "Message", recordID: CKRecord.ID(recordName: message.id.uuidString))
        record.setValue(message.text, forKey: "text")
        
        container.save(record) { [weak self] record, error in
            if let error = error {
                print("Error saving to CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteMessage(_ message: Message) {
        DispatchQueue.main.async {
            self.messages.removeAll { $0.id == message.id }
            self.saveToLocalStorage()
        }
        
        let recordID = CKRecord.ID(recordName: message.id.uuidString)
        container.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("Error deleting from CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    func updateMessage(at index: Int, with newText: String) {
        let message = messages[index]
        let updatedMessage = Message(id: message.id, text: newText)
        
        DispatchQueue.main.async {
            self.messages[index] = updatedMessage
            self.saveToLocalStorage()
        }
        
        let record = CKRecord(recordType: "Message", recordID: CKRecord.ID(recordName: message.id.uuidString))
        record.setValue(newText, forKey: "text")
        
        container.save(record) { [weak self] record, error in
            if let error = error {
                print("Error updating in CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchMessages() {
        let query = CKQuery(recordType: "Message", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "text", ascending: true)]
        
        container.perform(query, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                print("Error fetching from CloudKit: \(error.localizedDescription)")
                return
            }
            
            guard let records = records else { return }
            
            DispatchQueue.main.async {
                let messages = records.compactMap { record -> Message? in
                    guard let text = record["text"] as? String else { return nil }
                    return Message(id: UUID(uuidString: record.recordID.recordName) ?? UUID(), text: text)
                }
                
                self?.messages = messages
                self?.saveToLocalStorage()
            }
        }
    }
}
