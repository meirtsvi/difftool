import SwiftUI
import AppKit

@main
struct DiffToolApp: App {
    @StateObject private var folderViewModel: FolderComparisonViewModel

    init() {
        // Activate as foreground app when launched from terminal
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Set app icon programmatically
        NSApplication.shared.applicationIconImage = Self.generateAppIcon()
        let args = CommandLine.arguments
        let leftPath: String?
        let rightPath: String?

        if args.count >= 3 {
            leftPath = args[1]
            rightPath = args[2]
        } else {
            leftPath = nil
            rightPath = nil
        }

        _folderViewModel = StateObject(wrappedValue: FolderComparisonViewModel(
            leftPath: leftPath,
            rightPath: rightPath
        ))
    }

    private static func generateAppIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        
        // Background rounded rect
        let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 20, dy: 20), xRadius: 80, yRadius: 80)
        NSColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0).setFill()
        bgPath.fill()
        
        // Left document (orange/removed side)
        let leftDoc = NSRect(x: 80, y: 140, width: 160, height: 240)
        let leftPath = NSBezierPath(roundedRect: leftDoc, xRadius: 12, yRadius: 12)
        NSColor(red: 0.95, green: 0.5, blue: 0.2, alpha: 0.9).setFill()
        leftPath.fill()
        
        // Left doc lines
        NSColor.white.withAlphaComponent(0.7).setFill()
        for i in 0..<5 {
            let lineRect = NSRect(x: 100, y: CGFloat(320 - i * 35), width: CGFloat(100 + (i % 3) * 20), height: 8)
            NSBezierPath(roundedRect: lineRect, xRadius: 4, yRadius: 4).fill()
        }
        
        // Right document (blue/added side)
        let rightDoc = NSRect(x: 272, y: 140, width: 160, height: 240)
        let rightPath = NSBezierPath(roundedRect: rightDoc, xRadius: 12, yRadius: 12)
        NSColor(red: 0.2, green: 0.5, blue: 0.95, alpha: 0.9).setFill()
        rightPath.fill()
        
        // Right doc lines
        NSColor.white.withAlphaComponent(0.7).setFill()
        for i in 0..<5 {
            let lineRect = NSRect(x: 292, y: CGFloat(320 - i * 35), width: CGFloat(80 + (i % 2) * 40), height: 8)
            NSBezierPath(roundedRect: lineRect, xRadius: 4, yRadius: 4).fill()
        }
        
        // Arrows between docs
        let arrowColor = NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        arrowColor.setFill()
        arrowColor.setStroke()
        
        // Right arrow
        let arrowRight = NSBezierPath()
        arrowRight.move(to: NSPoint(x: 245, y: 280))
        arrowRight.line(to: NSPoint(x: 267, y: 265))
        arrowRight.line(to: NSPoint(x: 245, y: 250))
        arrowRight.close()
        arrowRight.fill()
        
        // Left arrow
        let arrowLeft = NSBezierPath()
        arrowLeft.move(to: NSPoint(x: 267, y: 230))
        arrowLeft.line(to: NSPoint(x: 245, y: 215))
        arrowLeft.line(to: NSPoint(x: 267, y: 200))
        arrowLeft.close()
        arrowLeft.fill()
        
        // "DIFF" text at bottom
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let text = "DIFF" as NSString
        let textSize = text.size(withAttributes: textAttrs)
        let textPoint = NSPoint(x: (size.width - textSize.width) / 2, y: 60)
        text.draw(at: textPoint, withAttributes: textAttrs)
        
        image.unlockFocus()
        return image
    }

    var body: some Scene {
        WindowGroup {
            ContentView(folderViewModel: folderViewModel)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Compare") {
                Button("Refresh") {
                    folderViewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Show All Files") {
                    folderViewModel.filterMode = .all
                    folderViewModel.applyFilterAndSort()
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Show Differences Only") {
                    folderViewModel.filterMode = .differencesOnly
                    folderViewModel.applyFilterAndSort()
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Show Left Only") {
                    folderViewModel.filterMode = .leftOnly
                    folderViewModel.applyFilterAndSort()
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Show Right Only") {
                    folderViewModel.filterMode = .rightOnly
                    folderViewModel.applyFilterAndSort()
                }
                .keyboardShortcut("4", modifiers: .command)
            }

            CommandMenu("Navigate") {
                Button("Next Difference") {
                    // Handled by FileDiffView
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Previous Difference") {
                    // Handled by FileDiffView
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandMenu("Merge") {
                Button("Copy Left to Right") {
                    // Handled by FileDiffView
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("Copy Right to Left") {
                    // Handled by FileDiffView
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
    }
}
