# QuestMemory

Track which quests your alts have already done.

## What It Does

Hover over any quest in your quest log to see:
- Which of your other characters completed it
- When they finished it
- Any flags or notes you've added

Right-click quests to mark them as "Recommended" or "Skip" and add personal notes.

## Install

1. Copy the `QuestMemory` folder to:
   ```
   World of Warcraft/_classic_/Interface/AddOns/
   ```
2. Restart WoW or type `/reload`

## Usage

**Hover** over a quest to see alt completion info.

**Right-click** a quest for options:
- Mark as Recommended
- Mark as Skip/Avoid
- Add/Edit Note
- Print Quest Info (to chat)

**Commands:**
- `/qm` - Help
- `/qm count` - Your quest count
- `/qm chars` - All tracked characters
- `/qm info 12345` - Details for quest ID 12345

## How It Works

When you turn in quests, QuestMemory saves the quest ID. On login, it also picks up quests you've already finished. All characters on your account share the same data file.

## Requirements

TBC Classic (Interface 20501)
