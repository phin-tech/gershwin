import AppKit
import GershwinAppKit
import GershwinChrome
import GershwinSwiftUI
import SwiftUI

struct Entry: Identifiable {
    let id: String
    var children: [Entry]?
}

let tree = [
    Entry(id: "Documents", children: [Entry(id: "Letters", children: [Entry(id: "to Sam.txt")]),
                                      Entry(id: "Budget.xls")]),
    Entry(id: "Empty folder", children: []),
    Entry(id: "ReadMe"),
]

@MainActor
@Observable
final class Model {
    var themeID = "platinum" { didSet { changed() } }
    var scale = 1.0 { didSet { changed() } }
    var onChange: () -> Void = {}
    var theme: ClassicTheme { ClassicTheme(ChromeTheme.named(themeID) ?? .platinum, scale: scale) }
    private func changed() { onChange() }
}

struct Root: View {
    @Bindable var model: Model
    @State private var page = 0
    @State private var text = "Fanfare"
    @State private var password = "hunter2"
    @State private var search = ""
    @State private var combo = "Geneva"
    @State private var segment = 1
    @State private var volume = 0.6
    @State private var copies = 3.0
    @State private var checked = true
    @State private var radio = "b"
    @State private var level = 6
    @State private var date = Date()
    @State private var color = ClassicColorWell.palette[6]
    @State private var popUp = "Platinum"
    @State private var selection: String? = "Budget.xls"
    @State private var expanded: Set<String> = ["Documents"]
    @State private var sheet = false
    @State private var status = "Right-click anything in Lists."
    @State private var progress = 0.4

    var body: some View {
        let theme = model.theme, s = theme.scale
        VStack(spacing: 0) {
            HStack(spacing: 12 * s) {
                Text("Theme:")
                ClassicPopUp(selection: $model.themeID,
                             options: ChromeTheme.builtIn.map { (value: $0.id, label: $0.name) })
                Text("Scale:")
                ClassicSegmentedControl(selection: $model.scale, options: [(1.0, "1×"), (1.5, "1.5×"), (2.0, "2×")])
                Spacer()
            }
            .padding(10 * s)
            ClassicTabView(selection: $page, titles: ["Controls", "Fields", "Lists", "Dialogs"]) {
                Group {
                    switch page {
                    case 0: controls
                    case 1: fields
                    case 2: lists
                    default: dialogs
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300 * s, alignment: .topLeading)
            }
            .padding(.horizontal, 10 * s)
            ClassicStatusBar(status, progress: nil).padding(.top, 10 * s)
        }
        .classicSheet(isPresented: $sheet) {
            VStack(alignment: .leading, spacing: 12 * s) {
                Text("Save changes to “Untitled”?")
                ClassicField("Name", text: $text, onCancel: { sheet = false }).frame(width: 240 * s)
                HStack {
                    Spacer()
                    Button("Cancel") { sheet = false }
                    Button("Save") { sheet = false }.classicDefault()
                }
            }
        }
    }

    var controls: some View {
        VStack(alignment: .leading, spacing: 12 * model.theme.scale) {
            HStack {
                Button("Cancel") {}
                Button("OK") {}.classicDefault()
                Button("Bevel") {}.buttonStyle(ClassicBevelButtonStyle())
                Button("On") {}.buttonStyle(ClassicBevelButtonStyle(isOn: true))
            }
            Toggle("Checkbox", isOn: $checked)
            ClassicRadioGroup(selection: $radio, options: [(value: "a", label: "One"), (value: "b", label: "Two")])
            HStack {
                ClassicSlider(value: $volume).frame(width: 180)
                Text("Copies: \(Int(copies))")
                ClassicLittleArrows(value: $copies, in: 1...10)
            }
            ClassicSegmentedControl(selection: $segment,
                                    options: [(0, "Icon"), (1, "List"), (2, "Column")])
            HStack {
                ClassicProgressView(value: progress).frame(width: 180, height: 14 * model.theme.scale)
                ClassicProgressView(value: nil).frame(width: 120, height: 14 * model.theme.scale)
            }
            HStack {
                ClassicLevelIndicator(value: level).frame(width: 160)
                ClassicLittleArrows(value: Binding(get: { Double(level) }, set: { level = Int($0) }), in: 0...10)
            }
            DisclosureGroup("Details", isExpanded: $checked) { Text("Shown when open.") }
            GroupBox("Group box") { Text("Contents").padding(4) }
        }
    }

    var fields: some View {
        ClassicForm {
            ClassicFormRow("Name:") { ClassicField(text: $text).frame(width: 220) }
            ClassicFormRow("Password:") { ClassicSecureField(text: $password).frame(width: 220) }
            ClassicFormRow("Search:") { ClassicSearchField(text: $search).frame(width: 220) }
            ClassicFormRow("Font:") {
                ClassicComboBox(text: $combo, options: ["Chicago", "Geneva", "Monaco", "New York"]).frame(width: 220)
            }
            ClassicFormRow("Theme:") {
                ClassicPopUp(selection: $popUp, options: [(value: "Platinum", label: "Platinum"),
                                                          (value: "System 7", label: "System 7")])
            }
            ClassicFormRow("Date:") { ClassicDatePicker(date: $date) }
            ClassicFormRow("Colour:") { ClassicColorWell(selection: $color) }
        }
    }

    var lists: some View {
        HStack(alignment: .top) {
            ClassicOutline(tree, children: \.children, selection: $selection, expanded: $expanded,
                           title: { $0.id }, onOpen: { status = "Opened \($0.id)" })
                .frame(width: 220 * model.theme.scale, height: 240 * model.theme.scale)
                .classicContextMenu {
                    [ClassicMenuItem("Open") { status = "Open \(selection ?? "nothing")" },
                     ClassicMenuItem("Get Info", isEnabled: selection != nil) { status = "Info on \(selection ?? "")" },
                     .separator,
                     ClassicMenuItem("Label", submenu: [ClassicMenuItem("Red") { status = "Red" },
                                                        ClassicMenuItem("Blue", isChecked: true) { status = "Blue" }])]
                }
            ClassicIconGrid(tree, selection: $selection, title: { $0.id }) { entry in
                Image(systemName: entry.children == nil ? "doc" : "folder").font(.system(size: 28))
            }
            .frame(width: 240 * model.theme.scale, height: 240 * model.theme.scale)
        }
    }

    var dialogs: some View {
        VStack(alignment: .leading, spacing: 12 * model.theme.scale) {
            Button("Show Sheet…") { sheet = true }
            Button("Show Alert…") {
                let alert = ClassicAlert(icon: .caution, message: "Close the window?",
                                         informativeText: "Closing it ends what's running in it.",
                                         buttons: ["Close", "Cancel"])
                status = "Alert chose button \(alert.runModal(theme: model.theme))"
            }
        }
    }
}

/// The root with the theme applied; it reads the model, so a theme change redraws it in place, state kept.
struct GalleryRoot: View {
    var model: Model

    var body: some View { Root(model: model).gershwin(model.theme) }
}

@MainActor
final class App: NSObject, NSApplicationDelegate {
    let model = Model()
    var window: ClassicWindow!
    var host: NSHostingView<GalleryRoot>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 560), style: .document,
                               theme: model.theme)
        window.title = "Gershwin Gallery"
        host = NSHostingView(rootView: GalleryRoot(model: model))
        window.frameView.mainView = host
        model.onChange = { [unowned self] in
            window.theme = model.theme
        }
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Gallery", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
