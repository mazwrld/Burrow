import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            switch model.lookup {
            case .ready: split
            case .checking: Color.clear
            case .missing, .tooOld: SetupView()
            }
        }
        .task {
            await model.locate()
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }

    private var split: some View {
        @Bindable var model = model
        return NavigationSplitView {
            List(Page.allCases, selection: Binding($model.page)) { page in
                Label(page.title, systemImage: page.symbol)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            page
        }
        .onChange(of: model.page) { model.refresh() }
    }

    @ViewBuilder
    private var page: some View {
        switch model.page {
        case .health: HealthView()
        case .clean: CleanView()
        case .history: HistoryView()
        case .space, .apps: ComingSoonView(page: model.page)
        }
    }
}

private extension Binding where Value == Page? {
    /// The sidebar List wants an optional selection; the model always has a page.
    init(_ page: Binding<Page>) {
        self.init(get: { page.wrappedValue }, set: { if let new = $0 { page.wrappedValue = new } })
    }
}

struct ComingSoonView: View {
    let page: Page

    var body: some View {
        ContentUnavailableView {
            Label(page.title, systemImage: page.symbol)
        } description: {
            Text(page == .space
                 ? "Coming soon: see what uses your disk and which folders Mole knows are caches."
                 : "Coming soon: see your apps by size and preview what an uninstall removes.")
        }
        .navigationTitle(page.title)
    }
}
