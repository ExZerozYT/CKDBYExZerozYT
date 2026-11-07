-- ============================================================================
-- CKD Smart Cluster Slot Macro + Auto Pick Wish (ลำดับบัพกำหนดเองได้)
-- UI: Cartoon style ตาม mockup (ส่วน logic เดิมไม่ได้แก้ไข)
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
-- Wish Catalog (ลำดับเริ่มต้นตาม tier list, ผู้ใช้จัดลำดับใหม่ได้ในหน้า Wish priority)
-- ============================================================================
local WishCatalog = {
    { key = "gems", name = "Gems of the Crowns", rarity = "Legendary", desc = "ดาเมจฮีโร่ทุกตัว +30%" },
    { key = "outside", name = "Outside of Time", rarity = "Legendary", desc = "ความเร็วโจมตี +25%" },
    { key = "stars", name = "Gold Stars", rarity = "Legendary", desc = "20% ของการโจมตีทำดาเมจ x2.5" },
    { key = "hoop", name = "Hoop in a Trash Can", rarity = "Twisted", desc = "รอบถัดไปได้การ์ด Legendary 3 ใบ" },
    { key = "remote", name = "Prismo's Remote", rarity = "Legendary", desc = "เลือดศัตรู -15%, เลือดบอส -30%" },
    { key = "titans", name = "Clock Titans", rarity = "Rare", desc = "ความเร็วโจมตี +15%" },
    { key = "book", name = "The Enchiridion", rarity = "Rare", desc = "ดาเมจฮีโร่ทุกตัว +15%" },
    { key = "burrito", name = "Everything Burrito", rarity = "Legendary", desc = "เงินจากการฆ่า +40%, ค่าอัปเกรด -10%" },
    { key = "frost", name = "The Power of Frost", rarity = "Twisted", desc = "ดาเมจ +60%, ความเร็วโจมตี -15%" },
    { key = "beast", name = "Belly of the Beast", rarity = "Rare", desc = "ดาเมจใส่บอส +30%" },
    { key = "owl", name = "Cosmic Owl", rarity = "Rare", desc = "ระยะยิง +20%" },
    { key = "goose", name = "Choose Goose", rarity = "Rare", desc = "ค่าอัปเกรด -12%" },
    { key = "business", name = "Business Time", rarity = "Common", desc = "เงินที่ได้จบแต่ละเวฟ x2" },
    { key = "nap", name = "Old Man's Nap", rarity = "Rare", desc = "เลือดบอส -20%" },
    { key = "wakeup", name = "Wake Up", rarity = "Twisted", desc = "ดาเมจ +100%, ข้าม Wish 2 รอบ" },
    { key = "waves", name = "Time Waves", rarity = "Common", desc = "ความเร็วโจมตี +8%" },
    { key = "cards", name = "Card Wars", rarity = "Common", desc = "10% ของการโจมตีทำดาเมจ x2" },
    { key = "tv", name = "TV Wall", rarity = "Common", desc = "ระยะยิง +10%" },
    { key = "extinct", name = "A Little Extinction", rarity = "Rare", desc = "เลือดศัตรู -8%" },
    { key = "slow", name = "Time Sandwich", rarity = "Rare", desc = "ศัตรูเดินช้าลง 6%" },
    { key = "late", name = "Bad Timing", rarity = "Common", desc = "บอสเดินช้าลง 15%" },
    { key = "wagon", name = "Pickle Wagon", rarity = "Common", desc = "เงินจากการฆ่ามอน +20%" },
    { key = "core", name = "Time Core", rarity = "Rare", desc = "คูลดาวน์สกิล -20%" },
    { key = "friends", name = "Friends Forever", rarity = "Rare", desc = "คูลดาวน์ Duo -25%" },
    { key = "stays", name = "Everything Stays", rarity = "Rare", desc = "ศัตรูที่ตีเลือดลดได้ไม่เกิน 3 หน่วย" },
    { key = "guardian", name = "Citadel Guardian", rarity = "Rare", desc = "มอนตัวแรกที่หลุดไม่เสียเลือด" },
    { key = "pony", name = "Shelby's Wish", rarity = "Common", desc = "รับ $300 ทันที และ +$40 ต่อเวฟ" },
    { key = "lichwish", name = "The Lich's Wish", rarity = "Twisted", desc = "ดาเมจ +70%, เลือดหาร 2" },
    { key = "party", name = "Party's Over", rarity = "Twisted", desc = "ความเร็วโจมตี +35%, มอนเดินเร็วขึ้น 12%" },
    { key = "farmworld", name = "Farmworld", rarity = "Twisted", desc = "เลือดบอส -40%, เลือดมอนทั่วไป +20%" },
    { key = "maid", name = "The Maid", rarity = "Twisted", desc = "ศัตรูไม่มี Trait 10 เวฟ" },
    { key = "ichor", name = "Ichor of Coconteppi", rarity = "Twisted", desc = "ค่าอัปเกรด -30%, เงินจากการฆ่า -30%" },
    { key = "sandwich", name = "A Sandwich, Not a Wish", rarity = "Common", desc = "Reroll +2 ครั้ง" },
    { key = "foul", name = "Party Foul", rarity = "Common", desc = "เจาะเกราะฟองสบู่ 50%" },
    { key = "normalman", name = "Normal Man", rarity = "Common", desc = "เจาะเกราะดาเมจ Normal" },
    { key = "bomb", name = "Mushroom Bomb", rarity = "Common", desc = "ขนาดระเบิด +20%" },
    { key = "hero", name = "Algebraic!", rarity = "Common", desc = "ดาเมจธาตุ Hero +30%" },
    { key = "magic", name = "Power Animal", rarity = "Common", desc = "ดาเมจธาตุ Magic +30%" },
    { key = "tech", name = "Be More", rarity = "Common", desc = "ดาเมจธาตุ Tech +30%" },
    { key = "dark", name = "Red Starved", rarity = "Common", desc = "ดาเมจธาตุ Dark +30%" },
    { key = "fire", name = "Hot to the Touch", rarity = "Common", desc = "ดาเมจธาตุ Fire +30%" },
    { key = "fairy", name = "Jelly Beans Have Power", rarity = "Common", desc = "ดาเมจธาตุ Fairy +30%" },
    { key = "sour", name = "Unacceptable!", rarity = "Common", desc = "ดาเมจธาตุ Sour +30%" },
    { key = "normal", name = "Chamber of Blades", rarity = "Common", desc = "ดาเมจ Normal +20%" },
    { key = "wizards", name = "Wizards Only, Fools", rarity = "Common", desc = "ดาเมจ Magic +20%" },
    { key = "forever", name = "Party Forever!", rarity = "Legendary", desc = "ชีวิต +10" },
    { key = "reboot", name = "Reboot", rarity = "Rare", desc = "ชีวิต +6" },
    { key = "tub", name = "Prismo's Hot Tub", rarity = "Common", desc = "ชีวิต +3" },
    { key = "pickle", name = "The Last Pickle", rarity = "Twisted", desc = "ฟื้นเลือดเต็ม แต่เงินปัจจุบันหาย 50%" },
}

local WishByKey = {}
for _, item in ipairs(WishCatalog) do
    WishByKey[item.key] = item
end

local function DefaultWishOrder()
    local order = {}
    for _, item in ipairs(WishCatalog) do
        table.insert(order, item.key)
    end
    return order
end

-- ============================================================================
-- 3. Settings Manager (Auto-Save JSON)
-- ============================================================================
local DefaultSettings = {
    MasterSwitch = true,
    AutoStartWave = true,
    AutoAbility = true,
    AutoReplay = false,
    AutoReturnHub = false,
    WishAutoPick = true,
    WishOrder = DefaultWishOrder(),
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

-- ทำความสะอาดลำดับบัพ: เก็บเฉพาะคีย์ที่รู้จัก ไม่ซ้ำ และเติมบัพที่หายไปไว้ท้ายสุด
local function SanitizeWishOrder()
    local seen, out = {}, {}
    if type(Settings.WishOrder) == "table" then
        for _, k in ipairs(Settings.WishOrder) do
            if WishByKey[k] and not seen[k] then
                seen[k] = true
                table.insert(out, k)
            end
        end
    end
    for _, item in ipairs(WishCatalog) do
        if not seen[item.key] then
            table.insert(out, item.key)
        end
    end
    Settings.WishOrder = out
end

SanitizeWishOrder()

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
-- Auto Pick Wish: คะแนนตามตำแหน่งในลำดับที่ผู้ใช้จัด (อันบนสุดคะแนนสูงสุด)
-- ============================================================================
local function GetWishScore(key)
    local total = #Settings.WishOrder
    for index, k in ipairs(Settings.WishOrder) do
        if k == key then
            return total - index + 1
        end
    end
    return 0
end

local function getCardPriority(card)
    local perkId = card:GetAttribute("PerkId") or card:GetAttribute("Id")
    if perkId and WishByKey[perkId] then
        return GetWishScore(perkId)
    end

    -- ตรวจจับจากชื่อบัพที่แสดงอยู่ในการ์ด
    for _, d in ipairs(card:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= "" then
            local text = d.Text:lower()
            for _, item in ipairs(WishCatalog) do
                if text:find(item.name:lower(), 1, true) then
                    return GetWishScore(item.key)
                end
            end
        end
    end

    return 0
end

local isChoosing = false
local wishPickedCount = 0
-- ฟังก์ชันนี้จะถูกกำหนดค่าใหม่ตอนสร้าง GUI เพื่ออัปเดตตัวเลขบัพที่เลือกแล้ว
local OnWishPicked = function() end

local function checkAndPickWish()
    if not Settings.WishAutoPick then return end

    local wishRunGui = PlayerGui:FindFirstChild("WishRun")
    if not wishRunGui or not wishRunGui.Enabled then return end

    local stage = wishRunGui:FindFirstChild("Shade") and wishRunGui.Shade:FindFirstChild("Stage")
    if not stage or not stage.Visible then return end

    local row = stage:FindFirstChild("Row")
    if not row then return end

    local availableCards = {}
    for _, card in ipairs(row:GetChildren()) do
        if card:IsA("GuiObject") and card.Visible and card.Name:find("Card") then
            local wishBtn = nil
            for _, btn in ipairs(card:GetDescendants()) do
                if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                    if btn.Name == "Wish" or btn.Name == "Button" or btn.Name == "Face" or btn:FindFirstChild("Caption") then
                        wishBtn = btn
                        break
                    end
                end
            end
            if not wishBtn then
                wishBtn = card:FindFirstChildWhichIsA("TextButton", true) or card:FindFirstChildWhichIsA("ImageButton", true)
            end

            if wishBtn then
                table.insert(availableCards, {
                    card = card,
                    btn = wishBtn,
                    score = getCardPriority(card)
                })
            end
        end
    end

    if #availableCards > 0 and not isChoosing then
        isChoosing = true
        table.sort(availableCards, function(a, b)
            return a.score > b.score
        end)

        local best = availableCards[1]
        task.wait(0.5)

        if best.btn and best.btn.Parent then
            pcall(function()
                best.btn.Active = true
                for _, conn in ipairs(getconnections(best.btn.Activated)) do
                    conn:Fire()
                end
            end)
            pcall(function()
                for _, conn in ipairs(getconnections(best.btn.MouseButton1Click)) do
                    conn:Fire()
                end
            end)
            OnWishPicked()
        end

        task.wait(1.5)
        isChoosing = false
    end
end

-- ============================================================================
-- 2. GUI Interface (Cartoon style ตาม mockup)
-- ============================================================================
local COLORS = {
    sky = Color3.fromRGB(127, 180, 224),
    brown = Color3.fromRGB(91, 58, 36),
    sidebar = Color3.fromRGB(168, 106, 67),
    sidebarText = Color3.fromRGB(251, 233, 214),
    sidebarMuted = Color3.fromRGB(243, 217, 191),
    sidebarFooter = Color3.fromRGB(143, 87, 54),
    cream = Color3.fromRGB(251, 241, 223),
    white = Color3.fromRGB(255, 255, 255),
    field = Color3.fromRGB(251, 241, 223),
    text = Color3.fromRGB(59, 37, 22),
    muted = Color3.fromRGB(138, 106, 82),
    yellow = Color3.fromRGB(242, 197, 61),
    red = Color3.fromRGB(224, 70, 58),
    green = Color3.fromRGB(123, 201, 111),
    off = Color3.fromRGB(217, 195, 173),
    statusBg = Color3.fromRGB(206, 232, 250),
    statusDefault = Color3.fromRGB(12, 68, 124),
    statusWait = Color3.fromRGB(184, 110, 16),
    statusDone = Color3.fromRGB(59, 120, 40),
}

local function MakeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function MakeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 2
    s.Parent = parent
    return s
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlotLogicUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local WIN_W, WIN_H, TITLE_H = 520, 470, 50

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
MainFrame.Position = UDim2.new(0.02, 0, 0.20, 0)
MainFrame.BackgroundColor3 = COLORS.cream
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
MakeCorner(MainFrame, 14)
MakeStroke(MainFrame, COLORS.brown, 3)

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

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = COLORS.sky
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
MakeStroke(TitleBar, COLORS.brown, 3)

local Logo = Instance.new("TextLabel")
Logo.Size = UDim2.new(0, 32, 0, 32)
Logo.Position = UDim2.new(0, 12, 0.5, -16)
Logo.BackgroundColor3 = COLORS.red
Logo.Text = "C"
Logo.TextColor3 = COLORS.white
Logo.Font = Enum.Font.GothamBold
Logo.TextSize = 14
Logo.Parent = TitleBar
MakeCorner(Logo, 16)
MakeStroke(Logo, COLORS.white, 2)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "Candy Macro"
TitleLabel.TextColor3 = COLORS.white
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextStrokeColor3 = COLORS.brown
TitleLabel.TextStrokeTransparency = 0
TitleLabel.Size = UDim2.new(0, 200, 1, 0)
TitleLabel.Position = UDim2.new(0, 54, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -42, 0.5, -15)
CloseBtn.BackgroundColor3 = COLORS.red
CloseBtn.TextColor3 = COLORS.white
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TitleBar
MakeCorner(CloseBtn, 8)
MakeStroke(CloseBtn, COLORS.brown, 2)

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "-"
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -80, 0.5, -15)
MinBtn.BackgroundColor3 = COLORS.yellow
MinBtn.TextColor3 = COLORS.brown
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.Parent = TitleBar
MakeCorner(MinBtn, 8)
MakeStroke(MinBtn, COLORS.brown, 2)

CloseBtn.MouseButton1Click:Connect(function()
    _G.CKD_SlotMacro_Running = false
    ScreenGui:Destroy()
end)

local isMin = false
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, WIN_W, 0, isMin and TITLE_H or WIN_H)
    }):Play()
    MinBtn.Text = isMin and "+" or "-"
end)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, -TITLE_H)
Sidebar.Position = UDim2.new(0, 0, 0, TITLE_H)
Sidebar.BackgroundColor3 = COLORS.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
MakeStroke(Sidebar, COLORS.brown, 2)

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 6)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 12)
SidebarPad.PaddingLeft = UDim.new(0, 10)
SidebarPad.PaddingRight = UDim.new(0, 10)
SidebarPad.Parent = Sidebar

local function MakeSection(text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = COLORS.sidebarMuted
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = Sidebar
    return l
end

-- Content area
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -140, 1, -TITLE_H)
ContentArea.Position = UDim2.new(0, 140, 0, TITLE_H)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Pages = {}
local TabButtons = {}

local function ShowPage(name)
    for pageName, page in pairs(Pages) do
        page.Visible = (pageName == name)
    end
    for tabName, btn in pairs(TabButtons) do
        local active = (tabName == name)
        btn.BackgroundColor3 = active and COLORS.cream or COLORS.sidebar
        btn.TextColor3 = active and COLORS.text or COLORS.sidebarText
        local stroke = btn:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Enabled = active
        end
    end
end

local function MakeTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = COLORS.sidebar
    btn.Text = name
    btn.TextColor3 = COLORS.sidebarText
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.Parent = Sidebar
    MakeCorner(btn, 10)
    local tp = Instance.new("UIPadding")
    tp.PaddingLeft = UDim.new(0, 12)
    tp.Parent = btn
    local s = MakeStroke(btn, COLORS.brown, 2)
    s.Enabled = false
    btn.MouseButton1Click:Connect(function()
        ShowPage(name)
    end)
    TabButtons[name] = btn
end

local function MakePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = COLORS.brown
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = ContentArea

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    Pages[name] = page
    return page
end

MakeSection("หน้าหลัก", 1)
MakeTab("Dashboard", 2)
MakeSection("ตั้งค่า", 3)
MakeTab("Slots", 4)
MakeTab("Wish priority", 5)

local footer = Instance.new("Frame")
footer.Size = UDim2.new(1, 0, 0, 30)
footer.BackgroundColor3 = COLORS.sidebarFooter
footer.LayoutOrder = 20
footer.Parent = Sidebar
MakeCorner(footer, 10)
MakeStroke(footer, COLORS.brown, 2)

local footerLabel = Instance.new("TextLabel")
footerLabel.Size = UDim2.new(1, 0, 1, 0)
footerLabel.BackgroundTransparency = 1
footerLabel.Text = "เวอร์ชัน 1.0"
footerLabel.TextColor3 = COLORS.sidebarText
footerLabel.Font = Enum.Font.GothamMedium
footerLabel.TextSize = 10
footerLabel.Parent = footer

local DashPage = MakePage("Dashboard")
local SlotsPage = MakePage("Slots")
local WishPage = MakePage("Wish priority")

-- ============================================================================
-- Switch row (ปกติ และแบบ compact สำหรับตารางระบบอัตโนมัติ)
-- ============================================================================
local function MakeSwitchRow(parent, labelText, onColor, getState, onToggle, order, compact)
    local trackW = compact and 34 or 44
    local trackH = compact and 19 or 24
    local knobSize = compact and 13 or 18
    local pad = 2

    local row = Instance.new("TextButton")
    row.Size = compact and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = COLORS.white
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = order
    row.Parent = parent
    MakeCorner(row, 12)
    MakeStroke(row, COLORS.brown, 2)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -(trackW + 22), 1, 0)
    label.Position = UDim2.new(0, compact and 10 or 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = COLORS.text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = compact and 12 or 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, trackW, 0, trackH)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -10, 0.5, 0)
    track.BorderSizePixel = 0
    track.Parent = row
    MakeCorner(track, trackH / 2)
    MakeStroke(track, COLORS.brown, 2)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, knobSize, 0, knobSize)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = COLORS.white
    knob.Parent = track
    MakeCorner(knob, knobSize / 2)

    local function render(animate)
        local on = getState()
        local color = on and onColor or COLORS.off
        local pos = on and UDim2.new(0, trackW - knobSize - pad, 0.5, 0) or UDim2.new(0, pad, 0.5, 0)
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

local function MakeLabel(parent, text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = COLORS.muted
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = parent
    return l
end

-- ============================================================================
-- Dashboard page
-- ============================================================================
local StatsRow = Instance.new("Frame")
StatsRow.Size = UDim2.new(1, 0, 0, 58)
StatsRow.BackgroundTransparency = 1
StatsRow.LayoutOrder = 1
StatsRow.Parent = DashPage

local StatsLayout = Instance.new("UIListLayout")
StatsLayout.FillDirection = Enum.FillDirection.Horizontal
StatsLayout.Padding = UDim.new(0, 8)
StatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
StatsLayout.Parent = StatsRow

local function MakeStatTile(caption, initial, order)
    local tile = Instance.new("Frame")
    tile.Size = UDim2.new(0.3333, -6, 1, 0)
    tile.BackgroundColor3 = COLORS.white
    tile.LayoutOrder = order
    tile.Parent = StatsRow
    MakeCorner(tile, 12)
    MakeStroke(tile, COLORS.brown, 2)

    local cap = Instance.new("TextLabel")
    cap.Size = UDim2.new(1, -20, 0, 14)
    cap.Position = UDim2.new(0, 10, 0, 8)
    cap.BackgroundTransparency = 1
    cap.Text = caption
    cap.TextColor3 = COLORS.muted
    cap.Font = Enum.Font.Gotham
    cap.TextSize = 10
    cap.TextXAlignment = Enum.TextXAlignment.Left
    cap.Parent = tile

    local value = Instance.new("TextLabel")
    value.Size = UDim2.new(1, -20, 0, 26)
    value.Position = UDim2.new(0, 10, 0, 24)
    value.BackgroundTransparency = 1
    value.Text = initial
    value.TextColor3 = COLORS.text
    value.Font = Enum.Font.GothamBold
    value.TextSize = 18
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.Parent = tile

    return value
end

local WaveValue = MakeStatTile("เวฟ", "-", 1)
local UnitsValue = MakeStatTile("ยูนิต", "0 / 0", 2)
local PickedValue = MakeStatTile("บัพที่เลือก", "0", 3)

-- การ์ดสถานะพร้อมแถบความคืบหน้า
local ProgressCard = Instance.new("Frame")
ProgressCard.Size = UDim2.new(1, 0, 0, 62)
ProgressCard.BackgroundColor3 = COLORS.statusBg
ProgressCard.LayoutOrder = 2
ProgressCard.Parent = DashPage
MakeCorner(ProgressCard, 12)
MakeStroke(ProgressCard, COLORS.brown, 2)

local PlayBox = Instance.new("Frame")
PlayBox.Size = UDim2.new(0, 38, 0, 38)
PlayBox.Position = UDim2.new(0, 12, 0.5, -19)
PlayBox.BackgroundColor3 = COLORS.green
PlayBox.Parent = ProgressCard
MakeCorner(PlayBox, 10)
MakeStroke(PlayBox, COLORS.brown, 2)

local PlayText = Instance.new("TextLabel")
PlayText.Size = UDim2.new(1, 0, 1, 0)
PlayText.BackgroundTransparency = 1
PlayText.Text = ">"
PlayText.TextColor3 = COLORS.brown
PlayText.Font = Enum.Font.GothamBold
PlayText.TextSize = 18
PlayText.Parent = PlayBox

local StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, -150, 0, 18)
StatusBar.Position = UDim2.new(0, 62, 0, 8)
StatusBar.BackgroundTransparency = 1
StatusBar.TextColor3 = COLORS.statusDefault
StatusBar.Font = Enum.Font.GothamMedium
StatusBar.TextSize = 13
StatusBar.TextXAlignment = Enum.TextXAlignment.Left
StatusBar.TextTruncate = Enum.TextTruncate.AtEnd
StatusBar.Text = "กำลังเริ่มทำงาน"
StatusBar.Parent = ProgressCard

local ProgressCount = Instance.new("TextLabel")
ProgressCount.Size = UDim2.new(0, 80, 0, 18)
ProgressCount.Position = UDim2.new(1, -92, 0, 8)
ProgressCount.BackgroundTransparency = 1
ProgressCount.Text = "0 / 0"
ProgressCount.TextColor3 = COLORS.statusDefault
ProgressCount.Font = Enum.Font.GothamMedium
ProgressCount.TextSize = 11
ProgressCount.TextXAlignment = Enum.TextXAlignment.Right
ProgressCount.Parent = ProgressCard

local ProgressBack = Instance.new("Frame")
ProgressBack.Size = UDim2.new(1, -74, 0, 10)
ProgressBack.Position = UDim2.new(0, 62, 0, 36)
ProgressBack.BackgroundColor3 = COLORS.white
ProgressBack.ClipsDescendants = true
ProgressBack.Parent = ProgressCard
MakeCorner(ProgressBack, 5)
MakeStroke(ProgressBack, COLORS.brown, 1.5)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = COLORS.green
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBack

local function SetProgress(placed, total)
    local ratio = 0
    if total > 0 then
        ratio = math.clamp(placed / total, 0, 1)
    end
    ProgressFill.Size = UDim2.new(ratio, 0, 1, 0)
    ProgressCount.Text = string.format("%d / %d", placed, total)
end

MakeSwitchRow(DashPage, "สวิตช์หลัก", COLORS.green, function()
    return Settings.MasterSwitch
end, function()
    Settings.MasterSwitch = not Settings.MasterSwitch
    SaveSettings()
end, 3)

MakeLabel(DashPage, "ระบบอัตโนมัติ", 4)

local AutoGrid = Instance.new("Frame")
AutoGrid.Size = UDim2.new(1, 0, 0, 96)
AutoGrid.BackgroundTransparency = 1
AutoGrid.LayoutOrder = 5
AutoGrid.Parent = DashPage

local AutoGridLayout = Instance.new("UIGridLayout")
AutoGridLayout.CellSize = UDim2.new(0.5, -4, 0, 44)
AutoGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
AutoGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
AutoGridLayout.Parent = AutoGrid

MakeSwitchRow(AutoGrid, "เริ่มเวฟอัตโนมัติ", COLORS.green, function()
    return Settings.AutoStartWave
end, function()
    Settings.AutoStartWave = not Settings.AutoStartWave
    SaveSettings()
end, 1, true)

MakeSwitchRow(AutoGrid, "ใช้สกิลอัตโนมัติ", COLORS.green, function()
    return Settings.AutoAbility
end, function()
    Settings.AutoAbility = not Settings.AutoAbility
    SaveSettings()
end, 2, true)

MakeSwitchRow(AutoGrid, "เล่นต่ออัตโนมัติ", COLORS.green, function()
    return Settings.AutoReplay
end, function()
    Settings.AutoReplay = not Settings.AutoReplay
    SaveSettings()
end, 3, true)

MakeSwitchRow(AutoGrid, "กลับ Hub", COLORS.green, function()
    return Settings.AutoReturnHub
end, function()
    Settings.AutoReturnHub = not Settings.AutoReturnHub
    SaveSettings()
end, 4, true)

MakeLabel(DashPage, "บัพ Wish ที่เลือกไว้", 6)

-- สรุปบัพ 3 อันดับแรกจากลำดับที่ผู้ใช้จัด
local WishSummaryBox = Instance.new("Frame")
WishSummaryBox.Size = UDim2.new(1, 0, 0, 108)
WishSummaryBox.BackgroundColor3 = COLORS.white
WishSummaryBox.LayoutOrder = 7
WishSummaryBox.Parent = DashPage
MakeCorner(WishSummaryBox, 12)
MakeStroke(WishSummaryBox, COLORS.brown, 2)

local SummaryPad = Instance.new("UIPadding")
SummaryPad.PaddingLeft = UDim.new(0, 10)
SummaryPad.PaddingRight = UDim.new(0, 10)
SummaryPad.PaddingTop = UDim.new(0, 10)
SummaryPad.PaddingBottom = UDim.new(0, 10)
SummaryPad.Parent = WishSummaryBox

local SummaryLayout = Instance.new("UIListLayout")
SummaryLayout.Padding = UDim.new(0, 4)
SummaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
SummaryLayout.Parent = WishSummaryBox

local WishSummaryRows = {}
for i = 1, 3 do
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 28)
    r.BackgroundTransparency = 1
    r.LayoutOrder = i
    r.Parent = WishSummaryBox

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 20, 0, 20)
    badge.Position = UDim2.new(0, 0, 0.5, -10)
    badge.BackgroundColor3 = COLORS.yellow
    badge.Text = tostring(i)
    badge.TextColor3 = COLORS.brown
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 11
    badge.Parent = r
    MakeCorner(badge, 6)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -140, 1, 0)
    nameLbl.Position = UDim2.new(0, 28, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = COLORS.text
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = r

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(0, 130, 1, 0)
    descLbl.Position = UDim2.new(1, -130, 0, 0)
    descLbl.BackgroundTransparency = 1
    descLbl.TextColor3 = COLORS.muted
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 11
    descLbl.TextXAlignment = Enum.TextXAlignment.Right
    descLbl.TextTruncate = Enum.TextTruncate.AtEnd
    descLbl.Parent = r

    WishSummaryRows[i] = { Badge = badge, Name = nameLbl, Desc = descLbl }
end

local function RefreshWishSummary()
    for i = 1, 3 do
        local r = WishSummaryRows[i]
        local key = Settings.WishOrder[i]
        local item = key and WishByKey[key]
        if item and r then
            r.Badge.BackgroundColor3 = (i == 1) and COLORS.red or COLORS.yellow
            r.Badge.TextColor3 = (i == 1) and COLORS.white or COLORS.brown
            r.Name.Text = item.name
            r.Desc.Text = item.desc
        end
    end
end

RefreshWishSummary()

-- ตัวเลขบัพที่เลือกไปแล้วในรอบนี้
OnWishPicked = function()
    wishPickedCount = wishPickedCount + 1
    PickedValue.Text = tostring(wishPickedCount)
end

-- ============================================================================
-- Slots page
-- ============================================================================
local SlotsHeader = Instance.new("Frame")
SlotsHeader.Size = UDim2.new(1, 0, 0, 22)
SlotsHeader.BackgroundTransparency = 1
SlotsHeader.LayoutOrder = 0
SlotsHeader.Parent = SlotsPage

local SlotsTitle = Instance.new("TextLabel")
SlotsTitle.Size = UDim2.new(0.6, 0, 1, 0)
SlotsTitle.BackgroundTransparency = 1
SlotsTitle.Text = "Slots"
SlotsTitle.TextColor3 = COLORS.text
SlotsTitle.Font = Enum.Font.GothamBold
SlotsTitle.TextSize = 15
SlotsTitle.TextXAlignment = Enum.TextXAlignment.Left
SlotsTitle.Parent = SlotsHeader

local SlotsHint = Instance.new("TextLabel")
SlotsHint.Size = UDim2.new(0.4, 0, 1, 0)
SlotsHint.Position = UDim2.new(0.6, 0, 0, 0)
SlotsHint.BackgroundTransparency = 1
SlotsHint.Text = "จำนวน / ระดับ"
SlotsHint.TextColor3 = COLORS.muted
SlotsHint.Font = Enum.Font.Gotham
SlotsHint.TextSize = 10
SlotsHint.TextXAlignment = Enum.TextXAlignment.Right
SlotsHint.Parent = SlotsHeader

local function GetMaxLimit(slotIdx)
    local maxLimit = 6
    local gc = GetGameController()
    if gc and gc.slots and gc.slots[slotIdx] and gc.capOf then
        maxLimit = gc.capOf(gc.slots[slotIdx]) or 6
    end
    return maxLimit
end

-- ปุ่ม − / ค่า / + แบบกะทัดรัด กว้าง 84 px
local function MakeMiniGroup(parent, xOffset)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 84, 1, 0)
    box.Position = UDim2.new(0, xOffset, 0, 0)
    box.BackgroundColor3 = COLORS.field
    box.Parent = parent
    MakeCorner(box, 8)
    MakeStroke(box, COLORS.brown, 1.5)

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 22, 0, 20)
    minus.Position = UDim2.new(0, 3, 0.5, -10)
    minus.BackgroundColor3 = COLORS.yellow
    minus.Text = "-"
    minus.TextColor3 = COLORS.brown
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 13
    minus.Parent = box
    MakeCorner(minus, 6)
    MakeStroke(minus, COLORS.brown, 1.5)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 22, 0, 20)
    plus.Position = UDim2.new(1, -25, 0.5, -10)
    plus.BackgroundColor3 = COLORS.green
    plus.Text = "+"
    plus.TextColor3 = COLORS.brown
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 13
    plus.Parent = box
    MakeCorner(plus, 6)
    MakeStroke(plus, COLORS.brown, 1.5)

    local value = Instance.new("TextLabel")
    value.Size = UDim2.new(0, 36, 1, 0)
    value.Position = UDim2.new(0.5, -18, 0, 0)
    value.BackgroundTransparency = 1
    value.Text = "0"
    value.TextColor3 = COLORS.text
    value.Font = Enum.Font.GothamBold
    value.TextSize = 13
    value.Parent = box

    return { Minus = minus, Plus = plus, Value = value }
end

local SlotRows = {}
for slotIdx = 1, 6 do
    Settings.Slots[slotIdx] = Settings.Slots[slotIdx] or { TargetCount = 0, TargetLevel = 0 }
    local slotConfig = Settings.Slots[slotIdx]

    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(1, 0, 0, 50)
    Card.BackgroundColor3 = COLORS.white
    Card.LayoutOrder = slotIdx
    Card.Parent = SlotsPage
    MakeCorner(Card, 10)
    MakeStroke(Card, COLORS.brown, 2)

    local SlotTitle = Instance.new("TextLabel")
    SlotTitle.Size = UDim2.new(1, -200, 0, 16)
    SlotTitle.Position = UDim2.new(0, 10, 0, 7)
    SlotTitle.BackgroundTransparency = 1
    SlotTitle.Text = string.format("%d: ว่าง", slotIdx)
    SlotTitle.TextColor3 = COLORS.text
    SlotTitle.Font = Enum.Font.GothamBold
    SlotTitle.TextSize = 12
    SlotTitle.TextXAlignment = Enum.TextXAlignment.Left
    SlotTitle.TextTruncate = Enum.TextTruncate.AtEnd
    SlotTitle.Parent = Card

    local SlotSub = Instance.new("TextLabel")
    SlotSub.Size = UDim2.new(1, -200, 0, 12)
    SlotSub.Position = UDim2.new(0, 10, 0, 27)
    SlotSub.BackgroundTransparency = 1
    SlotSub.Text = "ยังไม่มียูนิต"
    SlotSub.TextColor3 = COLORS.muted
    SlotSub.Font = Enum.Font.Gotham
    SlotSub.TextSize = 10
    SlotSub.TextXAlignment = Enum.TextXAlignment.Left
    SlotSub.Parent = Card

    local Steppers = Instance.new("Frame")
    Steppers.Size = UDim2.new(0, 176, 0, 28)
    Steppers.Position = UDim2.new(1, -186, 0.5, -14)
    Steppers.BackgroundTransparency = 1
    Steppers.Visible = false
    Steppers.Parent = Card

    local countGroup = MakeMiniGroup(Steppers, 0)
    local levelGroup = MakeMiniGroup(Steppers, 92)

    local function RefreshSlot()
        countGroup.Value.Text = tostring(slotConfig.TargetCount)
        levelGroup.Value.Text = slotConfig.TargetLevel == 0 and "OFF" or tostring(slotConfig.TargetLevel)
    end

    countGroup.Plus.MouseButton1Click:Connect(function()
        local maxLimit = GetMaxLimit(slotIdx)
        if slotConfig.TargetCount < maxLimit then
            slotConfig.TargetCount = slotConfig.TargetCount + 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    countGroup.Minus.MouseButton1Click:Connect(function()
        if slotConfig.TargetCount > 0 then
            slotConfig.TargetCount = slotConfig.TargetCount - 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    levelGroup.Plus.MouseButton1Click:Connect(function()
        if slotConfig.TargetLevel < 10 then
            slotConfig.TargetLevel = slotConfig.TargetLevel + 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    levelGroup.Minus.MouseButton1Click:Connect(function()
        if slotConfig.TargetLevel > 0 then
            slotConfig.TargetLevel = slotConfig.TargetLevel - 1
        end
        RefreshSlot()
        SaveSettings()
    end)

    SlotRows[slotIdx] = {
        Card = Card,
        Title = SlotTitle,
        Sub = SlotSub,
        Steppers = Steppers,
        CountBtn = countGroup.Value,
        LvlBtn = levelGroup.Value
    }
    RefreshSlot()
end

-- ============================================================================
-- Wish priority page
-- ============================================================================
local WishTitle = Instance.new("TextLabel")
WishTitle.Size = UDim2.new(1, 0, 0, 22)
WishTitle.BackgroundTransparency = 1
WishTitle.Text = "Wish priority"
WishTitle.TextColor3 = COLORS.text
WishTitle.Font = Enum.Font.GothamBold
WishTitle.TextSize = 15
WishTitle.TextXAlignment = Enum.TextXAlignment.Left
WishTitle.LayoutOrder = 1
WishTitle.Parent = WishPage

local WishHint = Instance.new("TextLabel")
WishHint.Size = UDim2.new(1, 0, 0, 16)
WishHint.BackgroundTransparency = 1
WishHint.Text = "Top is picked first. Use Up and Down to reorder."
WishHint.TextColor3 = COLORS.muted
WishHint.Font = Enum.Font.Gotham
WishHint.TextSize = 11
WishHint.TextXAlignment = Enum.TextXAlignment.Left
WishHint.LayoutOrder = 2
WishHint.Parent = WishPage

MakeSwitchRow(WishPage, "Auto pick wish", COLORS.green, function()
    return Settings.WishAutoPick
end, function()
    Settings.WishAutoPick = not Settings.WishAutoPick
    SaveSettings()
end, 3)

local ResetWishBtn = Instance.new("TextButton")
ResetWishBtn.Size = UDim2.new(1, 0, 0, 30)
ResetWishBtn.BackgroundColor3 = COLORS.yellow
ResetWishBtn.Text = "Reset to default order"
ResetWishBtn.TextColor3 = COLORS.brown
ResetWishBtn.Font = Enum.Font.GothamBold
ResetWishBtn.TextSize = 12
ResetWishBtn.LayoutOrder = 4
ResetWishBtn.Parent = WishPage
MakeCorner(ResetWishBtn, 10)
MakeStroke(ResetWishBtn, COLORS.brown, 2)

local RebuildWishList

local function BuildWishRow(rank, item)
    local total = #Settings.WishOrder

    local row = Instance.new("Frame")
    row.Name = "WishRow"
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = COLORS.white
    row.LayoutOrder = 10 + rank
    row.Parent = WishPage
    MakeCorner(row, 10)
    MakeStroke(row, rank == 1 and COLORS.red or COLORS.brown, 2)

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 26, 0, 26)
    badge.Position = UDim2.new(0, 10, 0.5, -13)
    badge.BackgroundColor3 = rank == 1 and COLORS.red or (rank <= 10 and COLORS.yellow or COLORS.sky)
    badge.Text = tostring(rank)
    badge.TextColor3 = rank == 1 and COLORS.white or COLORS.brown
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 12
    badge.Parent = row
    MakeCorner(badge, 7)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -150, 0, 18)
    nameLabel.Position = UDim2.new(0, 46, 0, 7)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name .. "  ·  " .. item.rarity
    nameLabel.TextColor3 = COLORS.text
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = row

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -150, 0, 18)
    descLabel.Position = UDim2.new(0, 46, 0, 28)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = item.desc
    descLabel.TextColor3 = COLORS.muted
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 11
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descLabel.Parent = row

    local upBtn = Instance.new("TextButton")
    upBtn.Size = UDim2.new(0, 42, 0, 20)
    upBtn.Position = UDim2.new(1, -52, 0, 7)
    upBtn.BackgroundColor3 = rank > 1 and COLORS.yellow or COLORS.off
    upBtn.Text = "Up"
    upBtn.TextColor3 = COLORS.brown
    upBtn.Font = Enum.Font.GothamBold
    upBtn.TextSize = 10
    upBtn.Parent = row
    MakeCorner(upBtn, 6)
    MakeStroke(upBtn, COLORS.brown, 1.5)

    local downBtn = Instance.new("TextButton")
    downBtn.Size = UDim2.new(0, 42, 0, 20)
    downBtn.Position = UDim2.new(1, -52, 0, 29)
    downBtn.BackgroundColor3 = rank < total and COLORS.yellow or COLORS.off
    downBtn.Text = "Down"
    downBtn.TextColor3 = COLORS.brown
    downBtn.Font = Enum.Font.GothamBold
    downBtn.TextSize = 10
    downBtn.Parent = row
    MakeCorner(downBtn, 6)
    MakeStroke(downBtn, COLORS.brown, 1.5)

    upBtn.MouseButton1Click:Connect(function()
        if rank > 1 then
            local order = Settings.WishOrder
            order[rank], order[rank - 1] = order[rank - 1], order[rank]
            SaveSettings()
            RebuildWishList()
        end
    end)

    downBtn.MouseButton1Click:Connect(function()
        local order = Settings.WishOrder
        if rank < #order then
            order[rank], order[rank + 1] = order[rank + 1], order[rank]
            SaveSettings()
            RebuildWishList()
        end
    end)
end

RebuildWishList = function()
    for _, child in ipairs(WishPage:GetChildren()) do
        if child.Name == "WishRow" then
            child:Destroy()
        end
    end
    for rank, key in ipairs(Settings.WishOrder) do
        local item = WishByKey[key]
        if item then
            BuildWishRow(rank, item)
        end
    end
    RefreshWishSummary()
end

ResetWishBtn.MouseButton1Click:Connect(function()
    Settings.WishOrder = DefaultWishOrder()
    SaveSettings()
    RebuildWishList()
end)

RebuildWishList()

ShowPage("Dashboard")

-- ============================================================================
-- 5. End Screen Overlay Handler + Raid Replay Pay System
-- ============================================================================
local lastReplayPay = 0
local function HandleEndScreen()
    local candyGui = PlayerGui:FindFirstChild("CandyTD")
    if candyGui then
        -- 0. ตรวจสอบ UI ReplayItems / Popup ยืนยันการใช้ไอเทม Raid
        if Settings.AutoReplay then
            local replayItems = candyGui:FindFirstChild("ReplayItems")
            if replayItems then
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
            if Settings.AutoReplay then
                -- 1. ลองจ่ายไอเทมเรด/ประตูเพื่อ Replay ก่อน
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

                -- 3. กดปุ่ม Next
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
        StatusBar.Text = string.format("กำลังเริ่ม... (%d วินาที)", i)
        StatusBar.TextColor3 = COLORS.statusWait
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
                            row.Title.Text = string.format("%d: %s", slotIdx, unitName)
                            row.Sub.Text = string.format("สูงสุด %d", cap)
                            row.Card.BackgroundColor3 = COLORS.white
                            row.Steppers.Visible = true
                        else
                            row.Title.Text = string.format("%d: ว่าง", slotIdx)
                            row.Sub.Text = "ยังไม่มียูนิต"
                            row.Card.BackgroundColor3 = COLORS.cream
                            row.Steppers.Visible = false
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

                    -- Auto Ability
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

                        for _, tower in ipairs(others) do
                            task.spawn(function()
                                pcall(function()
                                    ActRemote:InvokeServer("ability", tower.id)
                                end)
                            end)
                        end

                        if #vamps > 0 then
                            table.sort(vamps, function(a, b) return a.id < b.id end)

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
                                            break
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

                    UnitsValue.Text = string.format("%d / %d", totalPlacedConfigured, totalTargetConfigured)

                    if not anyTargetConfigured then
                        SetProgress(0, 0)
                        StatusBar.Text = "รอ (ยังไม่ได้ตั้งเป้าหมายทุกช่อง)"
                        StatusBar.TextColor3 = COLORS.statusDefault

                    elseif needMorePlacement then
                        SetProgress(totalPlacedConfigured, totalTargetConfigured)
                        StatusBar.Text = "กำลังวางยูนิต"
                        StatusBar.TextColor3 = COLORS.statusWait

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

                    else
                        local bestCandidate = nil
                        local lowestLevel = math.huge
                        local bestSlotIdx = 0

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

                        SetProgress(totalPlacedConfigured, totalTargetConfigured)

                        if bestCandidate then
                            local unitKind = bestCandidate.unit
                            local config = Settings.Slots[bestSlotIdx]
                            StatusBar.Text = string.format("กำลังอัปเกรด: Slot %d (%s) Lvl %d->%d", bestSlotIdx, unitKind, bestCandidate.level, config.TargetLevel)
                            StatusBar.TextColor3 = COLORS.statusDone
                            pcall(function()
                                gc.net.request("upgrade", bestCandidate.id)
                            end)
                        else
                            StatusBar.Text = "วางและอัปเกรดครบแล้ว"
                            StatusBar.TextColor3 = COLORS.statusDone
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- Wish Picker Loop (ตรวจเช็คหน้าต่าง Wish ทุก 0.5 วินาที)
-- ============================================================================
task.spawn(function()
    print("[WishPicker] Script started! Listening for Wish offers...")
    while _G.CKD_SlotMacro_Running do
        pcall(checkAndPickWish)
        task.wait(0.5)
    end
end)

print("[CKD] Macro Ready: Auto Ability + Distributed Upgrade + Wish Priority Picker Loaded with 12s Delay!")