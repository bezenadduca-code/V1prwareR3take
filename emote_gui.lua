-- Custom Emote GUI - Mobile-first Rework
-- Controls: Tap toggle button or press L to open | X / Stop button to stop emote

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONSTANTS
-- ============================================================

local COLORS = {
    BG          = Color3.fromRGB(14, 14, 18),
    BG2         = Color3.fromRGB(22, 22, 28),
    BG3         = Color3.fromRGB(32, 32, 40),
    Accent      = Color3.fromRGB(100, 160, 255),
    AccentDark  = Color3.fromRGB(60, 100, 200),
    Danger      = Color3.fromRGB(220, 60, 60),
    DangerDark  = Color3.fromRGB(160, 40, 40),
    Success     = Color3.fromRGB(60, 200, 100),
    Text        = Color3.fromRGB(240, 240, 250),
    TextDim     = Color3.fromRGB(130, 130, 150),
    White       = Color3.fromRGB(255, 255, 255),
}

-- Detect mobile
local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Responsive sizing helpers
local function px(n) return UDim2.new(0, n, 0, n) end
local BTN_H   = isMobile() and 52 or 40   -- taller tap targets on mobile
local ROW_H   = isMobile() and 48 or 34
local FONT_SM = isMobile() and 15 or 13
local FONT_MD = isMobile() and 17 or 14
local FONT_LG = isMobile() and 20 or 16

-- ============================================================
-- STATE
-- ============================================================

local EmotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Emotes")

local state = {
    isEmoting     = false,
    isOpen        = false,
    activeTrack   = nil,
    activeSound   = nil,
    restoreSpeed  = 16,
    restoreJump   = 50,
    currentEmote  = nil,
    stopRequested = false,
    soundConn     = nil,
    activeEffects = {},
    stopKeyDown   = false,
}

-- ============================================================
-- HELPERS
-- ============================================================

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function padding(parent, px_all, px_lr)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, px_all)
    p.PaddingBottom = UDim.new(0, px_all)
    p.PaddingLeft   = UDim.new(0, px_lr or px_all)
    p.PaddingRight  = UDim.new(0, px_lr or px_all)
    p.Parent = parent
    return p
end

local function frame(parent, props)
    local f = Instance.new("Frame")
    for k, v in pairs(props or {}) do f[k] = v end
    f.BorderSizePixel = 0
    f.Parent = parent
    return f
end

local function label(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.TextScaled = false
    l.Font = Enum.Font.GothamSemibold
    l.TextColor3 = COLORS.Text
    l.TextSize = FONT_MD
    for k, v in pairs(props or {}) do l[k] = v end
    l.Parent = parent
    return l
end

local function tween(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ============================================================
-- STOP EMOTING
-- ============================================================

local function StopEmoting()
    if not state.isEmoting then return end
    state.isEmoting = false
    state.stopRequested = true

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = state.restoreSpeed
            hum.JumpPower = state.restoreJump
            for _, s in ipairs({
                Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Jumping,
                Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.Climbing,
                Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Swimming,
                Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.FallingDown,
                Enum.HumanoidStateType.Landed, Enum.HumanoidStateType.RunningNoPhysics,
                Enum.HumanoidStateType.StrafingNoPhysics,
            }) do hum:SetStateEnabled(s, true) end
        end
    end

    for _, e in ipairs(state.activeEffects) do pcall(function() e:Destroy() end) end
    state.activeEffects = {}

    if state.activeTrack  then pcall(function() state.activeTrack:Stop() end)   ; state.activeTrack  = nil end
    if state.activeSound  then pcall(function() state.activeSound:Stop(); state.activeSound:Destroy() end) ; state.activeSound  = nil end
    if state.soundConn    then pcall(function() state.soundConn:Disconnect() end); state.soundConn    = nil end

    state.currentEmote  = nil
    state.stopRequested = false
end

-- ============================================================
-- PLAY EMOTE
-- ============================================================

local function PlayEmote(moduleScript)
    if state.isEmoting then StopEmoting(); task.wait(0.1) end

    local char = LocalPlayer.Character
    if not char then return end
    local hum      = char:FindFirstChildOfClass("Humanoid")
    local root     = char:FindFirstChild("HumanoidRootPart")
    local animator = hum and hum:WaitForChild("Animator", 2)
    if not hum or not root or not animator then return end

    local ok, data = pcall(require, moduleScript)
    if not ok or not data.AssetID then return end

    state.isEmoting     = true
    state.currentEmote  = moduleScript.Name
    state.stopRequested = false
    state.restoreSpeed  = hum.WalkSpeed
    state.restoreJump   = hum.JumpPower

    hum.WalkSpeed = 0; hum.JumpPower = 0
    for _, s in ipairs({
        Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Jumping,
        Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Landed, Enum.HumanoidStateType.RunningNoPhysics,
        Enum.HumanoidStateType.StrafingNoPhysics,
    }) do hum:SetStateEnabled(s, false) end

    local anim = Instance.new("Animation")
    anim.AnimationId = tostring(data.AssetID)
    state.activeTrack = animator:LoadAnimation(anim)
    state.activeTrack:Play()

    if data.SFX then
        local snd = Instance.new("Sound")
        snd.SoundId = tostring(data.SFX)
        snd.Volume = 3
        snd.RollOffMaxDistance = 200
        snd.MaxDistance = 200
        snd.Looped = true
        snd.Parent = root
        snd:Play()
        state.activeSound = snd
        state.soundConn = snd.Ended:Connect(function()
            if state.isEmoting and not state.stopRequested and snd and snd.Parent then
                snd:Play()
            end
        end)
    end
end

-- ============================================================
-- GUI BUILD
-- ============================================================

-- Destroy any old instance
local old = PlayerGui:FindFirstChild("EmoteGUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EmoteGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

-- ============================================================
-- TOGGLE BUTTON (bottom-right, thumb-friendly)
-- ============================================================

local toggleSize = isMobile() and 64 or 52
local ToggleBtn  = Instance.new("TextButton")
ToggleBtn.Size     = UDim2.new(0, toggleSize, 0, toggleSize)
ToggleBtn.Position = UDim2.new(1, -(toggleSize + 16), 1, -(toggleSize + 32))
ToggleBtn.Text     = "🎵"
ToggleBtn.TextSize = isMobile() and 26 or 22
ToggleBtn.BackgroundColor3  = COLORS.Accent
ToggleBtn.AutoButtonColor   = false
ToggleBtn.BorderSizePixel   = 0
ToggleBtn.ZIndex = 10
ToggleBtn.Parent = ScreenGui
corner(ToggleBtn, toggleSize)

-- ============================================================
-- MAIN PANEL
-- ============================================================

-- Anchored bottom-right on mobile, centered on desktop
local panelW = isMobile() and math.min(400, workspace.CurrentCamera.ViewportSize.X - 20) or 360
local panelH = isMobile() and math.min(560, workspace.CurrentCamera.ViewportSize.Y - 120) or 500

local Panel = frame(ScreenGui, {
    Size              = UDim2.new(0, panelW, 0, panelH),
    Position          = isMobile()
        and UDim2.new(0.5, -panelW/2, 1, panelH + 20) -- starts off-screen (slides up)
        or  UDim2.new(0.5, -panelW/2, 0.5, -panelH/2),
    BackgroundColor3  = COLORS.BG,
    ClipsDescendants  = true,
    Visible           = true,
    ZIndex            = 5,
})
corner(Panel, 12)

-- Panel slide-in target position
local panelOpenPos  = isMobile()
    and UDim2.new(0.5, -panelW/2, 1, -(panelH + toggleSize + 24))
    or  UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
local panelClosedPos = isMobile()
    and UDim2.new(0.5, -panelW/2, 1, panelH + 20)
    or  UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)

-- ============================================================
-- TITLE BAR
-- ============================================================

local TitleBar = frame(Panel, {
    Size             = UDim2.new(1, 0, 0, BTN_H + 8),
    BackgroundColor3 = COLORS.BG2,
})
corner(TitleBar, 12)

-- Mask bottom corners of title bar
local titleMask = frame(TitleBar, {
    Size             = UDim2.new(1, 0, 0.5, 0),
    Position         = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = COLORS.BG2,
})

label(TitleBar, {
    Size     = UDim2.new(1, -100, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    Text     = "Emote Library",
    TextSize = FONT_LG,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, BTN_H, 0, BTN_H - 8)
CloseBtn.Position         = UDim2.new(1, -(BTN_H + 6), 0, 4)
CloseBtn.Text             = "✕"
CloseBtn.TextSize         = FONT_LG
CloseBtn.TextColor3       = COLORS.TextDim
CloseBtn.BackgroundColor3 = COLORS.BG3
CloseBtn.AutoButtonColor  = false
CloseBtn.BorderSizePixel  = 0
CloseBtn.Parent           = TitleBar
corner(CloseBtn, 6)

-- ============================================================
-- SEARCH BOX
-- ============================================================

local SearchBox = Instance.new("TextBox")
SearchBox.Size             = UDim2.new(1, -16, 0, BTN_H)
SearchBox.Position         = UDim2.new(0, 8, 0, BTN_H + 12)
SearchBox.PlaceholderText  = "Search emotes..."
SearchBox.Text             = ""
SearchBox.TextColor3       = COLORS.Text
SearchBox.PlaceholderColor3 = COLORS.TextDim
SearchBox.TextSize         = FONT_SM
SearchBox.Font             = Enum.Font.Gotham
SearchBox.BackgroundColor3 = COLORS.BG2
SearchBox.BorderSizePixel  = 0
SearchBox.ClearTextOnFocus  = false
SearchBox.Parent           = Panel
corner(SearchBox, 8)
padding(SearchBox, 0, 12)

-- ============================================================
-- SCROLL LIST
-- ============================================================

local listTop = BTN_H + 14 + BTN_H + 8
local listH   = panelH - listTop - BTN_H - 56

local ListBG = frame(Panel, {
    Size             = UDim2.new(1, -16, 0, listH),
    Position         = UDim2.new(0, 8, 0, listTop),
    BackgroundColor3 = COLORS.BG2,
})
corner(ListBG, 8)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size                  = UDim2.new(1, -8, 1, -8)
Scroll.Position              = UDim2.new(0, 4, 0, 4)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel       = 0
Scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
Scroll.ScrollBarThickness    = isMobile() and 5 or 4
Scroll.ScrollBarImageColor3  = COLORS.Accent
Scroll.ScrollBarImageTransparency = 0.4
Scroll.ScrollingDirection    = Enum.ScrollingDirection.Y
Scroll.Parent                = ListBG

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding   = UDim.new(0, 4)
ListLayout.Parent    = Scroll

-- ============================================================
-- NOW PLAYING + STOP BAR
-- ============================================================

local BottomBar = frame(Panel, {
    Size             = UDim2.new(1, -16, 0, BTN_H + 12),
    Position         = UDim2.new(0, 8, 1, -(BTN_H + 20)),
    BackgroundColor3 = COLORS.BG2,
})
corner(BottomBar, 8)

local NowPlaying = label(BottomBar, {
    Size     = UDim2.new(1, -(BTN_H*2 + 16), 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    Text     = "No emote playing",
    TextSize = FONT_SM,
    TextColor3 = COLORS.TextDim,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate   = Enum.TextTruncate.AtEnd,
})

local StopBtn = Instance.new("TextButton")
StopBtn.Size             = UDim2.new(0, BTN_H * 2, 0, BTN_H)
StopBtn.Position         = UDim2.new(1, -(BTN_H * 2 + 6), 0.5, -BTN_H/2)
StopBtn.Text             = "Stop"
StopBtn.TextSize         = FONT_SM
StopBtn.TextColor3       = COLORS.White
StopBtn.BackgroundColor3 = COLORS.Danger
StopBtn.AutoButtonColor  = false
StopBtn.BorderSizePixel  = 0
StopBtn.Parent           = BottomBar
corner(StopBtn, 6)

-- ============================================================
-- EMOTE LIST LOGIC
-- ============================================================

local emoteButtons = {}

local function refreshList(search)
    for _, b in ipairs(emoteButtons) do pcall(function() b:Destroy() end) end
    emoteButtons = {}

    local searchLow = search and string.lower(search) or ""
    local count = 0

    for _, child in ipairs(EmotesFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            if searchLow == "" or string.find(string.lower(child.Name), searchLow, 1, true) then
                count += 1

                local row = Instance.new("TextButton")
                row.Size             = UDim2.new(1, 0, 0, ROW_H)
                row.Text             = child.Name
                row.TextColor3       = COLORS.Text
                row.TextSize         = FONT_MD
                row.Font             = Enum.Font.Gotham
                row.TextXAlignment   = Enum.TextXAlignment.Left
                row.BackgroundColor3 = COLORS.BG3
                row.BackgroundTransparency = 0.4
                row.AutoButtonColor  = false
                row.BorderSizePixel  = 0
                row.LayoutOrder      = count
                row.Parent           = Scroll
                corner(row, 6)
                padding(row, 0, 12)

                row.MouseEnter:Connect(function()
                    tween(row, 0.12, {BackgroundTransparency = 0.1})
                end)
                row.MouseLeave:Connect(function()
                    tween(row, 0.12, {BackgroundTransparency = 0.4})
                end)

                -- Touch press visual
                row.MouseButton1Down:Connect(function()
                    tween(row, 0.07, {BackgroundTransparency = 0})
                end)

                row.MouseButton1Click:Connect(function()
                    PlayEmote(child)
                    NowPlaying.Text = "▶  " .. child.Name
                    NowPlaying.TextColor3 = COLORS.Success
                    tween(ToggleBtn, 0.3, {BackgroundColor3 = COLORS.Success})
                end)

                table.insert(emoteButtons, row)
            end
        end
    end

    Scroll.CanvasSize = UDim2.new(0, 0, 0, count * (ROW_H + 4) + 8)

    if count == 0 then
        local empty = label(Scroll, {
            Size       = UDim2.new(1, 0, 0, ROW_H),
            Text       = "No emotes found",
            TextColor3 = COLORS.TextDim,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        table.insert(emoteButtons, empty)
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    refreshList(SearchBox.Text)
end)

-- ============================================================
-- OPEN / CLOSE PANEL
-- ============================================================

local function setPanel(open)
    state.isOpen = open
    ToggleBtn.Text = open and "✕" or "🎵"

    if isMobile() then
        tween(Panel, 0.28, {Position = open and panelOpenPos or panelClosedPos})
    else
        Panel.Visible = open
    end

    if open then refreshList(SearchBox.Text) end
end

ToggleBtn.MouseButton1Click:Connect(function() setPanel(not state.isOpen) end)
CloseBtn.MouseButton1Click:Connect(function() setPanel(false) end)

ToggleBtn.MouseEnter:Connect(function() tween(ToggleBtn, 0.15, {BackgroundColor3 = COLORS.AccentDark}) end)
ToggleBtn.MouseLeave:Connect(function()
    tween(ToggleBtn, 0.15, {BackgroundColor3 = state.isEmoting and COLORS.Success or COLORS.Accent})
end)

CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, 0.15, {BackgroundColor3 = COLORS.Danger}) end)
CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, 0.15, {BackgroundColor3 = COLORS.BG3}) end)

StopBtn.MouseButton1Click:Connect(function()
    StopEmoting()
    NowPlaying.Text      = "No emote playing"
    NowPlaying.TextColor3 = COLORS.TextDim
    tween(ToggleBtn, 0.3, {BackgroundColor3 = COLORS.Accent})
end)
StopBtn.MouseEnter:Connect(function() tween(StopBtn, 0.15, {BackgroundColor3 = COLORS.DangerDark}) end)
StopBtn.MouseLeave:Connect(function() tween(StopBtn, 0.15, {BackgroundColor3 = COLORS.Danger}) end)

-- ============================================================
-- KEYBOARD (desktop only)
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.L then
        setPanel(not state.isOpen)
    elseif input.KeyCode == Enum.KeyCode.X then
        if not state.stopKeyDown then
            state.stopKeyDown = true
            StopEmoting()
            NowPlaying.Text       = "No emote playing"
            NowPlaying.TextColor3 = COLORS.TextDim
            tween(ToggleBtn, 0.3, {BackgroundColor3 = COLORS.Accent})
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.X then state.stopKeyDown = false end
end)

-- ============================================================
-- DRAGGING (desktop only)
-- ============================================================

if not isMobile() then
    local dragging, dStart, dOffset = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dStart = input.Position; dOffset = Panel.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dStart
            Panel.Position = UDim2.new(dOffset.X.Scale, dOffset.X.Offset + d.X, dOffset.Y.Scale, dOffset.Y.Offset + d.Y)
        end
    end)
end

-- ============================================================
-- CHARACTER HANDLING
-- ============================================================

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if state.isEmoting then StopEmoting() end
end)

LocalPlayer.CharacterRemoving:Connect(function()
    if state.isEmoting then StopEmoting() end
end)

-- ============================================================
-- INIT - desktop starts hidden; mobile starts off-screen
-- ============================================================

if not isMobile() then Panel.Visible = false end

print("[EmoteGUI] Loaded | L = toggle | X = stop")
