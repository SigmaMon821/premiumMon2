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
    Size = UDim2.fromOffset(600, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftAlt,
})

local Tabs = {
    Farm     = Window:AddTab({ Title = "Auto Farm",  Icon = "sword" }),
    Teleport = Window:AddTab({ Title = "Teleport",   Icon = "map-pin" }),
    Skill    = Window:AddTab({ Title = "Auto Skill", Icon = "zap" }),
    Misc     = Window:AddTab({ Title = "Misc",       Icon = "settings" }),
    Settings = Window:AddTab({ Title = "Settings",   Icon = "sliders-horizontal" }),
}

-- ─── State ────────────────────────────────────────────────────────────────────
local State = {
    AutoFarm       = false,
    TeleportMode   = "Behind",
    TeleportOffset = 3.5,
    AttackDelay    = 0.15,
}

local SkillConfig = {
    Interval   = 0.4,
    HoldTime   = 0.0,
    Mode       = "Tap",
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

-- Alive อยู่ใน workspace โดยตรง (Folder, ClassName = Folder, Name = "Alive")
local function GetAliveFolder()
    return workspace:FindFirstChild("Alive")
end

local function IsMonster(model)
    if not model:IsA("Model") then return false end
    if not model.Name:find("Lv") then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == model then return false end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function GetNearestMonster()
    local hrp = GetHRP()
    if not hrp then return nil end
    local alive = GetAliveFolder()
    if not alive then return nil end

    local nearest, shortest = nil, math.huge
    for _, model in ipairs(alive:GetChildren()) do
        if IsMonster(model) then
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

-- ─── Teleport Logic ───────────────────────────────────────────────────────────
local function TeleportToMonster(target)
    local hrp = GetHRP()
    if not hrp then return end
    local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
    if not root then return end

    local offset = State.TeleportOffset

    if State.TeleportMode == "Behind" then
        hrp.CFrame = root.CFrame * CFrame.new(0, 0, offset)
    else
        hrp.CFrame = root.CFrame * CFrame.new(0, offset, 0) * CFrame.Angles(math.pi, 0, 0)
    end

    task.wait(0.1)
end

-- ─── Farm Loop ────────────────────────────────────────────────────────────────
local function StartFarmLoop()
    task.spawn(function()
        while State.AutoFarm do
            local hum = GetHumanoid()
            if hum and hum.Health > 0 then
                local target = GetNearestMonster()
                if target then
                    local monHum = target:FindFirstChildOfClass("Humanoid")
                    if monHum and monHum.Health > 0 then
                        TeleportToMonster(target)
                        local char = LocalPlayer.Character
                        if char then
                            local tool = char:FindFirstChildOfClass("Tool")
                            if tool then tool:Activate() end
                        end
                        task.wait(State.AttackDelay)
                    else
                        task.wait(0.3)
                    end
                else
                    task.wait(1)
                end
            else
                task.wait(1)
            end
        end
    end)
end

-- ─── Farm Tab ─────────────────────────────────────────────────────────────────
Tabs.Farm:AddSection("Monster Farm")

Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title       = "Auto Farm Monster",
    Description = "ค้นหาจาก workspace.Alive แล้ววาปตี",
    Default     = false,
    Callback    = function(val)
        State.AutoFarm = val
        if val then StartFarmLoop() end
    end,
})

Tabs.Farm:AddDropdown("TeleportModeDD", {
    Title       = "รูปแบบการวาป",
    Description = "Behind = ด้านหลัง  /  Above = ด้านบน (นอนคว่ำ)",
    Values      = { "Behind", "Above" },
    Default     = "Behind",
    Callback    = function(val)
        State.TeleportMode = val
    end,
})

Tabs.Farm:AddInput("TeleportOffsetInput", {
    Title       = "ระยะวาป (studs)",
    Description = "พิมตัวเลข เช่น 3.5",
    Default     = "3.5",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local n = tonumber(val)
        if n then State.TeleportOffset = n end
    end,
})

Tabs.Farm:AddInput("AttackDelayInput", {
    Title       = "Attack Delay (วินาที)",
    Description = "พิมตัวเลข เช่น 0.15",
    Default     = "0.15",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local n = tonumber(val)
        if n then State.AttackDelay = n end
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
    Title       = "Teleport to Nearest Monster",
    Description = "วาปไปหา Monster ที่ใกล้ที่สุดทันที",
    Callback    = function()
        local target = GetNearestMonster()
        if target then
            TeleportToMonster(target)
            Fluent:Notify({ Title = "Teleport", Content = "วาปไปหา: " .. target.Name, Duration = 3 })
        else
            Fluent:Notify({ Title = "ไม่พบ Monster", Content = "ไม่มีใน workspace.Alive", Duration = 3 })
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
    Callback    = function(val)
        SkillConfig.Mode = val
    end,
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
    Title       = "เวลาค้าง (วินาที) - ใช้เฉพาะโหมด Hold",
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
                            { KeyCode = Enum.KeyCode[key], UserInputType = Enum.UserInputType.Keyboard },
                            false
                        )
                        task.wait(SkillConfig.HoldTime)
                        UserInputService.InputEnded:Fire(
                            { KeyCode = Enum.KeyCode[key], UserInputType = Enum.UserInputType.Keyboard },
                            false
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
        local req = (syn and syn.request) or request or http_request
        if not req then
            Fluent:Notify({ Title = "Error", Content = "Executor ไม่รองรับ HTTP", Duration = 3 })
            return
        end
        local ok, res = pcall(function()
            return req({ Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100", Method = "GET" })
        end)
        if ok and res and res.Body then
            local data = HttpService:JSONDecode(res.Body)
            local servers = {}
            for _, s in ipairs(data.data or {}) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
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
SaveManager:SetIgnoreIndexes({ "AutoFarmToggle" })
InterfaceManager:SetFolder("OPFHub")
SaveManager:SetFolder("OPFHub/configs")
InterfaceManager:BuildInterfacePage(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ─── Respawn ──────────────────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.AutoFarm then StartFarmLoop() end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "OPF Hub", Content = "โหลดสำเร็จ! กด LeftAlt ซ่อน/แสดง", Duration = 5 })
