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
    Size = UDim2.fromOffset(600, 430),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftAlt,
})

local Tabs = {
    Farm     = Window:AddTab({ Title = "Auto Farm", Icon = "sword" }),
    Teleport = Window:AddTab({ Title = "Teleport",  Icon = "map-pin" }),
    Skill    = Window:AddTab({ Title = "Auto Skill", Icon = "zap" }),
    Misc     = Window:AddTab({ Title = "Misc",       Icon = "settings" }),
    Settings = Window:AddTab({ Title = "Settings",   Icon = "sliders-horizontal" }),
}

-- ─── State ────────────────────────────────────────────────────────────────────
local State = {
    AutoFarm    = false,
    TeleportMode = "Behind",
    TeleportOffset = 3.5,
    AttackDelay = 0.15,
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
    for _, obj in ipairs(workspace:GetChildren()) do
        local alive = obj:FindFirstChild("Alive")
        if alive then return alive end
    end
    return nil
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
    elseif State.TeleportMode == "Above" then
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
                        task.wait(0.4)
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

-- ─── Farm Tab UI ──────────────────────────────────────────────────────────────
Tabs.Farm:AddSection("Monster Farm")

Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title    = "Auto Farm Monster",
    Description = "วาปหา Monster ที่มีคำว่า Lv แล้วตีจนตาย",
    Default  = false,
    Callback = function(val)
        State.AutoFarm = val
        if val then StartFarmLoop() end
    end,
})

Tabs.Farm:AddDropdown("TeleportMode", {
    Title   = "รูปแบบการวาป",
    Description = "Behind = วาปหลัง / Above = วาปบน (นอนคว่ำ)",
    Values  = { "Behind", "Above" },
    Default = "Behind",
    Callback = function(val)
        State.TeleportMode = val
    end,
})

Tabs.Farm:AddInput("TeleportOffset", {
    Title       = "ระยะวาป (studs)",
    Description = "พิมตัวเลข เช่น 3.5",
    Default     = "3.5",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local num = tonumber(val)
        if num then State.TeleportOffset = num end
    end,
})

Tabs.Farm:AddInput("AttackDelayInput", {
    Title       = "Attack Delay (วินาที)",
    Description = "พิมตัวเลข เช่น 0.15",
    Default     = "0.15",
    Numeric     = true,
    Finished    = false,
    Callback    = function(val)
        local num = tonumber(val)
        if num then State.AttackDelay = num end
    end,
})

-- ─── Teleport Tab UI ──────────────────────────────────────────────────────────
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
            Fluent:Notify({ Title = "ไม่พบ Monster", Content = "ไม่มี Monster ใน Alive folder", Duration = 3 })
        end
    end,
})

-- ─── Skill Tab UI ─────────────────────────────────────────────────────────────
Tabs.Skill:AddSection("Auto Press Key")

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
        task.wait(0.4)
        for _, key in ipairs(skillKeys) do
            if skillState[key] then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:TypeKey(key:lower())
                end)
                task.wait(0.25)
            end
        end
    end
end)

-- ─── Misc Tab UI ──────────────────────────────────────────────────────────────
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
        if not req then Fluent:Notify({ Title = "Error", Content = "Executor ไม่รองรับ HTTP", Duration = 3 }) return end
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

-- ─── Settings Tab ─────────────────────────────────────────────────────────────
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "AutoFarmToggle" })
InterfaceManager:SetFolder("OPFHub")
SaveManager:SetFolder("OPFHub/configs")
InterfaceManager:BuildInterfacePage(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ─── Respawn Handler ──────────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.AutoFarm then StartFarmLoop() end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "OPF Hub", Content = "โหลดสำเร็จ! กด LeftAlt ซ่อน/แสดง UI", Duration = 5 })
