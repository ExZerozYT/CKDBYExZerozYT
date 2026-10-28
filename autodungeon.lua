-- =========================================================
-- [Auto Challenge Train - Persistent File State Loop]
-- =========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- รอ LocalPlayer โหลดเสร็จ
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local SAVE_FILE = "CandyTD_AutoTrain_State.json"
local targetCars = {1, 2, 3}

-- ฟังก์ชันอ่านข้อมูลจากไฟล์ (แก้ไขจุดบั๊ก pcall แล้ว)
local function loadState()
    if isfile and isfile(SAVE_FILE) then
        local readOk, content = pcall(readfile, SAVE_FILE)
        if readOk and content and #content > 0 then
            local jsonOk, data = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if jsonOk and type(data) == "table" then
                return data
            end
        end
    end
    return { currentPeriod = 0, nextCarIdx = 1 }
end

-- ฟังก์ชันบันทึกข้อมูลลงไฟล์
local function saveState(period, nextIdx)
    if writefile then
        local data = {
            currentPeriod = period,
            nextCarIdx = nextIdx
        }
        local encoded = HttpService:JSONEncode(data)
        pcall(writefile, SAVE_FILE, encoded)
    end
end

local isProcessing = false

local function joinNextChallenge()
    if isProcessing then return end
    isProcessing = true

    print("[Auto Train]: Checking place...")

    -- ตรวจสอบว่าอยู่ใน Hub / Lobby หรือไม่
    local HubFolder = ReplicatedStorage:WaitForChild("Hub", 5)
    local HubRemotes = ReplicatedStorage:WaitForChild("HubRemotes", 5)
    
    if not HubFolder or not HubRemotes then
        print("[Auto Train]: Not in Hub / Lobby. Standing by...")
        isProcessing = false
        return
    end

    local CatalogMod = HubFolder:WaitForChild("Catalog", 10)
    local CreateMatch = HubRemotes:WaitForChild("CreateMatch", 10)
    local StartMatch = HubRemotes:WaitForChild("StartMatch", 10)

    if not CatalogMod or not CreateMatch or not StartMatch then
        print("[Auto Train]: Core components not ready. Standing by...")
        isProcessing = false
        return
    end

    task.wait(4.0) -- [ปรับแก้ดีเรย์] จาก 2.5 เป็น 4.0 วินาที (รอระบบซิงค์เซิร์ฟเวอร์ให้นานขึ้น)

    local Catalog = require(CatalogMod)
    local serverNow = workspace:GetServerTimeNow()
    
    -- คำนวณ Period ของรอบ 30 นาที
    local currentPeriod = Catalog.challengePeriod and Catalog.challengePeriod(serverNow) or math.floor(serverNow / 1800)
    local challenges = Catalog.challengesAt and Catalog.challengesAt(serverNow)

    if not challenges or #challenges == 0 then
        warn("[Auto Train]: Could not get challenges from Catalog.")
        isProcessing = false
        return
    end

    -- โหลดข้อมูลรอบและตู้ที่เซฟไว้
    local state = loadState()
    local carIdxToPlay = 1

    -- ตรวจสอบว่ายังเป็นรอบ 30 นาทีเดิมหรือไม่
    if state.currentPeriod == currentPeriod then
        carIdxToPlay = state.nextCarIdx or 1
        print(string.format("[Auto Train]: Continuing current period (%s) -> Playing CAR %d", tostring(currentPeriod), targetCars[carIdxToPlay]))
    else
        print(string.format("[Auto Train]: New 30-min period detected (%s -> %s)! Resetting to CAR 1.", tostring(state.currentPeriod), tostring(currentPeriod)))
        carIdxToPlay = 1
    end

    local carNum = targetCars[carIdxToPlay]
    local targetChallenge = challenges[carNum]

    if not targetChallenge then
        warn(string.format("[Auto Train]: Data for Car %d not found!", carNum))
        isProcessing = false
        return
    end

    print(string.format("[Auto Train]: Target CAR %d -> Stage: %s, ID: %s", carNum, tostring(targetChallenge.stage), tostring(targetChallenge.id)))

    -- 1. บันทึกคิวของรอบต่อไปลงไฟล์ทันที (วน 1 -> 2 -> 3 -> 1 ...)
    local nextIdx = (carIdxToPlay % #targetCars) + 1
    saveState(currentPeriod, nextIdx)
    print(string.format("[Auto Train]: Saved! Next game will target CAR %d.", targetCars[nextIdx]))

    -- 2. สร้างห้อง CreateMatch
    print(string.format("[Auto Train]: Invoking CreateMatch for CAR %d...", carNum))
    pcall(function()
        CreateMatch:InvokeServer(targetChallenge.stage, targetChallenge.id, true)
    end)

    task.wait(2.0) -- [ปรับแก้ดีเรย์] จาก 0.8 เป็น 2.0 วินาที (เว้นระยะให้เซิร์ฟเวอร์สร้างห้องเสร็จ)

    -- 3. เริ่มเกม StartMatch
    print("[Auto Train]: Invoking StartMatch...")
    pcall(function()
        StartMatch:InvokeServer()
    end)

    isProcessing = false
end

-- เมื่อตัวละครเกิดใหม่ (เมื่อจบเกมกลับมา Hub)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(3.5) -- [ปรับแก้ดีเรย์] จาก 2 เป็น 3.5 วินาที (รอให้โหลดเข้า Hub สมบูรณ์ก่อนเริ่มทำงาน)
    joinNextChallenge()
end)

-- รันทันทีหากโหลดเข้าเกมมาอยู่แล้ว
if LocalPlayer.Character then
    task.spawn(function()
        task.wait(2.0) -- [ปรับแก้ดีเรย์] เพิ่มดีเรย์เล็กน้อยตอนรันสคริปต์ครั้งแรก
        joinNextChallenge()
    end)
end