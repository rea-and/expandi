# Expandi

A polished, native macOS text expansion and snippet management application built with Swift and SwiftUI.

Expandi monitors keystroke abbreviations system-wide across all your applications and instantaneously expands them into rich snippets, boilerplate emails, code blocks, dynamic dates, and interactive fill-in forms.

---

## Features

### 1. Global Keystroke Interception & Expansion Engine
- **Instant Expansion**: Expands immediately as soon as the abbreviation is typed (e.g., `;sig` -> full signature).
- **Delimiter-Triggered Expansion**: Expands only after typing a word delimiter (Space, Return, Tab, punctuation `,`, `.`, `;`, `:`), with options to keep or discard the delimiter.
- **Adaptive Case Matching**:
  - *Adapt to Typed Case*: Typing `;date` -> `today`, `;Date` -> `Today`, `;DATE` -> `TODAY`.
  - *Exact Match Only*: Only triggers when the casing matches exactly.
  - *Case-Insensitive*: Expands stored casing regardless of what was typed.
- **Excluded Applications**: Configure apps where expansion is globally paused (e.g. password managers or terminal).
- **Clipboard Restoration**: Snippet expansion via clipboard preserves and restores your previous pasteboard contents.
- **Subtle Audio Feedback**: Optional audio confirmation upon expansion with selectable macOS system sounds (*Tink*, *Pop*, *Glass*, *Purr*, etc.).

---

### 2. Comprehensive Fill-In Forms & Variables

Expandi supports all standard interactive fill-in field types:

| Fill-In Type | Syntax | Description |
| :--- | :--- | :--- |
| **Single Line Field** | `{{fill:Field Name}}`<br>`{{fill:Field Name:default=Val}}` | Single-line text input for names, subject lines, customer IDs. |
| **Multi Line Field** | `{{multiline:Notes}}`<br>`{{multiline:Notes:default=Val}}` | Multi-line text editor for paragraphs, notes, or explanations. |
| **Date Picker** | `{{datepicker:Date:format=YYYY-MM-dd}}` | Interactive graphical macOS calendar date picker. |
| **Optional Section** | `{{opt:Include title:Senior Engineer\n}}` | Checkbox toggle that includes or excludes a block of text. |
| **Popup Menu** | `{{choice:Dept:Sales,Support,Billing:default=Support}}` | Dropdown menu allowing selection from predefined choices. |
| **Show at Top** | `{{show_at_top}}` | Pins fill-in variable controls to the top of prompt dialogs. |

When a snippet with dynamic fill-ins is triggered, Expandi presents a floating, non-activating modal HUD over your active window. As you fill out the fields, a live result preview updates in real time. Press **Return** (or **⌘↵**) to insert directly into your target app, or **⎋** to cancel.

---

### 3. Dynamic Macros & Automation

- **Dates & Times**:
  - `{{date:YYYY-MM-dd}}` -> ISO date (e.g., `2026-10-20`)
  - `{{date:MMMM d, YYYY}}` -> Long date (e.g., `October 20, 2026`)
  - `{{time:h:mm a}}` -> Time with AM/PM (e.g., `9:15 PM`)
  - `{{datetime}}` -> Full localized date and timestamp
- **Date Math & Offsets**:
  - `{{date+1d}}` or `{{date:offset=+1d,format=YYYY-MM-dd}}` -> Tomorrow
  - `{{date-1d}}` -> Yesterday
  - `{{date+7d}}` -> Next week
  - `{{date+1m}}` -> Next month
  - `{{date+1y}}` -> Next year
- **Clipboard Macro**:
  - `{{clipboard}}` -> Inserts current clipboard contents inline.
- **Cursor Repositioning**:
  - `{{cursor}}` -> Places the text cursor exactly at this location after expansion.
- **Nested Snippets**:
  - `{{snippet:;sig}}` -> Dynamically embeds another snippet (with recursion safeguards).
- **Simulated Key Presses**:
  - `{{key:tab}}`, `{{key:return}}`, `{{key:esc}}` -> Automates form navigation.
- **Shell & AppleScript Execution**:
  - `{{shell:command}}` -> Runs shell command and inserts standard output.
  - `{{applescript:code}}` -> Executes AppleScript and inserts the return value.

---

### 4. Quick Search HUD Palette

- Global shortcut (defaults to **⌥ Space** / Option + Space or **⇧⌘E**).
- Spotlight / Raycast-style floating window centered on screen.
- Instant fuzzy search across snippet titles, abbreviations, content, and tags.
- Live snippet preview pane with syntax formatting.
- Press **↵** to insert directly into your previously active application.
- Press **⌘C** to copy the evaluated snippet to your clipboard.

---

### 5. Menu Bar Status Item

- Dedicated macOS menu bar status icon.
- Quick status indicator (*Expansion Active* / *Expansion Paused*).
- 1-click toggle to pause or resume expansion system-wide.
- Recent snippets menu for quick access.
- Live productivity counter (*X expansions • Y keystrokes saved*).
- Direct access to Preferences, Import/Export, and Accessibility status.

---

### 6. Snippet Library & Organization

- **Smart Collections**:
  - *All Snippets*
  - *Favorites* (Starred)
  - *Recently Used*
  - *Fill-In Templates* (Snippets containing dynamic form fields)
- **Custom Groups**:
  - Color-coded folders with custom SF Symbols.
  - Group trigger prefix (e.g., automatically prepend `;` to all group snippets).
  - Group-specific application exclusion lists.
- **Tags & Search**:
  - Tag multiple snippets for easy multi-dimensional categorization.
  - Instant search filtering by text, abbreviation, or tag.
- **Trash & Recovery**:
  - Soft deletion with full restore or permanent purge capabilities.

---

### 7. Import & Export

- **JSON Archive (`.json` / `.expandi`)**:
  - Complete export and backup preserving all groups, tags, delimiters, and preferences.
- **Universal CSV (`.csv`)**:
  - RFC-4180 compliant CSV export and import with full quote and multi-line support.
- **Duplicate Conflict Resolution**:
  - *Keep Both (Create Copy)*
  - *Overwrite Existing*
  - *Skip Duplicates*

---

### 8. Analytics & Productivity Dashboard

- Total expansions counter.
- Keystrokes saved counter (`expanded_length - abbreviation_length`).
- Estimated time saved calculation in hours and minutes.
- Most-used snippets ranking and group activity breakdown.

---

## Getting Started

### Prerequisites
- macOS 14.0 or later (Apple Silicon or Intel).
- Swift 6.0+ toolchain (Xcode Command Line Tools).

### Building Expandi
Run the build script in the root directory:
```bash
./build.sh
```
This produces a release-optimized, signed macOS application bundle at:
`build/Expandi.app`

### Deploying Expandi
Run the deploy script to build and install into `/Applications`:
```bash
./deploy.sh
```

### Running Self-Tests
Expandi includes an internal 9-suite verification test runner covering all macro engines, fill-ins, date math, case adaptation, and import/export:
```bash
./build/Expandi.app/Contents/MacOS/Expandi --test
```

### Cleaning Build Artifacts
```bash
./clean.sh
```

---

## Permissions Setup

Expandi requires macOS **Accessibility** permission to monitor abbreviations and inject expanded text:

1. Launch Expandi (`open /Applications/Expandi.app`).
2. When prompted, open **System Settings** -> **Privacy & Security** -> **Accessibility**.
3. Toggle on **Expandi**.
4. Expandi immediately activates without requiring an application restart.
