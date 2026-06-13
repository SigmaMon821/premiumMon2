local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ─── Linoria UI Library ───────────────────────────────────────────────────────
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library    = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title   = "OPF Hub",
    Center  = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Farm     = Window:AddTab("Auto Farm"),
    Teleport = Window:AddTab("Teleport"),
    Skill    = Window:AddTab("Auto Skill"),
    Misc     = Window:AddTab("Misc"),
    Settings = Window:AddTab("Settings"),
}

local FarmGroup  = Tabs.Farm:AddLeftGroupbox("Monster Farm")
local TpGroup    = Tabs.Teleport:AddLeftGroupbox("Locations")
local SkillGroup = Tabs.Skill:AddLeftGroupbox("Auto Skill Keys")
local MiscGroup  = Tabs.Misc:AddLeftGroupbox("Utilities")

-- ─── Helper: Get Character Parts ─────────────────────────────────────────────
local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ─── Find Monster Container (Class-based, has child named "Alive") ────────────
local function GetAliveFolder()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("Alive") then
            return obj:FindFirstChild("Alive")
        end
    end
    return nil
end

-- ─── Check if model is a Monster (has "Lv" in name, not a Player) ─────────────
local function IsMonster(model)
    if not model:IsA("Model") then return false end
    if not model.Name:find("Lv") then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == model then return false end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- ─── Get Nearest Monster from Alive folder ────────────────────────────────────
local function GetNearestMonster()
    local hrp = GetHRP()
    if not hrp then return nil end

    local alive = GetAliveFolder()
    if not alive then return nil end

    local nearest, shortestDist = nil, math.huge

    for _, model in ipairs(alive:GetChildren()) do
        if IsMonster(model) then
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    nearest = model
                end
            end
        end
    end

    return nearest
end

-- ─── Teleport Behind Monster ──────────────────────────────────────────────────
local function TeleportBehindMonster(target)
    local hrp = GetHRP()
    if not hrp then return end
    local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
    if not root then return end
    hrp.CFrame = root.CFrame * CFrame.new(0, 0, 3.5)
    task.wait(0.15)
end

-- ─── Attack Current Target ────────────────────────────────────────────────────
local function AttackTarget(target)
    local char = LocalPlayer.Character
    if not char then return end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    end

    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Connections")
    if remote then
        local atk = remote:FindFirstChild("Attack") or remote:FindFirstChild("Hit")
        if atk then
            pcall(function()
                local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
                atk:FireServer(target, root and root.Position or Vector3.zero)
            end)
        end
    end
end

-- ─── Auto Farm State ──────────────────────────────────────────────────────────
local State = {
    AutoFarm    = false,
    AttackDelay = 0.15,
}

local function StartFarmLoop()
    task.spawn(function()
        while State.AutoFarm do
            local hum = GetHumanoid()
            if hum and hum.Health > 0 then
                local target = GetNearestMonster()
                if target then
                    local monHum = target:FindFirstChildOfClass("Humanoid")
                    if monHum and monHum.Health > 0 then
                        TeleportBehindMonster(target)
                        AttackTarget(target)
                        task.wait(State.AttackDelay)
                    else
                        task.wait(0.5)
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

-- ─── UI: Farm Tab ─────────────────────────────────────────────────────────────
FarmGroup:AddToggle("AutoFarmToggle", {
    Text    = "Auto Farm Monster (Lv)",
    Default = false,
    Callback = function(val)
        State.AutoFarm = val
        if val then StartFarmLoop() end
    end,
})

FarmGroup:AddSlider("AttackDelaySlider", {
    Text    = "Attack Delay (ms)",
    Default = 15,
    Min     = 5,
    Max     = 80,
    Rounding = 0,
    Callback = function(val)
        State.AttackDelay = val / 100
    end,
})

FarmGroup:AddLabel("กรองมอนจาก Folder ที่มี 'Alive'")
FarmGroup:AddLabel("วาปหลังมอน → ตี → เปลี่ยนเป้าเมื่อมอนตาย")

-- ─── UI: Teleport Tab ─────────────────────────────────────────────────────────
local Locations = {
    ["Spawn"]         = CFrame.new(0, 5, 0),
    ["Marine Base"]   = CFrame.new(500, 5, 200),
    ["Pirate Island"] = CFrame.new(-300, 5, 600),
    ["Marineford"]    = CFrame.new(-800, 5, -300),
    ["Grand Line"]    = CFrame.new(1200, 5, -400),
}

for name, cf in pairs(Locations) do
    TpGroup:AddButton(name, function()
        local hrp = GetHRP()
        if hrp then hrp.CFrame = cf end
    end)
end

TpGroup:AddButton("Teleport to Nearest Monster", function()
    local target = GetNearestMonster()
    if target then
        TeleportBehindMonster(target)
        Library:Notify("วาปไปหา: " .. target.Name, 3)
    else
        Library:Notify("ไม่พบ Monster ใน Alive folder", 3)
    end
end)

-- ─── UI: Auto Skill Tab ───────────────────────────────────────────────────────
local skillKeys  = {"Z","X","C","V","B","N","F","G","H","J","K","L"}
local skillState = {}

for _, key in ipairs(skillKeys) do
    skillState[key] = false
    SkillGroup:AddToggle("Skill_" .. key, {
        Text    = "Auto " .. key,
        Default = false,
        Callback = function(val)
            skillState[key] = val
        end,
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

-- ─── UI: Misc Tab ─────────────────────────────────────────────────────────────
local noclip = false
MiscGroup:AddToggle("Noclip", {
    Text    = "Noclip",
    Default = false,
    Callback = function(val) noclip = val end,
})

RunService.Stepped:Connect(function()
    if noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

local infJump = false
MiscGroup:AddToggle("InfJump", {
    Text    = "Infinite Jump",
    Default = false,
    Callback = function(val) infJump = val end,
})

UserInputService.JumpRequest:Connect(function()
    if infJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

MiscGroup:AddToggle("AntiAFK", {
    Text    = "Anti AFK",
    Default = false,
    Callback = function(val)
        if val then
            LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end,
})

MiscGroup:AddButton("Server Hop", function()
    local req = (syn and syn.request) or request or http_request
    if not req then
        Library:Notify("Executor ไม่รองรับ HTTP", 3)
        return
    end
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"
    local ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
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
            Library:Notify("ไม่พบเซิร์ฟเวอร์ที่ว่าง", 3)
        end
    end
end)

-- ─── Settings Tab ─────────────────────────────────────────────────────────────
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:AddIgnoreKey("AutoFarmToggle")
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ─── Respawn Handler ──────────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.AutoFarm then
        StartFarmLoop()
    end
end)

Library:Notify("OPF Hub โหลดสำเร็จ!", 4)
