-- QuestMemory: Track quest completions across all characters
-- Author: Tom
-- Version: 1.1.0

local ADDON_NAME = "QuestMemory"
local DB_VERSION = 2

-- ============================================================================
-- SECTION 1: Configuration & Constants
-- ============================================================================

local COLORS = {
    addon = "|cff00ff00",
    recommended = "|cff44ff44",
    notRecommended = "|cffff4444",
    note = "|cffffcc00",
    completedBy = "|cff00ff00",
    timestamp = "|cff888888",
    questId = "|cff666666",
    notCompleted = "|cffff6600",
}

-- Defaults: backfilled quests use timestamp 0, notes max 256 chars
local BACKFILL_TIMESTAMP = 0
local NOTE_MAX_LENGTH = 256
local NOTE_PREVIEW_LENGTH = 40

-- ============================================================================
-- SECTION 2: Local State
-- ============================================================================

local db = nil
local questMeta = nil
local playerKey = nil
local hooked = false

-- ============================================================================
-- SECTION 3: Utilities
-- ============================================================================

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(COLORS.addon .. "[QuestMemory]|r " .. tostring(msg))
    end
end

local function GetPlayerKey()
    if playerKey then return playerKey end
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm then
        playerKey = name .. "-" .. realm
    end
    return playerKey
end

local function ExtractCharName(charKey)
    if not charKey then return "Unknown" end
    return charKey:match("^([^-]+)") or charKey
end

local function FormatRelativeTime(timestamp)
    if not timestamp or timestamp == 0 then return nil end

    local diff = time() - timestamp
    if diff < 3600 then
        local mins = math.max(1, math.floor(diff / 60))
        return mins .. (mins == 1 and " min ago" or " mins ago")
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. (hours == 1 and " hour ago" or " hours ago")
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return days .. (days == 1 and " day ago" or " days ago")
    elseif diff < 2592000 then  -- ~30 days
        local weeks = math.floor(diff / 604800)
        return weeks .. (weeks == 1 and " week ago" or " weeks ago")
    elseif diff < 7776000 then  -- ~90 days
        local months = math.floor(diff / 2592000)
        return months .. (months == 1 and " month ago" or " months ago")
    else
        return "long ago"
    end
end

local function GetSettings()
    if not QuestMemoryDB then return { enabled = true, showTimestamps = true } end
    return QuestMemoryDB["_settings"] or { enabled = true, showTimestamps = true }
end

local function Truncate(str, maxLen)
    if not str then return nil end
    if #str <= maxLen then return str end
    return str:sub(1, maxLen - 3) .. "..."
end

-- ============================================================================
-- SECTION 4: SavedVariables & Migration
-- ============================================================================

local function MigrateDB()
    local version = db["_dbVersion"] or 1
    if version >= DB_VERSION then return end

    Print("Migrating database to version " .. DB_VERSION .. "...")

    -- v1 -> v2: Convert boolean quest entries to timestamps
    if version < 2 then
        for charKey, quests in pairs(db) do
            if type(quests) == "table" and charKey:sub(1, 1) ~= "_" then
                for questId, value in pairs(quests) do
                    if value == true then
                        quests[questId] = BACKFILL_TIMESTAMP
                    end
                end
            end
        end
    end

    db["_dbVersion"] = DB_VERSION
    Print("Migration complete.")
end

local function InitDB()
    QuestMemoryDB = QuestMemoryDB or {
        ["_dbVersion"] = DB_VERSION,
        ["_questMeta"] = {},
        ["_settings"] = { enabled = true, showTimestamps = true },
    }

    db = QuestMemoryDB
    questMeta = db["_questMeta"] or {}
    db["_questMeta"] = questMeta
    db["_settings"] = db["_settings"] or { enabled = true, showTimestamps = true }

    MigrateDB()

    local key = GetPlayerKey()
    if key then
        db[key] = db[key] or {}
    end
end

-- ============================================================================
-- SECTION 5: Quest Tracking (Events & Data)
-- ============================================================================

local function RecordQuest(questId, timestamp)
    local key = GetPlayerKey()
    if not key or not db or not questId then return end

    db[key] = db[key] or {}

    -- Only update if new, or upgrading from backfill to real timestamp
    local existing = db[key][questId]
    if not existing or (existing == 0 and timestamp and timestamp > 0) then
        db[key][questId] = timestamp or time()
    end
end

local function BackfillQuests()
    local completed = GetQuestsCompleted and GetQuestsCompleted()
    if not completed then return 0 end

    local key = GetPlayerKey()
    if not key or not db or not db[key] then return 0 end

    local count = 0
    for questId in pairs(completed) do
        if not db[key][questId] then
            db[key][questId] = BACKFILL_TIMESTAMP
            count = count + 1
        end
    end
    return count
end

local function GetQuestMeta(questId)
    return questMeta and questId and questMeta[questId]
end

local function SetQuestFlag(questId, flag)
    if not questMeta or not questId then return end

    questMeta[questId] = questMeta[questId] or {}
    questMeta[questId].flag = flag
    questMeta[questId].flaggedBy = GetPlayerKey()
    questMeta[questId].flaggedAt = time()

    Print(flag and ("Quest " .. questId .. " marked as " .. flag) or ("Flag cleared for quest " .. questId))
end

local function SetQuestNote(questId, note)
    if not questMeta or not questId then return end

    questMeta[questId] = questMeta[questId] or {}
    questMeta[questId].note = note
    questMeta[questId].noteBy = GetPlayerKey()

    Print(note and ("Note saved for quest " .. questId) or ("Note cleared for quest " .. questId))
end

local function GetOtherCharCompletions(questId)
    if not db or not questId then return {} end

    local currentKey = GetPlayerKey()
    local results = {}

    for charKey, quests in pairs(db) do
        if type(quests) == "table" and charKey:sub(1, 1) ~= "_" and charKey ~= currentKey then
            local ts = quests[questId]
            if ts then
                results[#results + 1] = { char = charKey, ts = ts }
            end
        end
    end

    -- Sort: real timestamps first (descending), then backfills alphabetically
    table.sort(results, function(a, b)
        if a.ts == 0 and b.ts == 0 then return a.char < b.char end
        if a.ts == 0 then return false end
        if b.ts == 0 then return true end
        return a.ts > b.ts
    end)

    return results
end

-- ============================================================================
-- SECTION 6: Tooltip Rendering
-- ============================================================================

local MAX_COMPLETIONS_SHOWN = 3

local function AddQuestInfoToTooltip(questId)
    if not questId or not GameTooltip then return end

    local settings = GetSettings()
    if not settings.enabled then return end

    GameTooltip:AddLine(" ")

    -- Flag
    local meta = GetQuestMeta(questId)
    if meta and meta.flag then
        local byWho = meta.flaggedBy and (" (by " .. ExtractCharName(meta.flaggedBy) .. ")") or ""
        if meta.flag == "recommended" then
            GameTooltip:AddLine(COLORS.recommended .. "RECOMMENDED" .. byWho .. "|r")
        elseif meta.flag == "not_recommended" then
            GameTooltip:AddLine(COLORS.notRecommended .. "NOT RECOMMENDED" .. byWho .. "|r")
        end
    end

    -- Note
    if meta and meta.note then
        GameTooltip:AddLine(COLORS.note .. "Note:|r " .. meta.note, 1, 1, 1, true)
    end

    -- Other character completions
    local completions = GetOtherCharCompletions(questId)
    if #completions > 0 then
        -- Single completion: inline format
        if #completions == 1 then
            local c = completions[1]
            local name = ExtractCharName(c.char)
            if settings.showTimestamps then
                local timeStr = FormatRelativeTime(c.ts)
                local line = timeStr and (name .. " " .. COLORS.timestamp .. "– " .. timeStr .. "|r") or name
                GameTooltip:AddLine(COLORS.completedBy .. "Completed by " .. line .. "|r")
            else
                GameTooltip:AddLine(COLORS.completedBy .. "Completed by " .. name .. "|r")
            end
        else
            -- Multiple completions: list format
            GameTooltip:AddLine(COLORS.completedBy .. "Completed by:|r")
            local shown = 0
            for i, c in ipairs(completions) do
                if shown >= MAX_COMPLETIONS_SHOWN then
                    local remaining = #completions - shown
                    GameTooltip:AddLine(COLORS.timestamp .. "  +" .. remaining .. " more|r")
                    break
                end
                local name = ExtractCharName(c.char)
                if settings.showTimestamps then
                    local timeStr = FormatRelativeTime(c.ts)
                    local line = timeStr and ("  " .. name .. " " .. COLORS.timestamp .. "– " .. timeStr .. "|r") or ("  " .. name)
                    GameTooltip:AddLine(line)
                else
                    GameTooltip:AddLine("  " .. name)
                end
                shown = shown + 1
            end
        end
    else
        GameTooltip:AddLine(COLORS.timestamp .. "No recorded completions|r")
    end

    -- Quest ID reference (subtle)
    GameTooltip:AddLine(COLORS.questId .. "Quest ID: " .. questId .. "|r")

    GameTooltip:Show()
end

-- ============================================================================
-- SECTION 7: Quest Log Hooks (Defensive)
-- ============================================================================

local function SafeGetQuestInfo(buttonIndex)
    -- Guard: check global exists
    if not QuestLogListScrollFrame then return nil, nil end

    local button = _G["QuestLogTitle" .. buttonIndex]
    if not button or not button:IsVisible() then return nil, nil end

    local id = button:GetID()
    if not id or id == 0 then return nil, nil end

    local offset = FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
    local questIndex = id + offset

    -- Guard: GetQuestLogTitle may not exist or return nil
    if not GetQuestLogTitle then return nil, nil end

    local questTitle, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(questIndex)

    -- Headers don't have quest IDs
    if isHeader or not questID then return nil, nil end

    return questID, questTitle
end

local originalHandlers = {}

local function HookQuestLogUI()
    if hooked then return end

    -- Guard: required globals
    if not QUESTS_DISPLAYED or not QuestLogListScrollFrame then return end

    for i = 1, QUESTS_DISPLAYED do
        local button = _G["QuestLogTitle" .. i]
        if button then
            -- Store originals once
            if not originalHandlers[button] then
                originalHandlers[button] = {
                    enter = button:GetScript("OnEnter"),
                    click = button:GetScript("OnClick"),
                }
            end

            -- OnEnter: add tooltip info
            button:SetScript("OnEnter", function(self, ...)
                local orig = originalHandlers[self] and originalHandlers[self].enter
                if orig then pcall(orig, self, ...) end

                local questId = SafeGetQuestInfo(self:GetID())
                if questId then
                    AddQuestInfoToTooltip(questId)
                end
            end)

            -- OnClick: intercept right-click for context menu
            button:SetScript("OnClick", function(self, mouseButton, ...)
                if mouseButton == "RightButton" then
                    local questId, questTitle = SafeGetQuestInfo(self:GetID())
                    if questId then
                        ShowContextMenu(questId, questTitle)
                        return
                    end
                end

                local orig = originalHandlers[self] and originalHandlers[self].click
                if orig then orig(self, mouseButton, ...) end
            end)
        end
    end

    hooked = true
end

local function RefreshHooks()
    -- Re-apply hooks on scroll or frame show
    hooked = false
    HookQuestLogUI()
end

-- ============================================================================
-- SECTION 8: Context Menu
-- ============================================================================

local QMDropDown = CreateFrame("Frame", "QuestMemoryDropDown", UIParent, "UIDropDownMenuTemplate")
local menuQuestId, menuQuestTitle = nil, nil

local function InitDropDown()
    if not menuQuestId then return end

    local meta = GetQuestMeta(menuQuestId) or {}
    local info

    -- Header
    info = UIDropDownMenu_CreateInfo()
    info.text = menuQuestTitle or ("Quest " .. menuQuestId)
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    -- Mark as Recommended
    info = UIDropDownMenu_CreateInfo()
    info.text = "Mark as Recommended"
    info.notCheckable = true
    info.disabled = (meta.flag == "recommended")
    info.func = function() SetQuestFlag(menuQuestId, "recommended") end
    UIDropDownMenu_AddButton(info)

    -- Mark as Skip/Avoid
    info = UIDropDownMenu_CreateInfo()
    info.text = "Mark as Skip/Avoid"
    info.notCheckable = true
    info.disabled = (meta.flag == "not_recommended")
    info.func = function() SetQuestFlag(menuQuestId, "not_recommended") end
    UIDropDownMenu_AddButton(info)

    -- Clear Flag
    if meta.flag then
        info = UIDropDownMenu_CreateInfo()
        info.text = "Clear Flag"
        info.notCheckable = true
        info.func = function() SetQuestFlag(menuQuestId, nil) end
        UIDropDownMenu_AddButton(info)
    end

    -- Separator
    info = UIDropDownMenu_CreateInfo()
    info.text = ""
    info.disabled = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    -- Add/Edit Note
    info = UIDropDownMenu_CreateInfo()
    info.text = meta.note and "Edit Note..." or "Add Note..."
    info.notCheckable = true
    info.func = function()
        StaticPopup_Show("QUESTMEMORY_NOTE_INPUT", nil, nil, {
            questId = menuQuestId,
            existingNote = meta.note,
        })
    end
    UIDropDownMenu_AddButton(info)

    -- Note preview
    if meta.note then
        info = UIDropDownMenu_CreateInfo()
        info.text = COLORS.timestamp .. "\"" .. Truncate(meta.note, NOTE_PREVIEW_LENGTH) .. "\"|r"
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)
    end

    -- Separator
    info = UIDropDownMenu_CreateInfo()
    info.text = ""
    info.disabled = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    -- Print Quest Info
    info = UIDropDownMenu_CreateInfo()
    info.text = "Print Quest Info"
    info.notCheckable = true
    info.func = function() PrintQuestInfo(menuQuestId) end
    UIDropDownMenu_AddButton(info)

    -- Cancel
    info = UIDropDownMenu_CreateInfo()
    info.text = CANCEL
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)
end

UIDropDownMenu_Initialize(QMDropDown, InitDropDown, "MENU")

function ShowContextMenu(questId, questTitle)
    menuQuestId = questId
    menuQuestTitle = questTitle
    ToggleDropDownMenu(1, nil, QMDropDown, "cursor", 0, 0)
end

-- ============================================================================
-- SECTION 9: Note Popup
-- ============================================================================

StaticPopupDialogs["QUESTMEMORY_NOTE_INPUT"] = {
    text = "Enter note for this quest:",
    button1 = "Save",
    button2 = "Cancel",
    button3 = "Clear Note",
    hasEditBox = true,
    maxLetters = NOTE_MAX_LENGTH,
    OnShow = function(self, data)
        self.editBox:SetText(data and data.existingNote or "")
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end,
    OnAccept = function(self, data)
        local text = self.editBox:GetText()
        if data and data.questId and text and #text > 0 then
            SetQuestNote(data.questId, text)
        end
    end,
    OnAlt = function(self, data)
        if data and data.questId then
            SetQuestNote(data.questId, nil)
        end
    end,
    EditBoxOnEnterPressed = function(self, data)
        local parent = self:GetParent()
        local text = parent.editBox:GetText()
        if data and data.questId and text and #text > 0 then
            SetQuestNote(data.questId, text)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ============================================================================
-- SECTION 10: Slash Commands
-- ============================================================================

function PrintQuestInfo(questId)
    questId = tonumber(questId)
    if not questId then
        Print("Usage: /qm info <questID>")
        return
    end

    Print("--- Quest ID: " .. questId .. " ---")

    local meta = GetQuestMeta(questId)
    if meta then
        if meta.flag then
            Print("Flag: " .. meta.flag .. (meta.flaggedBy and (" by " .. meta.flaggedBy) or ""))
        end
        if meta.note then
            Print("Note: " .. meta.note)
        end
    end

    local key = GetPlayerKey()
    local ts = key and db[key] and db[key][questId]
    if ts then
        local timeStr = FormatRelativeTime(ts)
        Print("Current character: completed" .. (timeStr and (" " .. timeStr) or ""))
    else
        Print("Current character: not completed")
    end

    local completions = GetOtherCharCompletions(questId)
    if #completions > 0 then
        Print("Other characters:")
        for _, c in ipairs(completions) do
            local timeStr = FormatRelativeTime(c.ts)
            Print("  " .. c.char .. (timeStr and (" (" .. timeStr .. ")") or ""))
        end
    end
end

local function ShowCount()
    local key = GetPlayerKey()
    if not key or not db or not db[key] then
        Print("No data for current character")
        return
    end

    local count = 0
    for _ in pairs(db[key]) do count = count + 1 end
    Print(key .. " has completed " .. count .. " tracked quests")
end

local function ShowChars()
    Print("--- Tracked Characters ---")
    local found = false
    for charKey, quests in pairs(db) do
        if type(quests) == "table" and charKey:sub(1, 1) ~= "_" then
            local count = 0
            for _ in pairs(quests) do count = count + 1 end
            Print(charKey .. ": " .. count .. " quests")
            found = true
        end
    end
    if not found then Print("No characters tracked yet") end
end

local function ClearAllData()
    StaticPopup_Show("QUESTMEMORY_CONFIRM_CLEAR")
end

local function ShowHelp()
    Print("Commands:")
    Print("  /qm - Show help")
    Print("  /qm config - Open options panel")
    Print("  /qm count - Quest count for this character")
    Print("  /qm chars - All tracked characters")
    Print("  /qm info <id> - Quest details")
    Print("  /qm clear - Clear all data")
    Print("Right-click quests in log for more options")
end

SLASH_QUESTMEMORY1 = "/qm"
SLASH_QUESTMEMORY2 = "/questmemory"
SlashCmdList["QUESTMEMORY"] = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()

    if cmd == "count" then ShowCount()
    elseif cmd == "chars" then ShowChars()
    elseif cmd == "info" then PrintQuestInfo(arg)
    elseif cmd == "clear" then ClearAllData()
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then
        InterfaceOptionsFrame_OpenToCategory("QuestMemory")
        InterfaceOptionsFrame_OpenToCategory("QuestMemory")  -- Called twice due to Blizzard bug
    else ShowHelp()
    end
end

-- ============================================================================
-- SECTION 11: Event Handling (Bootstrap)
-- ============================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_TURNED_IN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
        Print("v1.1.0 loaded. Type /qm for help.")

    elseif event == "PLAYER_LOGIN" then
        local count = BackfillQuests()
        if count > 0 then
            Print("Backfilled " .. count .. " quest completions")
        end

        -- Delay hook to let UI initialize
        C_Timer.After(0.5, HookQuestLogUI)

    elseif event == "QUEST_TURNED_IN" and arg1 then
        RecordQuest(arg1, time())
    end
end)

-- Re-hook on scroll/show (defensive: frames may not exist at load time)
C_Timer.After(1, function()
    if QuestLogListScrollFrame then
        QuestLogListScrollFrame:HookScript("OnVerticalScroll", RefreshHooks)
    end
    if QuestLogFrame then
        QuestLogFrame:HookScript("OnShow", function()
            C_Timer.After(0.1, RefreshHooks)
        end)
    end
end)
