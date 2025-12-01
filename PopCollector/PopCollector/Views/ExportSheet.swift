//
//  ExportSheet.swift
//  PopCollector
//
//  Export collection as CSV or beautiful PDF
//  Includes total value, signed info, and bin organization
//

import SwiftUI
import PDFKit

struct ExportSheet: View {
    let pops: [PopItem]
    
    @Environment(\.dismiss) private var dismiss
    
    private var totalValue: Double {
        pops.reduce(0) { $0 + $1.displayValue }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(pops.count) Pops • Total Value: $\(totalValue, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    // CSV Export
                    Button {
                        exportCSV()
                    } label: {
                        Label("Export as CSV", systemImage: "doc.text")
                            .foregroundColor(.blue)
                    }
                    
                    // PDF Export
                    Button {
                        exportPDF()
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                            .foregroundColor(.purple)
                    }
                }
                
                Section {
                    Text("CSV: Spreadsheet format for Excel, Numbers, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("PDF: Beautiful formatted document with images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Export to CSV
    
    private func exportCSV() {
        let headers = "Name,Number,Series,UPC,Quantity,Value Each,Total Value,Signed By,Has COA,Bin,Date Added"
        
        let rows = pops.map { pop in
            let total = pop.displayValue
            let signed = pop.isSigned ? pop.signedBy : ""
            let coa = pop.hasCOA ? "Yes" : "No"
            let bin = pop.folder?.name ?? "None"
            let date = pop.dateAdded.formatted(date: .numeric, time: .omitted)
            
            // Escape commas and quotes in CSV
            let escapeCSV: (String) -> String = { str in
                if str.contains(",") || str.contains("\"") {
                    return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return str
            }
            
            return [
                escapeCSV(pop.name),
                escapeCSV(pop.number),
                escapeCSV(pop.series),
                pop.upc,
                "\(pop.quantity)",
                String(format: "%.2f", pop.value),
                String(format: "%.2f", total),
                escapeCSV(signed),
                coa,
                escapeCSV(bin),
                date
            ].joined(separator: ",")
        }
        
        let csv = [headers] + rows
        let csvString = csv.joined(separator: "\n")
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PopCollection_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv")
        
        do {
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            share(url: url)
            Toast.show(message: "CSV exported!", systemImage: "checkmark.circle.fill")
        } catch {
            print("CSV export error: \(error)")
        }
    }
    
    // MARK: - Export to PDF
    
    private func exportPDF() {
        let pdfMetaData = [
            kCGPDFContextCreator: "PopCollector",
            kCGPDFContextAuthor: "PopCollector App",
            kCGPDFContextTitle: "My Pop Collection"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PopCollection_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).pdf")
        
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                
                // Create PDF content view
                let pdfView = PDFExportView(pops: pops)
                let hostingController = UIHostingController(rootView: pdfView)
                hostingController.view.frame = pageRect
                hostingController.view.backgroundColor = .white
                
                // Render to image first, then to PDF
                let renderer = ImageRenderer(content: pdfView)
                renderer.scale = 1.0
                
                if let image = renderer.uiImage {
                    image.draw(in: pageRect)
                }
            }
            
            share(url: url)
            Toast.show(message: "PDF exported!", systemImage: "checkmark.circle.fill")
        } catch {
            print("PDF export error: \(error)")
            Toast.show(message: "PDF export failed", systemImage: "exclamationmark.triangle")
        }
    }
    
    // MARK: - Share Sheet
    
    private func share(url: URL) {
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activity, animated: true)
        }
    }
}

// MARK: - Beautiful PDF View

struct PDFExportView: View {
    let pops: [PopItem]
    
    private var totalValue: Double {
        pops.reduce(0) { $0 + $1.displayValue }
    }
    
    private var totalCount: Int {
        pops.reduce(0) { $0 + $1.quantity }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("My Pop Collection")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                Text("Exported on \(Date().formatted(date: .long, time: .omitted))")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("Total Value: $\(totalValue, specifier: "%.2f") • \(totalCount) Pops • \(pops.count) Unique Items")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Pops List
            ForEach(pops) { pop in
                HStack(spacing: 16) {
                    // Pop Image
                    AsyncImage(url: URL(string: pop.imageURL)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                        }
                    }
                    .cornerRadius(8)
                    
                    // Pop Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pop.name)
                            .font(.headline)
                            .lineLimit(2)
                        
                        if !pop.number.isEmpty {
                            Text("\(pop.series) #\(pop.number)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if !pop.series.isEmpty {
                            Text(pop.series)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            if pop.quantity > 1 {
                                Text("×\(pop.quantity)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            if pop.isSigned {
                                HStack(spacing: 4) {
                                    Image(systemName: "signature")
                                        .font(.caption2)
                                    Text(pop.signedBy.isEmpty ? "Signed by Actor" : "Signed by \(pop.signedBy)")
                                        .font(.caption)
                                        .lineLimit(2)
                                    if pop.hasCOA {
                                        Text("COA")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .background(Color.purple.opacity(0.3))
                                            .cornerRadius(3)
                                    }
                                }
                                .foregroundColor(.purple)
                            }
                        }
                        
                        Text("Bin: \(pop.folder?.name ?? "None")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Value
                    VStack(alignment: .trailing) {
                        Text("$\(pop.displayValue, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(pop.isSigned ? .purple : .green)
                        
                        if pop.value > 0 {
                            Text("$\(pop.value, specifier: "%.2f") each")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
            }
            
            Spacer()
            
            // Footer
            Text("Generated by PopCollector")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }
}

#Preview {
    ExportSheet(pops: [])
}

