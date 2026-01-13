--[[
    QuestMemory - Options Panel
    TBC Classic 2.5.x compatible

    Uses ONLY:
    - InterfaceOptionsFrame
    - InterfaceOptions_AddCategory
    - Basic frames, checkboxes
]]

local ADDON_NAME = "QuestMemory"

--------------------------------------------------------------------------------
-- Create Panel
--------------------------------------------------------------------------------

local panel = CreateFrame("Frame", "QuestMemoryOptionsPanel")
panel.name = "QuestMemory"

-- Title
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("QuestMemory")

-- Subtitle
local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Track quest completions across all characters")

--------------------------------------------------------------------------------
-- Enable Tooltips Checkbox
--------------------------------------------------------------------------------

local enableCheck = CreateFrame("CheckButton", "QMEnableCheck", panel, "InterfaceOptionsCheckButtonTemplate")
enableCheck:SetPoint("TOPLEFT", 16, -60)
enableCheck.Text:SetText("Enable QuestMemory tooltips")

enableCheck:SetScript("OnClick", function(self)
    if QuestMemoryDB then
        QuestMemoryDB["_settings"] = QuestMemoryDB["_settings"] or {}
        QuestMemoryDB["_settings"].enabled = self:GetChecked() and true or false
    end
end)

--------------------------------------------------------------------------------
-- Show Timestamps Checkbox
--------------------------------------------------------------------------------

local timestampCheck = CreateFrame("CheckButton", "QMTimestampCheck", panel, "InterfaceOptionsCheckButtonTemplate")
timestampCheck:SetPoint("TOPLEFT", 16, -90)
timestampCheck.Text:SetText("Show completion timestamps")

timestampCheck:SetScript("OnClick", function(self)
    if QuestMemoryDB then
        QuestMemoryDB["_settings"] = QuestMemoryDB["_settings"] or {}
        QuestMemoryDB["_settings"].showTimestamps = self:GetChecked() and true or false
    end
end)

--------------------------------------------------------------------------------
-- Clear Data Button
--------------------------------------------------------------------------------

local actionsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
actionsLabel:SetPoint("TOPLEFT", 16, -140)
actionsLabel:SetText("Data Management:")

local clearBtn = CreateFrame("Button", "QMClearBtn", panel, "UIPanelButtonTemplate")
clearBtn:SetPoint("TOPLEFT", 16, -160)
clearBtn:SetSize(180, 22)
clearBtn:SetText("Clear All Data")
clearBtn:SetScript("OnClick", function()
    StaticPopup_Show("QUESTMEMORY_CONFIRM_CLEAR")
end)

local clearHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
clearHint:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -4)
clearHint:SetText("Removes all tracked quest data (requires reload)")
clearHint:SetTextColor(0.5, 0.5, 0.5)

--------------------------------------------------------------------------------
-- Clear Confirmation Dialog
--------------------------------------------------------------------------------

StaticPopupDialogs["QUESTMEMORY_CONFIRM_CLEAR"] = {
    text = "Clear ALL QuestMemory data?\n\nThis will remove all tracked quest completions for all characters.",
    button1 = "Clear All",
    button2 = "Cancel",
    OnAccept = function()
        QuestMemoryDB = {
            ["_dbVersion"] = 2,
            ["_questMeta"] = {},
            ["_settings"] = QuestMemoryDB and QuestMemoryDB["_settings"] or { enabled = true, showTimestamps = true },
        }
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[QuestMemory]|r All data cleared. /reload to refresh.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

--------------------------------------------------------------------------------
-- Panel Refresh
--------------------------------------------------------------------------------

panel:SetScript("OnShow", function()
    if QuestMemoryDB then
        local settings = QuestMemoryDB["_settings"] or {}
        enableCheck:SetChecked(settings.enabled ~= false)  -- Default true
        timestampCheck:SetChecked(settings.showTimestamps ~= false)  -- Default true
    else
        enableCheck:SetChecked(true)
        timestampCheck:SetChecked(true)
    end
end)

--------------------------------------------------------------------------------
-- Register with Blizzard Interface Options
--------------------------------------------------------------------------------

InterfaceOptions_AddCategory(panel)
