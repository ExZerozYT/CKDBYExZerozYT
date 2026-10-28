-- ============================================================================
-- CKD Smart Cluster Slot Macro (Robust Placement + Distributed Upgrade + Auto Ability)
-- UI redesign: ส่วน logic เดิมไม่ได้แก้ไข
-- ============================================================================
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. รอเกมและ LocalPlayer โหลดเสร็จสมบูรณ์
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.2)
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 30) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
assert(PlayerGui, "Failed to load PlayerGui")

local CONFIG_FILE_NAME = "CKD_SlotLogic_settings.json"

-- ป้องกันรันซ้อน
if _G.CKD_SlotMacro_Running then
    _G.CKD_SlotMacro_Running = false
    task.wait(0.5)
end
_G.CKD_SlotMacro_Running = true

local oldUI = PlayerGui:FindFirstChild("SlotLogicUI")
if oldUI then
    oldUI:Destroy()
end

-- Remote Act สำหรับยิงสกิล
local MatchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 10)
local ActRemote = MatchRemotes and MatchRemotes:WaitForChild("Act", 10)

-- ============================================================================
-- 3. Settings Manager (Auto-Save JSON)
-- ============================================================================
local DefaultSettings = {
    MasterSwitch = true,
    AutoStartWave = true,
    AutoAbility = true,
    AutoReplay = false,
    AutoReturnHub = false,
    WebhookEnabled = false,
    WebhookUrl = "",
    Slots = {
        [1] = { TargetCount = 0, TargetLevel = 0 },
        [2] = { TargetCount = 0, TargetLevel = 0 },
        [3] = { TargetCount = 0, TargetLevel = 0 },
        [4] = { TargetCount = 0, TargetLevel = 0 },
        [5] = { TargetCount = 0, TargetLevel = 0 },
        [6] = { TargetCount = 0, TargetLevel = 0 },
    }
}

local Settings = table.clone(DefaultSettings)

local function SaveSettings()
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(Settings)
    end)
    if success and encoded then
        pcall(function()
            if writefile then
                writefile(CONFIG_FILE_NAME, encoded)
            end
        end)
    end
end

local function LoadSettings()
    if isfile and readfile and isfile(CONFIG_FILE_NAME) then
        local success, content = pcall(function()
            return readfile(CONFIG_FILE_NAME)
        end)
        if success and content then
            local decodeSuccess, parsed = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if decodeSuccess and type(parsed) == "table" then
                for k, v in pairs(parsed) do
                    Settings[k] = v
                end
            end
        end
    end
end

LoadSettings()

-- ============================================================================
-- 6. Anti-AFK
-- ============================================================================
if not _G.CKD_AntiAFK_Installed then
    _G.CKD_AntiAFK_Installed = true
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)
end

-- ============================================================================
-- 1 & 4. Game Controller & Slot Detection Engine
-- ============================================================================
local function GetGameController()
    local candyGui = PlayerGui:FindFirstChild("CandyTD")
    if not candyGui then return nil end
    for _, child in ipairs(candyGui:GetChildren()) do
        if child.Name:find("Card$") and child:IsA("GuiButton") then
            local conns = getconnections and getconnections(child.Activated)
            if conns and #conns > 0 and conns[1].Function then
                local u = debug.getupvalues(conns[1].Function)
                if u and u[1] and type(u[1]) == "table" and u[1].net then
                    return u[1]
                end
            end
        end
    end
    return nil
end

local function GetSlotUnits()
    local gc = GetGameController()
    if gc and gc.slots and #gc.slots > 0 then
        return gc.slots
    end

    local candyGui = PlayerGui:FindFirstChild("CandyTD")
    if candyGui then
        local cards = {}
        for _, c in ipairs(candyGui:GetChildren()) do
            if c.Name:find("Card$") and c:IsA("GuiObject") then
                table.insert(cards, c)
            end
        end
        table.sort(cards, function(a, b)
            return a.AbsolutePosition.X < b.AbsolutePosition.X
        end)
        local names = {}
        for _, c in ipairs(cards) do
            local cleanName = c.Name:gsub("Card$", "")
            table.insert(names, cleanName)
        end
        return names
    end

    return {}
end

local function GetPlacedTowers(gc)
    if not gc or not gc.net or not gc.net.place then return {} end
    local u = debug.getupvalues(gc.net.place)
    local state = u and u[3]
    local towers = {}
    if state and state.towers then
        for id, t in pairs(state.towers) do
            if t.owner == gc.me then
                table.insert(towers, t)
            end
        end
    end
    return towers
end

local function GetReliableSpot(gc, unitKind)
    if gc.goodSpot then
        local base = gc.goodSpot(unitKind)
        if base then return base end
    end
    return nil
end

-- ============================================================================
-- 2. GUI Interface (Redesigned: แบ่งกลุ่มชัด, สวิตช์ on/off, ตัวนับ − / +)
-- ============================================================================
local COLORS = {
    bg = Color3.fromRGB(24, 26, 32),
    header = Color3.fromRGB(30, 32, 40),
    card = Color3.fromRGB(35, 38, 47),
    field = Color3.fromRGB(46, 50, 61),
    stroke = Color3.fromRGB(58, 62, 75),
    text = Color3.fromRGB(240, 242, 247),
    muted = Color3.fromRGB(142, 148, 163),
    accent = Color3.fromRGB(59, 130, 246),
    success = Color3.fromRGB(34, 197, 94),
    off = Color3.fromRGB(72, 76, 90),
    knob = Color3.fromRGB(255, 255, 255),
}

local function MakeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlotLogicUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 520)
MainFrame.Position = UDim2.new(0.02, 0, 0.20, 0)
MainFrame.BackgroundColor3 = COLORS.bg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
MakeCorner(MainFrame, 12)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = COLORS.stroke
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- Draggable
do
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput then
            local delta = dragInput.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Header
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 52)
TitleBar.BackgroundColor3 = COLORS.header
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "Smart Cluster Slot Macro"
TitleLabel.TextColor3 = COLORS.text
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.Size = UDim2.new(1, -64, 0, 22)
TitleLabel.Position = UDim2.new(0, 16, 0, 9)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local SubLabel = Instance.new("TextLabel")
SubLabel.Text = "CKD auto slot placement"
SubLabel.TextColor3 = COLORS.muted
SubLabel.Font = Enum.Font.Gotham
SubLabel.TextSize = 11
SubLabel.Size = UDim2.new(1, -64, 0, 14)
SubLabel.Position = UDim2.new(0, 16, 0, 30)
SubLabel.BackgroundTransparency = 1
SubLabel.TextXAlignment = Enum.TextXAlignment.Left
SubLabel.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "-"
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -40, 0, 11)
MinBtn.BackgroundColor3 = COLORS.field
MinBtn.TextColor3 = COLORS.text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.AutoButtonColor = true
MinBtn.Parent = TitleBar
MakeCorner(MinBtn, 8)

local isMin = false
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 340, 0, isMin and 52 or 520)
    }):Play()
    MinBtn.Text = isMin and "+" or "-"
end)

-- Content
local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Size = UDim2.new(1, 0, 1, -52)
ContentScroll.Position = UDim2.new(0, 0, 0, 52)
ContentScroll.BackgroundTransparency = 1
ContentScroll.BorderSizePixel = 0
ContentScroll.ScrollBarThickness = 3
ScrollBarImageColor3 = COLORS.stroke
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentScroll.Parent = MainFrame

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingLeft = UDim.new(0, 12)
ContentPadding.PaddingRight = UDim.new(0, 12)
ContentPadding.PaddingTop = UDim.new(0, 6)
ContentPadding.PaddingBottom = UDim.new(0, 14)
ContentPadding.Parent = ContentScroll

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 8)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ContentScroll

-- Status
local StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, 0, 0, 44)
StatusBar.BackgroundColor3 = COLORS.card
StatusBar.TextColor3 = COLORS.muted
StatusBar.Font = Enum.Font.GothamMedium
StatusBar.TextSize = 12
StatusBar.TextXAlignment = Enum.TextXAlignment.Left
StatusBar.Text = "Status: ⏳ Initializing (Delay 12s)..."
StatusBar.LayoutOrder = 1
StatusBar.Parent = ContentScroll
MakeCorner(StatusBar, 10)

local StatusPadding = Instance.new("UIPadding")
StatusPadding.PaddingLeft = UDim.new(0, 14)
StatusPadding.PaddingRight = UDim.new(0, 14)
StatusPadding.Parent = StatusBar

local function MakeSectionLabel(text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = COLORS.muted
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = ContentScroll
    return l
end

-- สวิตช์แบบ on/off ใช้ได้ทั้ง Master และ Toggle ทั่วไป
local function MakeSwitchRow(labelText, onColor, getState, onToggle, order, isBold)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = COLORS.card
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = order
    row.Parent = ContentScroll
    MakeCorner(row, 10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = COLORS.text
    label.Font = isBold and Enum.Font.GothamMedium or Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 40, 0, 22)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -14, 0.5, 0)
    track.BorderSizePixel = 0
    track.Parent = row
    MakeCorner(track, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 2, 0.5, 0)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = COLORS.knob
    knob.Parent = track
    MakeCorner(knob, 9)

    local function render(animate)
        local on = getState()
        local color = on and onColor or COLORS.off
        local pos = on and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        if animate then
            TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = color }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), { Position = pos }):Play()
        else
            track.BackgroundColor3 = color
            knob.Position = pos
        end
    end

    row.MouseButton1Click:Connect(function()
        onToggle()
        render(true)
    end)

    render(false)
    return row
end

-- Master Switch
MakeSwitchRow("Master switch", COLORS.success, function()
    return Settings.MasterSwitch
end, function()
    Settings.MasterSwitch = not Settings.MasterSwitch
    SaveSettings()
end, 2, true)

MakeSectionLabel("Automation", 3)

local function MakeToggle(name, key, order)
    return MakeSwitchRow(name, COLORS.accent, function()
        return Settings[key]
    end, function()
        Settings[key] = not Settings[key]
        SaveSettings()
    end, order)
end

MakeToggle("Auto start wave", "AutoStartWave", 4)
MakeToggle("Auto ability", "AutoAbility", 5)
MakeToggle("Auto replay", "AutoReplay", 6)
MakeToggle("Auto return to hub", "AutoReturnHub", 7)

MakeSectionLabel("Notifications", 8)

MakeToggle("Discord webhook", "WebhookEnabled", 9)

-- Webhook URL
local WebhookBoxFrame = Instance.new("Frame")
WebhookBoxFrame.Size = UDim2.new(1, 0, 0, 40)
WebhookBoxFrame.BackgroundColor3 = COLORS.card
WebhookBoxFrame.LayoutOrder = 10
WebhookBoxFrame.Parent = ContentScroll
MakeCorner(WebhookBoxFrame, 10)

local WebhookTextBox = Instance.new("TextBox")
WebhookTextBox.Size = UDim2.new(1, -24, 1, -12)
WebhookTextBox.Position = UDim2.new(0, 12, 0, 6)
WebhookTextBox.BackgroundColor3 = COLORS.field
WebhookTextBox.BorderSizePixel = 0
WebhookTextBox.Font = Enum.Font.Gotham
WebhookTextBox.TextSize = 12
WebhookTextBox.TextColor3 = COLORS.text
WebhookTextBox.PlaceholderColor3 = COLORS.muted
WebhookTextBox.PlaceholderText = "Paste Discord webhook URL here..."
WebhookTextBox.Text = Settings.WebhookUrl or ""
WebhookTextBox.ClearTextOnFocus = false
WebhookTextBox.TextXAlignment = Enum.TextXAlignment.Left
WebhookTextBox.TextTruncate = Enum.TextTruncate.AtEnd
WebhookTextBox.Parent = WebhookBoxFrame
MakeCorner(WebhookTextBox, 8)

local WebhookPadding = Instance.new("UIPadding")
WebhookPadding.PaddingLeft = UDim.new(0, 10)
WebhookPadding.PaddingRight = UDim.new(0, 10)
WebhookPadding.Parent = WebhookTextBox

WebhookTextBox.FocusLost:Connect(function()
    Settings.WebhookUrl = WebhookTextBox.Text:gsub("%s+", "")
    SaveSettings()
end)

MakeSectionLabel("Slots", 11)

-- Slot cards: ตัวนับ − / + และระดับ − / +
local function GetMaxLimit(slotIdx)
    local maxLimit = 6
    local gc = GetGameController()
    if gc and gc.slots and gc.slots[slotIdx] and gc.capOf then
        maxLimit = gc.capOf(gc.slots[slotIdx]) or 6
    end
    return maxLimit
end

local SlotRows = {}
for slotIdx = 1, 6 do
    Settings.Slots[slotIdx] = Settings.Slots[slotIdx] or { TargetCount = 0, TargetLevel = 0 }
    local slotConfig = Settings.Slots[slotIdx]

    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(1, 0, 0, 96)
    Card.BackgroundColor3 = COLORS.card
    Card.LayoutOrder = 11 + slotIdx
    Card.Parent = ContentScroll
    MakeCorner(Card, 10)

    local SlotTitle = Instance.new("TextLabel")
    SlotTitle.Size = UDim2.new(1, -24, 0, 18)
    SlotTitle.Position = UDim2.new(0, 12, 0, 8)
    SlotTitle.BackgroundTransparency = 1
    SlotTitle.Text = string.format("Slot %d: (Empty)", slotIdx)
    SlotTitle.TextColor3 = COLORS.text
    SlotTitle.Font = Enum.Font.GothamMedium
    SlotTitle.TextSize = 13
    SlotTitle.TextXAlignment = Enum.TextXAlignment.Left
    SlotTitle.TextTruncate = Enum.TextTruncate.AtEnd
    SlotTitle.Parent = Card

    local Steppers = Instance.new("Frame")
    Steppers.Size = UDim2.new(1, -20, 0, 50)
    Steppers.Position = UDim2.new(0, 10, 0, 36)
    Steppers.BackgroundTransparency = 1
    Steppers.Parent = Card

    local StepLayout = Instance.new("UIListLayout")
    StepLayout.FillDirection = Enum.FillDirection.Horizontal
    StepLayout.Padding = UDim.new(0, 8)
    StepLayout.SortOrder = Enum.SortOrder.LayoutOrder
    StepLayout.Parent = Steppers

    local function MakeStepper(order, caption)
        local box = Instance.new("Frame")
        box.Size = UDim2.new(0.5, -4, 1, 0)
        box.BackgroundColor3 = COLORS.field
        box.LayoutOrder = order
        box.Parent = Steppers
        MakeCorner(box, 8)

        local cap = Instance.new("TextLabel")
        cap.Size = UDim2.new(1, -16, 0, 14)
        cap.Position = UDim2.new(0, 10, 0, 5)
        cap.BackgroundTransparency = 1
        cap.Text = caption
        cap.TextColor3 = COLORS.muted
        cap.Font = Enum.Font.Gotham
        cap.TextSize = 11
        cap.TextXAlignment = Enum.TextXAlignment.Left
        cap.Parent = box

        local minus = Instance.new("TextButton")
        minus.Size = UDim2.new(0, 28, 0, 22)
        minus.Position = UDim2.new(0, 6, 1, -27)
        minus.BackgroundColor3 = COLORS.stroke
        minus.Text = "-"
        minus.TextColor3 = COLORS.text
        minus.Font = Enum.Font.GothamBold
        minus.TextSize = 14
        minus.Parent = box
        MakeCorner(minus, 6)

        local plus = Instance.new("TextButton")
        plus.Size = UDim2.new(0, 28, 0, 22)
        plus.Position = UDim2.new(1, -34, 1, -27)
        plus.BackgroundColor3 = COLORS.stroke
        plus.Text = "+"
        plus.TextColor3 = COLORS.text
        plus.Font = Enum.Font.GothamBold
        plus.TextSize = 14
        plus.Parent = box
        MakeCorner(plus, 6)

        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(0, 46, 0, 22)
        value.Position = UDim2.new(0.5, -23, 1, -27)
        value.BackgroundTransparency = 1
        value.Text = "0"
        value.TextColor3 = COLORS.text
        value.Font = Enum.Font.GothamMedium
        value.TextSize = 14
        value.Parent = box

        return { Minus = minus, Plus = plus, Value = value }
    end

    local countStep = MakeStepper(1, "Count")
    local levelStep = MakeStepper(2, "Level")

    local function RefreshSlot()
        countStep.Value.Text = tostring(slotConfig.TargetCount)
        levelStep.Value.Text = slotConfig.TargetLevel == 0 and "OFF" or tostring(slotConfig.TargetLevel)
    end

    countStep.Plus.MouseButton1Click:Connect(function()
        local maxLimit = GetMaxLimit(slotIdx)
        if slotConfig.TargetCount < maxLimit then
            slotConfig.TargetCount = slotConfig.TargetCount + 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    countStep.Minus.MouseButton1Click:Connect(function()
        if slotConfig.TargetCount > 0 then
            slotConfig.TargetCount = slotConfig.TargetCount - 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    levelStep.Plus.MouseButton1Click:Connect(function()
        if slotConfig.TargetLevel < 10 then
            slotConfig.TargetLevel = slotConfig.TargetLevel + 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    levelStep.Minus.MouseButton1Click:Connect(function()
        if slotConfig.TargetLevel > 0 then
            slotConfig.TargetLevel = slotConfig.TargetLevel - 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    SlotRows[slotIdx] = {
        Title = SlotTitle,
        CountBtn = countStep.Value,
        LvlBtn = levelStep.Value
    }
    RefreshSlot()
end

-- ============================================================================
-- 5. Discord Webhook Notification System
-- ============================================================================
local lastWebhookSentTime = 0
local function SendEndGameWebhook(resultTitle, waveText, bestWaveText, stageText, gemsEarned, totalGems, dropItems, heroDamageList)
    if not Settings.WebhookEnabled or not Settings.WebhookUrl or Settings.WebhookUrl == "" then
        return
    end
    if os.clock() - lastWebhookSentTime < 10 then
        return
    end
    lastWebhookSentTime = os.clock()

    task.spawn(function()
        local httpReq = (syn and syn.request) or (http and http.request) or http_request or request
        if not httpReq then return end

        local playerName = LocalPlayer and LocalPlayer.Name or "Unknown"
        local titleColor = (resultTitle:find("VICTORY") or resultTitle:find("WELL FOUGHT") or resultTitle:find("CLEAR")) and 0x2ECC71 or 0xE74C3C

        local fields = {
            { name = "👤 ผู้เล่น", value = string.format("`%s`", playerName), inline = true },
            { name = "🗺️ ด่าน / Stage", value = string.format("`%s`", stageText ~= "" and stageText or "Normal"), inline = true },
            { name = "🌊 เวฟ / Wave", value = string.format("`%s` (สถิติ: %s)", waveText ~= "" and waveText or "-", bestWaveText ~= "" and bestWaveText or "-"), inline = true },
            { name = "💎 เพชรที่ได้รับ (Gems)", value = string.format("**%s** (รวมทั้งหมด: %s)", gemsEarned ~= "" and gemsEarned or "0", totalGems ~= "" and totalGems or "-"), inline = false }
        }

        if #dropItems > 0 then
            local dropStr = table.concat(dropItems, "\n")
            table.insert(fields, { name = "🎁 ไอเทมที่ดรอป / ของรางวัล (Drops)", value = dropStr, inline = false })
        end

        if #heroDamageList > 0 then
            local dmgStr = table.concat(heroDamageList, "\n")
            table.insert(fields, { name = "⚔️ ดาเมจฮีโร่ (Top Damage)", value = dmgStr, inline = false })
        end

        local payload = {
            username = "Candy Kingdom Notifier",
            avatar_url = "https://tr.rbxcdn.com/180DAY-4e3f42c2627e997f74c730ce91ebc5d6/150/150/Image/Webp/noFilter",
            embeds = {
                {
                    title = "🎮 สรุปผลจบเกม: " .. resultTitle,
                    color = titleColor,
                    fields = fields,
                    footer = { text = "CKD Smart Slot Macro • " .. os.date("%Y-%m-%d %H:%M:%S") }
                }
            }
        }

        pcall(function()
            httpReq({
                Url = Settings.WebhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

-- ============================================================================
-- 5. End Screen Overlay Handler + Raid Replay Pay System
-- ============================================================================
local lastReplayPay = 0
local function HandleEndScreen()
    local candyGui = PlayerGui:FindFirstChild("CandyTD")
    if candyGui then
        -- 0. ตรวจสอบ UI ReplayItems / Popup ยืนยันการใช้ไอเทม Raid (เช่น POUR 1 BUG MILK และ ถาม YES / NO)
        if Settings.AutoReplay then
            local replayItems = candyGui:FindFirstChild("ReplayItems")
            if replayItems then
                -- ถ้ามี Popup "PLAY AGAIN?" / ถาม Yes/No ปรากฏขึ้นมา
                local askFrame = replayItems:FindFirstChild("Ask")
                if askFrame and askFrame.Visible then
                    local question = askFrame:FindFirstChild("Holder") and askFrame.Holder:FindFirstChild("Question")
                    local yesBtn = question and question:FindFirstChild("Yes")
                    if yesBtn and yesBtn:IsA("GuiButton") and yesBtn.Visible then
                        pcall(function() firesignal(yesBtn.Activated) end)
                        task.wait(0.5)
                        return true
                    end
                end

                -- ถ้าหน้าต่าง ReplayItems เปิดอยู่ และมีปุ่ม Use (POUR 1 BUG MILK)
                if replayItems.Visible then
                    local card = replayItems:FindFirstChild("Holder") and replayItems.Holder:FindFirstChild("Card")
                    local useBtn = card and card:FindFirstChild("Use")
                    if useBtn and useBtn:IsA("GuiButton") and useBtn.Visible then
                        pcall(function() firesignal(useBtn.Activated) end)
                        task.wait(0.5)
                        return true
                    end
                end
            end
        end

        local overlay = candyGui:FindFirstChild("Overlay")
        if overlay and overlay.Visible then
            -- ส่ง Webhook สรุปผลเมื่อพบหน้าจอจบเกม (Overlay)
            pcall(function()
                local titleLabel = overlay:FindFirstChild("TitlePlate", true) and overlay.TitlePlate:FindFirstChild("Label", true)
                local resTitle = titleLabel and titleLabel.Text or "WELL FOUGHT!"

                local waveLbl = overlay:FindFirstChild("Stats", true) and overlay.Stats:FindFirstChild("Frame", true) and overlay.Stats.Frame:FindFirstChild("Label", true)
                local waveTxt = waveLbl and waveLbl.Text or ""

                local bestTxt = ""
                if overlay:FindFirstChild("Stats", true) then
                    for _, tl in ipairs(overlay.Stats:GetDescendants()) do
                        if tl:IsA("TextLabel") and tl.Text:find("BEST") then
                            bestTxt = tl.Text
                            break
                        end
                    end
                end

                local amtLbl = overlay:FindFirstChild("Amount", true) and overlay.Amount:FindFirstChild("Label", true)
                local gemsAmt = amtLbl and amtLbl.Text or ""

                local totLbl = overlay:FindFirstChild("Total", true) and overlay.Total:FindFirstChild("Value", true) and overlay.Total.Value:FindFirstChild("Label", true)
                local gemsTot = totLbl and totLbl.Text or ""

                local drops = {}
                local subReward = overlay:FindFirstChild("Sub", true)
                if subReward and subReward:IsA("TextLabel") and subReward.Text ~= "" then
                    table.insert(drops, "• " .. subReward.Text)
                end
                local firstClear = overlay:FindFirstChild("FirstClear", true)
                if firstClear and firstClear.Visible then
                    table.insert(drops, "• 🌟 FIRST CLEAR REWARD")
                end

                local dmgList = {}
                local dmgFrame = overlay:FindFirstChild("Damage", true)
                if dmgFrame then
                    for rowIdx = 1, 6 do
                        local row = dmgFrame:FindFirstChild("Row" .. rowIdx, true)
                        if row then
                            local n = row:FindFirstChild("Name") and row.Name.Text
                            local v = row:FindFirstChild("Value") and row.Value.Text
                            if n and v and n ~= "" and v ~= "" then
                                table.insert(dmgList, string.format("• **%s**: `%s`", n, v))
                            end
                        end
                    end
                end

                local gc = GetGameController()
                local stageName = (gc and gc.name) or (gc and gc.stageId and ("Stage " .. tostring(gc.stageId))) or ""

                SendEndGameWebhook(resTitle, waveTxt, bestTxt, stageName, gemsAmt, gemsTot, drops, dmgList)
            end)
            if Settings.AutoReplay then
                -- 1. ลองจ่ายไอเทมเรด/ประตูเพื่อ Replay ก่อน (ถ้ามี Remote Replay)
                local curMatchRemotes = ReplicatedStorage:FindFirstChild("MatchRemotes")
                local curReplayRemote = curMatchRemotes and curMatchRemotes:FindFirstChild("Replay")
                if curReplayRemote and (os.clock() - lastReplayPay >= 2) then
                    lastReplayPay = os.clock()
                    local infoOk, info = pcall(function()
                        return curReplayRemote:InvokeServer("info")
                    end)
                    if infoOk and type(info) == "table" and info.ok then
                        local have = tonumber(info.have) or 0
                        local cost = tonumber(info.cost) or 1
                        if have >= cost then
                            pcall(function()
                                curReplayRemote:InvokeServer("pay")
                            end)
                            return true
                        end
                    end
                end

                -- 2. กดปุ่ม PlayAgain ปกติ
                local playAgain = overlay:FindFirstChild("PlayAgain")
                if playAgain and playAgain:IsA("GuiButton") and playAgain.Visible then
                    pcall(function() firesignal(playAgain.Activated) end)
                    return true
                end

                -- 3. กดปุ่ม Next (ถ้ามี)
                local nextBtn = overlay:FindFirstChild("Next")
                if nextBtn and nextBtn:IsA("GuiButton") and nextBtn.Visible then
                    pcall(function() firesignal(nextBtn.Activated) end)
                    return true
                end
            end
            if Settings.AutoReturnHub then
                local retHub = overlay:FindFirstChild("ReturnToHub")
                if retHub and retHub:IsA("GuiButton") and retHub.Visible then
                    pcall(function() firesignal(retHub.Activated) end)
                    return true
                end
            end
        end

        -- HomeOverlay (หน้าจอแพ้ / ลองใหม่)
        local homeOverlay = candyGui:FindFirstChild("HomeOverlay")
        if homeOverlay and homeOverlay.Visible then
            pcall(function()
                local gc = GetGameController()
                local stageName = (gc and gc.name) or (gc and gc.stageId and ("Stage " .. tostring(gc.stageId))) or ""
                SendEndGameWebhook("GAME OVER / DEFEAT", "-", "-", stageName, "0", "-", {}, {})
            end)
            if Settings.AutoReplay then
                local tryAgain = homeOverlay:FindFirstChild("TryAgain")
                if tryAgain and tryAgain:IsA("GuiButton") and tryAgain.Visible then
                    pcall(function() firesignal(tryAgain.Activated) end)
                    return true
                end
            end
            if Settings.AutoReturnHub then
                local okBtn = homeOverlay:FindFirstChild("OK")
                if okBtn and okBtn:IsA("GuiButton") and okBtn.Visible then
                    pcall(function() firesignal(okBtn.Activated) end)
                    return true
                end
            end
        end
    end
    return false
end

-- ============================================================================
-- 4. Main Macro Execution Loop (Robust Placement & Distributed Upgrade + Auto Ability)
-- ============================================================================
local failCount = {}
local lastAbilityTick = 0

task.spawn(function()
    -- หน่วงเวลาเริ่มต้น 12 วินาทีก่อนเริ่มทำงานจริง
    for i = 12, 1, -1 do
        if not _G.CKD_SlotMacro_Running then return end
        StatusBar.Text = string.format("Status: ⏳ Initializing (Waiting %ds)...", i)
        StatusBar.TextColor3 = Color3.fromRGB(255, 175, 50)
        task.wait(1)
    end

    while _G.CKD_SlotMacro_Running do
        task.wait(0.4)

        if Settings.MasterSwitch then
            local ended = HandleEndScreen()

            if not ended then
                local gc = GetGameController()
                local slotUnits = GetSlotUnits()

                -- อัปเดต UI รายชื่อ Slot
                for slotIdx = 1, 6 do
                    local unitName = slotUnits[slotIdx]
                    local row = SlotRows[slotIdx]
                    if row then
                        if unitName then
                            local cap = (gc and gc.capOf and gc.capOf(unitName)) or 6
                            row.Title.Text = string.format("%d: %s (Max:%d)", slotIdx, unitName, cap)
                        else
                            row.Title.Text = string.format("Slot %d: (Empty)", slotIdx)
                        end
                    end
                end

                -- Auto Start Wave
                if Settings.AutoStartWave then
                    local candyGui = PlayerGui:FindFirstChild("CandyTD")
                    local startWave = candyGui and candyGui:FindFirstChild("StartWave")
                    if startWave and startWave:IsA("GuiButton") and startWave.Visible then
                        pcall(function()
                            firesignal(startWave.Activated)
                        end)
                    end
                end

                -- การวาง ยูนิต และการอัปเกรด
                if gc and slotUnits and #slotUnits > 0 then
                    local placedTowers = GetPlacedTowers(gc)

                    -- Auto Ability: วนบัพสำหรับ Rock Vampire / Vampire King (Encore) และตัวอื่นกดปกติ
                    if Settings.AutoAbility and ActRemote and (os.clock() - lastAbilityTick >= 1.0) then
                        lastAbilityTick = os.clock()

                        local vamps = {}
                        local others = {}

                        for _, tower in ipairs(placedTowers) do
                            if tower.id then
                                local uName = tostring(tower.unit)
                                if uName == "MarshallLee" or uName == "MarshallLeeVampireKing" then
                                    table.insert(vamps, tower)
                                else
                                    table.insert(others, tower)
                                end
                            end
                        end

                        -- 1. ตัวละครทั่วไป: กดสกิลตามรอบปกติ
                        for _, tower in ipairs(others) do
                            task.spawn(function()
                                pcall(function()
                                    ActRemote:InvokeServer("ability", tower.id)
                                end)
                            end)
                        end

                        -- 2. Rock Vampire / Vampire King: วนกดบัพทีละตัวเมื่อบัพหมด
                        if #vamps > 0 then
                            table.sort(vamps, function(a, b) return a.id < b.id end)

                            -- ตรวจสอบว่ามีตัวใดกำลังติดบัพ Encore อยู่หรือไม่
                            local anyBuffActive = false
                            for _, v in ipairs(vamps) do
                                local e = v.encore
                                if e and type(e.t) == "number" and type(e.untilT) == "number" then
                                    if e.t < e.untilT then
                                        anyBuffActive = true
                                        break
                                    end
                                end
                            end

                            -- ถ้าไม่มีตัวไหนกำลังติดบัพ -> สั่งกดตัวที่พร้อม
                            if not anyBuffActive then
                                for _, v in ipairs(vamps) do
                                    local lvl = tonumber(v.level) or 1
                                    if lvl >= 3 then
                                        local e = v.encore
                                        local ready = true
                                        if e and type(e.t) == "number" and type(e.untilT) == "number" then
                                            if e.t < e.untilT then
                                                ready = false
                                            end
                                        end
                                        if ready then
                                            task.spawn(function()
                                                pcall(function()
                                                    ActRemote:InvokeServer("ability", v.id)
                                                end)
                                            end)
                                            break -- กดทีละ 1 ตัว เพื่อให้บัพวนต่อกัน
                                        end
                                    end
                                end
                            end
                        end
                    end

                    local anyTargetConfigured = false
                    local needMorePlacement = false
                    local totalPlacedConfigured = 0
                    local totalTargetConfigured = 0
                    local slotCurrentCounts = {}
                    local slotTargetCounts = {}

                    -- นับจำนวนเฉพาะ Slot ที่ผู้เล่นตั้งค่าไว้ (TargetCount > 0)
                    for slotIdx = 1, #slotUnits do
                        local unitKind = slotUnits[slotIdx]
                        local config = Settings.Slots[slotIdx]
                        if unitKind and config then
                            local currentCount = 0
                            for _, t in ipairs(placedTowers) do
                                if t.unit == unitKind then
                                    currentCount = currentCount + 1
                                end
                            end

                            local maxCap = (gc.capOf and gc.capOf(unitKind)) or 6
                            local target = math.min(config.TargetCount, maxCap)

                            slotCurrentCounts[slotIdx] = currentCount
                            slotTargetCounts[slotIdx] = target

                            if target > 0 then
                                anyTargetConfigured = true
                                totalTargetConfigured = totalTargetConfigured + target
                                totalPlacedConfigured = totalPlacedConfigured + math.min(currentCount, target)
                                if currentCount < target then
                                    needMorePlacement = true
                                end
                            end
                        end
                    end

                    -- ถ้าทุก Slot ปรับเป็น 0 หมด
                    if not anyTargetConfigured then
                        StatusBar.Text = "Status: 💤 Standing by (All slots 0)"
                        StatusBar.TextColor3 = Color3.fromRGB(180, 180, 190)

                    -- ====================================================================
                    -- [PHASE 1]: วางตัวให้ครบตามจำนวนเป้าหมายก่อน (ห้ามแตะต้องระบบอัปเกรดเด็ดขาด)
                    -- ====================================================================
                    elseif needMorePlacement then
                        StatusBar.Text = string.format("Status: ⏳ Placing Units (%d/%d)", totalPlacedConfigured, totalTargetConfigured)
                        StatusBar.TextColor3 = Color3.fromRGB(255, 175, 50)

                        for slotIdx = 1, #slotUnits do
                            local unitKind = slotUnits[slotIdx]
                            local current = slotCurrentCounts[slotIdx] or 0
                            local target = slotTargetCounts[slotIdx] or 0

                            if target > 0 and current < target then
                                local price = (gc.placePrice and gc.placePrice(unitKind)) or 0
                                local canAfford = (gc.canPay and gc.canPay(price))

                                if canAfford then
                                    local spot = GetReliableSpot(gc, unitKind)
                                    if spot then
                                        local success, res = pcall(function()
                                            return gc.net.place(unitKind, spot)
                                        end)

                                        if success and res and res.ok then
                                            failCount[slotIdx] = 0
                                            break
                                        else
                                            failCount[slotIdx] = (failCount[slotIdx] or 0) + 1
                                            if failCount[slotIdx] < 2 then
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end

                    -- ====================================================================
                    -- [PHASE 2]: วางตัวครบทั้งหมดแล้ว -> กระจายอัปเกรดยูนิตอย่างทั่วถึง (Distributed Upgrade)
                    -- ====================================================================
                    else
                        local bestCandidate = nil
                        local lowestLevel = math.huge
                        local bestSlotIdx = 0

                        -- เกลี่ยอัปเกรดตัวที่มีเลเวลต่ำสุดก่อนเสมอ
                        for slotIdx = 1, #slotUnits do
                            local unitKind = slotUnits[slotIdx]
                            local config = Settings.Slots[slotIdx]
                            if unitKind and config and config.TargetLevel > 0 then
                                for _, tower in ipairs(placedTowers) do
                                    if tower.unit == unitKind and tower.level and tower.level < config.TargetLevel then
                                        if tower.level < lowestLevel then
                                            lowestLevel = tower.level
                                            bestCandidate = tower
                                            bestSlotIdx = slotIdx
                                        end
                                    end
                                end
                            end
                        end

                        if bestCandidate then
                            local unitKind = bestCandidate.unit
                            local config = Settings.Slots[bestSlotIdx]
                            StatusBar.Text = string.format("Status: ⬆ Distributed: Slot %d (%s) Lvl %d->%d", bestSlotIdx, unitKind, bestCandidate.level, config.TargetLevel)
                            StatusBar.TextColor3 = Color3.fromRGB(112, 222, 112)
                            pcall(function()
                                gc.net.request("upgrade", bestCandidate.id)
                            end)
                        else
                            StatusBar.Text = "Status: ✅ All Units Placed & Upgraded!"
                            StatusBar.TextColor3 = Color3.fromRGB(46, 204, 113)
                        end
                    end
                end
            end
        end
    end
end)

print("[CKD] Macro Ready: Auto Ability + Distributed Upgrade Engine Loaded with 12s Delay!")