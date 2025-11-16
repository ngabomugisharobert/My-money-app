//
//  SMSImportView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct SMSImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    
    @StateObject private var smsService: SMSTransactionService
    @State private var smsText: String = ""
    @State private var showingPreview = false
    @State private var parsedTransaction: ParsedTransaction?
    @State private var errorMessage: String?
    
    init(context: NSManagedObjectContext) {
        _smsService = StateObject(wrappedValue: SMSTransactionService(context: context))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Paste your transaction SMS here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $smsText)
                        .frame(height: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: smsText) { oldValue, newValue in
                            parseSMS(newValue)
                        }
                } header: {
                    Text("SMS Content")
                } footer: {
                    Text("Example: Chase Freedom Unlimited Visa: You made a $18.48 transaction with FRED-MEYER #0186 on Nov 13, 2025 at 8:26 PM ET.")
                }
                
                if let parsed = parsedTransaction {
                    Section("Preview") {
                        HStack {
                            Text("Type")
                            Spacer()
                            Text(parsed.isIncome ? "Income" : "Expense")
                                .foregroundColor(parsed.isIncome ? .green : .red)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Amount")
                            Spacer()
                            Text("$\(String(format: "%.2f", parsed.amount))")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text(parsed.isIncome ? "From" : "Merchant")
                            Spacer()
                            Text(parsed.merchant)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(parsed.date, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: createTransaction) {
                        HStack {
                            Spacer()
                            Text("Create Transaction")
                            Spacer()
                        }
                    }
                    .disabled(parsedTransaction == nil)
                }
            }
            .navigationTitle("Import from SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                smsService.setUserId(sessionViewModel.userId)
            }
        }
    }
    
    private func parseSMS(_ text: String) {
        errorMessage = nil
        parsedTransaction = smsService.parseTransactionFromSMS(text)
        
        if !text.isEmpty && parsedTransaction == nil {
            errorMessage = "Could not parse transaction from SMS. Please check the format."
        }
    }
    
    private func createTransaction() {
        guard let parsed = parsedTransaction,
              let userId = sessionViewModel.userId else { return }
        
        smsService.createTransactionFromParsed(parsed, userId: userId)
        dismiss()
    }
}

#Preview {
    SMSImportView(context: CoreDataManager.shared.viewContext)
        .environmentObject(SessionViewModel())
}

