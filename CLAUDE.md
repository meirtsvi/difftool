# DiffTool - macOS Native Folder & File Diff Tool

## Overview
Build a native macOS app using SwiftUI that compares two folders and shows file differences — inspired by Araxis Merge and Beyond Compare.

## Architecture
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Target:** macOS 14+ (Sonoma)
- **Build:** Xcode project (use `swift package init` or create .xcodeproj)
- **App Name:** DiffTool

## Features

### 1. Folder Comparison View (Main View)
- Side-by-side panel showing two folder trees
- Color-coded file status:
  - 🟢 Green: Identical files
  - 🔴 Red: Modified/different files  
  - 🟡 Yellow: Files only in left folder (removed)
  - 🔵 Blue: Files only in right folder (added)
- Show file size, modification date
- Recursive folder comparison
- Filter: show all / only differences / only added / only removed
- Sort by name, status, date, size

### 2. File Diff View (Detail View)
- Triggered by pressing Enter on a modified file in the folder comparison
- Side-by-side diff view with syntax highlighting
- Line-by-line comparison with change highlighting
- Inline diff within changed lines (highlight specific changed characters/words)
- **Merge actions:**
  - Copy change from left → right (per line or per block)
  - Copy change from right → left (per line or per block)
  - Arrow buttons between the two panes for each diff hunk
- Navigation: jump to next/previous difference
- Back button or Escape to return to folder comparison

### 3. CLI Integration
- Accept two folder paths as command-line arguments: `DiffTool /path/left /path/right`
- If no arguments provided, show folder picker UI with two "…" buttons to select folders
- Register as a command-line tool (provide instructions for symlinking)

### 4. Keyboard Shortcuts
- `Enter` / `Return`: Open file diff for selected file
- `Escape`: Back to folder view from file diff
- `⌘→`: Copy selected change left to right
- `⌘←`: Copy selected change right to left
- `⌘↓` or `⌘N`: Next difference
- `⌘↑` or `⌘P`: Previous difference
- `⌘R`: Refresh/re-compare
- `⌘F`: Filter files
- `⌘1`: Show all files
- `⌘2`: Show only differences
- `⌘3`: Show only left-only files
- `⌘4`: Show only right-only files

### 5. UI Design (Araxis/Beyond Compare inspired)
- Clean, professional look
- Toolbar with folder paths and action buttons
- Split view with adjustable divider
- Status bar showing comparison summary (X files identical, Y modified, Z added, W removed)
- Dark mode support
- Monospaced font for diff view
- Line numbers in diff view
- Synchronized scrolling in diff view

## Technical Notes
- Use `FileManager` for directory traversal
- Use a diffing algorithm (Myers diff or similar) for line-by-line comparison
- Compute file hashes (SHA256) for quick identical/different detection
- Use `NSOpenPanel` for folder selection
- Handle large files gracefully (lazy loading)
- Handle binary files (show "Binary files differ" message)
- Support common text encodings (UTF-8, ASCII, Latin-1)

## Build & Run
```bash
# Build
swift build -c release

# Run with folders
.build/release/DiffTool /path/to/left /path/to/right

# Run without args (shows folder picker)
.build/release/DiffTool
```
