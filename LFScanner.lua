LFScanner = {}
LFScanner.raidWidgets = {}
LFScanner.lastAlerts = {}

-- Pre-filled Database
local defaultDB = {
    enabled = true,
    role = "DPS",
    minimapPos = 45,
    history = {},
    mutedPlayers = {},
    roles = {
        ["DPS"]  = { "DPS", "DD", "DAMAGE", "MELEE" },
        ["RDPS"] = { "RDPS", "RANGED", "HUNTER", "MAGE", "LOCK", "CASTER", "WARLOCK" },
        ["TANK"] = { "TANK", "MT", "OT" },
        ["HEAL"] = { "HEAL", "HEALER", "HEALS" },
    },
    raids = {
        ["MOLTEN CORE"] = { enabled = true, keywords = { "MC", "MOLTEN CORE", "MC40", "MC25", "MC20" } },
        ["ONYXIA"] = { enabled = true, keywords = { "ONYXIA", "ONY", "ONY10", "ONY20", "ONY40" } },
        ["EMERALD SANCTUM NM"] = { enabled = true, keywords = { "ES ", "ES NM", "EMERALD SANCTUM NORMAL", "SANCTUM NM" } },
        ["RUINS OF AQ"] = { enabled = true, keywords = { "AQ15", "AQ20", "AQ RUINS", "RAQ" } },
        ["ZUL'GURUB"] = { enabled = true, keywords = { "ZG", "ZULGURUB", "ZG10", "ZG20" } },
        ["KARAZHAN 10"] = { enabled = true, keywords = { "K10", "KARA10", "KARAZHAN HALLS", "LOWER KARA", "KARA " } },
    },
}

-------------------------------------------------------
-- Utils
-------------------------------------------------------
local function ContainsAny(msg, list)
    if not list then return false end
    for _, k in ipairs(list) do
        if k and string.find(msg, k, 1, true) then return true end
    end
    return false
end

local function IsRecruitment(msg)
    if (string.find(msg, "LFG") or string.find(msg, "LOOKING FOR GROUP")) and
        not (string.find(msg, "LFM") or string.find(msg, "NEED")) then
        return false
    end
    if string.find(msg, "ES HM") or string.find(msg, "SANCTUM HM") then return false end
    return ContainsAny(msg, { "LFM", "NEED", "LF ", "RECRUIT" })
end

local function IsMuted(name)
    if not LFScannerDB or not LFScannerDB.mutedPlayers or not LFScannerDB.mutedPlayers[name] then return false end
    if GetTime() > LFScannerDB.mutedPlayers[name] then
        LFScannerDB.mutedPlayers[name] = nil
        return false
    end
    return true
end

-------------------------------------------------------
-- Minimap Button Logic
-------------------------------------------------------
function LFScanner:UpdateMinimapPosition()
    local angle = LFScannerDB.minimapPos or 45
    local x, y = 80 * cos(angle), 80 * sin(angle)
    LFScannerMinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function LFScanner:UpdateMinimapIcon()
    if not LFScannerMinimapButton or not LFScannerMinimapButton.icon then return end
    if LFScannerDB.enabled then
        LFScannerMinimapButton.icon:SetTexture("Interface\\Icons\\Spell_Holy_PrayerOfHealing")
        LFScannerMinimapButton.icon:SetVertexColor(1, 1, 1)
    else
        LFScannerMinimapButton.icon:SetTexture("Interface\\Icons\\Spell_Shadow_Shadowform")
        LFScannerMinimapButton.icon:SetVertexColor(0.5, 0.5, 0.5)
    end
end

function LFScanner:CreateMinimapButton()
    local b = CreateFrame("Button", "LFScannerMinimapButton", Minimap)
    b:SetWidth(31)
    b:SetHeight(31)
    b:SetFrameStrata("MEDIUM")
    b:SetPoint("CENTER", Minimap, "CENTER", -80, 0)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", 0, 0)
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(52)
    border:SetHeight(52)
    border:SetPoint("TOPLEFT", 0, 0)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function() LFScanner:ToggleUI() end)

    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("LFScanner")
        local status = LFScannerDB.enabled and "|cff00ff00Scanning|r" or "|cffff0000Paused|r"
        GameTooltip:AddLine("Status: " .. status)
        local mCount = 0
        if LFScannerDB.mutedPlayers then
            for n, _ in pairs(LFScannerDB.mutedPlayers) do
                if IsMuted(n) then mCount = mCount + 1 end
            end
        end
        if mCount > 0 then GameTooltip:AddLine("Muted Players: |cffffffff" .. mCount .. "|r") end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function()
        this:SetScript("OnUpdate", function()
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            xpos = xmin - xpos / Minimap:GetEffectiveScale() + 70
            ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70
            LFScannerDB.minimapPos = math.deg(math.atan2(ypos, xpos))
            LFScanner:UpdateMinimapPosition()
        end)
    end)
    b:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
    self:UpdateMinimapPosition()
    self:UpdateMinimapIcon()
end

-------------------------------------------------------
-- UI & History
-------------------------------------------------------
function LFScanner:ToggleUI()
    if not self.frame then self:BuildUI() end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:UpdateToggleButton()
        self:RebuildRaidList()
        self:UpdateHistoryDisplay()
    end
end

function LFScanner:UpdateHistoryDisplay()
    if not self.historyText then return end
    local historyStr = ""
    for i, entry in ipairs(LFScannerDB.history) do
        local color = IsMuted(entry.sender) and "|cff888888" or "|cffffffff"
        historyStr = historyStr ..
            "|cffffff00[" .. entry.time .. "]|r " .. color .. entry.sender .. ": " .. entry.msg .. "|r\n"
    end
    if historyStr == "" then historyStr = "No history yet..." end
    self.historyText:SetText(historyStr)
end

function LFScanner:Alert(sender, msg, raidName)
    local key = sender .. raidName
    if self.lastAlerts[key] and (GetTime() - self.lastAlerts[key] < 60) then return end
    self.lastAlerts[key] = GetTime()

    if RaidWarningFrame then
        RaidWarningFrame:AddMessage("LFScanner: " .. sender, 1.0, 0.5, 0.0, 1.0, 5)
    else
        UIErrorsFrame:AddMessage("LFScanner: " .. sender, 1.0, 0.1, 0.1, 1.0, 5)
    end
    PlaySoundFile("Sound\\Interface\\RaidWarning.wav")

    local t = date("%H:%M")
    table.insert(LFScannerDB.history, 1, { time = t, sender = sender, msg = msg })
    if table.getn(LFScannerDB.history) > 7 then table.remove(LFScannerDB.history) end
    if self.frame and self.frame:IsShown() then self:UpdateHistoryDisplay() end

    local chatMsg = "|cff00ff00[LFScanner]|r [|Hplayer:" .. sender .. "|h|cffffff00" .. sender .. "|h|r]: " .. msg
    DEFAULT_CHAT_FRAME:AddMessage(chatMsg)
end

function LFScanner:BuildUI()
    if self.frame then return end
    if not LFScannerDB then LFScannerDB = defaultDB end

    local f = CreateFrame("Frame", "LFScannerMainFrame", UIParent)
    self.frame = f
    f:SetWidth(400)
    f:SetHeight(580)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    tinsert(UISpecialFrames, "LFScannerMainFrame")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("LFScanner Config")

    local closeBtn = CreateFrame("Button", "LFScannerCloseBtn", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local toggleBtn = CreateFrame("Button", "LFScannerToggleBtn", f, "UIPanelButtonTemplate")
    toggleBtn:SetWidth(80)
    toggleBtn:SetHeight(22)
    toggleBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -15)
    self.toggleBtn = toggleBtn
    toggleBtn:SetScript("OnClick", function()
        LFScannerDB.enabled = not LFScannerDB.enabled
        LFScanner:UpdateToggleButton()
    end)

    -- History Controls
    local hTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hTitle:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 25, 230)
    hTitle:SetText("History:")

    local muteLast = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    muteLast:SetWidth(80)
    muteLast:SetHeight(18)
    muteLast:SetPoint("LEFT", hTitle, "RIGHT", 5, 0)
    muteLast:SetText("Mute Last")
    muteLast:SetScript("OnClick", function()
        if LFScannerDB.history[1] then
            local name = LFScannerDB.history[1].sender
            LFScannerDB.mutedPlayers[name] = GetTime() + 3600
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00LFScanner:|r Muted |cffffff00" .. name .. "|r for 1 hour.")
            LFScanner:UpdateHistoryDisplay()
        end
    end)

    local clearHistory = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearHistory:SetWidth(80)
    clearHistory:SetHeight(18)
    clearHistory:SetPoint("LEFT", muteLast, "RIGHT", 5, 0)
    clearHistory:SetText("Clear Log")
    clearHistory:SetScript("OnClick", function()
        LFScannerDB.history = {}
        LFScanner:UpdateHistoryDisplay()
    end)

    local clearMutes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearMutes:SetWidth(80)
    clearMutes:SetHeight(18)
    clearMutes:SetPoint("LEFT", clearHistory, "RIGHT", 5, 0)
    clearMutes:SetText("Unmute All")
    clearMutes:SetScript("OnClick", function()
        LFScannerDB.mutedPlayers = {}
        LFScanner:UpdateHistoryDisplay()
    end)

    -- History Display
    local hFrame = CreateFrame("Frame", nil, f)
    hFrame:SetWidth(350)
    hFrame:SetHeight(150)
    hFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 70)
    hFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile =
        "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    hFrame:SetBackdropColor(0, 0, 0, 0.8)

    local hText = hFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hText:SetPoint("TOPLEFT", 10, -10)
    hText:SetWidth(330)
    hText:SetJustifyH("LEFT")
    hText:SetJustifyV("TOP")
    self.historyText = hText

    local dropDown = CreateFrame("Frame", "LFScannerRoleDropDown", f, "UIDropDownMenuTemplate")
    dropDown:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    UIDropDownMenu_SetWidth(120, dropDown)
    UIDropDownMenu_Initialize(dropDown, function()
        local roleOrder = { "DPS", "RDPS", "TANK", "HEAL" }
        for _, role in ipairs(roleOrder) do
            local info = {
                text = role,
                value = role,
                func = function()
                    LFScannerDB.role = this.value
                    UIDropDownMenu_SetSelectedValue(LFScannerRoleDropDown, this.value)
                    UIDropDownMenu_SetText(this.value, LFScannerRoleDropDown)
                end
            }
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(dropDown, LFScannerDB.role)
    UIDropDownMenu_SetText(LFScannerDB.role, dropDown)

    local nameEdit = CreateFrame("EditBox", "LFScannerNameInput", f, "InputBoxTemplate")
    nameEdit:SetWidth(120)
    nameEdit:SetHeight(20)
    nameEdit:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 25, 30)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetText("RAID NAME")

    local keyEdit = CreateFrame("EditBox", "LFScannerKeyInput", f, "InputBoxTemplate")
    keyEdit:SetWidth(150)
    keyEdit:SetHeight(20)
    keyEdit:SetPoint("LEFT", nameEdit, "RIGHT", 10, 0)
    keyEdit:SetAutoFocus(false)
    keyEdit:SetText("KEY1,KEY2")

    local addBtn = CreateFrame("Button", "LFScannerAddBtn", f, "UIPanelButtonTemplate")
    addBtn:SetWidth(60)
    addBtn:SetHeight(22)
    addBtn:SetPoint("LEFT", keyEdit, "RIGHT", 10, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local name = string.upper(LFScannerNameInput:GetText() or "")
        local keyText = LFScannerKeyInput:GetText() or ""
        if name == "" or name == "RAID NAME" then return end
        local keys = {}
        for w in string.gmatch(keyText, "[^,]+") do
            local clean = string.upper(string.gsub(w, "^%s*(.-)%s*$", "%1"))
            if clean ~= "" then table.insert(keys, clean) end
        end
        LFScannerDB.raids[name] = { enabled = true, keywords = keys }
        LFScanner:RebuildRaidList()
    end)
    f:Hide()
end

function LFScanner:UpdateToggleButton()
    if not self.toggleBtn then return end
    if LFScannerDB.enabled then
        self.toggleBtn:SetText("PAUSE")
        local txt = self.toggleBtn:GetFontString()
        if txt then txt:SetTextColor(0, 1, 0) end
    else
        self.toggleBtn:SetText("START")
        local txt = self.toggleBtn:GetFontString()
        if txt then txt:SetTextColor(1, 0, 0) end
    end
    self:UpdateMinimapIcon()
end

function LFScanner:RebuildRaidList()
    if not self.frame then return end
    if self.raidWidgets then for _, w in ipairs(self.raidWidgets) do w:Hide() end end
    self.raidWidgets = {}
    local y = -80
    for name, raid in pairs(LFScannerDB.raids) do
        local currentName = name
        local cb = CreateFrame("CheckButton", "LFScannerCB_" .. currentName, self.frame, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 25, y)
        cb:SetChecked(raid.enabled)
        cb:SetScript("OnClick", function() LFScannerDB.raids[currentName].enabled = this:GetChecked() end)
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        text:SetText(currentName)
        local del = CreateFrame("Button", "LFScannerDelBtn_" .. currentName, self.frame, "UIPanelButtonTemplate")
        del:SetWidth(40)
        del:SetHeight(18)
        del:SetPoint("LEFT", text, "RIGHT", 10, 0)
        del:SetText("Del")
        del:SetScript("OnClick", function()
            LFScannerDB.raids[currentName] = nil
            LFScanner:RebuildRaidList()
        end)
        table.insert(self.raidWidgets, cb)
        table.insert(self.raidWidgets, del)
        y = y - 26
    end
end

-------------------------------------------------------
-- Event Handler
-------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("VARIABLES_LOADED")
ef:RegisterEvent("CHAT_MSG_CHANNEL")
ef:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if not LFScannerDB then
            LFScannerDB = defaultDB
        else
            if not LFScannerDB.history then LFScannerDB.history = {} end
            if not LFScannerDB.mutedPlayers then LFScannerDB.mutedPlayers = {} end
            for k, v in pairs(defaultDB.roles) do if not LFScannerDB.roles[k] then LFScannerDB.roles[k] = v end end
            for k, v in pairs(defaultDB.raids) do if not LFScannerDB.raids[k] then LFScannerDB.raids[k] = v end end
        end
        LFScanner:CreateMinimapButton()
    end
    if event == "CHAT_MSG_CHANNEL" then
        if not LFScannerDB or not LFScannerDB.enabled then return end
        local msg, sender, channelName = arg1, arg2, arg9
        if channelName and string.lower(channelName) == "world" then
            if IsMuted(sender) then return end
            local text = string.upper(msg)
            if string.find(text, "ES HM") or string.find(text, "SANCTUM HM") then return end
            local matchedRaid = nil
            for rName, rData in pairs(LFScannerDB.raids) do
                if rData.enabled and ContainsAny(text, rData.keywords) then
                    matchedRaid = rName
                    break
                end
            end
            if matchedRaid and IsRecruitment(text) then
                local roleKeywords = LFScannerDB.roles[LFScannerDB.role]
                if string.find(text, "NEED ALL") or (roleKeywords and ContainsAny(text, roleKeywords)) then
                    LFScanner:Alert(sender, msg, matchedRaid)
                end
            end
        end
    end
end)

SLASH_LFSCANNER1 = "/lfscanner"
SlashCmdList["LFSCANNER"] = function() LFScanner:ToggleUI() end
