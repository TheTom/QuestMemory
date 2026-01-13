# QuestMemory Testing Guide

## Prerequisites

- TBC Classic WoW client (Interface 20501)
- At least 2 characters for cross-character testing
- Access to quests at various completion states

## Test Cases

### T1: Addon Loading

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T1.1 | Install addon and log in | "[QuestMemory] Loaded. Type /qm for help." appears in chat | |
| T1.2 | First character login | Database created with character key | |
| T1.3 | Subsequent logins | No duplicate entries created | |

### T2: Automatic Quest Tracking

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T2.1 | Complete a new quest | Quest ID recorded with current timestamp | |
| T2.2 | Check with /qm count | Count increases by 1 | |
| T2.3 | Log out and back in | Quest still tracked (persisted) | |
| T2.4 | Backfill on login | Previously completed quests backfilled with timestamp 0 | |
| T2.5 | Backfill message | "Backfilled X quest completions" shows if new quests found | |

### T3: Tooltip Enhancement

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T3.1 | Hover over quest in log | Tooltip shows additional QuestMemory info | |
| T3.2 | Quest with no flags/notes | Shows "Not completed by other characters" if none, Quest ID at bottom | |
| T3.3 | Quest completed by alt | Shows alt character name in "Completed by:" section | |
| T3.4 | Quest with timestamp | Shows relative time (e.g., "2h ago") next to character | |
| T3.5 | Quest with flag | Flag displays with correct color and flaggedBy info | |
| T3.6 | Quest with note | Note displays in yellow | |
| T3.7 | Hover over zone header | No tooltip modification (headers are not quests) | |
| T3.8 | Scroll quest log and hover | Correct quest info shown for scrolled position | |

### T4: Time Formatting

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T4.1 | Quest completed < 1 hour ago | Shows "Xm ago" | |
| T4.2 | Quest completed 1-24 hours ago | Shows "Xh ago" | |
| T4.3 | Quest completed 1-7 days ago | Shows "Xd ago" | |
| T4.4 | Quest completed > 7 days ago | Shows "Mon DD" format (e.g., "Jan 15") | |
| T4.5 | Backfilled quest (timestamp 0) | No time shown, just character name | |

### T5: Right-Click Context Menu

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T5.1 | Right-click quest in log | Context menu appears at cursor | |
| T5.2 | Menu header | Shows quest title | |
| T5.3 | Click "Mark as Recommended" | Quest flagged, message in chat | |
| T5.4 | Already recommended | "Mark as Recommended" option disabled | |
| T5.5 | Click "Mark as Skip/Avoid" | Quest flagged as not_recommended | |
| T5.6 | Click "Clear Flag" | Flag removed, option disappears from menu | |
| T5.7 | Click "Add Note..." | Note popup appears | |
| T5.8 | Existing note | Shows "Edit Note..." and note preview | |
| T5.9 | Long note preview | Truncated to 40 chars with "..." | |
| T5.10 | Click "Print Quest Info" | Quest info printed to chat | |
| T5.11 | Click "Cancel" | Menu closes | |
| T5.12 | Right-click zone header | No menu (not a quest) | |

### T6: Note Input Popup

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T6.1 | Open Add Note | Empty edit box, focused | |
| T6.2 | Open Edit Note | Existing note pre-filled and highlighted | |
| T6.3 | Type and click Save | Note saved, confirmation in chat | |
| T6.4 | Press Enter | Note saved (same as Save button) | |
| T6.5 | Press Escape | Popup closes, no changes | |
| T6.6 | Click Cancel | Popup closes, no changes | |
| T6.7 | Click Clear Note | Note removed, confirmation in chat | |
| T6.8 | Very long note (>256 chars) | Input limited to 256 characters | |

### T7: Slash Commands

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T7.1 | /qm | Shows help text | |
| T7.2 | /questmemory | Same as /qm | |
| T7.3 | /qm count | Shows quest count for current character | |
| T7.4 | /qm chars | Lists all tracked characters with quest counts | |
| T7.5 | /qm info 12345 | Shows all data for quest 12345 | |
| T7.6 | /qm info (no ID) | Shows usage message | |
| T7.7 | /qm info abc | Shows "Invalid quest ID" | |
| T7.8 | /qm unknown | Shows help (unknown command) | |

### T8: Database Migration

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T8.1 | Fresh install | DB version set to 2 | |
| T8.2 | Simulate v1 data (questID = true) | On load, migrated to questID = 0 | |
| T8.3 | Migration message | "Migrating database..." and "Migration complete." shown | |
| T8.4 | Already v2 | No migration runs | |

### T9: Multi-Character

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T9.1 | Complete quest on Char A | Recorded for Char A | |
| T9.2 | Log in as Char B, check same quest | Tooltip shows "Completed by: CharA" | |
| T9.3 | Complete same quest on Char B | Now shows Char A in tooltip (not self) | |
| T9.4 | Multiple alts completed | All shown, sorted by most recent | |
| T9.5 | Flag set by Char A | Visible on Char B with "by CharA" | |

### T10: Edge Cases

| ID | Test | Expected Result | Status |
|----|------|-----------------|--------|
| T10.1 | Empty quest log | No errors when opening quest log | |
| T10.2 | Quest log with only headers | No tooltip modifications for headers | |
| T10.3 | Special characters in realm name | Character key correctly formed | |
| T10.4 | Very long character list (10+ alts) | All displayed, no truncation | |
| T10.5 | Quest with nil ID | Gracefully handled, no error | |
| T10.6 | Rapid scrolling | No errors, correct quests shown | |

## Manual Verification Checklist

### Visual Checks
- [ ] Tooltip doesn't overflow screen
- [ ] Colors are readable on default UI
- [ ] Context menu positioned correctly
- [ ] Note popup centered properly

### Performance Checks
- [ ] No noticeable lag when opening quest log
- [ ] Scrolling is smooth
- [ ] No memory warnings in /console errors

### Persistence Checks
- [ ] Data survives logout/login
- [ ] Data survives /reload
- [ ] Data survives client restart
- [ ] SavedVariables file exists in WTF folder

## Debugging Commands

```
/dump QuestMemoryDB
/dump QuestMemoryDB["_questMeta"]
/dump QuestMemoryDB["CharName-RealmName"]
/console scriptErrors 1
```

## Test Data Setup

To manually create test data for development:

```lua
-- In-game via /run or dev console
QuestMemoryDB = {
    ["TestChar-TestRealm"] = {
        [12345] = 1704067200, -- Jan 1, 2024
        [12346] = 0,          -- Unknown time
    },
    ["AltChar-TestRealm"] = {
        [12345] = 1704153600, -- Jan 2, 2024
    },
    ["_questMeta"] = {
        [12345] = {
            flag = "recommended",
            note = "Great quest for XP!",
            flaggedBy = "TestChar-TestRealm",
            flaggedAt = 1704067200,
            noteBy = "TestChar-TestRealm",
        },
    },
    ["_dbVersion"] = 2,
}
```
