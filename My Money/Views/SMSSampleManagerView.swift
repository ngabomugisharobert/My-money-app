//
//  SMSSampleManagerView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData
import UIKit

struct SMSSampleManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    
    @StateObject private var smsService: SMSTransactionService
    @State private var samples: [SMSSample] = []
    @State private var showingAddSample = false
    @State private var selectedSample: SMSSample?
    @State private var showingTestResult = false
    @State private var testResult: ParsedTransaction?
    
    init(context: NSManagedObjectContext) {
        _smsService = StateObject(wrappedValue: SMSTransactionService(context: context))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showingAddSample = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Sample SMS")
                        }
                    }
                } header: {
                    Text("Actions")
                }
                
                if samples.isEmpty {
                    Section {
                        Text("No SMS samples yet. Add one to test parsing.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } else {
                    Section("SMS Samples (\(samples.count))") {
                        ForEach(samples) { sample in
                            SMSampleRow(
                                sample: sample,
                                smsService: smsService,
                                onTap: { testSample(sample) },
                                onEdit: { selectedSample = sample },
                                onDelete: { deleteSample(sample) }
                            )
                        }
                    }
                }
                
                Section("Default Samples") {
                    Button(action: { addDefaultSamples() }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Load Default Samples")
                        }
                    }
                }
            }
            .navigationTitle("SMS Samples")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSamples()
                smsService.setUserId(sessionViewModel.userId)
            }
            .sheet(isPresented: $showingAddSample, onDismiss: {
                // Reload samples when sheet dismisses to ensure sync
                loadSamples()
            }) {
                AddSMSSampleView(samples: $samples)
            }
            .sheet(item: $selectedSample) { sample in
                EditSMSSampleView(sample: sample, samples: $samples)
            }
            .sheet(isPresented: $showingTestResult) {
                if let result = testResult {
                    SMSTestResultView(parsedTransaction: result, smsService: smsService, userId: sessionViewModel.userId)
                }
            }
        }
    }
    
    private func loadSamples() {
        if let data = UserDefaults.standard.data(forKey: "smsSamples"),
           let decoded = try? JSONDecoder().decode([SMSSample].self, from: data) {
            samples = decoded
        }
    }
    
    private func saveSamples() {
        if let encoded = try? JSONEncoder().encode(samples) {
            UserDefaults.standard.set(encoded, forKey: "smsSamples")
        }
    }
    
    private func testSample(_ sample: SMSSample) {
        if let parsed = smsService.parseTransactionFromSMS(sample.content) {
            testResult = parsed
            showingTestResult = true
        }
    }
    
    private func deleteSample(_ sample: SMSSample) {
        samples.removeAll { $0.id == sample.id }
        saveSamples()
    }
    
    private func addDefaultSamples() {
        let defaultSamples = [
            SMSSample(
                title: "Chase Expense",
                content: "Chase Freedom Unlimited Visa: You made a $18.48 transaction with FRED-MEYER #0186 on Nov 13, 2025 at 8:26 PM ET.",
                createdAt: Date()
            ),
            SMSSample(
                title: "Zelle Income",
                content: "Chase | Zelle(R): PAUL WANGECHI sent you $49.95 & it's ready now. Reply STOP to cancel these texts.",
                createdAt: Date()
            ),
            SMSSample(
                title: "Generic Expense",
                content: "You spent $25.99 at STARBUCKS on Dec 1, 2025",
                createdAt: Date()
            )
        ]
        
        // Only add if not already present
        for defaultSample in defaultSamples {
            if !samples.contains(where: { $0.content == defaultSample.content }) {
                samples.append(defaultSample)
            }
        }
        
        saveSamples()
    }
}

// MARK: - SMS Sample Model
struct SMSSample: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    let createdAt: Date
    
    init(id: UUID = UUID(), title: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }
    
    static func == (lhs: SMSSample, rhs: SMSSample) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Add SMS Sample View
struct AddSMSSampleView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var samples: [SMSSample]
    
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sample Details") {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(height: 150)
                }
            }
            .navigationTitle("Add Sample")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissKeyboard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismissKeyboard()
                        saveSample()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func saveSample() {
        guard !title.isEmpty && !content.isEmpty else { return }
        
        dismissKeyboard()
        
        let sample = SMSSample(title: title.trimmingCharacters(in: .whitespacesAndNewlines), 
                               content: content.trimmingCharacters(in: .whitespacesAndNewlines))
        samples.append(sample)
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(samples) {
            UserDefaults.standard.set(encoded, forKey: "smsSamples")
        }
        
        dismiss()
    }
}

// MARK: - Edit SMS Sample View
struct EditSMSSampleView: View {
    @Environment(\.dismiss) private var dismiss
    let sample: SMSSample
    @Binding var samples: [SMSSample]
    
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sample Details") {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(height: 150)
                }
            }
            .navigationTitle("Edit Sample")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissKeyboard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismissKeyboard()
                        saveSample()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
            .onAppear {
                title = sample.title
                content = sample.content
            }
        }
    }
    
    private func saveSample() {
        dismissKeyboard()
        
        if let index = samples.firstIndex(where: { $0.id == sample.id }) {
            var updatedSample = samples[index]
            updatedSample.title = title
            updatedSample.content = content
            samples[index] = updatedSample
            
            if let encoded = try? JSONEncoder().encode(samples) {
                UserDefaults.standard.set(encoded, forKey: "smsSamples")
            }
        }
        
        dismiss()
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - SMS Test Result View
struct SMSTestResultView: View {
    @Environment(\.dismiss) private var dismiss
    let parsedTransaction: ParsedTransaction
    let smsService: SMSTransactionService
    let userId: String?
    
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Parsed Transaction") {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(parsedTransaction.isIncome ? "Income" : "Expense")
                            .foregroundColor(parsedTransaction.isIncome ? .green : .red)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$\(String(format: "%.2f", parsedTransaction.amount))")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text(parsedTransaction.isIncome ? "From" : "Merchant")
                        Spacer()
                        Text(parsedTransaction.merchant)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(parsedTransaction.date, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Original SMS") {
                    Text(parsedTransaction.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if userId != nil {
                    Section {
                        Button(action: createTransaction) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text("Create Transaction")
                            }
                        }
                        .disabled(isCreating)
                    }
                }
            }
            .navigationTitle("Test Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createTransaction() {
        guard let userId = userId else { return }
        
        isCreating = true
        smsService.createTransactionFromParsed(parsedTransaction, userId: userId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isCreating = false
            dismiss()
        }
    }
}

// MARK: - SMS Sample Row Component
struct SMSampleRow: View {
    let sample: SMSSample
    let smsService: SMSTransactionService
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var parsedResult: ParsedTransaction? {
        smsService.parseTransactionFromSMS(sample.content)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sample.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let parsed = parsedResult {
                        HStack(spacing: 6) {
                            Image(systemName: parsed.isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundColor(parsed.isIncome ? .green : .red)
                                .font(.caption)
                            
                            Text(parsed.isIncome ? "Income" : "Expense")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(parsed.isIncome ? .green : .red)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            Text("$\(String(format: "%.2f", parsed.amount))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            if !parsed.merchant.isEmpty {
                                Text("•")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Text(parsed.merchant)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text("Invalid - Cannot parse")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(sample.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(sample.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // SMS Content
            VStack(alignment: .leading, spacing: 4) {
                Text("SMS Content:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(sample.content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

#Preview {
    SMSSampleManagerView(context: CoreDataManager.shared.viewContext)
        .environmentObject(SessionViewModel())
}

