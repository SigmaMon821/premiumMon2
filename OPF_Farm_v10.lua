local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "OPF Hub",
    SubTitle = "Farm Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 500),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftAlt,
})

local Tabs = {
    Farm     = Window:AddTab({ Title = "Auto Farm",  Icon = "sword" }),
    Item     = Window:AddTab({ Title = "Item",        Icon = "star" }),
    Player   = Window:AddTab({ Title = "Player",      Icon = "user" }),
    Teleport = Window:AddTab({ Title = "Teleport",   Icon = "map-pin" }),
    Skill    = Window:AddTab({ Title = "Auto Skill", Icon = "zap" }),
    Misc     = Window:AddTab({ Title = "Misc",       Icon = "settings" }),
    Settings = Window:AddTab({ Title = "Settings",   Icon = "sliders-horizontal" }),
}

-- ─── Wanted Items ─────────────────────────────────────────────────────────────
local WantedItems = {
    ["Rare Box"]       = true,
    ["Ultra Rare Box"] = true,
    ["Chilly Fruit"]   = true,
    ["Vampire Fruit"]  = true,
    ["Sand Fruit"]     = true,
    ["Plasma Fruit"]   = true,
    ["Snow Fruit"]     = true,
    ["Light Fruit"]    = true,
    ["Candy Fruit"]    = true,
    ["Quake Fruit"]    = true,
    ["Blood Fruit"]    = true,
    ["Ope Fruit"]      = true,
    ["Gum Fruit"]      = true,
    ["Dark Fruit"]     = true,
    ["Rumble Fruit"]   = true,
    ["Gravity Fruit"]  = true,
    ["Venom Fruit"]    = true,
    ["Magma Fruit"]    = true,
    ["Gas Fruit"]      = true,
    ["Hollow Fruit"]   = true,
    ["Flare Fruit"]    = true,
    ["Alice Fruit"]    = true,
    ["Reset Token"]    = true,
    ["Compass"]        = true,
}

-- ─── State ────────────────────────────────────────────────────────────────────
local State = {
    AutoFarm         = false,
    TeleportMode     = "Behind",
    TeleportOffset   = 3.5,
    FarmMode         = "ทั้งหมด",
    TargetName       = "",
    MaxLv            = 300,
    FarmConnection   = nil,
    AttackConnection = nil,
    ItemESP          = false,
    AutoPickup       = false,
    FollowPlayer     = false,
    FollowMode       = "Behind",
    FollowOffset     = 2.5,
    FollowTarget     = "",
    FollowConnection = nil,
}

local SkillConfig = {
    Interval = 0.4,
    HoldTime = 0.0,
    Mode     = "Tap",
}

-- ─── ClassName-safe Helpers ───────────────────────────────────────────────────

-- Character ของ LocalPlayer (Model)
local function GetChar()
    return LocalPlayer.Character
end

-- HumanoidRootPart = BasePart ชื่อ HumanoidRootPart (ชื่อนี้ unique ใน Roblox engine)
local function GetHRP()
    local c = GetChar()
    if not c then return nil end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "HumanoidRootPart" then return v end
    end
end

-- Humanoid ใน Character
local function GetHumanoid()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- root ของ Model (HumanoidRootPart หรือ UpperTorso หรือ Torso ล้วน BasePart)
local function GetModelRoot(model)
    for _, v in ipairs(model:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "HumanoidRootPart" then return v end
    end
    for _, v in ipairs(model:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "UpperTorso" then return v end
    end
    for _, v in ipairs(model:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "Torso" then return v end
    end
    return nil
end

-- Head ของ Model (BasePart ชื่อ Head)
local function GetModelHead(model)
    for _, v in ipairs(model:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "Head" then return v end
    end
    return nil
end

-- Alive Folder: ClassName = Folder, Name = "Alive" ใน workspace
local function GetAliveFolder()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Folder") and obj.Name == "Alive" then return obj end
    end
    return nil
end

-- ตรวจ Tool ที่ต้องการ (ClassName = Tool)
local function IsWantedTool(obj)
    if not obj:IsA("Tool") then return false end
    for name in pairs(WantedItems) do
        if obj.Name:find(name) then return true end
    end
    return false
end

-- Handle ของ Tool (ClassName = BasePart ชื่อ Handle)
local function GetHandle(tool)
    for _, v in ipairs(tool:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "Handle" then return v end
    end
    return nil
end

-- ตรวจว่า Model นี้เป็น Character ของ Player คนไหนไหม
local function IsPlayerCharacter(model)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == model then return true end
    end
    return false
end

-- ─── Monster Helpers ──────────────────────────────────────────────────────────
local function GetMonsterLv(name)
    local lv = name:match("Lv(%d+)")
    return lv and tonumber(lv) or 0
end

local function GetMonsterNames()
    local alive = GetAliveFolder()
    if not alive then return {} end
    local seen, names = {}, {}
    for _, model in ipairs(alive:GetChildren()) do
        if model:IsA("Model") and model.Name:find("Lv") and not IsPlayerCharacter(model) then
            if not seen[model.Name] then
                seen[model.Name] = true
                table.insert(names, model.Name)
            end
        end
    end
    table.sort(names, function(a, b) return GetMonsterLv(a) < GetMonsterLv(b) end)
    return names
end

local function IsValidMonster(model)
    if not model:IsA("Model") then return false end
    if not model.Name:find("Lv") then return false end
    if IsPlayerCharacter(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    if State.FarmMode == "เจาะจง" then
        return model.Name == State.TargetName
    else
        if model.Name:find("Vokun") then return true end
        return GetMonsterLv(model.Name) <= State.MaxLv
    end
end

local function GetNearestMonster()
    local hrp = GetHRP()
    if not hrp then return nil end
    local alive = GetAliveFolder()
    if not alive then return nil end

    local nearest, shortest = nil, math.huge
    for _, model in ipairs(alive:GetChildren()) do
        if IsValidMonster(model) then
            local root = GetModelRoot(model)
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < shortest then shortest = dist; nearest = model end
            end
        end
    end
    return nearest
end

-- ─── CFrame Offset ────────────────────────────────────────────────────────────
local function GetOffsetCFrame(rootCF, mode, offset)
    if mode == "Behind" then
        return rootCF * CFrame.new(0, 0, offset)
    else
        return rootCF * CFrame.new(0, offset, 0) * CFrame.Angles(math.pi, 0, 0)
    end
end

-- ─── Auto Farm (Heartbeat) ────────────────────────────────────────────────────
local function StopFarm()
    if State.FarmConnection   then State.FarmConnection:Disconnect();   State.FarmConnection   = nil end
    if State.AttackConnection then State.AttackConnection:Disconnect(); State.AttackConnection = nil end
end

local function StartFarm()
    StopFarm()
    local currentTarget = nil

    State.FarmConnection = RunService.Heartbeat:Connect(function()
        if not State.AutoFarm then return end
        local hrp   = GetHRP()
        local myHum = GetHumanoid()
        if not hrp or not myHum or myHum.Health <= 0 then return end

        if currentTarget then
            local monHum = currentTarget:FindFirstChildOfClass("Humanoid")
            local root   = GetModelRoot(currentTarget)
            if monHum and monHum.Health > 0 and root and root.Parent then
                hrp.CFrame = GetOffsetCFrame(root.CFrame, State.TeleportMode, State.TeleportOffset)
                return
            else
                currentTarget = nil
            end
        end

        currentTarget = GetNearestMonster()
    end)

    State.AttackConnection = RunService.Heartbeat:Connect(function()
        if not State.AutoFarm then return end
        local char = GetChar()
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    end)
end

-- ─── Item ESP ─────────────────────────────────────────────────────────────────
-- ค้นหา Tool (ClassName) ใน Backpack (Backpack = ClassName Backpack) และ Character (Model)
local function FindItemInPlayer(plr)
    local found = nil

    -- Backpack: ClassName = Backpack → ลูกเป็น Tool
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then
                for name in pairs(WantedItems) do
                    if item.Name:find(name) then found = item.Name; break end
                end
            end
            if found then break end
        end
    end

    -- Character (Model): Tool ที่กำลังถืออยู่
    if not found and plr.Character then
        for _, item in ipairs(plr.Character:GetChildren()) do
            if item:IsA("Tool") then
                for name in pairs(WantedItems) do
                    if item.Name:find(name) then found = item.Name; break end
                end
                if found then break end
            end
        end
    end

    return found
end

local function CheckPlayerItems(plr)
    if plr == LocalPlayer then return end
    if not plr.Character then return end
    local head = GetModelHead(plr.Character)
    if not head then return end

    local found = FindItemInPlayer(plr)
    local tag   = head:FindFirstChild("ItemESP")

    if State.ItemESP and found then
        if not tag then
            tag = Instance.new("BillboardGui", head)
            tag.Name = "ItemESP"
            tag.Size = UDim2.new(0, 220, 0, 35)
            tag.AlwaysOnTop = true
            tag.ExtentsOffset = Vector3.new(0, 3, 0)
            local label = Instance.new("TextLabel", tag)
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(255, 220, 0)
            label.TextScaled = true
            label.Font = Enum.Font.GothamBold
            label.Text = "⭐ " .. plr.Name .. ": " .. found
        else
            local label = tag:FindFirstChildOfClass("TextLabel")
            if label then label.Text = "⭐ " .. plr.Name .. ": " .. found end
        end
    elseif tag then
        tag:Destroy()
    end
end

local function StartItemESPLoop()
    task.spawn(function()
        while State.ItemESP do
            for _, plr in ipairs(Players:GetPlayers()) do
                pcall(function() CheckPlayerItems(plr) end)
            end
            task.wait(2)
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            pcall(function()
                if not plr.Character then return end
                local head = GetModelHead(plr.Character)
                if head then
                    local tag = head:FindFirstChild("ItemESP")
                    if tag then tag:Destroy() end
                end
            end)
        end
    end)
end

-- ─── Auto Pickup ──────────────────────────────────────────────────────────────
-- ค้นหา ClassName = Tool ใน workspace โดยตรง
-- ของที่ตกพื้น Parent จะเป็น workspace (ไม่มี Humanoid เป็น ancestor)
local function StartAutoPickup()
    task.spawn(function()
        while State.AutoPickup do
            task.wait(0.3)
            local hrp = GetHRP()
            if not hrp then continue end

            for _, obj in ipairs(workspace:GetChildren()) do
                if not State.AutoPickup then break end
                if IsWantedTool(obj) then
                    -- Parent ของ Tool ที่ตกพื้นคือ workspace ไม่มี Humanoid
                    local parentHasHuman = obj.Parent and obj.Parent:FindFirstChildOfClass("Humanoid")
                    if not parentHasHuman then
                        local handle = GetHandle(obj)
                        if handle then
                            hrp.CFrame = CFrame.new(handle.Position)
                            task.wait(0.15)
                            pcall(function() firetouchinterest(hrp, handle, 0) end)
                            task.wait(0.1)
                            pcall(function() firetouchinterest(hrp, handle, 1) end)
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end)
end

-- ─── Follow Player (Heartbeat) ────────────────────────────────────────────────
local function StopFollowPlayer()
    if State.FollowConnection then State.FollowConnection:Disconnect(); State.FollowConnection = nil end
end

local function StartFollowPlayer()
    StopFollowPlayer()
    State.FollowConnection = RunService.Heartbeat:Connect(function()
        if not State.FollowPlayer or State.FollowTarget == "" then return end
        local hrp   = GetHRP()
        local myHum = GetHumanoid()
        if not hrp or not myHum or myHum.Health <= 0 then return end

        local targetPlr = Players:FindFirstChild(State.FollowTarget)
        if not targetPlr or not targetPlr.Character then return end

        local targetRoot = GetModelRoot(targetPlr.Character)
        if not targetRoot then return end

        hrp.CFrame = GetOffsetCFrame(targetRoot.CFrame, State.FollowMode, State.FollowOffset)
    end)
end

local function GetPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then table.insert(names, plr.Name) end
    end
    if #names == 0 then table.insert(names, "ไม่มีผู้เล่น") end
    return names
end

-- ─── Farm Tab ─────────────────────────────────────────────────────────────────
Tabs.Farm:AddSection("Monster Farm")

Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title       = "Auto Farm Monster",
    Description = "Heartbeat lock-on ประกบมอนทุก frame",
    Default     = false,
    Callback    = function(val)
        State.AutoFarm = val
        if val then StartFarm() else StopFarm() end
    end,
})

Tabs.Farm:AddDropdown("FarmModeDD", {
    Title       = "โหมดฟาม",
    Description = "ทั้งหมด = ฟามทุกมอน Lv ≤ ที่กำหนด  /  เจาะจง = เลือกชื่อมอน",
    Values      = { "ทั้งหมด", "เจาะจง" },
    Default     = "ทั้งหมด",
    Callback    = function(val) State.FarmMode = val end,
})

Tabs.Farm:AddInput("MaxLvInput", {
    Title       = "Lv สูงสุด (โหมดทั้งหมด)",
    Description = "ข้ามมอนที่ Lv เกินค่านี้  (Vokun ยกเว้นเสมอ)",
    Default     = "300",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local n = tonumber(val)
        if n then State.MaxLv = n end
    end,
})

local monsterNames = GetMonsterNames()
if #monsterNames == 0 then monsterNames = { "ยังไม่พบมอน" } end

local MonsterDD = Tabs.Farm:AddDropdown("MonsterNameDD", {
    Title       = "เลือกมอน (โหมดเจาะจง)",
    Description = "กด Refresh ถ้ายังไม่เห็นมอน",
    Values      = monsterNames,
    Default     = monsterNames[1],
    Callback    = function(val) State.TargetName = val end,
})
State.TargetName = monsterNames[1]

Tabs.Farm:AddButton({
    Title    = "🔄 Refresh Monster List",
    Callback = function()
        local newNames = GetMonsterNames()
        if #newNames == 0 then
            Fluent:Notify({ Title = "Refresh", Content = "ไม่พบมอนใน Alive", Duration = 3 })
            return
        end
        MonsterDD:SetValues(newNames)
        MonsterDD:SetValue(newNames[1])
        State.TargetName = newNames[1]
        Fluent:Notify({ Title = "Refresh", Content = "พบมอน " .. #newNames .. " ชนิด", Duration = 3 })
    end,
})

Tabs.Farm:AddDropdown("TeleportModeDD", {
    Title       = "รูปแบบการประกบ",
    Description = "Behind = ด้านหลัง  /  Above = ด้านบน (นอนคว่ำ)",
    Values      = { "Behind", "Above" },
    Default     = "Behind",
    Callback    = function(val) State.TeleportMode = val end,
})

Tabs.Farm:AddInput("TeleportOffsetInput", {
    Title    = "ระยะประกบ (studs)",
    Default  = "3.5",
    Numeric  = true,
    Finished = false,
    Callback = function(val)
        local n = tonumber(val)
        if n then State.TeleportOffset = n end
    end,
})

-- ─── Item Tab ─────────────────────────────────────────────────────────────────
Tabs.Item:AddSection("Item ESP")

Tabs.Item:AddToggle("ItemESPToggle", {
    Title       = "Item ESP",
    Description = "ค้นหา ClassName=Tool ใน Backpack และ Character",
    Default     = false,
    Callback    = function(val)
        State.ItemESP = val
        if val then StartItemESPLoop() end
    end,
})

Tabs.Item:AddSection("Auto Pickup")

Tabs.Item:AddToggle("AutoPickupToggle", {
    Title       = "Auto Pickup",
    Description = "ค้นหา ClassName=Tool ใน workspace แล้ววาปเก็บ",
    Default     = false,
    Callback    = function(val)
        State.AutoPickup = val
        if val then StartAutoPickup() end
    end,
})

Tabs.Item:AddSection("รายการของที่ติดตาม / เก็บ")
local itemList = {}
for name in pairs(WantedItems) do table.insert(itemList, name) end
table.sort(itemList)
Tabs.Item:AddLabel(table.concat(itemList, "  |  "))

-- ─── Player Tab ───────────────────────────────────────────────────────────────
Tabs.Player:AddSection("Follow / ติดตาม Player")

local playerNames = GetPlayerNames()

local PlayerDD = Tabs.Player:AddDropdown("PlayerTargetDD", {
    Title    = "เลือก Player ที่จะติดตาม",
    Values   = playerNames,
    Default  = playerNames[1],
    Callback = function(val) State.FollowTarget = val end,
})
State.FollowTarget = playerNames[1]

Tabs.Player:AddButton({
    Title    = "🔄 Refresh Player List",
    Callback = function()
        local newNames = GetPlayerNames()
        PlayerDD:SetValues(newNames)
        PlayerDD:SetValue(newNames[1])
        State.FollowTarget = newNames[1]
        Fluent:Notify({ Title = "Refresh", Content = "อัปเดตรายชื่อผู้เล่นแล้ว", Duration = 3 })
    end,
})

Tabs.Player:AddDropdown("FollowModeDD", {
    Title       = "รูปแบบการติดตาม",
    Description = "Behind = ประกบหลัง  /  Above = ประกบบน (นอนคว่ำ)",
    Values      = { "Behind", "Above" },
    Default     = "Behind",
    Callback    = function(val) State.FollowMode = val end,
})

Tabs.Player:AddInput("FollowOffsetInput", {
    Title    = "ระยะประกบ (studs)",
    Default  = "2.5",
    Numeric  = true,
    Finished = false,
    Callback = function(val)
        local n = tonumber(val)
        if n then State.FollowOffset = n end
    end,
})

Tabs.Player:AddToggle("FollowPlayerToggle", {
    Title       = "ติดตาม Player (Heartbeat)",
    Description = "ประกบหลัง/บน Player ที่เลือกตลอดเวลา",
    Default     = false,
    Callback    = function(val)
        State.FollowPlayer = val
        if val then StartFollowPlayer() else StopFollowPlayer() end
    end,
})

Tabs.Player:AddButton({
    Title       = "วาปหา Player (ครั้งเดียว)",
    Description = "วาปไปหา Player ที่เลือกทันที",
    Callback    = function()
        local hrp = GetHRP()
        if not hrp then return end
        local targetPlr = Players:FindFirstChild(State.FollowTarget)
        if not targetPlr or not targetPlr.Character then
            Fluent:Notify({ Title = "Error", Content = "ไม่พบ Player หรือ Character", Duration = 3 })
            return
        end
        local targetRoot = GetModelRoot(targetPlr.Character)
        if targetRoot then
            hrp.CFrame = GetOffsetCFrame(targetRoot.CFrame, State.FollowMode, State.FollowOffset)
            Fluent:Notify({ Title = "Teleport", Content = "วาปไปหา: " .. State.FollowTarget, Duration = 3 })
        end
    end,
})

-- ─── Teleport Tab ─────────────────────────────────────────────────────────────
Tabs.Teleport:AddSection("Locations")

local Locations = {
    ["Spawn"]         = CFrame.new(0, 5, 0),
    ["Marine Base"]   = CFrame.new(500, 5, 200),
    ["Pirate Island"] = CFrame.new(-300, 5, 600),
    ["Marineford"]    = CFrame.new(-800, 5, -300),
    ["Grand Line"]    = CFrame.new(1200, 5, -400),
}

for name, cf in pairs(Locations) do
    Tabs.Teleport:AddButton({
        Title    = "Teleport: " .. name,
        Callback = function()
            local hrp = GetHRP()
            if hrp then hrp.CFrame = cf end
        end,
    })
end

Tabs.Teleport:AddButton({
    Title    = "Teleport to Nearest Monster",
    Callback = function()
        local hrp    = GetHRP()
        local target = GetNearestMonster()
        if target and hrp then
            local root = GetModelRoot(target)
            if root then
                hrp.CFrame = GetOffsetCFrame(root.CFrame, State.TeleportMode, State.TeleportOffset)
                Fluent:Notify({ Title = "Teleport", Content = "วาปไปหา: " .. target.Name, Duration = 3 })
            end
        else
            Fluent:Notify({ Title = "ไม่พบ Monster", Content = "ไม่มีมอนที่ผ่านเงื่อนไขใน Alive", Duration = 3 })
        end
    end,
})

-- ─── Skill Tab ────────────────────────────────────────────────────────────────
Tabs.Skill:AddSection("ตั้งค่าการกด")

Tabs.Skill:AddDropdown("SkillModeDD", {
    Title    = "โหมดการกด",
    Values   = { "Tap", "Hold" },
    Default  = "Tap",
    Callback = function(val) SkillConfig.Mode = val end,
})

Tabs.Skill:AddInput("SkillIntervalInput", {
    Title    = "ความเร็วการกด (วินาที)",
    Default  = "0.4",
    Numeric  = true,
    Finished = false,
    Callback = function(val)
        local n = tonumber(val)
        if n and n > 0 then SkillConfig.Interval = n end
    end,
})

Tabs.Skill:AddInput("SkillHoldInput", {
    Title    = "เวลาค้าง (วินาที) - โหมด Hold เท่านั้น",
    Default  = "0.3",
    Numeric  = true,
    Finished = false,
    Callback = function(val)
        local n = tonumber(val)
        if n and n >= 0 then SkillConfig.HoldTime = n end
    end,
})

Tabs.Skill:AddSection("เลือก Skill Key")

local skillKeys  = { "Z","X","C","V","B","N","Y","F","G","H","J","K","L" }
local skillState = {}

for _, key in ipairs(skillKeys) do
    skillState[key] = false
    Tabs.Skill:AddToggle("Skill_" .. key, {
        Title    = "Auto " .. key,
        Default  = false,
        Callback = function(val) skillState[key] = val end,
    })
end

task.spawn(function()
    while true do
        task.wait(SkillConfig.Interval)
        for _, key in ipairs(skillKeys) do
            if skillState[key] then
                pcall(function()
                    if SkillConfig.Mode == "Tap" then
                        VirtualUser:CaptureController()
                        VirtualUser:TypeKey(key:lower())
                    else
                        UserInputService.InputBegan:Fire(
                            { KeyCode = Enum.KeyCode[key], UserInputType = Enum.UserInputType.Keyboard }, false
                        )
                        task.wait(SkillConfig.HoldTime)
                        UserInputService.InputEnded:Fire(
                            { KeyCode = Enum.KeyCode[key], UserInputType = Enum.UserInputType.Keyboard }, false
                        )
                    end
                end)
                task.wait(0.05)
            end
        end
    end
end)

-- ─── Misc Tab ─────────────────────────────────────────────────────────────────
Tabs.Misc:AddSection("Utilities")

local noclip = false
Tabs.Misc:AddToggle("Noclip", {
    Title    = "Noclip",
    Default  = false,
    Callback = function(val) noclip = val end,
})

RunService.Stepped:Connect(function()
    if not noclip then return end
    local char = GetChar()
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

local infJump = false
Tabs.Misc:AddToggle("InfJump", {
    Title    = "Infinite Jump",
    Default  = false,
    Callback = function(val) infJump = val end,
})

UserInputService.JumpRequest:Connect(function()
    if not infJump then return end
    local hum = GetHumanoid()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

Tabs.Misc:AddToggle("AntiAFK", {
    Title    = "Anti AFK",
    Default  = false,
    Callback = function(val)
        if val then
            LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end,
})

Tabs.Misc:AddButton({
    Title    = "Server Hop",
    Callback = function()
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if not req then
            Fluent:Notify({ Title = "Error", Content = "Executor ไม่รองรับ HTTP", Duration = 3 })
            return
        end
        local ok, res = pcall(function()
            return req({ Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100", Method = "GET" })
        end)
        if ok and res and res.Body then
            local data = HttpService:JSONDecode(res.Body)
            local servers = {}
            for _, s in ipairs(data.data or {}) do
                if type(s) == "table" and s.playing < s.maxPlayers and s.id ~= game.JobId then
                    table.insert(servers, s.id)
                end
            end
            if #servers > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
            else
                Fluent:Notify({ Title = "Server Hop", Content = "ไม่พบเซิร์ฟเวอร์ว่าง", Duration = 3 })
            end
        end
    end,
})

-- ─── Settings ─────────────────────────────────────────────────────────────────
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "AutoFarmToggle", "ItemESPToggle", "AutoPickupToggle", "FollowPlayerToggle" })
InterfaceManager:SetFolder("OPFHub")
SaveManager:SetFolder("OPFHub/configs")
InterfaceManager:BuildInterfacePage(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ─── Respawn ──────────────────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.AutoFarm then StartFarm() end
    if State.FollowPlayer then StartFollowPlayer() end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "OPF Hub", Content = "โหลดสำเร็จ! กด LeftAlt ซ่อน/แสดง", Duration = 5 })
