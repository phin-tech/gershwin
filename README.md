# Gershwin

Windows and controls drawn the way the classic Mac OS, BeOS and OS/2 Warp drew them, for AppKit and SwiftUI on macOS 14 and
later. Named for the planned successor to Copland, the Mac OS that never shipped.

Ten themes are built in: **Platinum** (Mac OS 8 and 9), Copland's **Hi-Tech**, **Gizmo** and **Drawing Board**,
**System 7**, **System 1** (one bit, dithered), **BeOS** and **BeOS Dark**, and **OS/2 Warp** and **OS/2 Warp
Dark** (a sizing border round a blue title bar, the system menu at its left; the dark one is new, Warp had none). A theme is a value (`ChromeTheme`), so an
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
    in the menu bar; and it works from an app that isn't active, like a status bar's helper.
  - `ClassicPopUpButton`, `ClassicButton` (with the default button's ring), `ClassicProgressBar` (and System 7's
    barber pole), `ClassicAlert` (Stop, Caution and Note), and Balloon Help (`ClassicBalloon`), which a window's
    frame uses to explain its own parts.
  - Utility windows (`.utility`): a thin title bar and small boxes, or BeOS's smaller tab. They float over the
    document they work on, which stays the main window.
  - `ClassicTextField`: an edit-text field showing the keyboard focus as its era did (Mac OS 8's ring in the
    highlight colour, System 7's caret alone, BeOS's blue outline), and `ClassicTabBar`, whose tabs also make a
    dialog's tab control (`opensOntoPanel`).
  - A progress bar in a document window's placard (`placardProgress`), and Mac OS 8's drop highlight
    (`ClassicDropHighlight`), to show over a view while something dragged over it can drop there.
- **GershwinSwiftUI**: `.gershwin(theme)` at the root of a view restyles SwiftUI's own `Button`, `Toggle`,
  `GroupBox` and `DisclosureGroup` beneath it, the way [NeoBrutalism](https://github.com/rational-kunal/NeoBrutalism)
  does, plus, for what SwiftUI won't let be styled, `ClassicPopUp`, `ClassicRadioGroup`, `ClassicSlider`,
  `ClassicLittleArrows`, `ClassicBevelButtonStyle`, `ClassicThemeChooser` (a settings pane's theme pop-ups and
  Follow macOS checkbox, for a `ThemeChoice`), `ClassicField` (a `ClassicTextField`; SwiftUI's TextField
  draws macOS's focus ring), `ClassicTabView` (Mac OS 8's tab control) and `.classicField()`.

```swift
import GershwinAppKit
import GershwinSwiftUI

let window = ClassicWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320), style: .document,
                           theme: ClassicTheme(.platinum, scale: 1.5))
window.title = "Untitled"
window.frameView.mainView = NSHostingView(rootView: MyView().gershwin(window.theme))
window.makeKeyAndOrderFront(nil)
```

Text is in ChicagoFLF when it is installed, and the system font otherwise; BeOS and OS/2 themes use Helvetica Bold
(for Swiss 721 and WarpSans, which aren't free).

Gershwin came out of [Fanfare](https://github.com/phin-tech/fanfare-for-the-command-line), a terminal drawn this way.

## Develop

```sh
swift test
GERSHWIN_GALLERY=/tmp/gallery swift test --filter writeGallery   # every component in every theme, as PNGs
```
