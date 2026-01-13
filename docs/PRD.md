# QuestMemory - World of Warcraft Addon PRD

## Overview

Build a WoW addon called "QuestMemory" for TBC Classic (Interface 20501) that tracks quest completions across all characters on an account and displays this information in tooltips.

## Core Problem

Players with multiple characters can't easily see if they've already completed a quest on another character. They want to know "Did my other characters do this quest?" when looking at their quest log.

## Technical Stack

- Lua for logic
- WoW API (TBC Classic 2.5.x)
- SavedVariables for persistent storage

## File Structure

```
QuestMemory/
├── QuestMemory.toc
├── Core.lua
├── docs/
│   ├── PRD.md
│   └── TESTING.md
└── README.md
```

## Data Structure

```lua
QuestMemoryDB = {
    ["CharacterName-RealmName"] = {
        [questID] = timestamp, -- when completed (0 for backfilled/unknown)
    },
    ["_questMeta"] = {
        [questID] = {
            flag = "recommended" or "not_recommended" or nil,
            note = "user note string",
            flaggedBy = "CharName-Realm",
            flaggedAt = timestamp,
            noteBy = "CharName-Realm",
        },
    },
    ["_dbVersion"] = 2,
}
```

## Features

### F1: Automatic Quest Tracking
- On QUEST_TURNED_IN event, store questID with current timestamp
- On PLAYER_LOGIN, backfill all completed quests using GetQuestsCompleted()
- Backfilled quests get timestamp of 0 (unknown completion time)
- Character key format: "CharName-RealmName"

### F2: Quest Log Tooltip Enhancement
- Hook quest log entry OnEnter to add info to GameTooltip
- Display flag status (if set) with color coding
- Display note (if set)
- Display list of other characters who completed the quest
- Sort characters by completion timestamp (most recent first)
- Show relative time (e.g., "2h ago", "3d ago", "Jan 15")
- Show quest ID in gray at bottom for reference
- Exclude current character from "completed by" list

### F3: Right-Click Context Menu
- Hook quest log entry OnClick for RightButton
- Use UIDropDownMenu for context menu
- Menu options:
  - Header showing quest name
  - "Mark as Recommended" (green checkmark)
  - "Mark as Skip/Avoid" (red warning)
  - "Clear Flag" (only if flagged)
  - "Add Note..." / "Edit Note..." (opens popup)
  - Note preview if exists (truncated to 40 chars)
  - "Print Quest Info" (outputs to chat)
  - "Cancel"
- Disable current flag option if already set

### F4: Note Input Popup
- Use StaticPopupDialogs for note entry
- Pre-fill existing note if editing
- Buttons: Save, Cancel, Clear Note
- Support Enter key to save
- Max 256 characters

### F5: Slash Commands
- /qm or /questmemory
- /qm - show help
- /qm count - show completed quest count for current character
- /qm chars - list all tracked characters with quest counts
- /qm info <questID> - show all data for a quest

### F6: Database Migration
- Track _dbVersion in saved variables
- Version 1: questID = true (boolean)
- Version 2: questID = timestamp (number)
- On load, migrate v1 to v2 by converting true to 0

## UI Specifications

### Tooltip Format
```
[Original tooltip content]

⚠ NOT RECOMMENDED (by CharName)
Note: User's note text here
Completed by:
  Thrall (2h ago)
  Garrosh (3d ago)
  Sylvanas
Quest ID: 12345
```

### Colors
- Addon name in chat: green #00ff00
- Recommended flag: green #44ff44
- Not recommended flag: red #ff4444
- Note label: yellow #ffcc00
- Completed by label: green #00ff00
- Timestamps/secondary text: gray #888888
- Quest ID: dark gray #666666
- Not completed message: orange #ff6600

### Time Formatting
- < 1 hour: "Xm ago"
- < 24 hours: "Xh ago"
- < 7 days: "Xd ago"
- >= 7 days: "Mon DD" format

## Events to Hook
- ADDON_LOADED: Initialize saved variables
- PLAYER_LOGIN: Run backfill
- QUEST_TURNED_IN: Track new completions

## API Functions Used
- GetQuestsCompleted()
- GetQuestLogTitle(questIndex)
- UnitName("player")
- GetRealmName()
- FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
- GameTooltip:AddLine()
- CreateFrame()
- UIDropDownMenu_Initialize/AddButton/CreateInfo
- StaticPopup_Show()
- time()
- date()

## Edge Cases to Handle
- Zone headers in quest log (not quests, no questID)
- Quest log scrolling (recalculate questIndex with offset)
- Characters with special/unicode names
- Empty database on first install
- Very long character lists
- Missing or nil questIDs
