//
//  ReportsView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct ReportsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var reportViewModel: ReportViewModel
    
    @State private var selectedChartType: ChartType = .bar
    @State private var selectedMonth: Date = Date()
    @State private var dateRangeMode: DateRangeMode = .month
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    enum ChartType: String, CaseIterable {
        case bar = "Bar Chart"
        case line = "Line Chart"
    }
    
    enum DateRangeMode: String, CaseIterable {
        case month = "Month"
        case range = "Date Range"
    }
    
    init(context: NSManagedObjectContext) {
        let tvm = TransactionViewModel(context: context)
        _transactionViewModel = StateObject(wrappedValue: tvm)
        _reportViewModel = StateObject(wrappedValue: ReportViewModel(context: context, transactionViewModel: tvm))
    }
    
    private func updateReportViewModel() {
        reportViewModel.setUserId(sessionViewModel.userId)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Date Range Selector
                    VStack(alignment: .leading, spacing: 12) {
                        // Mode Picker
                        Picker("Mode", selection: $dateRangeMode) {
                            ForEach(DateRangeMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: dateRangeMode) { oldValue, newValue in
                            updateReportForDateRange()
                        }
                        
                        // Month Picker
                        if dateRangeMode == .month {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Month")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                DatePicker("Month", selection: $selectedMonth, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .padding(.horizontal)
                                    .onChange(of: selectedMonth) { oldValue, newMonth in
                                        reportViewModel.updateSelectedMonth(newMonth)
                                    }
                            }
                        } else {
                            // Date Range Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Date Range")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .onChange(of: startDate) { oldValue, newValue in
                                            // Ensure start date is before end date
                                            if newValue > endDate {
                                                endDate = newValue
                                            }
                                            updateReportForDateRange()
                                        }
                                    
                                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .onChange(of: endDate) { oldValue, newValue in
                                            // Ensure end date is after start date
                                            if newValue < startDate {
                                                startDate = newValue
                                            }
                                            updateReportForDateRange()
                                        }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                    
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text(dateRangeMode == .month ? "Monthly Summary" : "Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            SummaryCard(
                                title: "Income",
                                amount: getSelectedRangeIncome(),
                                color: .green
                            )
                            
                            SummaryCard(
                                title: "Expenses",
                                amount: getSelectedRangeExpenses(),
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Category Breakdown (Pie Chart)
                    if !reportViewModel.categorySpending.isEmpty {
                        CategoryBreakdownView(reportViewModel: reportViewModel)
                    }
                    
                    // Monthly Trends
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Monthly Trends")
                                .font(.headline)
                            
                            Spacer()
                            
                            Picker("Chart Type", selection: $selectedChartType) {
                                ForEach(ChartType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                        .padding(.horizontal)
                        
                        MonthlyTrendsView(
                            reportViewModel: reportViewModel,
                            selectedChartType: selectedChartType
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Reports")
            .onAppear {
                updateReportViewModel()
                updateReportForDateRange()
            }
            .onChange(of: sessionViewModel.userId) { oldValue, newValue in
                updateReportViewModel()
                updateReportForDateRange()
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func updateReportForDateRange() {
        if dateRangeMode == .month {
            reportViewModel.updateSelectedMonth(selectedMonth)
        } else {
            reportViewModel.updateDateRange(startDate: startDate, endDate: endDate)
        }
    }
    
    private func getSelectedRangeIncome() -> Double {
        if dateRangeMode == .month {
            let calendar = Calendar.current
            let startOfSelectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
            let selectedMonthData = reportViewModel.monthlyData.first { calendar.isDate($0.month, equalTo: startOfSelectedMonth, toGranularity: .month) }
            return selectedMonthData?.income ?? 0
        } else {
            return reportViewModel.rangeIncome
        }
    }
    
    private func getSelectedRangeExpenses() -> Double {
        if dateRangeMode == .month {
            let calendar = Calendar.current
            let startOfSelectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
            let selectedMonthData = reportViewModel.monthlyData.first { calendar.isDate($0.month, equalTo: startOfSelectedMonth, toGranularity: .month) }
            return selectedMonthData?.expenses ?? 0
        } else {
            return reportViewModel.rangeExpenses
        }
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(amount))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct CategoryBreakdownView: View {
    @ObservedObject var reportViewModel: ReportViewModel
    
    private var pieData: [(category: Category, amount: Double, color: Color)] {
        reportViewModel.getPieChartData()
    }
    
    private var total: Double {
        pieData.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)
                .padding(.horizontal)
            
            PieChart(data: pieData, total: total)
                .frame(height: 250)
                .padding()
            
            // Category List
            VStack(alignment: .leading, spacing: 8) {
                ForEach(reportViewModel.categorySpending.prefix(5), id: \.category.id) { spending in
                    HStack {
                        Circle()
                            .fill(spending.category.colorValue)
                            .frame(width: 12, height: 12)
                        
                        Text(spending.category.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(formatCurrency(spending.amount))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("(\(String(format: "%.1f", spending.percentage))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct MonthlyTrendsView: View {
    @ObservedObject var reportViewModel: ReportViewModel
    let selectedChartType: ReportsView.ChartType
    
    private var barData: [(month: String, income: Double, expenses: Double)] {
        reportViewModel.getBarChartData()
    }
    
    var body: some View {
        if selectedChartType == .bar {
            BarChart(data: barData)
                .frame(height: 200)
        } else {
            LineChart(data: barData)
                .frame(height: 200)
                .padding()
        }
    }
}

#Preview {
    ReportsView(context: CoreDataManager.shared.viewContext)
}

