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
    Teleport = Window:AddTab({ Title = "Teleport",   Icon = "map-pin" }),
    Skill    = Window:AddTab({ Title = "Auto Skill", Icon = "zap" }),
    Misc     = Window:AddTab({ Title = "Misc",       Icon = "settings" }),
    Settings = Window:AddTab({ Title = "Settings",   Icon = "sliders-horizontal" }),
}

-- ─── Wanted Items (ไม่มี Luck Fruit, มี Reset Token) ─────────────────────────
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
    AutoFarm       = false,
    TeleportMode   = "Behind",
    TeleportOffset = 3.5,
    AttackDelay    = 0.15,
    FarmMode       = "ทั้งหมด",
    TargetName     = "",
    MaxLv          = 300,
    TrackThread    = nil,
    ItemESP        = false,
    AutoPickup     = false,
}

local SkillConfig = {
    Interval = 0.4,
    HoldTime = 0.0,
    Mode     = "Tap",
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function GetAliveFolder()
    return workspace:FindFirstChild("Alive")
end

local function GetMonsterLv(name)
    local lv = name:match("Lv(%d+)")
    return lv and tonumber(lv) or 0
end

local function GetMonsterNames()
    local alive = GetAliveFolder()
    if not alive then return {} end
    local seen, names = {}, {}
    for _, model in ipairs(alive:GetChildren()) do
        if model:IsA("Model") and model.Name:find("Lv") then
            local isPlayer = false
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character == model then isPlayer = true; break end
            end
            if not isPlayer and not seen[model.Name] then
                seen[model.Name] = true
                table.insert(names, model.Name)
            end
        end
    end
    table.sort(names, function(a, b)
        return GetMonsterLv(a) < GetMonsterLv(b)
    end)
    return names
end

local function IsValidMonster(model)
    if not model:IsA("Model") then return false end
    if not model.Name:find("Lv") then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == model then return false end
    end
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
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    nearest = model
                end
            end
        end
    end
    return nearest
end

local function GetOffsetCFrame(root)
    local offset = State.TeleportOffset
    if State.TeleportMode == "Behind" then
        return root.CFrame * CFrame.new(0, 0, offset)
    else
        return root.CFrame * CFrame.new(0, offset, 0) * CFrame.Angles(math.pi, 0, 0)
    end
end

-- ─── Lock-on Loop ─────────────────────────────────────────────────────────────
local function StartTrackTarget(target)
    if State.TrackThread then
        task.cancel(State.TrackThread)
        State.TrackThread = nil
    end

    State.TrackThread = task.spawn(function()
        local monHum = target:FindFirstChildOfClass("Humanoid")
        local root   = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")

        while State.AutoFarm and monHum and monHum.Health > 0 and root and root.Parent do
            local hrp   = GetHRP()
            local myHum = GetHumanoid()
            if hrp and myHum and myHum.Health > 0 then
                hrp.CFrame = GetOffsetCFrame(root)
                local char = LocalPlayer.Character
                if char then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool then pcall(function() tool:Activate() end) end
                end
            end
            task.wait(State.AttackDelay)
        end

        State.TrackThread = nil
    end)
end

local function StartFarmLoop()
    task.spawn(function()
        while State.AutoFarm do
            local myHum = GetHumanoid()
            if myHum and myHum.Health > 0 then
                if not State.TrackThread then
                    local target = GetNearestMonster()
                    if target then
                        StartTrackTarget(target)
                    else
                        task.wait(1)
                    end
                else
                    task.wait(0.3)
                end
            else
                task.wait(1)
            end
        end
        if State.TrackThread then
            task.cancel(State.TrackThread)
            State.TrackThread = nil
        end
    end)
end

-- ─── Item ESP ─────────────────────────────────────────────────────────────────
local function CheckPlayerItems(plr)
    if plr == LocalPlayer then return end
    if not plr.Character or not plr.Character:FindFirstChild("Head") then return end

    local found = nil

    for _, item in ipairs(plr.Backpack:GetChildren()) do
        for name in pairs(WantedItems) do
            if item.Name:find(name) then found = item.Name; break end
        end
        if found then break end
    end

    if not found then
        for _, item in ipairs(plr.Character:GetChildren()) do
            if item:IsA("Tool") then
                for name in pairs(WantedItems) do
                    if item.Name:find(name) then found = item.Name; break end
                end
                if found then break end
            end
        end
    end

    local head = plr.Character:FindFirstChild("Head")
    if not head then return end
    local tag = head:FindFirstChild("ItemESP")

    if State.ItemESP and found then
        if not tag then
            tag = Instance.new("BillboardGui", head)
            tag.Name = "ItemESP"
            tag.Size = UDim2.new(0, 200, 0, 35)
            tag.AlwaysOnTop = true
            tag.ExtentsOffset = Vector3.new(0, 3, 0)
            local label = Instance.new("TextLabel", tag)
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(255, 220, 0)
            label.TextScaled = true
            label.Font = Enum.Font.GothamBold
            label.Text = "⭐ " .. plr.Name .. " Has: " .. found
        else
            local label = tag:FindFirstChildOfClass("TextLabel")
            if label then label.Text = "⭐ " .. plr.Name .. " Has: " .. found end
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
                if plr.Character and plr.Character:FindFirstChild("Head") then
                    local tag = plr.Character.Head:FindFirstChild("ItemESP")
                    if tag then tag:Destroy() end
                end
            end)
        end
    end)
end

-- ─── Auto Pickup ──────────────────────────────────────────────────────────────
local function StartAutoPickup()
    task.spawn(function()
        while State.AutoPickup do
            task.wait(0.3)
            local hrp = GetHRP()
            if hrp then
                for _, obj in ipairs(workspace:GetChildren()) do
                    if not State.AutoPickup then break end
                    if obj:IsA("Tool") and obj:FindFirstChild("Handle") then
                        local isWanted = false
                        for name in pairs(WantedItems) do
                            if obj.Name:find(name) then isWanted = true; break end
                        end
                        if isWanted and obj.Parent and not obj.Parent:FindFirstChildOfClass("Humanoid") then
                            hrp.CFrame = obj.Handle.CFrame
                            task.wait(0.15)
                            pcall(function() firetouchinterest(hrp, obj.Handle, 0) end)
                            task.wait(0.15)
                            pcall(function() firetouchinterest(hrp, obj.Handle, 1) end)
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end)
end

-- ─── Farm Tab ─────────────────────────────────────────────────────────────────
Tabs.Farm:AddSection("Monster Farm")

Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title       = "Auto Farm Monster",
    Description = "Lock-on ติดตามมอนแบบ real-time จนมอนตาย",
    Default     = false,
    Callback    = function(val)
        State.AutoFarm = val
        if val then
            StartFarmLoop()
        else
            if State.TrackThread then
                task.cancel(State.TrackThread)
                State.TrackThread = nil
            end
        end
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
    Title       = "🔄 Refresh Monster List",
    Description = "ดึงรายชื่อมอนจาก Alive ใหม่",
    Callback    = function()
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
    Title       = "รูปแบบการวาป",
    Description = "Behind = ด้านหลัง  /  Above = ด้านบน (นอนคว่ำ)",
    Values      = { "Behind", "Above" },
    Default     = "Behind",
    Callback    = function(val) State.TeleportMode = val end,
})

Tabs.Farm:AddInput("TeleportOffsetInput", {
    Title    = "ระยะวาป (studs)",
    Default  = "3.5",
    Numeric  = true,
    Finished = false,
    Callback = function(val)
        local n = tonumber(val)
        if n then State.TeleportOffset = n end
    end,
})

Tabs.Farm:AddInput("AttackDelayInput", {
    Title       = "Attack Delay / Track Speed (วินาที)",
    Description = "ยิ่งน้อยยิ่งติดตามเร็ว เช่น 0.05",
    Default     = "0.15",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local n = tonumber(val)
        if n then State.AttackDelay = n end
    end,
})

-- ─── Item Tab ─────────────────────────────────────────────────────────────────
Tabs.Item:AddSection("Item ESP")

Tabs.Item:AddToggle("ItemESPToggle", {
    Title       = "Item ESP",
    Description = "แสดงชื่อ Player ที่มีของสำคัญ",
    Default     = false,
    Callback    = function(val)
        State.ItemESP = val
        if val then StartItemESPLoop() end
    end,
})

Tabs.Item:AddSection("Auto Pickup")

Tabs.Item:AddToggle("AutoPickupToggle", {
    Title       = "Auto Pickup",
    Description = "วาปเก็บของที่ตกอยู่ใน workspace อัตโนมัติ",
    Default     = false,
    Callback    = function(val)
        State.AutoPickup = val
        if val then StartAutoPickup() end
    end,
})

Tabs.Item:AddSection("รายการของที่ติดตาม / เก็บ")

local itemList = {}
for name in pairs(WantedItems) do
    table.insert(itemList, name)
end
table.sort(itemList)

for _, name in ipairs(itemList) do
    Tabs.Item:AddLabel(name)
end

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
    Title       = "Teleport to Nearest Monster",
    Description = "วาปไปหา Monster ที่ผ่านเงื่อนไขทันที",
    Callback    = function()
        local hrp    = GetHRP()
        local target = GetNearestMonster()
        if target and hrp then
            local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
            if root then
                hrp.CFrame = GetOffsetCFrame(root)
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
    Title       = "โหมดการกด",
    Description = "Tap = กดปล่อยทันที  /  Hold = กดค้างตามเวลา",
    Values      = { "Tap", "Hold" },
    Default     = "Tap",
    Callback    = function(val) SkillConfig.Mode = val end,
})

Tabs.Skill:AddInput("SkillIntervalInput", {
    Title       = "ความเร็วการกด (วินาที)",
    Description = "ระยะห่างระหว่างกดแต่ละครั้ง เช่น 0.4",
    Default     = "0.4",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local n = tonumber(val)
        if n and n > 0 then SkillConfig.Interval = n end
    end,
})

Tabs.Skill:AddInput("SkillHoldInput", {
    Title       = "เวลาค้าง (วินาที) - โหมด Hold เท่านั้น",
    Description = "กดค้างกี่วินาทีก่อนปล่อย เช่น 0.3",
    Default     = "0.3",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local n = tonumber(val)
        if n and n >= 0 then SkillConfig.HoldTime = n end
    end,
})

Tabs.Skill:AddSection("เลือก Skill Key")

local skillKeys  = { "Z","X","C","V","B","N","F","G","H","J","K","L" }
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
    if noclip and LocalPlayer.Character then
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

local infJump = false
Tabs.Misc:AddToggle("InfJump", {
    Title    = "Infinite Jump",
    Default  = false,
    Callback = function(val) infJump = val end,
})

UserInputService.JumpRequest:Connect(function()
    if infJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
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
SaveManager:SetIgnoreIndexes({ "AutoFarmToggle", "ItemESPToggle", "AutoPickupToggle" })
InterfaceManager:SetFolder("OPFHub")
SaveManager:SetFolder("OPFHub/configs")
InterfaceManager:BuildInterfacePage(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ─── Respawn ──────────────────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    State.TrackThread = nil
    if State.AutoFarm then StartFarmLoop() end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "OPF Hub", Content = "โหลดสำเร็จ! กด LeftAlt ซ่อน/แสดง", Duration = 5 })
