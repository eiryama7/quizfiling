import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var processingCoordinator: DocumentProcessingCoordinator

    @Query(sort: \DocumentEntity.createdAt, order: .reverse) private var documents: [DocumentEntity]

    @State private var searchText: String = ""
    @State private var selectedSubject: SubjectEntity?
    @State private var subjects: [SubjectEntity] = []

    @State private var showScanner = false
    @State private var showPDFImporter = false
    @State private var showImageImporter = false
    @State private var importError: String?

    private let importService = DocumentImportService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredDocuments) { document in
                        NavigationLink {
                            DocumentDetailView(document: document)
                        } label: {
                            DocumentRow(document: document)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("ライブラリ")
            .searchable(text: $searchText, prompt: "タイトル・OCR検索")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("スキャン", systemImage: "doc.viewfinder")
                    }
                    Menu {
                        Button("PDFを読み込む") {
                            showPDFImporter = true
                        }
                        Button("画像を読み込む") {
                            showImageImporter = true
                        }
                    } label: {
                        Label("読み込み", systemImage: "square.and.arrow.down")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { selectedSubject = nil }
                        ForEach(subjects) { subject in
                            Button(subject.name) { selectedSubject = subject }
                        }
                    } label: {
                        Label(selectedSubject?.name ?? "科目", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { result in
                    showScanner = false
                    handleScan(result: result)
                } onCancel: {
                    showScanner = false
                }
            }
            .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
                handlePDFImport(result: result)
            }
            .fileImporter(isPresented: $showImageImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                handleImageImport(result: result)
            }
            .alert("読み込みエラー", isPresented: Binding(get: {
                importError != nil
            }, set: { newValue in
                if !newValue { importError = nil }
            }), actions: {
                Button("OK") { importError = nil }
            }, message: {
                Text(importError ?? "")
            })
            .task {
                let repo = SubjectRepository(context: context)
                subjects = (try? repo.enabledSubjects()) ?? []
            }
        }
    }

    private var filteredDocuments: [DocumentEntity] {
        documents.filter { document in
            let matchesSubject = selectedSubject == nil || document.subject?.id == selectedSubject?.id
            let matchesSearch = searchText.isEmpty || document.title.localizedCaseInsensitiveContains(searchText) || document.ocrFullText.localizedCaseInsensitiveContains(searchText)
            return matchesSubject && matchesSearch
        }
    }

    private func delete(at offsets: IndexSet) {
        let storage = FileStorageService.shared
        for index in offsets {
            let document = filteredDocuments[index]
            document.fileURLs.forEach { storage.remove($0) }
            context.delete(document)
        }
        try? context.save()
    }

    private func handleScan(result: DocumentScanResult) {
        do {
            let payload = try importService.importScan(pdfData: result.pdfData, images: result.images)
            let document = DocumentEntity(title: payload.title, fileURLs: payload.filePaths, pageCount: payload.pageCount)
            context.insert(document)
            try context.save()
            let repo = SubjectRepository(context: context)
            processingCoordinator.process(document: document, context: context, subjectRepository: repo)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func handlePDFImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let payload = try importService.importPDF(from: url)
                let document = DocumentEntity(title: payload.title, fileURLs: payload.filePaths, pageCount: payload.pageCount)
                context.insert(document)
                try context.save()
                let repo = SubjectRepository(context: context)
                processingCoordinator.process(document: document, context: context, subjectRepository: repo)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func handleImageImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            do {
                let payload = try importService.importImages(urls: urls)
                let document = DocumentEntity(title: payload.title, fileURLs: payload.filePaths, pageCount: payload.pageCount)
                context.insert(document)
                try context.save()
                let repo = SubjectRepository(context: context)
                processingCoordinator.process(document: document, context: context, subjectRepository: repo)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

private struct DocumentRow: View {
    let document: DocumentEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(document.title)
                .font(.headline)
            HStack {
                Text(document.subject?.name ?? "未分類")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(document.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !document.summary.isEmpty {
                Text(document.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(document.statusLabel)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(document.statusColor)
                    .clipShape(Capsule())
            }
        }
    }
}
