# Gershwin

Windows and controls drawn the way the classic Mac OS, BeOS, OS/2 Warp, Windows 3.1, 95 and 7, the Amiga's Workbench,
Sun's OPEN LOOK and Mac OS X's Aqua drew them, for AppKit and SwiftUI on macOS 14 and
later. Named for the planned successor to Copland, the Mac OS that never shipped.

Twenty themes are built in: **Platinum** (Mac OS 8 and 9) and **Platinum Dark** (its greys inverted; Mac OS 9
had none), Copland's **Hi-Tech**, **Gizmo** and **Drawing Board**,
**System 7**, **System 1** (one bit, dithered), **BeOS** and **BeOS Dark**, **OS/2 Warp** and **OS/2 Warp
Dark** (a sizing border round a blue title bar, the system menu at its left; the dark one is new, Warp had none),
**Windows 3.1** and **Windows 95** (OS/2's shape, with their own title bars), **Windows 7** and **Windows 7 Dark**
(Aero: a glass frame with a bright line inside its outline, glass minimize and maximize buttons and a red close
button hung from the top edge, the title at the left with its glow; square and opaque, and the dark one is new), and the Amiga's **Workbench** (3.1) and
**Workbench 1.3** (the drag bar between the close gadget and the zoom and depth gadgets, the scroll bar's arrows
together above the size gadget), and Sun's **OPEN LOOK** (a window menu button for boxes, a resize corner in each
corner, pushpins on pop-ups, and the elevator scroll bar riding its cable), and Mac OS X's **Aqua** and **Aqua
Graphite** (10.0 to 10.4: pinstripes, the close, minimize and zoom buttons as gel at the left of the title bar, a blue
gel scroll thumb with both arrows at the bottom, capsule buttons with the default one blue; menus, tabs and dividers
keep Platinum's shapes in Aqua's colours). A theme is a value (`ChromeTheme`), so an
app can make its own.

## What's in it

- **GershwinChrome**: plain values, no AppKit, tested headless. The themes (`ChromeTheme.builtIn`, found and saved
  by id): their colour tokens (`Palette`), the colours of the text they show (`TextColors`: a terminal's sixteen, or a
  code view's, read from a Ghostty theme file too), and their pairs for the other mode; `ThemeChoice`, a theme, or a light and a dark one while following
  macOS, each kept as chosen. And the geometry of every part: a Mac window's title bar, boxes, scroll bar, placard and grow box (`WindowChromeLayout`), a
  BeOS window's sliding title tabs (`BeOSChromeLayout`), an OS/2 window's title bar and buttons (`OS2ChromeLayout`), a proportional scroll thumb (`ScrollbarGeometry`), and tabs
  (`TabList`, `TabStripLayout`).
- **GershwinAppKit**: `ClassicWindow`, a borderless window that draws its whole frame itself: pinstriped title bar,
  close, zoom and collapse (WindowShade) boxes that track the mouse as the Toolbox did, a grow box that drags an
  outline, a scroll bar whose arrows and track repeat while held, and tabs in each era's style. Its chrome is drawn in
  Mac OS 9 pixels and scaled (1×, 1.5×, 2×) crisply; its content is not scaled.
  Also, each drawn in the theme's own family (Platinum, System 1–7 or BeOS):
  - `ClassicMenu`: any NSMenu drawn as a classic menu (submenus, alternates, keyboard, Mac OS 8's sticky click),
    for context menus and pop-ups. Given a bar's titles (`ClassicMenuTitle`), moving onto another opens its menu, as
    in the menu bar; it works from an app that isn't active, like a status bar's helper; and given `tearOff`,
    it tears off as Mac OS 8.5's Application menu did, into a palette where it's dropped.
  - `ClassicPopUpButton`, `ClassicButton` (with the default button's ring), `ClassicProgressBar` (and System 7's
    barber pole), `ClassicAlert` (Stop, Caution and Note), and Balloon Help (`ClassicBalloon`), which a window's
    frame uses to explain its own parts.
  - Utility windows (`.utility`): a thin title bar and small boxes, or BeOS's smaller tab. They float over the
    document they work on, which stays the main window.
  - `ClassicTextField`: an edit-text field showing the keyboard focus as its era did (Mac OS 8's ring in the
    highlight colour, System 7's caret alone, BeOS's blue outline), and `ClassicTabBar`, whose tabs also make a
    dialog's tab control (`opensOntoPanel`).
  - Adjustable panes (`ClassicSplitView`, over a `SplitTree` of the app's own views, which it never re-parents):
    each era's divider (Platinum's bevelled bar and split box, MPW's double line, Haiku's, OS/2's split bar), a scroll
    bar for each pane, the one being typed in drawn active, and dividers dragged with an outline.
  - A command palette (`ClassicPalette`): a floating utility window with an edit-text field over a list in a sunken
    well, in the theme's own style. The app gives it `PaletteEntry` values (a title, a group, an optional detail and
    shortcut, and what choosing it does), so it knows nothing about what they are; `PaletteEntry.entries(from:)` makes
    them from an NSMenu. Typing narrows the list by fuzzy match (`PaletteMatcher`, in GershwinChrome, with the matched
    letters underlined), what was chosen lately floats up (`PaletteHistory`), and `update(entries:)` brings in entries
    that arrive late. `swift run PaletteDemo` in `Examples/PaletteDemo` tries it.
  - A progress bar in a document window's placard (`placardProgress`), and Mac OS 8's drop highlight
    (`ClassicDropHighlight`), to show over a view while something dragged over it can drop there.
- **GershwinSwiftUI**: `.gershwin(theme)` at the root of a view restyles SwiftUI's own `Button`, `Toggle`,
  `GroupBox` and `DisclosureGroup` beneath it, the way [NeoBrutalism](https://github.com/rational-kunal/NeoBrutalism)
  does, plus, for what SwiftUI won't let be styled, `ClassicPopUp`, `ClassicRadioGroup`, `ClassicSlider`,
  `ClassicLittleArrows`, `ClassicBevelButtonStyle`, `ClassicThemeChooser` (a settings pane's theme pop-ups and
  Follow macOS checkbox, for a `ThemeChoice`), `ClassicSidebar` (sections of button rows, each with a lamp, a detail line and a badge, for a source list), `ClassicField` (a `ClassicTextField`; SwiftUI's TextField
  draws macOS's focus ring), `ClassicTabView` (Mac OS 8's tab control) and `.classicField()`. Also
  `ClassicOutline` (a tree with disclosure triangles and arrow-key navigation), `ClassicSearchField`,
  `ClassicSecureField`, `ClassicComboBox`, `ClassicSegmentedControl`, `.classicSheet(isPresented:)` (a modal dialog
  over a view; Aqua's hangs from the top), and `.classicContextMenu { [ClassicMenuItem] }`, a right-click menu drawn
  by `ClassicMenu` in place of macOS's. Esc closes a sheet or popover (`.classicPopover`). And
  `ClassicLevelIndicator`, `ClassicForm`/`ClassicFormRow`, `ClassicDatePicker` (Mac OS 8's date field with little
  arrows), `ClassicColorWell` (the 16-colour palette) and `ClassicIconGrid` (the Finder's icon view).

```swift
import GershwinAppKit
import GershwinSwiftUI

let window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320), style: .document,
                           theme: ClassicTheme(.platinum, scale: 1.5))
window.title = "Untitled"
window.frameView.mainView = NSHostingView(rootView: MyView().gershwin(window.theme))
window.makeKeyAndOrderFront(nil)
```

Text is in ChicagoFLF when it is installed, and the system font otherwise; BeOS, OS/2 and Windows themes use Helvetica
Bold (for Swiss 721, WarpSans and MS Sans Serif, which aren't free), and the Amiga's Monaco (for Topaz).

Gershwin came out of [Fanfare](https://github.com/phin-tech/fanfare-for-the-command-line), a terminal drawn this way.

## Develop

```sh
swift test
GERSHWIN_GALLERY=/tmp/gallery swift test --filter writeGallery   # every component in every theme, as PNGs
```
