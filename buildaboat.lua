--[[
    NightFall | Build A Boat For Treasure
    Auto farm / auto collect / fly / player utilities
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local Player = Players.LocalPlayer

local Config = {
    AutoFarm = false,
    AutoCollect = false,
    AntiAFK = false,
    Fly = false,
    NoClip = false,
    SpeedBoost = false,
    InfiniteJump = false,
    BoatFly = false,
    FarmMethod = "Stages",
    PartnerLiftHeight = 50,
    FarmDelay = 2,
    FarmTweenTime = 2.5,
    ChestWait = 10,
    FlySpeed = 200,
    WalkSpeed = 50,
    CollectRadius = 25,
    AutoLoadSave = false,
}

local COLORS = {
    bg = Color3.fromRGB(13, 14, 18),
    sidebar = Color3.fromRGB(16, 17, 23),
    surface = Color3.fromRGB(22, 24, 31),
    surfaceHover = Color3.fromRGB(28, 30, 40),
    elevated = Color3.fromRGB(34, 36, 46),
    border = Color3.fromRGB(44, 46, 58),
    tabActive = Color3.fromRGB(99, 102, 241),
    tabActiveBg = Color3.fromRGB(28, 30, 48),
    text = Color3.fromRGB(236, 237, 242),
    textMuted = Color3.fromRGB(128, 132, 150),
    accent = Color3.fromRGB(99, 102, 241),
    accentLight = Color3.fromRGB(129, 140, 248),
    success = Color3.fromRGB(52, 211, 153),
    danger = Color3.fromRGB(239, 68, 68),
    toggleOff = Color3.fromRGB(55, 58, 72),
    toggleOn = Color3.fromRGB(99, 102, 241),
    track = Color3.fromRGB(18, 19, 26),
    accentOn = Color3.fromRGB(56, 189, 248),
}

local RADIUS = { sm = 6, md = 10, lg = 14, xl = 20, full = 999 }
local SIDEBAR_WIDTH = 132
local TOGGLE_SIZE_PATH = "ScriptHub/babft_toggle_size.txt"
local MAX_CAVE_STAGE = 10
local CHEST_STAGE = 11

local UI = {}
local State = { toggleCubeSize = 44 }

local FarmState = {
    currentStage = 1,
    farmRunning = false,
    collectRunning = false,
    tweening = false,
    savedGravity = workspace.Gravity,
    boatFlyTarget = nil,
    farmBoatFlyActive = false,
    boatFlyFastDescent = false,
    boatFlyPushForward = false,
    boatFlyHoldAltitude = false,
    savedBoatFly = false,
    chestPushActive = false,
    chestPushChest = nil,
    chestHoldActive = false,
    chestHoldPos = nil,
}

local FlyState = {
    bv = nil,
    bg = nil,
}

local BoatFlyState = {
    bv = nil,
    bg = nil,
}

local GlideState = {
    bv = nil,
    bg = nil,
    active = false,
}

local PartnerGlideState = {
    bv = nil,
    bg = nil,
    part = nil,
    active = false,
}

local MainFarmState = {
    active = false,
    running = false,
    yourSeat = nil,
    partnerSeat = nil,
    partner = nil,
    boat = nil,
    stage = 1,
    pickerMode = nil,
    setupOpen = false,
    savedYourAnchored = true,
    savedPartnerAnchored = true,
    yourSeatName = nil,
    partnerSeatName = nil,
    yourSeatPos = nil,
    partnerSeatPos = nil,
    autoResume = false,
    respawnHandling = false,
    cycleRestarting = false,
    saveClickPoints = {},
    saveClickAutomation = false,
    suppressRespawnHandler = false,
    skipSaveLoadOnNextPrep = false,
    pendingRoundRestart = false,
    flingInProgress = false,
    restartingAfterRound = false,
    partnerDeathHandling = false,
    farmEnabled = false,
    yourSeatMarkPos = nil,
    partnerSeatMarkPos = nil,
    savedPartnerName = nil,
    farmHadForwardMotion = false,
}

local BuildState = {
    targetPlayer = nil,
    clipboard = nil,
    previewFolder = nil,
    isPasting = false,
    playerIndex = 1,
    previewActive = false,
    farmTemplate = nil,
    textBuilderOrigin = nil,
    textBuilderPicking = false,
}

local FARM_METHODS = { "Stages" }

local ensureFarmBuildOnPlot
local hasFarmBuildOnPlot
local pasteBuildBlocks
local scanAndSaveFarmBuild
local loadFarmSaveViaClicks
local syncClientBuildAfterSave
local testFarmSaveClicks
local updateSaveClickStatusLabel
local ensureClickPointMarker
local stopPartPicker
local startFarmDeathWatch
local stopFarmDeathWatch
local rebindPartnerDeathWatch
local beginBoatFarmFromSetup
local persistFarmSetup
local loadPersistedFarmSetup
local resolveSavedFarmPartner

local showBuildPreview
local clearBuildPreview

local restartBoatFarmAfterRound
local startBoatAutoFarm
local stopBoatAutoFarm
local handleBoatFarmRespawn
local openPlayerPicker
local openSeatPicker
local closePlayerPicker
local closeSeatPicker
local formatPlayerButtonText
local updateBuildPlayerLabel
local scanBuildFromPlayer
local wirePreviewHandlers
local refreshPlayerPickerList
local refreshSeatPickerList
local runFarmPrepAndSeat
local clearPartnerESP
local startPartnerESP
local openMainFarmSetup
local closeMainFarmSetup
local updateMainFarmSetupLabels
local restartBoatFarmCycle
local prepareBoatFarmSession
local wirePremiumTextBuilder

;(function()
local refreshFarmSeats
local setFarmStatus
local countSeatsOnPlot
local setCharacterCollisions
local function fsRead(path)
    local ok, result = pcall(function()
        if isfile and readfile and isfile(path) then
            return readfile(path)
        end
    end)
    return ok and result or nil
end

local function fsWrite(path, data)
    pcall(function()
        if writefile then
            if makefolder and isfolder and not isfolder("ScriptHub") then
                makefolder("ScriptHub")
            end
            writefile(path, data)
        end
    end)
end

local function fsDelete(path)
    pcall(function()
        if delfile and isfile and isfile(path) then
            delfile(path)
        end
    end)
end

local function loadToggleSize()
    return tonumber(fsRead(TOGGLE_SIZE_PATH)) or 44
end

local function applyToggleCubeSize(size)
    size = math.clamp(math.floor(size + 0.5), 24, 100)
    State.toggleCubeSize = size
    if UI.ToggleGui then
        UI.ToggleGui.Size = UDim2.new(0, size, 0, size)
    end
    if UI.ToggleIcon then
        UI.ToggleIcon.TextSize = math.clamp(math.floor(size * 0.44), 10, 28)
    end
    if UI.ToggleCorner then
        UI.ToggleCorner.CornerRadius = UDim.new(0, math.clamp(math.floor(size * 0.22), 4, 14))
    end
    fsWrite(TOGGLE_SIZE_PATH, tostring(size))
end

State.toggleCubeSize = loadToggleSize()

local function getGuiParent()
    local pg = Player:FindFirstChild("PlayerGui")
    return pg or CoreGui
end

local function applyCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or RADIUS.md)
    corner.Parent = parent
    return corner
end

local function applyStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or COLORS.border
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.55
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function tween(instance, props, duration)
    TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    ):Play()
end

local function createHubButton(parent, title, subtitle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, subtitle and 54 or 46)
    btn.BackgroundColor3 = COLORS.surface
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent
    applyCorner(btn, RADIUS.md)
    applyStroke(btn, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -110, 0, 18)
    titleLabel.Position = UDim2.new(0, 14, 0, subtitle and 10 or 14)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = btn

    if subtitle then
        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "SubLabel"
        subLabel.Size = UDim2.new(1, -110, 0, 14)
        subLabel.Position = UDim2.new(0, 14, 0, 30)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = subtitle
        subLabel.TextColor3 = COLORS.textMuted
        subLabel.TextSize = 11
        subLabel.Font = Enum.Font.GothamMedium
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.Parent = btn
    end

    local switchTrack = Instance.new("Frame")
    switchTrack.Name = "SwitchTrack"
    switchTrack.Size = UDim2.new(0, 44, 0, 22)
    switchTrack.Position = UDim2.new(1, -58, 0.5, -11)
    switchTrack.BackgroundColor3 = COLORS.toggleOff
    switchTrack.Parent = btn
    applyCorner(switchTrack, RADIUS.full)

    local switchKnob = Instance.new("Frame")
    switchKnob.Name = "SwitchKnob"
    switchKnob.Size = UDim2.new(0, 18, 0, 18)
    switchKnob.Position = UDim2.new(0, 2, 0.5, -9)
    switchKnob.BackgroundColor3 = COLORS.text
    switchKnob.Parent = switchTrack
    applyCorner(switchKnob, RADIUS.full)

    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.surfaceHover })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.surface })
    end)

    return btn
end

local function createActionButton(parent, title, subtitle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, subtitle and 50 or 42)
    btn.BackgroundColor3 = COLORS.surface
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent
    applyCorner(btn, RADIUS.md)
    applyStroke(btn, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 18)
    titleLabel.Position = UDim2.new(0, 14, 0, subtitle and 8 or 12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = btn

    if subtitle then
        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "SubLabel"
        subLabel.Size = UDim2.new(1, -20, 0, 14)
        subLabel.Position = UDim2.new(0, 14, 0, 28)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = subtitle
        subLabel.TextColor3 = COLORS.textMuted
        subLabel.TextSize = 11
        subLabel.Font = Enum.Font.GothamMedium
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.Parent = btn
    end

    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.surfaceHover })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.surface })
    end)

    return btn
end

local function bindPickerRowHover(row, getBaseColor)
    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.accentLight
    stroke.Thickness = 0
    stroke.Transparency = 0.15
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = row

    row.MouseEnter:Connect(function()
        tween(row, { BackgroundColor3 = COLORS.surfaceHover })
        stroke.Thickness = 2
    end)
    row.MouseLeave:Connect(function()
        tween(row, { BackgroundColor3 = getBaseColor() })
        stroke.Thickness = 0
    end)
end

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart, frameStart

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = frame.Position
        end
    end)

    local moveConn = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end)

    local endConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return function()
        moveConn:Disconnect()
        endConn:Disconnect()
    end
end

local function createPlayerPickerRow(parent, labelText)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 54)
    container.BackgroundColor3 = COLORS.surface
    container.Parent = parent
    applyCorner(container, RADIUS.md)
    applyStroke(container, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.38, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 14, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = labelText
    titleLabel.TextColor3 = COLORS.text
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local selectBtn = Instance.new("TextButton")
    selectBtn.Name = "SelectBtn"
    selectBtn.Size = UDim2.new(0.56, -18, 0, 32)
    selectBtn.Position = UDim2.new(0.42, 0, 0.5, -16)
    selectBtn.BackgroundColor3 = COLORS.elevated
    selectBtn.Text = "Select player..."
    selectBtn.TextColor3 = COLORS.textMuted
    selectBtn.TextSize = 12
    selectBtn.Font = Enum.Font.GothamMedium
    selectBtn.AutoButtonColor = false
    selectBtn.Parent = container
    applyCorner(selectBtn, RADIUS.sm)
    applyStroke(selectBtn, COLORS.border, 1, 0.5)

    return container, selectBtn
end

local function createPreviewRow(parent)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 54)
    row.BackgroundColor3 = COLORS.surface
    row.Active = true
    row.Parent = parent
    applyCorner(row, RADIUS.md)
    applyStroke(row, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -140, 0, 18)
    titleLabel.Position = UDim2.new(0, 14, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Active = false
    titleLabel.Text = "Preview"
    titleLabel.TextColor3 = COLORS.text
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 2
    titleLabel.Parent = row

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, -140, 0, 14)
    subLabel.Position = UDim2.new(0, 14, 0, 30)
    subLabel.BackgroundTransparency = 1
    subLabel.Active = false
    subLabel.Text = "Show or hide build preview"
    subLabel.TextColor3 = COLORS.textMuted
    subLabel.TextSize = 11
    subLabel.Font = Enum.Font.GothamMedium
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.ZIndex = 2
    subLabel.Parent = row

    local btnBar = Instance.new("Frame")
    btnBar.Size = UDim2.new(0, 118, 0, 30)
    btnBar.Position = UDim2.new(1, -128, 0.5, -15)
    btnBar.BackgroundTransparency = 1
    btnBar.Active = true
    btnBar.ZIndex = 5
    btnBar.Parent = row

    local onBtn = Instance.new("TextButton")
    onBtn.Size = UDim2.new(0, 54, 0, 30)
    onBtn.Position = UDim2.new(0, 0, 0, 0)
    onBtn.BackgroundColor3 = COLORS.elevated
    onBtn.Text = "On"
    onBtn.TextColor3 = COLORS.textMuted
    onBtn.TextSize = 12
    onBtn.Font = Enum.Font.GothamBold
    onBtn.AutoButtonColor = false
    onBtn.Active = true
    onBtn.ZIndex = 20
    onBtn.Parent = btnBar
    applyCorner(onBtn, RADIUS.sm)

    local offBtn = Instance.new("TextButton")
    offBtn.Size = UDim2.new(0, 54, 0, 30)
    offBtn.Position = UDim2.new(0, 60, 0, 0)
    offBtn.BackgroundColor3 = COLORS.elevated
    offBtn.Text = "Off"
    offBtn.TextColor3 = COLORS.textMuted
    offBtn.TextSize = 12
    offBtn.Font = Enum.Font.GothamBold
    offBtn.AutoButtonColor = false
    offBtn.Active = true
    offBtn.ZIndex = 20
    offBtn.Parent = btnBar
    applyCorner(offBtn, RADIUS.sm)

    local function setPreviewButtons(active)
        onBtn.BackgroundColor3 = active and COLORS.toggleOn or COLORS.elevated
        onBtn.TextColor3 = active and COLORS.text or COLORS.textMuted
        offBtn.BackgroundColor3 = active and COLORS.elevated or COLORS.danger
        offBtn.TextColor3 = active and COLORS.textMuted or COLORS.text
    end

    setPreviewButtons(false)
    return row, setPreviewButtons, onBtn, offBtn
end

local function setHubToggle(btn, enabled)
    local track = btn:FindFirstChild("SwitchTrack")
    local knob = track and track:FindFirstChild("SwitchKnob")
    if track and knob then
        tween(track, { BackgroundColor3 = enabled and COLORS.toggleOn or COLORS.toggleOff })
        tween(knob, {
            Position = enabled and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
        })
    end
end

local function createInputRow(parent, labelText, defaultVal, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = COLORS.surface
    row.Parent = parent
    applyCorner(row, RADIUS.md)
    applyStroke(row, COLORS.border, 1, 0.65)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = COLORS.text
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.42, 0, 0, 28)
    box.Position = UDim2.new(0.53, 0, 0.5, -14)
    box.BackgroundColor3 = COLORS.elevated
    box.Text = tostring(defaultVal)
    box.TextColor3 = COLORS.text
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 14
    box.ClearTextOnFocus = false
    box.Parent = row
    applyCorner(box, RADIUS.sm)
    applyStroke(box, COLORS.border, 1, 0.5)

    box.FocusLost:Connect(function()
        onChange(tonumber(box.Text))
    end)

    return row
end

local function createHubSlider(parent, title, minVal, maxVal, defaultVal, onChanged)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 72)
    container.BackgroundColor3 = COLORS.surface
    container.Parent = parent
    applyCorner(container, RADIUS.md)
    applyStroke(container, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.6, 0, 0, 22)
    titleLabel.Position = UDim2.new(0, 14, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.4, -14, 0, 22)
    valueLabel.Position = UDim2.new(0.6, 0, 0, 10)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = COLORS.accentOn
    valueLabel.TextSize = 13
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 10)
    track.Position = UDim2.new(0, 14, 0, 46)
    track.BackgroundColor3 = COLORS.track
    track.BorderSizePixel = 0
    track.Parent = container
    applyCorner(track, RADIUS.full)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COLORS.accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    applyCorner(fill, RADIUS.full)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, -9, 0.5, -9)
    knob.BackgroundColor3 = COLORS.text
    knob.BorderSizePixel = 0
    knob.Parent = track
    applyCorner(knob, RADIUS.full)

    local dragging = false
    local function setValue(value, fire)
        value = math.clamp(math.floor(value + 0.5), minVal, maxVal)
        valueLabel.Text = tostring(value)
        local alpha = (value - minVal) / math.max(maxVal - minVal, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -9, 0.5, -9)
        if fire and onChanged then onChanged(value) end
    end

    local hitPad = Instance.new("TextButton")
    hitPad.Size = UDim2.new(1, -16, 0, 32)
    hitPad.Position = UDim2.new(0, 8, 0, 34)
    hitPad.BackgroundTransparency = 1
    hitPad.Text = ""
    hitPad.AutoButtonColor = false
    hitPad.Parent = container

    local function updateFromScreenX(screenX)
        local trackPos = track.AbsolutePosition.X
        local trackSize = track.AbsoluteSize.X
        if trackSize <= 0 then return end
        local alpha = math.clamp((screenX - trackPos) / trackSize, 0, 1)
        setValue(minVal + (maxVal - minVal) * alpha, true)
    end

    hitPad.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromScreenX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            updateFromScreenX(input.Position.X)
        end
    end)

    setValue(defaultVal, false)
    return container, setValue
end

--- GAME LOGIC ---

;(function()
    local FARM_SETUP_PATH = "ScriptHub/babft_farm_setup.json"

    local function vecToTable(v)
        if not v then return nil end
        return { x = v.X, y = v.Y, z = v.Z }
    end

    local function tableToVec(t)
        if not t then return nil end
        return Vector3.new(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0)
    end

    local function fsReadSetup(path)
        local ok, result = pcall(function()
            if isfile and readfile and isfile(path) then
                return readfile(path)
            end
        end)
        return ok and result or nil
    end

    local function fsWriteSetup(path, content)
        pcall(function()
            if writefile then
                if makefolder and isfolder and not isfolder("ScriptHub") then
                    makefolder("ScriptHub")
                end
                writefile(path, content)
            end
        end)
    end

    resolveSavedFarmPartner = function()
        if MainFarmState.partner and MainFarmState.partner.Parent then
            return MainFarmState.partner
        end
        local savedName = MainFarmState.savedPartnerName
        if not savedName then return nil end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == savedName then
                MainFarmState.partner = plr
                return plr
            end
        end
        return nil
    end

    persistFarmSetup = function()
        if MainFarmState.partner then
            MainFarmState.savedPartnerName = MainFarmState.partner.Name
        end
        local data = {
            yourSeatName = MainFarmState.yourSeatName,
            yourSeatPos = vecToTable(MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos),
            partnerSeatName = MainFarmState.partnerSeatName,
            partnerSeatPos = vecToTable(MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos),
            partnerName = MainFarmState.savedPartnerName,
        }
        fsWriteSetup(FARM_SETUP_PATH, HttpService:JSONEncode(data))
    end

    loadPersistedFarmSetup = function()
        local raw = fsReadSetup(FARM_SETUP_PATH)
        if not raw then return end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if not ok or type(data) ~= "table" then return end

        if data.yourSeatName then
            MainFarmState.yourSeatName = data.yourSeatName
        end
        if data.partnerSeatName then
            MainFarmState.partnerSeatName = data.partnerSeatName
        end
        if data.yourSeatPos then
            MainFarmState.yourSeatMarkPos = tableToVec(data.yourSeatPos)
            MainFarmState.yourSeatPos = MainFarmState.yourSeatMarkPos
        end
        if data.partnerSeatPos then
            MainFarmState.partnerSeatMarkPos = tableToVec(data.partnerSeatPos)
            MainFarmState.partnerSeatPos = MainFarmState.partnerSeatMarkPos
        end
        if data.partnerName then
            MainFarmState.savedPartnerName = data.partnerName
            resolveSavedFarmPartner()
        end
    end

    loadPersistedFarmSetup()
end)()

--- GAME LOGIC ---

local function getCharacter()
    local char = Player.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function getNormalStages()
    local stages = workspace:FindFirstChild("BoatStages")
    return stages and stages:FindFirstChild("NormalStages")
end

local function getGoldenChest()
    local normalStages = getNormalStages()
    if not normalStages then return nil end
    local endpoint = normalStages:FindFirstChild("TheEnd")
    return endpoint and endpoint:FindFirstChild("GoldenChest")
end

local function getGainedGoldSlideFrame()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local gui = pg:FindFirstChild("GainedGoldGui")
    return gui and gui:FindFirstChild("SlideDownFrame")
end

local function isGainedGoldVisible()
    local frame = getGainedGoldSlideFrame()
    if not frame or not frame.Visible then return false end
    for _, child in ipairs(frame:GetDescendants()) do
        if child:IsA("TextLabel") and child.Visible and child.Text ~= "" and child.TextTransparency < 1 then
            return true
        end
    end
    return frame.BackgroundTransparency < 1 or frame.AbsoluteSize.Y > 4
end

local autoClickClaimGold

local function waitForGainedGoldPopup(timeout)
    timeout = timeout or math.clamp(Config.ChestWait or 45, 10, 90)
    local deadline = tick() + timeout
    while tick() < deadline do
        if isGainedGoldVisible() then
            if autoClickClaimGold then
                autoClickClaimGold(getGoldenChest())
                task.wait(0.12)
                autoClickClaimGold(getGoldenChest())
            end
            return true
        end
        task.wait(0.1)
    end
    return false
end

local function waitForChestRewardFallback(chest, activeCheck)
    local chestPos = chest:GetPivot().Position
    local waited = 0
    while activeCheck() do
        task.wait(1)
        waited += 1
        local _, hrp = getCharacter()
        if not hrp then break end
        if waited % 20 == 0 then
            pivotTo(chest:GetPivot() + Vector3.new(0, 0, -10))
        end
        if (hrp.Position - chestPos).Magnitude > 500 then
            break
        end
    end
end

local function pivotTo(cframe)
    local char, hrp = getCharacter()
    if not char or not hrp or not cframe then return false end
    pcall(function()
        if char.PrimaryPart then
            char:PivotTo(cframe)
        else
            hrp.CFrame = cframe
        end
    end)
    return true
end

local function tweenRootTo(targetCFrame, duration)
    local _, hrp = getCharacter()
    if not hrp or not targetCFrame then return false end

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = targetCFrame }
    )
    FarmState.tweening = true
    tween:Play()
    tween.Completed:Wait()
    FarmState.tweening = false
    return true
end

local function waitForChestReward(chest)
    local _, hrp = getCharacter()
    if not hrp or not chest then return end

    if waitForGainedGoldPopup() then
        task.wait(math.clamp(Config.ChestWait or 10, 2, 30))
        return
    end

    waitForChestRewardFallback(chest, function()
        return Config.AutoFarm
    end)
end

local function runFarmStep()
    local char, hrp = getCharacter()
    if not char or not hrp then return end

    local normalStages = getNormalStages()
    if not normalStages then return end

    if FarmState.currentStage >= CHEST_STAGE then
        FarmState.currentStage = 1
        local endpoint = normalStages:FindFirstChild("TheEnd")
        local chest = endpoint and endpoint:FindFirstChild("GoldenChest")
        if chest then
            local chestCF = chest:GetPivot() + Vector3.new(0, 0, -10)
            pivotTo(chestCF)
            local originalChar = Player.Character
            local deadline = tick() + 10
            while tick() < deadline do
                if Player.Character ~= originalChar or not Player.Character then
                    break
                end
                if isGainedGoldVisible() then
                    if autoClickClaimGold then
                        autoClickClaimGold(chest)
                        task.wait(0.12)
                        autoClickClaimGold(chest)
                    end
                    task.wait(1)
                    break
                end
                task.wait(0.1)
            end
        end
        return
    end

    local stage = normalStages:FindFirstChild("CaveStage" .. FarmState.currentStage)
    local darkPart = stage and stage:FindFirstChild("DarknessPart")
    if not darkPart then return end

    local stageCF = darkPart.CFrame - Vector3.new(0, 0, 15)
    pcall(function()
        char:PivotTo(stageCF)
    end)
    tweenRootTo(darkPart.CFrame + Vector3.new(0, 0, 20), Config.FarmTweenTime)
    FarmState.currentStage += 1
end

local function startAutoFarm()
    if FarmState.farmRunning then return end
    FarmState.farmRunning = true

    while Config.AutoFarm do
        if not FarmState.tweening then
            pcall(runFarmStep)
        end
        task.wait()
    end

    FarmState.farmRunning = false
end

local function collectNearbyGold()
    local _, hrp = getCharacter()
    if not hrp then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if not Config.AutoCollect then break end
        if obj:IsA("BasePart") then
            local nameLower = obj.Name:lower()
            if nameLower:find("coin") or nameLower:find("gold") or nameLower:find("treasure") then
                if (obj.Position - hrp.Position).Magnitude <= Config.CollectRadius then
                    pcall(function()
                        if firetouchinterest then
                            firetouchinterest(hrp, obj, 0)
                            firetouchinterest(hrp, obj, 1)
                        end
                    end)
                end
            end
        end
    end
end

local function startAutoCollect()
    if FarmState.collectRunning then return end
    FarmState.collectRunning = true

    while Config.AutoCollect do
        pcall(collectNearbyGold)
        task.wait(0.35)
    end

    FarmState.collectRunning = false
end

local function setFlyEnabled(enabled)
    Config.Fly = enabled
    if not enabled then
        FarmState.chestPushActive = false
        FarmState.chestPushChest = nil
        FarmState.chestHoldActive = false
        FarmState.chestHoldPos = nil
        if FlyState.bv then FlyState.bv:Destroy() FlyState.bv = nil end
        if FlyState.bg then FlyState.bg:Destroy() FlyState.bg = nil end
        local _, _, hum = getCharacter()
        if hum then
            hum.PlatformStand = false
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
        end
    end
end

local function setBoatFlyEnabled(enabled)
    Config.BoatFly = enabled
    if not enabled then
        if BoatFlyState.bv then BoatFlyState.bv:Destroy() BoatFlyState.bv = nil end
        if BoatFlyState.bg then BoatFlyState.bg:Destroy() BoatFlyState.bg = nil end
    end
end

local function isPlayerSeated()
    local _, _, hum = getCharacter()
    return hum and hum.Sit and hum.SeatPart ~= nil
end

local function getBoatFlyPart()
    local _, _, hum = getCharacter()
    if not hum or not hum.SeatPart then return nil end

    pcall(function()
        if hum.SeatPart.Anchored then
            hum.SeatPart.Anchored = false
        end
    end)

    local seat = hum.SeatPart
    local boat = seat:FindFirstAncestorWhichIsA("Model")
    if boat then
        if boat.PrimaryPart then
            return boat.PrimaryPart
        end
        local root = boat:FindFirstChild("HumanoidRootPart") or boat:FindFirstChildWhichIsA("BasePart")
        if root then return root end
    end
    return seat
end

-- Mobile input state for fly
local MobileFly = {
    rising = false,
}

-- JumpRequest on mobile = jump button → rise
UserInputService.JumpRequest:Connect(function()
    if (Config.Fly or Config.BoatFly) and UserInputService.TouchEnabled then
        MobileFly.rising = true
        task.delay(0.15, function() MobileFly.rising = false end)
    end
end)

local function getBoatFlyVelocity()
    local cam = workspace.CurrentCamera
    local look = cam.CFrame.LookVector
    local right = cam.CFrame.RightVector
    local vel = Vector3.zero

    -- Keyboard (PC)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += look end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel -= look end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel += right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel -= right end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then vel += Vector3.new(0, 1, 0) end

    -- Mobile: use humanoid MoveDirection (driven by the on-screen thumbstick)
    if UserInputService.TouchEnabled then
        local _, _, hum = getCharacter()
        if hum then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                -- Map thumbstick direction onto the camera's full 3D look/right vectors
                -- so pushing forward flies in the direction the camera is pointing (including up/down)
                local camLook = cam.CFrame.LookVector
                local camRight = cam.CFrame.RightVector
                -- Decompose md into forward/right components using world-flat camera axes
                local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
                local flatRight = Vector3.new(camRight.X, 0, camRight.Z)
                local fwdAmount = 0
                local rightAmount = 0
                if flatLook.Magnitude > 0.01 then
                    fwdAmount = md:Dot(flatLook.Unit)
                end
                if flatRight.Magnitude > 0.01 then
                    rightAmount = md:Dot(flatRight.Unit)
                end
                -- Apply those amounts to the full 3D camera vectors
                vel += camLook * fwdAmount + camRight * rightAmount
            end
        end
        if MobileFly.rising then
            vel += Vector3.new(0, 1, 0)
        end
    end

    if vel.Magnitude > 0 then
        return vel.Unit * Config.FlySpeed
    end
    return Vector3.zero
end

local function getNormalFlyVelocity()
    return getBoatFlyVelocity()
end

local function getChestPushForwardVector()
    local partnerHrp = getPartnerHRP()
    if not partnerHrp then return Vector3.new(0, 0, 1) end

    local pushForward = Vector3.new(partnerHrp.CFrame.LookVector.X, 0, partnerHrp.CFrame.LookVector.Z)
    local chest = FarmState.chestPushChest
    if chest and chest.Parent then
        local toChest = chest:GetPivot().Position - partnerHrp.Position
        toChest = Vector3.new(toChest.X, 0, toChest.Z)
        if toChest.Magnitude > 1 then
            pushForward = toChest
        end
    end

    if pushForward.Magnitude < 0.05 then
        return Vector3.new(0, 0, 1)
    end
    return pushForward.Unit
end

local function getChestPushFlyVelocity()
    return getChestPushForwardVector() * (Config.FlySpeed * 2)
end

local function getFarmBoatFlyVelocity()
    if FarmState.boatFlyTarget then
        local flyPart = getBoatFlyPart()
        if not flyPart then return Vector3.zero end
        local delta = FarmState.boatFlyTarget - flyPart.Position
        if FarmState.boatFlyHoldAltitude then
            delta = Vector3.new(delta.X, 0, delta.Z)
        end
        local dist = delta.Magnitude
        if dist < 2 then return Vector3.zero end
        local speed
        if not FarmState.boatFlyHoldAltitude
            and delta.Y < -1
            and (FarmState.farmBoatFlyActive or FarmState.boatFlyFastDescent) then
            speed = Config.FlySpeed
        else
            speed = math.min(Config.FlySpeed, math.max(dist * 1.5, 12))
        end
        if FarmState.boatFlyPushForward then
            speed = math.min(math.max(Config.FlySpeed, Config.FlySpeed * 2.2), speed * 1.8)
        end
        return delta.Unit * speed
    end
    return getBoatFlyVelocity()
end

local function applySpeed()
    local _, _, hum = getCharacter()
    if hum and Config.SpeedBoost then
        hum.WalkSpeed = Config.WalkSpeed
    elseif hum and not Config.SpeedBoost then
        hum.WalkSpeed = 16
    end
end

-- Auto claim, boat farm, auto build helpers

local function getPlayerZone(plr)
    plr = plr or Player
    local teamColor = plr.TeamColor

    local function findZoneIn(container)
        if not container then return nil end
        for _, v in ipairs(container:GetChildren()) do
            local tc = v:FindFirstChild("TeamColor")
            if tc and tc.Value == teamColor then
                return v
            end
        end
        return nil
    end

    local teams = workspace:FindFirstChild("Teams")
    local zone = findZoneIn(teams)
    if zone then
        return zone
    end

    return findZoneIn(workspace)
end

local function deleteAllTrees()
    local count = 0
    local processed = {}

    local function wipeTreesFolder(folder)
        if not folder or processed[folder] then return end
        processed[folder] = true
        for _, child in ipairs(folder:GetChildren()) do
            child:Destroy()
            count += 1
        end
    end

    local searchRoots = {}
    local teams = workspace:FindFirstChild("Teams")
    if teams then
        table.insert(searchRoots, teams)
    end
    table.insert(searchRoots, workspace)

    for _, root in ipairs(searchRoots) do
        for _, inst in ipairs(root:GetDescendants()) do
            if inst.Name == "Trees" then
                wipeTreesFolder(inst)
            end
        end
    end

    return count
end

local function deleteAllPoles()
    local count = 0
    local processed = {}

    local function wipePolesFolder(folder)
        if not folder or processed[folder] then return end
        processed[folder] = true
        for _, child in ipairs(folder:GetChildren()) do
            child:Destroy()
            count += 1
        end
    end

    local searchRoots = {}
    local teams = workspace:FindFirstChild("Teams")
    if teams then
        table.insert(searchRoots, teams)
    end
    table.insert(searchRoots, workspace)

    for _, root in ipairs(searchRoots) do
        for _, inst in ipairs(root:GetDescendants()) do
            if inst.Name == "Poles" then
                wipePolesFolder(inst)
            elseif inst.Name == "Pole" and inst:IsA("Model") and not processed[inst] then
                processed[inst] = true
                inst:Destroy()
                count += 1
            end
        end
    end

    return count
end

local WATERFALL_END_WALL_INDICES = {51, 52, 53, 54, 55, 56, 59, 60, 61, 62, 65, 66}

local function clearTheEndObstacles()
    local count = 0
    local normalStages = getNormalStages()
    local theEnd = normalStages and normalStages:FindFirstChild("TheEnd")
    if not theEnd then return 0 end

    local seen = {}
    local function destroyInst(inst)
        if not inst or seen[inst] then return end
        seen[inst] = true
        local ok = pcall(function()
            inst:Destroy()
        end)
        if ok then
            count += 1
        end
    end

    local function clearTerrainWallFolder(folder)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            if child.Name == "Wall" or child:IsA("Model") or child:IsA("BasePart") then
                destroyInst(child)
            end
        end
    end

    clearTerrainWallFolder(theEnd:FindFirstChild("TerrainWall"))
    for _, inst in ipairs(theEnd:GetDescendants()) do
        if inst.Name == "TerrainWall" then
            clearTerrainWallFolder(inst)
        end
    end

    local waterfallEnd = theEnd:FindFirstChild("WaterfallEnd")
    if waterfallEnd then
        local branchChildren = waterfallEnd:GetChildren()
        local branch = branchChildren[3]
        if branch then
            local wallChildren = branch:GetChildren()
            for _, idx in ipairs(WATERFALL_END_WALL_INDICES) do
                destroyInst(wallChildren[idx])
            end
        end
    end

    return count
end

local function getBlocksFolder()
    return workspace:FindFirstChild("Blocks")
end

local function getPlayerBuildFolder(plr)
    local blocks = getBlocksFolder()
    return blocks and plr and blocks:FindFirstChild(plr.Name)
end

local function getBlockDataFolder()
    return Player:FindFirstChild("Data")
end

local function getBlockID(name)
    local data = getBlockDataFolder()
    local block = data and data:FindFirstChild(name)
    return block and block.Value or 9
end

local function cframeToArray(cf)
    return { cf:GetComponents() }
end

local function arrayToCframe(arr)
    return CFrame.new(unpack(arr))
end

local function isGuiVisible(gui, root)
    if not gui then return false end
    if gui:IsA("GuiObject") and not gui.Visible then return false end
    local p = gui.Parent
    while p and p ~= root do
        if p:IsA("GuiObject") and not p.Visible then return false end
        p = p.Parent
    end
    return true
end

local function getGuiButtonText(gui)
    if not gui then return "" end
    if gui:IsA("TextButton") then
        return gui.Text or ""
    end
    if gui:IsA("ImageButton") then
        if gui.Name:lower():find("claim") or gui.Name:lower():find("launch") then
            return gui.Name
        end
        for _, child in ipairs(gui:GetDescendants()) do
            if child:IsA("TextLabel") and child.Text ~= "" then
                return child.Text
            end
        end
        return gui.Name or ""
    end
    return ""
end

local function clickGuiButton(btn)
    if not btn then return false end
    local ok = false
    pcall(function()
        if typeof(firesignal) == "function" then
            if btn.MouseButton1Click then
                firesignal(btn.MouseButton1Click)
            end
            if btn.Activated then
                firesignal(btn.Activated)
            end
            ok = true
        elseif typeof(getconnections) == "function" then
            if btn.MouseButton1Click then
                for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
                    conn:Fire()
                end
            end
            if btn.Activated then
                for _, conn in ipairs(getconnections(btn.Activated)) do
                    conn:Fire()
                end
            end
            ok = true
        end
        if btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
            local inset = GuiService:GetGuiInset()
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2 + Vector2.new(inset.X, inset.Y)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
            ok = true
        end
    end)
    return ok
end

local function tryClickGuiByText(textMatch)
    textMatch = textMatch:lower()
    for _, root in ipairs({ Player:FindFirstChild("PlayerGui"), CoreGui }) do
        if root then
            for _, desc in ipairs(root:GetDescendants()) do
                if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                    local txt = getGuiButtonText(desc):lower()
                    if txt:find(textMatch, 1, true) and isGuiVisible(desc, root) then
                        if clickGuiButton(desc) then
                            return true
                        end
                    end
                elseif desc:IsA("TextLabel") then
                    local txt = (desc.Text or ""):lower()
                    if txt:find(textMatch, 1, true) then
                        local btn = desc:FindFirstAncestorWhichIsA("TextButton")
                            or desc:FindFirstAncestorWhichIsA("ImageButton")
                        if btn and isGuiVisible(btn, root) and clickGuiButton(btn) then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function findClaimGoldGuiButton()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local gui = pg:FindFirstChild("GainedGoldGui")
    local frame = gui and gui:FindFirstChild("SlideDownFrame")
    if not frame then return nil end
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            local txt = getGuiButtonText(desc):lower()
            local name = desc.Name:lower()
            if txt:find("claim", 1, true) or name:find("claim", 1, true) then
                return desc
            end
        end
    end
    for _, desc in ipairs(frame:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
            return desc
        end
    end
    return nil
end

local function fireTouchInterest(part0, part1)
    if not part0 or not part1 then return false end
    if typeof(firetouchinterest) ~= "function" then return false end
    return pcall(function()
        firetouchinterest(part0, part1, 0)
        task.wait(0.05)
        firetouchinterest(part0, part1, 1)
    end)
end

autoClickClaimGold = function(chest)
    local clicked = false
    for _ = 1, 10 do
        if tryClickGuiByText("claim gold") or tryClickGuiByText("claim") then
            clicked = true
            break
        end
        local btn = findClaimGoldGuiButton()
        if btn and clickGuiButton(btn) then
            clicked = true
            break
        end
        task.wait(0.06)
    end

    if chest then
        local touchPart = chest:IsA("BasePart") and chest or chest:FindFirstChildWhichIsA("BasePart", true)
        local phrp = getPartnerHRP()
        local _, myHrp = getCharacter()
        local toucher = phrp or myHrp
        if touchPart and toucher then
            if fireTouchInterest(touchPart, toucher) or fireTouchInterest(toucher, touchPart) then
                clicked = true
            end
        end
    end

    return clicked
end

local function tryClickExactButton(text)
    text = text:lower()
    for _, root in ipairs({ Player:FindFirstChild("PlayerGui"), CoreGui }) do
        if root then
            for _, desc in ipairs(root:GetDescendants()) do
                if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                    local btnText = getGuiButtonText(desc):lower()
                    if btnText == text and isGuiVisible(desc, root) then
                        if clickGuiButton(desc) then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function virtualClickAtScreenXY(x, y)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function virtualClickStoredPoint(point)
    if not point or point.x == nil or point.y == nil then
        return false
    end
    local inset = GuiService:GetGuiInset()
    virtualClickAtScreenXY(point.x + inset.X, point.y + inset.Y)
    return true
end

;(function()
    local SAVE_CLICK_PATH = "ScriptHub/babft_save_clicks.json"

    local function fsRead(path)
        local ok, result = pcall(function()
            if isfile and readfile and isfile(path) then
                return readfile(path)
            end
        end)
        return ok and result or nil
    end

    local function fsWrite(path, content)
        pcall(function()
            if writefile then
                if makefolder and isfolder and not isfolder("ScriptHub") then
                    makefolder("ScriptHub")
                end
                writefile(path, content)
            end
        end)
    end

    local CLICK_POINT_KEYS = { "menu", "saves", "slot", "load", "confirm", "close" }

    local function countPlotBlocks()
        local folder = getPlayerBuildFolder(Player)
        if not folder then return 0 end
        local count = 0
        for _, child in ipairs(folder:GetChildren()) do
            if child:FindFirstChild("PPart") then
                count += 1
            end
        end
        return count
    end

    local function streamPlayerPlot()
        local zone = getPlayerZone(Player)
        local part = zone and (zone:IsA("BasePart") and zone or zone:FindFirstChildWhichIsA("BasePart", true))
        if not part then return end
        pcall(function()
            Player:RequestStreamAroundAsync(part.Position, 8)
        end)
    end

    local function nudgeCharacterOnPlot()
        local _, hrp = getCharacter()
        local zone = getPlayerZone(Player)
        local part = zone and (zone:IsA("BasePart") and zone or zone:FindFirstChildWhichIsA("BasePart", true))
        if not hrp or not part then return end
        pcall(function()
            hrp.CFrame = part.CFrame + Vector3.new(0, 6, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        streamPlayerPlot()
        task.wait(0.6)
        streamPlayerPlot()
    end

    local function runSaveClickSequence(pts)
        virtualClickStoredPoint(pts.menu)
        task.wait(0.55)
        virtualClickStoredPoint(pts.saves)
        task.wait(0.55)
        virtualClickStoredPoint(pts.slot)
        task.wait(0.45)
        virtualClickStoredPoint(pts.load)
        task.wait(1.2)
        virtualClickStoredPoint(pts.confirm)
        task.wait(0.8)
        virtualClickStoredPoint(pts.close)
        task.wait(1)
    end

    local function waitForClientBuildAfterSave(timeout)
        timeout = timeout or 40
        local startT = tick()
        while tick() - startT < timeout do
            streamPlayerPlot()
            if countSeatsOnPlot() >= 2 or countPlotBlocks() >= 4 then
                task.wait(0.8)
                refreshFarmSeats()
                if hasFarmBuildOnPlot and hasFarmBuildOnPlot() then
                    return true
                end
            end
            task.wait(0.35)
        end
        refreshFarmSeats()
        return hasFarmBuildOnPlot and hasFarmBuildOnPlot()
    end

    local function forceClientBuildResync()
        setFarmStatus("Build not visible — refreshing plot...", "info")
        MainFarmState.suppressRespawnHandler = true
        MainFarmState.yourSeat = nil
        MainFarmState.partnerSeat = nil
        MainFarmState.boat = nil

        nudgeCharacterOnPlot()
        if waitForClientBuildAfterSave(12) then
            MainFarmState.suppressRespawnHandler = false
            return true
        end

        setFarmStatus("Resyncing character...", "info")
        pcall(function()
            Player:LoadCharacter()
        end)
        local char = Player.Character
        if not char then
            char = Player.CharacterAdded:Wait()
        end
        pcall(function()
            char:WaitForChild("HumanoidRootPart", 15)
        end)
        task.wait(2.5)
        nudgeCharacterOnPlot()
        MainFarmState.suppressRespawnHandler = false
        return waitForClientBuildAfterSave(35)
    end

    syncClientBuildAfterSave = function()
        nudgeCharacterOnPlot()
        if waitForClientBuildAfterSave(30) then
            return true
        end
        return forceClientBuildResync()
    end

    local function clearFarmBoatStateAfterLoad()
        MainFarmState.yourSeat = nil
        MainFarmState.partnerSeat = nil
        MainFarmState.boat = nil
        refreshFarmSeats()
    end

    local function setClickMarkersVisible(visible)
        local playerGui = Player:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local hub = playerGui:FindFirstChild("NightFallBABFT")
        if not hub then return end
        for _, key in ipairs(CLICK_POINT_KEYS) do
            local marker = hub:FindFirstChild("NightFallClickPoint" .. key)
            if marker then
                marker.Visible = visible
            end
        end
    end

    local function hasSaveClickPointsConfigured()
        local pts = MainFarmState.saveClickPoints
        if not pts then return false end
        for _, key in ipairs(CLICK_POINT_KEYS) do
            local point = pts[key]
            if not point or point.x == nil or point.y == nil then
                return false
            end
        end
        return true
    end

    local function persistSaveClickPoints()
        pcall(function()
            fsWrite(SAVE_CLICK_PATH, HttpService:JSONEncode(MainFarmState.saveClickPoints or {}))
        end)
    end

    local function loadPersistedSaveClickPoints()
        local raw = fsRead(SAVE_CLICK_PATH)
        if not raw then return end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if ok and type(data) == "table" then
            MainFarmState.saveClickPoints = data
        end
    end

    loadPersistedSaveClickPoints()

    loadFarmSaveViaClicks = function()
        if not hasSaveClickPointsConfigured() then
            return false
        end

        MainFarmState.saveClickAutomation = true
        setClickMarkersVisible(false)
        task.wait(0.15)

        local pts = MainFarmState.saveClickPoints
        runSaveClickSequence(pts)

        MainFarmState.saveClickAutomation = false
        setClickMarkersVisible(true)

        clearFarmBoatStateAfterLoad()
        local synced = syncClientBuildAfterSave()
        if not synced then
            setFarmStatus("Save not visible — retrying load...", "info")
            MainFarmState.saveClickAutomation = true
            setClickMarkersVisible(false)
            task.wait(0.2)
            runSaveClickSequence(pts)
            MainFarmState.saveClickAutomation = false
            setClickMarkersVisible(true)
            clearFarmBoatStateAfterLoad()
            synced = syncClientBuildAfterSave()
        end
        if not synced and ensureFarmBuildOnPlot then
            setFarmStatus("Save load failed — auto-pasting saved build...", "info")
            synced = ensureFarmBuildOnPlot()
        end
        clearFarmBoatStateAfterLoad()
        return synced and hasFarmBuildOnPlot and hasFarmBuildOnPlot()
    end

    testFarmSaveClicks = function()
        return loadFarmSaveViaClicks()
    end
end)()

local function tryClickLaunchConfirm()
    for _ = 1, 15 do
        if tryClickExactButton("yes") then
            return true
        end
        for _, root in ipairs({ Player:FindFirstChild("PlayerGui"), CoreGui }) do
            if root then
                for _, desc in ipairs(root:GetDescendants()) do
                    if desc:IsA("TextLabel") then
                        local txt = (desc.Text or ""):lower()
                        if txt:find("launch your boat", 1, true) or txt:find("are you sure", 1, true) then
                            local frame = desc:FindFirstAncestorWhichIsA("Frame") or desc.Parent
                            if frame then
                                for _, btn in ipairs(frame:GetDescendants()) do
                                    if btn:IsA("TextButton") and (btn.Text or ""):lower() == "yes" then
                                        if isGuiVisible(btn, root) and clickGuiButton(btn) then
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
    return false
end

local function quickLaunchBoat()
    tryClickGuiByText("launch")
    tryClickExactButton("yes")
    task.spawn(function()
        for _ = 1, 5 do
            tryClickExactButton("yes")
            task.wait(0.1)
        end
    end)
end

local function tryClickLaunch()
    local clicked = tryClickGuiByText("launch")
    if not clicked then
        for _ = 1, 3 do
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
            end)
            task.wait(0.15)
        end
        clicked = tryClickGuiByText("launch")
    end
    task.wait(0.35)
    tryClickLaunchConfirm()
    return clicked or tryClickExactButton("yes")
end


local function isSeatPart(part)
    return part and (part:IsA("Seat") or part:IsA("VehicleSeat"))
end

local function isPlayerInSeat(plr, seat)
    if not plr or not seat then return false end
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Sit and hum.SeatPart == seat
end

local function findSeatInPlayerBuild(seatName, positionHint)
    if not seatName then return nil end

    local candidates = {}
    local seen = {}

    local function addCandidate(desc)
        if not isSeatPart(desc) or desc.Name ~= seatName or seen[desc] then return end
        seen[desc] = true
        table.insert(candidates, desc)
    end

    local function scan(container)
        if not container then return end
        for _, desc in ipairs(container:GetDescendants()) do
            addCandidate(desc)
        end
    end

    scan(getPlayerBuildFolder(Player))
    if MainFarmState.boat and MainFarmState.boat.Parent then
        scan(MainFarmState.boat)
    end

    local _, _, hum = getCharacter()
    if hum and hum.SeatPart and hum.SeatPart.Name == seatName then
        addCandidate(hum.SeatPart)
    end

    if #candidates == 0 then
        if MainFarmState.running and MainFarmState.active and isBoatAwayFromPlot() then
            for _, desc in ipairs(workspace:GetDescendants()) do
                addCandidate(desc)
                if #candidates >= 8 then break end
            end
        end
    end

    if #candidates == 0 then return nil end
    if #candidates == 1 then return candidates[1] end

    if positionHint then
        local maxDist = (not isBoatAwayFromPlot() and isPlayerOnPlot()) and SEAT_MARK_TOLERANCE or 60
        local best, bestDist = nil, math.huge
        for _, seat in ipairs(candidates) do
            local dist = (seat.Position - positionHint).Magnitude
            if dist < bestDist then
                best, bestDist = seat, dist
            end
        end
        if bestDist <= maxDist then
            return best
        end
    end

    local buildFolder = getPlayerBuildFolder(Player)
    local inFolder = {}
    if buildFolder then
        for _, seat in ipairs(candidates) do
            if seat:IsDescendantOf(buildFolder) then
                table.insert(inFolder, seat)
            end
        end
    end
    local pool = #inFolder > 0 and inFolder or candidates

    local zone = getPlayerZone(Player)
    local zonePart = zone and (zone:IsA("BasePart") and zone or zone:FindFirstChildWhichIsA("BasePart", true))
    if zonePart and #pool > 1 then
        local best, bestDist = pool[1], 0
        for _, seat in ipairs(pool) do
            local dist = (seat.Position - zonePart.Position).Magnitude
            if dist > bestDist then
                best, bestDist = seat, dist
            end
        end
        if bestDist > 90 then
            return best
        end
    end

    return pool[1]
end

local function findAllSeatsByName(seatName)
    if not seatName then return {} end

    local candidates = {}
    local seen = {}

    local function addCandidate(desc)
        if not isSeatPart(desc) or desc.Name ~= seatName or seen[desc] then return end
        seen[desc] = true
        table.insert(candidates, desc)
    end

    local function scan(container)
        if not container then return end
        for _, desc in ipairs(container:GetDescendants()) do
            addCandidate(desc)
        end
    end

    scan(getPlayerBuildFolder(Player))
    if MainFarmState.boat and MainFarmState.boat.Parent then
        scan(MainFarmState.boat)
    end

    return candidates
end

local function getAllSeatsOnPlayerBoat()
    local folder = getPlayerBuildFolder(Player)
    if not folder then return {} end

    local seats = {}
    local seen = {}
    for _, desc in ipairs(folder:GetDescendants()) do
        if isSeatPart(desc) and not seen[desc] then
            seen[desc] = true
            table.insert(seats, desc)
        end
    end

    table.sort(seats, function(a, b)
        if a.Name == b.Name then
            if math.abs(a.Position.X - b.Position.X) > 0.5 then
                return a.Position.X < b.Position.X
            end
            return a.Position.Z < b.Position.Z
        end
        return a.Name < b.Name
    end)

    return seats
end

local function getSeatAppearanceText(seat)
    if not seat then return "" end
    local size = seat.Size
    local pos = seat.Position
    return string.format(
        "%s · %dx%dx%d · @ %.0f, %.0f",
        seat.ClassName,
        math.floor(size.X + 0.5),
        math.floor(size.Y + 0.5),
        math.floor(size.Z + 0.5),
        pos.X,
        pos.Z
    )
end

local function resolveFarmSeatPair()
    local yourName = MainFarmState.yourSeatName
    local partnerName = MainFarmState.partnerSeatName
    if not yourName or not partnerName then
        return nil, nil
    end

    if yourName ~= partnerName then
        return findSeatInPlayerBuild(yourName, nil), findSeatInPlayerBuild(partnerName, nil)
    end

    local savedYourPos = MainFarmState.yourSeatPos
    local savedPartnerPos = MainFarmState.partnerSeatPos
    if not savedYourPos or not savedPartnerPos then
        local all = findAllSeatsByName(yourName)
        return all[1], all[2]
    end

    local savedOffset = savedPartnerPos - savedYourPos
    local candidates = findAllSeatsByName(yourName)
    if #candidates < 2 then
        return candidates[1], nil
    end

    local bestYour, bestPartner, bestScore = nil, nil, math.huge
    for _, seatA in ipairs(candidates) do
        for _, seatB in ipairs(candidates) do
            if seatA ~= seatB then
                local score = ((seatB.Position - seatA.Position) - savedOffset).Magnitude
                if score < bestScore then
                    bestScore = score
                    bestYour, bestPartner = seatA, seatB
                end
            end
        end
    end

    if bestYour and bestPartner and bestScore < 12 then
        return bestYour, bestPartner
    end

    return candidates[1], candidates[2]
end

local function isSeatOnPlayerPlot(seat)
    if not seat or not seat.Parent then return false end
    local folder = getPlayerBuildFolder(Player)
    return folder ~= nil and seat:IsDescendantOf(folder)
end

local function getBoatRoot(seat)
    if not seat or not seat.Parent then return nil end
    local buildFolder = getPlayerBuildFolder(Player)
    if buildFolder and seat:IsDescendantOf(buildFolder) then
        return buildFolder
    end
    if isBoatAwayFromPlot() or isSeatAwayFromPlot(seat, getPlotZonePart()) then
        local model = seat:FindFirstAncestorWhichIsA("Model")
        if model and model.Parent then return model end
        return seat.Parent
    end
    return nil
end

local function getBoatPrimaryPart(boat)
    if not boat or not boat.Parent then return nil end
    if boat:IsA("Model") and boat.PrimaryPart then
        return boat.PrimaryPart
    end
    return boat:FindFirstChildWhichIsA("BasePart", true)
end

local function getBoatReferenceCF()
    if MainFarmState.yourSeat and MainFarmState.yourSeat.Parent then
        return MainFarmState.yourSeat.CFrame
    end
    if MainFarmState.partnerSeat and MainFarmState.partnerSeat.Parent then
        return MainFarmState.partnerSeat.CFrame
    end
    if MainFarmState.boat and MainFarmState.boat:IsA("Model") then
        local ok, cf = pcall(function() return MainFarmState.boat:GetPivot() end)
        if ok then return cf end
    end
    return CFrame.new()
end

local function moveBoatPartsByDelta(delta)
    local moved = {}
    local function movePart(part)
        if not part or moved[part] then return end
        moved[part] = true
        part.CFrame = delta * part.CFrame
    end

    for _, container in ipairs({ getPlayerBuildFolder(Player), MainFarmState.boat }) do
        if container and container.Parent then
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("BasePart") then
                    movePart(desc)
                end
            end
        end
    end
end

local function boatTranslateBy(worldOffset)
    if isBoatAwayFromPlot() then
        return
    end
    if not worldOffset or worldOffset.Magnitude < 0.001 then
        return
    end
    moveBoatPartsByDelta(CFrame.new(worldOffset))
end

local function stabilizeBoatAssembly(boat)
    if boat and boat.Parent then
        for _, desc in ipairs(boat:GetDescendants()) do
            if desc:IsA("BasePart") then
                pcall(function()
                    desc.AssemblyLinearVelocity = Vector3.zero
                    desc.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
    end

    local _, hrp = getCharacter()
    if hrp then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function ensureFarmSeatNames()
    if MainFarmState.yourSeatMarkPos then
        MainFarmState.yourSeatPos = MainFarmState.yourSeatMarkPos
    elseif MainFarmState.yourSeat and MainFarmState.yourSeat.Parent then
        MainFarmState.yourSeatName = MainFarmState.yourSeatName or MainFarmState.yourSeat.Name
        MainFarmState.yourSeatPos = MainFarmState.yourSeatPos or MainFarmState.yourSeat.Position
    end
    if MainFarmState.partnerSeatMarkPos then
        MainFarmState.partnerSeatPos = MainFarmState.partnerSeatMarkPos
    elseif MainFarmState.partnerSeat and MainFarmState.partnerSeat.Parent then
        MainFarmState.partnerSeatName = MainFarmState.partnerSeatName or MainFarmState.partnerSeat.Name
        MainFarmState.partnerSeatPos = MainFarmState.partnerSeatPos or MainFarmState.partnerSeat.Position
    end
end

local function getPlotZonePart()
    local zone = getPlayerZone(Player)
    if not zone then return nil end
    return zone:IsA("BasePart") and zone or zone:FindFirstChildWhichIsA("BasePart", true)
end

local function isSeatAwayFromPlot(seat, zonePart)
    return seat and seat.Parent and zonePart
        and (seat.Position - zonePart.Position).Magnitude > 90
end

local SEAT_MARK_TOLERANCE = 25

local function isPlayerOnPlot()
    local zonePart = getPlotZonePart()
    local _, hrp = getCharacter()
    if not zonePart or not hrp then return false end
    return (hrp.Position - zonePart.Position).Magnitude <= 100
end

local function isSeatAtSavedMark(seat, markPos)
    if not seat or not markPos then return false end
    if not isSeatOnPlayerPlot(seat) then return false end
    return (seat.Position - markPos).Magnitude <= SEAT_MARK_TOLERANCE
end

local function findSeatOnPlotAtMark(seatName, markPos)
    if not seatName or not markPos then return nil end
    local folder = getPlayerBuildFolder(Player)
    if not folder then return nil end
    local best, bestDist = nil, math.huge
    for _, desc in ipairs(folder:GetDescendants()) do
        if isSeatPart(desc) and desc.Name == seatName then
            local dist = (desc.Position - markPos).Magnitude
            if dist <= SEAT_MARK_TOLERANCE and dist < bestDist then
                best, bestDist = desc, dist
            end
        end
    end
    return best
end

local function clearFarmBoatTracking()
    MainFarmState.yourSeat = nil
    MainFarmState.partnerSeat = nil
    MainFarmState.boat = nil
end

local function resetFarmSeatsForPlotPrep()
    if not isPlayerOnPlot() then return end
    clearFarmBoatTracking()
    ensureFarmSeatNames()
    if MainFarmState.yourSeatName then
        local mark = MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos
        MainFarmState.yourSeat = findSeatOnPlotAtMark(MainFarmState.yourSeatName, mark)
    end
    if MainFarmState.partnerSeatName then
        local mark = MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos
        MainFarmState.partnerSeat = findSeatOnPlotAtMark(MainFarmState.partnerSeatName, mark)
    end
    MainFarmState.boat = getBoatRoot(MainFarmState.yourSeat) or getBoatRoot(MainFarmState.partnerSeat)
end

local function isBoatAwayFromPlot()
    local zonePart = getPlotZonePart()
    if not zonePart then return false end

    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Sit and hum.SeatPart then
        if isSeatAwayFromPlot(hum.SeatPart, zonePart) then
            return true
        end
        if isPlayerOnPlot() then
            return false
        end
    end

    if isPlayerOnPlot() then
        return false
    end

    if MainFarmState.yourSeat and isSeatAwayFromPlot(MainFarmState.yourSeat, zonePart) then
        return true
    end
    if MainFarmState.partnerSeat and isSeatAwayFromPlot(MainFarmState.partnerSeat, zonePart) then
        return true
    end

    local normalStages = getNormalStages()
    if normalStages and normalStages:FindFirstChild("CaveStage1") then
        local _, hrp = getCharacter()
        if hrp and hrp.Position.Y < 20 and (hrp.Position - zonePart.Position).Magnitude > 80 then
            return true
        end
    end

    return false
end

local function upgradeFarmSeatsToLaunched()
    local zonePart = getPlotZonePart()
    if not zonePart then return end

    ensureFarmSeatNames()
    if not MainFarmState.yourSeatName or not MainFarmState.partnerSeatName then
        return
    end

    if MainFarmState.yourSeatName ~= MainFarmState.partnerSeatName then
        for _, stateKey in ipairs({ "yourSeat", "partnerSeat" }) do
            local nameKey = stateKey == "yourSeat" and "yourSeatName" or "partnerSeatName"
            local candidates = findAllSeatsByName(MainFarmState[nameKey])
            local best, bestDist = nil, 0
            for _, seat in ipairs(candidates) do
                local dist = (seat.Position - zonePart.Position).Magnitude
                if dist > bestDist then
                    best, bestDist = seat, dist
                end
            end
            if best and bestDist > 90 then
                MainFarmState[stateKey] = best
            end
        end
        return
    end

    local candidates = findAllSeatsByName(MainFarmState.yourSeatName)
    local launched = {}
    for _, seat in ipairs(candidates) do
        if (seat.Position - zonePart.Position).Magnitude > 90 then
            table.insert(launched, seat)
        end
    end
    if #launched >= 2 then
        local yourSeat, partnerSeat = resolveFarmSeatPair()
        if yourSeat and (yourSeat.Position - zonePart.Position).Magnitude > 90 then
            MainFarmState.yourSeat = yourSeat
        end
        if partnerSeat and (partnerSeat.Position - zonePart.Position).Magnitude > 90 then
            MainFarmState.partnerSeat = partnerSeat
        end
    end
end

refreshFarmSeats = function()
    ensureFarmSeatNames()

    if isBoatAwayFromPlot() then
        local yourSeat, partnerSeat = resolveFarmSeatPair()
        local zonePart = getPlotZonePart()
        if yourSeat and (isSeatOnPlayerPlot(yourSeat) or isSeatAwayFromPlot(yourSeat, zonePart)) then
            MainFarmState.yourSeat = yourSeat
        end
        if partnerSeat and (isSeatOnPlayerPlot(partnerSeat) or isSeatAwayFromPlot(partnerSeat, zonePart)) then
            MainFarmState.partnerSeat = partnerSeat
        end
        upgradeFarmSeatsToLaunched()
    else
        if MainFarmState.yourSeatName then
            local mark = MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos
            local seat = findSeatOnPlotAtMark(MainFarmState.yourSeatName, mark)
            MainFarmState.yourSeat = seat
        else
            MainFarmState.yourSeat = nil
        end
        if MainFarmState.partnerSeatName then
            local mark = MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos
            local seat = findSeatOnPlotAtMark(MainFarmState.partnerSeatName, mark)
            MainFarmState.partnerSeat = seat
        else
            MainFarmState.partnerSeat = nil
        end
    end

    if MainFarmState.yourSeat and not MainFarmState.yourSeat.Parent then
        MainFarmState.yourSeat = nil
    end
    if MainFarmState.partnerSeat and not MainFarmState.partnerSeat.Parent then
        MainFarmState.partnerSeat = nil
    end

    MainFarmState.boat = getBoatRoot(MainFarmState.yourSeat) or getBoatRoot(MainFarmState.partnerSeat)
end


local function isBoatRoundActive()
    local normalStages = getNormalStages()
    if not normalStages or not normalStages:FindFirstChild("CaveStage1") then
        return false
    end

    if isBoatAwayFromPlot() then
        return true
    end

    local _, hrp = getCharacter()
    local zonePart = getPlotZonePart()
    if hrp and zonePart then
        if (hrp.Position - zonePart.Position).Magnitude > 100 then
            return true
        end
        if hrp.Position.Y < 5 then
            return true
        end
    end

    if isPlayerInSeat(Player, MainFarmState.yourSeat)
        or isPlayerInSeat(MainFarmState.partner, MainFarmState.partnerSeat) then
        return true
    end

    return false
end

local function isBoatRoundStarted()
    if not getNormalStages() or not getNormalStages():FindFirstChild("CaveStage1") then
        return false
    end
    return isBoatAwayFromPlot()
end

local function getFarmStageStartPos(stage)
    local normalStages = getNormalStages()
    if not normalStages then return nil end
    stage = stage or 1
    local stageObj = normalStages:FindFirstChild("CaveStage" .. stage)
    local darkPart = stageObj and stageObj:FindFirstChild("DarknessPart")
    if not darkPart then return nil end
    return (darkPart.CFrame - Vector3.new(0, 0, 15)).Position
end

local function waitForRoundActive(timeout)
    timeout = timeout or 60
    local t = tick()
    while MainFarmState.active and tick() - t < timeout do
        if isBoatRoundStarted() then
            refreshFarmSeats()
            upgradeFarmSeatsToLaunched()
            refreshFarmSeats()
            return true
        end
        if isBoatRoundActive() and tick() - t > 8 then
            refreshFarmSeats()
            upgradeFarmSeatsToLaunched()
            refreshFarmSeats()
            return true
        end
        tryClickLaunch()
        tryClickLaunchConfirm()
        task.wait(0.5)
    end
    if isBoatRoundStarted() or isBoatRoundActive() then
        refreshFarmSeats()
        upgradeFarmSeatsToLaunched()
        refreshFarmSeats()
        return true
    end
    return false
end

local function areFarmSeatsReady()
    ensureFarmSeatNames()
    if not MainFarmState.yourSeatName or not MainFarmState.partnerSeatName then
        return false
    end
    if MainFarmState.yourSeatName == MainFarmState.partnerSeatName then
        if not MainFarmState.yourSeatPos or not MainFarmState.partnerSeatPos then
            return false
        end
        if (MainFarmState.yourSeatPos - MainFarmState.partnerSeatPos).Magnitude < 2 then
            return false
        end
    end
    refreshFarmSeats()
    if MainFarmState.yourSeat and MainFarmState.partnerSeat then
        return MainFarmState.yourSeat ~= MainFarmState.partnerSeat
            and MainFarmState.yourSeat.Parent
            and MainFarmState.partnerSeat.Parent
    end
    return true
end

setFarmStatus = function(text, kind)
    if not UI.FarmBuildStatusLabel then return end
    UI.FarmBuildStatusLabel.Text = text
    if kind == "error" then
        UI.FarmBuildStatusLabel.TextColor3 = COLORS.danger
    elseif kind == "ok" then
        UI.FarmBuildStatusLabel.TextColor3 = COLORS.success
    else
        UI.FarmBuildStatusLabel.TextColor3 = COLORS.textMuted
    end
end

countSeatsOnPlot = function()
    local folder = getPlayerBuildFolder(Player)
    if not folder then return 0 end
    local count = 0
    for _, desc in ipairs(folder:GetDescendants()) do
        if isSeatPart(desc) then
            count += 1
        end
    end
    return count
end

local function getFarmSetupBlocker(opts)
    opts = opts or {}
    ensureFarmSeatNames()

    if not MainFarmState.partner then
        resolveSavedFarmPartner()
    end
    if not MainFarmState.partner then
        return "Choose a partner player first"
    end

    if MainFarmState.yourSeatMarkPos then
        MainFarmState.yourSeatPos = MainFarmState.yourSeatMarkPos
    elseif MainFarmState.yourSeat and MainFarmState.yourSeat.Parent then
        MainFarmState.yourSeatName = MainFarmState.yourSeatName or MainFarmState.yourSeat.Name
        if not MainFarmState.yourSeatPos then
            MainFarmState.yourSeatPos = MainFarmState.yourSeat.Position
        end
    elseif not MainFarmState.yourSeatName then
        return "Choose your seat first"
    end

    if MainFarmState.partnerSeatMarkPos then
        MainFarmState.partnerSeatPos = MainFarmState.partnerSeatMarkPos
    elseif MainFarmState.partnerSeat and MainFarmState.partnerSeat.Parent then
        MainFarmState.partnerSeatName = MainFarmState.partnerSeatName or MainFarmState.partnerSeat.Name
        if not MainFarmState.partnerSeatPos then
            MainFarmState.partnerSeatPos = MainFarmState.partnerSeat.Position
        end
    elseif not MainFarmState.partnerSeatName then
        return "Choose the partner seat first"
    end

    if MainFarmState.yourSeatName == MainFarmState.partnerSeatName then
        if not MainFarmState.yourSeatPos or not MainFarmState.partnerSeatPos then
            return "Both seats share a name — re-mark both seats"
        end
        if (MainFarmState.yourSeatPos - MainFarmState.partnerSeatPos).Magnitude < 2 then
            return "Pick two different seats (yours and partner's)"
        end
    end

    if not opts.skipBuildCheck then
        local seatCount = countSeatsOnPlot()
        if seatCount < 2 then
            return "Farm build needs 2 seats on your plot (found " .. seatCount .. ")"
        end
    end

    return nil
end

local function waitForFarmSeatsAfterBuild(timeout)
    timeout = timeout or 20
    local startT = tick()
    while tick() - startT < timeout do
        refreshFarmSeats()
        if MainFarmState.yourSeat and MainFarmState.partnerSeat
            and MainFarmState.yourSeat.Parent and MainFarmState.partnerSeat.Parent
            and isSeatAtSavedMark(MainFarmState.yourSeat, MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos)
            and isSeatAtSavedMark(MainFarmState.partnerSeat, MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos) then
            return true
        end
        task.wait(0.4)
    end
    refreshFarmSeats()
    return MainFarmState.yourSeat and MainFarmState.partnerSeat
        and MainFarmState.yourSeat.Parent and MainFarmState.partnerSeat.Parent
        and isSeatAtSavedMark(MainFarmState.yourSeat, MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos)
        and isSeatAtSavedMark(MainFarmState.partnerSeat, MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos)
end

local function farmSeatsReadyOnPlot()
    refreshFarmSeats()
    return MainFarmState.yourSeat and MainFarmState.partnerSeat
        and MainFarmState.yourSeat.Parent and MainFarmState.partnerSeat.Parent
        and isSeatAtSavedMark(MainFarmState.yourSeat, MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos)
        and isSeatAtSavedMark(MainFarmState.partnerSeat, MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos)
end

local function reloadBuildUntilSeatsFound(maxAttempts)
    maxAttempts = maxAttempts or 30
    for attempt = 1, maxAttempts do
        refreshFarmSeats()
        if farmSeatsReadyOnPlot() then
            return true
        end

        setFarmStatus("Reloading build until seats appear (" .. attempt .. "/" .. maxAttempts .. ")...", "info")
        resetFarmSeatsForPlotPrep()

        if Config.AutoLoadSave and loadFarmSaveViaClicks then
            loadFarmSaveViaClicks()
        elseif ensureFarmBuildOnPlot then
            ensureFarmBuildOnPlot()
        end

        if syncClientBuildAfterSave then
            syncClientBuildAfterSave()
        end

        resetFarmSeatsForPlotPrep()
        refreshFarmSeats()
        task.wait(0.05)
    end

    return farmSeatsReadyOnPlot()
end

local function areBothPlayersSeated()
    return isPlayerInSeat(Player, MainFarmState.yourSeat)
        and isPlayerInSeat(MainFarmState.partner, MainFarmState.partnerSeat)
end

local function getPartnerHRP(plr)
    plr = plr or MainFarmState.partner
    local char = plr and plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getLaunchedPartnerSeat()
    ensureFarmSeatNames()
    local zonePart = getPlotZonePart()

    if MainFarmState.partnerSeat and MainFarmState.partnerSeat.Parent then
        if not zonePart or isSeatAwayFromPlot(MainFarmState.partnerSeat, zonePart) then
            return MainFarmState.partnerSeat
        end
    end

    if MainFarmState.partnerSeatName and zonePart then
        local launched = {}
        for _, seat in ipairs(findAllSeatsByName(MainFarmState.partnerSeatName)) do
            if isSeatAwayFromPlot(seat, zonePart) then
                table.insert(launched, seat)
            end
        end

        if #launched == 1 then
            return launched[1]
        end

        if #launched > 1 then
            if MainFarmState.yourSeatName == MainFarmState.partnerSeatName then
                local _, partnerSeat = resolveFarmSeatPair()
                if partnerSeat and isSeatAwayFromPlot(partnerSeat, zonePart) then
                    return partnerSeat
                end
            end
            if MainFarmState.partnerSeatPos then
                local best, bestDist = nil, math.huge
                for _, seat in ipairs(launched) do
                    local dist = (seat.Position - MainFarmState.partnerSeatPos).Magnitude
                    if dist < bestDist then
                        best, bestDist = seat, dist
                    end
                end
                if best then
                    return best
                end
            end
            return launched[1]
        end
    end

    return MainFarmState.partnerSeat
end

local function isPartnerNearBoat(maxDist)
    maxDist = maxDist or 100
    local partnerHrp = getPartnerHRP()
    local seat = getLaunchedPartnerSeat()
    if not partnerHrp or not seat or not seat.Parent then return false end
    return (partnerHrp.Position - seat.Position).Magnitude <= maxDist
end

local function isPartnerFarFromLaunchedBoat(maxDist)
    maxDist = maxDist or 200
    local partnerHrp = getPartnerHRP()
    local seat = getLaunchedPartnerSeat()
    if not partnerHrp or not seat or not seat.Parent then return true end
    return (partnerHrp.Position - seat.Position).Magnitude > maxDist
end

local function isPartnerSeatedOnFarmSeat()
    if not MainFarmState.partner then return false end
    local hum = MainFarmState.partner.Character
        and MainFarmState.partner.Character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.Sit or not hum.SeatPart then return false end
    if MainFarmState.partnerSeat and hum.SeatPart == MainFarmState.partnerSeat then
        return true
    end
    if MainFarmState.partnerSeatName and hum.SeatPart.Name == MainFarmState.partnerSeatName then
        MainFarmState.partnerSeat = hum.SeatPart
        return true
    end
    return false
end

local function isYouSeatedOnFarmSeat()
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.Sit or not hum.SeatPart then return false end
    if MainFarmState.yourSeat and hum.SeatPart == MainFarmState.yourSeat then
        return true
    end
    if MainFarmState.yourSeatName and hum.SeatPart.Name == MainFarmState.yourSeatName then
        MainFarmState.yourSeat = hum.SeatPart
        return true
    end
    return false
end

local PARTNER_SEAT_MATCH_DIST = 6
local PARTNER_SEAT_TOUCH_DIST = 2.5
local PARTNER_SEAT_SIT_RANGE = 15

local function getPartnerSeatTouchTarget()
    refreshFarmSeats()
    local partnerHrp = getPartnerHRP()
    if partnerHrp then
        return partnerHrp.Position + Vector3.new(0, 1.5, 0)
    end
    local seat = MainFarmState.partnerSeat
    if seat and seat.Parent then
        return seat.Position + Vector3.new(0, 1.5, 0)
    end
    return nil
end

local function getBoatFlyTargetForPartnerAlign()
    refreshFarmSeats()
    local partnerSeat = MainFarmState.partnerSeat
    local partnerHrp = getPartnerHRP()
    local flyPart = getBoatFlyPart()
    local partnerWorldTarget = getPartnerSeatTouchTarget()
    if not partnerWorldTarget or not flyPart then
        return nil
    end
    if partnerSeat and partnerSeat.Parent then
        local seatOffset = partnerSeat.Position - flyPart.Position
        return partnerWorldTarget - seatOffset
    end
    return partnerWorldTarget
end

local function getBoatFlyTargetAbovePartner()
    local target = getBoatFlyTargetForPartnerAlign()
    if not target then return nil end
    local flyPart = getBoatFlyPart()
    if flyPart then
        return Vector3.new(target.X, flyPart.Position.Y, target.Z)
    end
    return target
end

local function getBoatFlyTargetPushIntoPartner()
    local base = getBoatFlyTargetForPartnerAlign()
    if not base then return nil end
    local partnerHrp = getPartnerHRP()
    local flyPart = getBoatFlyPart()
    if not partnerHrp or not flyPart then return base end
    local flat = Vector3.new(partnerHrp.Position.X - flyPart.Position.X, 0, partnerHrp.Position.Z - flyPart.Position.Z)
    if flat.Magnitude < 0.5 then
        local look = partnerHrp.CFrame.LookVector
        flat = Vector3.new(look.X, 0, look.Z)
    end
    if flat.Magnitude > 0.05 then
        return base + flat.Unit * 10
    end
    return base
end

local function horizDistXZ(a, b)
    return (Vector3.new(a.X - b.X, 0, a.Z - b.Z)).Magnitude
end

local function getGoldenChestTouchPoint(chest)
    if not chest then return nil, nil, nil end
    local center = chest:GetPivot().Position
    local topY = center.Y

    if chest:IsA("Model") then
        local ok, cf, size = pcall(function()
            return chest:GetBoundingBox()
        end)
        if ok and cf and size then
            center = cf.Position
            topY = cf.Position.Y + size.Y * 0.5
        end
    elseif chest:IsA("BasePart") then
        center = chest.Position
        topY = chest.Position.Y + chest.Size.Y * 0.5
    else
        local part = chest:FindFirstChildWhichIsA("BasePart", true)
        if part then
            center = part.Position
            topY = part.Position.Y + part.Size.Y * 0.5
        end
    end

    local flatCenter = Vector3.new(center.X, topY, center.Z)
    local touchPoint = flatCenter + Vector3.new(0, 1.5, 0)
    return touchPoint, topY, flatCenter
end

local function getChestPartnerSeatTarget(chest)
    local _, _, flatCenter = getGoldenChestTouchPoint(chest)
    if not flatCenter then return nil end
    return flatCenter + Vector3.new(0, 1.5, 0)
end

local function getPartnerSeatDistToChest(chest)
    refreshFarmSeats()
    local partnerSeat = MainFarmState.partnerSeat
    local _, _, flatCenter = getGoldenChestTouchPoint(chest)
    if not partnerSeat or not partnerSeat.Parent or not flatCenter then
        return math.huge
    end
    return horizDistXZ(partnerSeat.Position, flatCenter)
end

local function getBoatFlyTargetForChestAlign(chest)
    refreshFarmSeats()
    local partnerSeat = MainFarmState.partnerSeat
    local flyPart = getBoatFlyPart()
    local chestWorldTarget = getChestPartnerSeatTarget(chest)
    if not chestWorldTarget or not flyPart then
        return nil
    end
    if partnerSeat and partnerSeat.Parent then
        local seatOffset = partnerSeat.Position - flyPart.Position
        return chestWorldTarget - seatOffset
    end
    return chestWorldTarget
end

local function getBoatFlyTargetForChestAlignFlat(chest)
    local target = getBoatFlyTargetForChestAlign(chest)
    if not target then return nil end
    local flyPart = getBoatFlyPart()
    if flyPart then
        return Vector3.new(target.X, flyPart.Position.Y, target.Z)
    end
    return target
end

local function getBoatFlyTargetForChestSideAlign(chest)
    refreshFarmSeats()
    local partnerSeat = MainFarmState.partnerSeat
    local yourSeat = MainFarmState.yourSeat
    local flyPart = getBoatFlyPart()
    local chestWorldTarget = getChestPartnerSeatTarget(chest)
    if not chestWorldTarget or not flyPart then
        return nil
    end

    local _, _, flatCenter = getGoldenChestTouchPoint(chest)
    local refPos = (yourSeat and yourSeat.Parent and yourSeat.Position) or flyPart.Position
    local toChest = flatCenter - Vector3.new(refPos.X, flatCenter.Y, refPos.Z)
    toChest = Vector3.new(toChest.X, 0, toChest.Z)
    if toChest.Magnitude < 0.5 then
        toChest = Vector3.new(0, 0, -1)
    else
        toChest = toChest.Unit
    end
    local lateral = toChest:Cross(Vector3.new(0, 1, 0))
    if lateral.Magnitude < 0.1 then
        lateral = Vector3.new(1, 0, 0)
    else
        lateral = lateral.Unit
    end

    local approachTarget = chestWorldTarget - toChest * 38 + lateral * 24
    if partnerSeat and partnerSeat.Parent then
        local seatOffset = partnerSeat.Position - flyPart.Position
        return approachTarget - seatOffset
    end
    return approachTarget
end

local function boatFlyGlidePartnerSeatToChest(chest, opts)
    opts = opts or {}
    local stopDist = opts.stopDist or PARTNER_SEAT_TOUCH_DIST
    local timeout = opts.timeout or 60

    if opts.sideApproach then
        boatFlyGlideToTarget(function()
            return getBoatFlyTargetForChestSideAlign(chest)
        end, 8, timeout, {
            breakOnPartnerSeated = false,
            chestAlignStop = true,
            chest = chest,
            holdAltitude = true,
        })
    end

    if opts.holdAltitude then
        boatFlyGlideToTarget(function()
            return getBoatFlyTargetForChestAlignFlat(chest)
        end, stopDist, timeout, {
            breakOnPartnerSeated = false,
            chestAlignStop = true,
            chest = chest,
            holdAltitude = true,
        })
    end

    boatFlyGlideToTarget(function()
        return getBoatFlyTargetForChestAlign(chest)
    end, stopDist, timeout, {
        breakOnPartnerSeated = false,
        chestAlignStop = true,
        chest = chest,
        fastDescent = opts.fastDescent ~= false,
        pushForward = opts.pushForward,
    })

    return getPartnerSeatDistToChest(chest) <= stopDist + 1
end

local function waitForPartnerNearSeatAndSit(timeout)
    timeout = timeout or 45
    setFarmStatus("Waiting for partner at their seat...", "info")

    local startT = tick()
    while MainFarmState.active and tick() - startT < timeout do
        refreshFarmSeats()

        if isPartnerSeatedOnFarmSeat() then
            return true
        end

        local seat = MainFarmState.partnerSeat
        local plr = MainFarmState.partner
        local hrp = getPartnerHRP(plr)
        if seat and hrp and seat.Parent then
            local dist = (hrp.Position - seat.Position).Magnitude
            if dist <= PARTNER_SEAT_SIT_RANGE then
                pcall(function()
                    seat.AssemblyLinearVelocity = Vector3.zero
                    seat.AssemblyAngularVelocity = Vector3.zero
                    if isSeatPart(seat) then
                        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                        if hum and not hum.Sit then
                            seat:Sit(hum)
                        end
                    end
                end)
                task.wait(0.15)
                if isPartnerSeatedOnFarmSeat() then
                    return true
                end
            end
        end

        task.wait(0.2)
    end

    return isPartnerSeatedOnFarmSeat()
end

local function gentleMovePartnerSeatToPlayer(seat, plr)
    seat = seat or MainFarmState.partnerSeat
    plr = plr or MainFarmState.partner
    if not seat or not plr or seat == MainFarmState.yourSeat or plr == Player then
        return false
    end
    if isPlayerInSeat(plr, seat) or isPartnerSeatedOnFarmSeat() then
        return true
    end

    if isBoatAwayFromPlot() then
        return waitForPartnerNearSeatAndSit(45)
    end

    stabilizeBoatAssembly(MainFarmState.boat)

    for _ = 1, 50 do
        if not MainFarmState.active then
            return false
        end
        if isPartnerSeatedOnFarmSeat() or isPlayerInSeat(plr, seat) then
            return true
        end

        refreshFarmSeats()
        seat = MainFarmState.partnerSeat
        local hrp = getPartnerHRP(plr)
        if not seat or not seat.Parent or not hrp then
            return false
        end

        local delta = hrp.Position - seat.Position
        local dist = delta.Magnitude
        if dist <= PARTNER_SEAT_TOUCH_DIST then
            pcall(function()
                seat.AssemblyLinearVelocity = Vector3.zero
                seat.AssemblyAngularVelocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                if isSeatPart(seat) then
                    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and not hum.Sit then
                        seat:Sit(hum)
                    end
                end
            end)
            task.wait(0.12)
            stabilizeBoatAssembly(MainFarmState.boat)
            if isPartnerSeatedOnFarmSeat() or isPlayerInSeat(plr, seat) then
                return true
            end
        else
            local step = math.min(1.8, dist * 0.3)
            pcall(function()
                seat.Anchored = false
                seat.CanCollide = false
                seat.AssemblyLinearVelocity = Vector3.zero
                seat.AssemblyAngularVelocity = Vector3.zero
                seat.CFrame = seat.CFrame + delta.Unit * step
            end)
            stabilizeBoatAssembly(MainFarmState.boat)
        end

        task.wait(0.05)
    end

    return isPartnerSeatedOnFarmSeat() or isPlayerInSeat(plr, seat)
end

local function isPartnerAtPartnerSeatPosition()
    if isPartnerSeatedOnFarmSeat() then
        return true
    end

    refreshFarmSeats()
    local partnerHrp = getPartnerHRP()
    local seat = MainFarmState.partnerSeat
    if not partnerHrp or not seat or not seat.Parent then
        return false
    end

    return (partnerHrp.Position - seat.Position).Magnitude <= PARTNER_SEAT_MATCH_DIST
end

local function forceSeatOnPlayer(seat, plr)
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not seat or not hrp then return false end
    if seat == MainFarmState.yourSeat and plr ~= Player then
        return false
    end
    if seat == MainFarmState.partnerSeat and plr == Player then
        return false
    end
    pcall(function()
        seat.Anchored = false
        seat.CanCollide = false
        seat.AssemblyLinearVelocity = Vector3.zero
        seat.AssemblyAngularVelocity = Vector3.zero
        seat.CFrame = hrp.CFrame
    end)
    return true
end

local sitPlayerOnSeat

local function forcePartnerSeatToPlayer(seat, plr)
    if not seat or not plr or seat == MainFarmState.yourSeat or plr == Player then
        return false
    end
    if PartnerGlideState.active then
        return false
    end
    return gentleMovePartnerSeatToPlayer(seat, plr)
end

local function teleportPlayerToSeat(plr, seat)
    if isPlayerInSeat(plr, seat) then
        return true
    end
    if plr ~= Player or not seat or not seat.Parent then
        return false
    end
    return pivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
end

local function isPartnerOnBoat()
    local partnerHrp = getPartnerHRP()
    local partnerSeat = getLaunchedPartnerSeat()
    if not partnerHrp or not partnerSeat or not partnerSeat.Parent then
        return false
    end
    return (partnerHrp.Position - partnerSeat.Position).Magnitude <= 35
end

local function getForceTeleportTarget()
    local partnerHrp = getPartnerHRP()
    if partnerHrp then
        return partnerHrp.CFrame * CFrame.new(0, 0, 5)
    end

    refreshFarmSeats()
    upgradeFarmSeatsToLaunched()
    refreshFarmSeats()

    local partnerSeat = getLaunchedPartnerSeat() or MainFarmState.partnerSeat
    if partnerSeat and partnerSeat.Parent then
        return partnerSeat.CFrame * CFrame.new(0, 3, 2)
    end

    if MainFarmState.yourSeat and MainFarmState.yourSeat.Parent then
        return MainFarmState.yourSeat.CFrame * CFrame.new(0, 3, 0)
    end

    if MainFarmState.partnerSeatPos then
        return CFrame.new(MainFarmState.partnerSeatPos + Vector3.new(0, 4, 0))
    end

    return nil
end

local function getTeleportTargetAfterLaunch()
    return getForceTeleportTarget()
end

local function forceTeleportTo(targetCF)
    local char, hrp, hum = getCharacter()
    if not char or not hrp or not targetCF then
        return false
    end

    if MainFarmState.yourSeat and isPlayerInSeat(Player, MainFarmState.yourSeat) then
        return true
    end

    local function applyOnce()
        pcall(function()
            if hum then
                hum.Sit = false
                hum.PlatformStand = true
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end
        end)
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = targetCF
        end)
        pcall(function()
            char:PivotTo(targetCF)
        end)
        pcall(function()
            hrp:PivotTo(targetCF)
        end)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
    end

    for _ = 1, 25 do
        applyOnce()
        RunService.Heartbeat:Wait()
    end

    for _ = 1, 15 do
        applyOnce()
        task.wait(0.04)
    end

    pcall(function()
        if hum then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)

    return true
end

local function hardTeleportTo(targetCF)
    return forceTeleportTo(targetCF)
end

local function getInFrontOfPartnerCF(studs)
    studs = studs or 20
    local partnerHrp = getPartnerHRP()
    if not partnerHrp then return nil end

    local look = partnerHrp.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.05 then
        flat = Vector3.new(0, 0, -1)
    else
        flat = flat.Unit
    end

    local pos = partnerHrp.Position + flat * studs
    return CFrame.new(pos.X, partnerHrp.Position.Y + 2, pos.Z)
end

local function getBehindPartnerCF(studs)
    studs = studs or 6
    local partnerHrp = getPartnerHRP()
    if not partnerHrp then return nil end

    local pushForward = getChestPushForwardVector()
    local pos = partnerHrp.Position - pushForward * studs
    pos = Vector3.new(pos.X, partnerHrp.Position.Y + 1.5, pos.Z)
    return CFrame.new(pos, pos + pushForward)
end

local function softTeleportNearPartner(studs)
    studs = studs or 20
    local cf = getInFrontOfPartnerCF(studs)
    if not cf then return false end

    local _, hrp, hum = getCharacter()
    if not hrp then return false end

    pcall(function()
        if hum and not hum.Sit then
            hum.PlatformStand = false
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = cf
    end)
    task.wait(0.15)
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

local setFarmBoatFlyEnabled

local function cleanupPartnerGlide()
    if PartnerGlideState.bv then
        PartnerGlideState.bv:Destroy()
        PartnerGlideState.bv = nil
    end
    if PartnerGlideState.bg then
        PartnerGlideState.bg:Destroy()
        PartnerGlideState.bg = nil
    end
    if PartnerGlideState.part then
        pcall(function()
            PartnerGlideState.part.AssemblyLinearVelocity = Vector3.zero
            PartnerGlideState.part.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    PartnerGlideState.part = nil
    PartnerGlideState.active = false
    setFarmBoatFlyEnabled(false)
end

local function getPartnerFrontTargetPos(studs)
    studs = studs or 20
    local cf = getInFrontOfPartnerCF(studs)
    if not cf then return nil end
    local flyPart = getBoatFlyPart()
    local _, hrp = getCharacter()
    local y = (flyPart or hrp) and (flyPart or hrp).Position.Y or cf.Position.Y
    return Vector3.new(cf.Position.X, y, cf.Position.Z)
end

local function getPartnerHRPTargetPos(studs)
    studs = studs or 10
    local cf = getInFrontOfPartnerCF(studs)
    if cf then
        return cf.Position
    end
    local partnerHrp = getPartnerHRP()
    if partnerHrp then
        return partnerHrp.Position + Vector3.new(0, 2, 0)
    end
    return nil
end

local function getPartnerFinalTargetPos()
    refreshFarmSeats()
    local seat = MainFarmState.partnerSeat
    if seat and seat.Parent then
        return seat.Position + Vector3.new(0, 2, 0)
    end
    local hrp = getPartnerHRP()
    if hrp then
        return hrp.Position + Vector3.new(0, 1, 0)
    end
    return nil
end

local function glidePartTowardTarget(part, getTargetFn, speed, timeout, stopDist)
    stopDist = stopDist or 4
    speed = speed or 30
    timeout = timeout or 20

    cleanupPartnerGlide()
    if not part or not part.Parent then
        return false
    end

    pcall(function()
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end)

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 0, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = part

    PartnerGlideState.bv = bv
    PartnerGlideState.part = part

    local startY = part.Position.Y
    local startT = tick()
    while MainFarmState.active and tick() - startT < timeout do
        refreshFarmSeats()

        if isPartnerSeatedOnFarmSeat() then
            break
        end

        local targetPos = getTargetFn()
        if not targetPos or not part.Parent then
            break
        end

        local flatTarget = Vector3.new(targetPos.X, startY, targetPos.Z)
        local flatCurrent = Vector3.new(part.Position.X, startY, part.Position.Z)
        local flatDelta = flatTarget - flatCurrent
        local dist = flatDelta.Magnitude
        if dist <= stopDist or dist < 2 then
            break
        end

        local glideVel = flatDelta.Unit * math.min(speed, math.max(dist * 2, 6))
        bv.Velocity = glideVel
        pcall(function()
            part.AssemblyAngularVelocity = Vector3.zero
            part.AssemblyLinearVelocity = Vector3.new(glideVel.X, 0, glideVel.Z)
        end)
        RunService.Heartbeat:Wait()
    end

    bv.Velocity = Vector3.zero
    cleanupPartnerGlide()
    return true
end

local boatPivotTo

local function flyBoatUp(liftStuds, speed)
    if isBoatAwayFromPlot() then
        return false
    end
    liftStuds = liftStuds or Config.PartnerLiftHeight or 50
    speed = speed or 20

    refreshFarmSeats()
    local boat = MainFarmState.boat
        or getBoatRoot(MainFarmState.yourSeat)
        or getBoatRoot(MainFarmState.partnerSeat)
    if not boat then
        return false
    end
    MainFarmState.boat = boat

    PartnerGlideState.active = true
    stabilizeBoatAssembly(boat)

    local startY = getBoatReferenceCF().Position.Y
    local targetY = startY + liftStuds
    local startT = tick()

    while MainFarmState.active and tick() - startT < 25 do
        local currentY = getBoatReferenceCF().Position.Y
        if currentY >= targetY - 1 then
            break
        end

        local dt = RunService.Heartbeat:Wait()
        local step = math.min(speed * dt, targetY - currentY)
        if step > 0.02 then
            boatTranslateBy(Vector3.new(0, step, 0))
        end
        stabilizeBoatAssembly(boat)
    end

    stabilizeBoatAssembly(boat)
    return true
end

local function glideBoatTowardTarget(getTargetFn, speed, timeout, stopDist, allowY)
    if isBoatAwayFromPlot() then
        return false
    end
    stopDist = stopDist or 6
    speed = speed or 22
    timeout = timeout or 35
    allowY = allowY == true

    cleanupPartnerGlide()
    PartnerGlideState.active = true

    refreshFarmSeats()
    local boat = MainFarmState.boat
        or getBoatRoot(MainFarmState.yourSeat)
        or getBoatRoot(MainFarmState.partnerSeat)
    if not boat then
        PartnerGlideState.active = false
        return false
    end
    MainFarmState.boat = boat

    stabilizeBoatAssembly(boat)
    local startCF = getBoatReferenceCF()
    local glideY = startCF.Position.Y

    local startT = tick()
    while MainFarmState.active and tick() - startT < timeout do
        refreshFarmSeats()

        if isPartnerSeatedOnFarmSeat() then
            break
        end

        local targetPos = getTargetFn()
        if not targetPos then
            break
        end

        local currentPos = getBoatReferenceCF().Position
        local moveTarget = allowY and targetPos or Vector3.new(targetPos.X, glideY, targetPos.Z)
        local moveCurrent = allowY and currentPos or Vector3.new(currentPos.X, glideY, currentPos.Z)
        local moveDelta = moveTarget - moveCurrent
        local dist = moveDelta.Magnitude
        if dist <= stopDist or dist < 2 then
            break
        end

        local dt = RunService.Heartbeat:Wait()
        local step = math.min(speed * dt, math.max(dist - stopDist * 0.5, 0))
        if step > 0.02 and dist > 0.05 then
            boatTranslateBy(moveDelta.Unit * step)
        end
        stabilizeBoatAssembly(boat)
    end

    stabilizeBoatAssembly(boat)
    cleanupPartnerGlide()
    return true
end

local function teleportPartNearPartner(part, studs)
    if isBoatAwayFromPlot() then
        return false
    end
    studs = studs or 20
    local cf = getInFrontOfPartnerCF(studs)
    if not cf or not part or not part.Parent then return false end

    pcall(function()
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
        part.CFrame = cf
    end)
    task.wait(0.15)
    pcall(function()
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

local function prepareBoatAssemblyForFly()
    refreshFarmSeats()
    local boat = MainFarmState.boat
        or (MainFarmState.yourSeat and getBoatRoot(MainFarmState.yourSeat))
        or (MainFarmState.partnerSeat and getBoatRoot(MainFarmState.partnerSeat))
    if boat then
        MainFarmState.boat = boat
        stabilizeBoatAssembly(boat)
        for _, part in ipairs(boat:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.Anchored = false
                end)
            end
        end
    end
    local flyPart = getBoatFlyPart()
    if flyPart then
        pcall(function()
            flyPart.Anchored = false
            flyPart.AssemblyLinearVelocity = Vector3.zero
            flyPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    return flyPart
end

local function boatFlyGlideToTarget(getTargetFn, stopDist, timeout, options)
    stopDist = stopDist or 10
    timeout = timeout or 45
    options = options or {}
    local breakOnPartnerSeated = options.breakOnPartnerSeated
    if breakOnPartnerSeated == nil then
        breakOnPartnerSeated = true
    end

    local flyPart = prepareBoatAssemblyForFly()
    if not flyPart or not isPlayerSeated() then
        return false
    end

    PartnerGlideState.active = true
    FarmState.tweening = true

    local function refreshTarget()
        local pos = getTargetFn()
        if pos then
            FarmState.boatFlyTarget = pos
        end
        return pos
    end

    refreshTarget()
    setFarmBoatFlyEnabled(true, FarmState.boatFlyTarget, options)

    local startT = tick()
    while tick() - startT < timeout do
        if not FarmState.farmBoatFlyActive then
            break
        end

        refreshFarmSeats()

        if breakOnPartnerSeated and isPartnerSeatedOnFarmSeat() then
            break
        end

        refreshTarget()

        flyPart = getBoatFlyPart()
        if not flyPart or not FarmState.boatFlyTarget then
            break
        end

        if not options.untilPartnerSeated then
            if options.partnerSeatStop then
                local partnerHrp = getPartnerHRP()
                local partnerSeat = MainFarmState.partnerSeat
                if partnerHrp and partnerSeat and partnerSeat.Parent then
                    if (partnerHrp.Position - partnerSeat.Position).Magnitude <= stopDist then
                        break
                    end
                end
            end

            if options.chestAlignStop and options.chest then
                if getPartnerSeatDistToChest(options.chest) <= stopDist then
                    break
                end
            end

            local dist
            if options.holdAltitude then
                local flatTarget = Vector3.new(
                    FarmState.boatFlyTarget.X,
                    flyPart.Position.Y,
                    FarmState.boatFlyTarget.Z
                )
                dist = (flatTarget - flyPart.Position).Magnitude
            else
                dist = (FarmState.boatFlyTarget - flyPart.Position).Magnitude
            end
            if dist <= stopDist then
                break
            end
        end

        RunService.Heartbeat:Wait()
    end

    pcall(function()
        if BoatFlyState.bv then
            BoatFlyState.bv.Velocity = Vector3.zero
        end
    end)
    setFarmBoatFlyEnabled(false)
    PartnerGlideState.active = false
    FarmState.tweening = false
    return true
end

local function trySeatPartnerOnBoat()
    refreshFarmSeats()
    if isPartnerSeatedOnFarmSeat() then
        return true
    end

    local seat = MainFarmState.partnerSeat
    local plr = MainFarmState.partner
    if not seat or not plr or not seat.Parent then
        return false
    end

    local hrp = getPartnerHRP(plr)
    if not hrp then
        return false
    end

    pcall(function()
        seat.AssemblyLinearVelocity = Vector3.zero
        seat.AssemblyAngularVelocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    local dist = (hrp.Position - seat.Position).Magnitude
    if dist <= PARTNER_SEAT_SIT_RANGE and isSeatPart(seat) then
        pcall(function()
            local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and not hum.Sit then
                seat:Sit(hum)
            end
        end)
        task.wait(0.12)
    end

    return isPartnerSeatedOnFarmSeat()
end

local function glideTowardPartner(studs)
    studs = studs or 20
    cleanupPartnerGlide()
    setFarmBoatFlyEnabled(false)

    if isPartnerSeatedOnFarmSeat() then
        return true
    end

    local flyPart = getBoatFlyPart()
    local _, hrp = getCharacter()
    local seatedOnBoat = flyPart ~= nil and isPlayerSeated()

    if seatedOnBoat then
        PartnerGlideState.active = true
        local lift = Config.PartnerLiftHeight or 50
        local startT = tick()

        flyPart = getBoatFlyPart()
        if flyPart and flyPart.Position.Y < lift + 5 then
            local liftOrigin = flyPart.Position
            setFarmStatus("Flying up (boat fly)...", "info")
            boatFlyGlideToTarget(function()
                return liftOrigin + Vector3.new(0, lift, 0)
            end, 8, 35, { breakOnPartnerSeated = true })
        end

        while MainFarmState.active and tick() - startT < 120 do
            if isPartnerSeatedOnFarmSeat() then
                break
            end

            refreshFarmSeats()
            flyPart = getBoatFlyPart()
            if not flyPart or not isPlayerSeated() then
                break
            end

            local partnerHrp = getPartnerHRP()
            local partnerSeat = MainFarmState.partnerSeat
            if not partnerHrp or not partnerSeat or not partnerSeat.Parent then
                break
            end

            local seatGap = (partnerHrp.Position - partnerSeat.Position).Magnitude
            local flatDist = Vector3.new(
                partnerHrp.Position.X - flyPart.Position.X,
                0,
                partnerHrp.Position.Z - flyPart.Position.Z
            ).Magnitude

            if seatGap > PARTNER_SEAT_SIT_RANGE then
                setFarmStatus(flatDist > 30 and "Gliding to partner..." or "Descending to partner...", "info")
                boatFlyGlideToTarget(getBoatFlyTargetForPartnerAlign, 4, 25, {
                    breakOnPartnerSeated = true,
                    untilPartnerSeated = true,
                    fastDescent = true,
                })
            else
                setFarmStatus("Pushing partner into seat...", "info")
                boatFlyGlideToTarget(getBoatFlyTargetPushIntoPartner, 2, 35, {
                    breakOnPartnerSeated = true,
                    untilPartnerSeated = true,
                    pushForward = true,
                })
            end

            trySeatPartnerOnBoat()
            gentleMovePartnerSeatToPlayer()
            task.wait(0.05)
        end

        trySeatPartnerOnBoat()
        stabilizeBoatAssembly(MainFarmState.boat)
        cleanupPartnerGlide()
        return isPartnerSeatedOnFarmSeat()
    end

    if hrp then
        PartnerGlideState.active = true
        setFarmStatus("Gliding to partner...", "info")
        glidePartTowardTarget(hrp, function()
            return getPartnerHRPTargetPos(10)
        end, 22, 40, 8)
        trySeatPartnerOnBoat()
        gentleMovePartnerSeatToPlayer()
        cleanupPartnerGlide()
        return isPartnerSeatedOnFarmSeat()
    end

    return false
end

setFarmBoatFlyEnabled = function(enabled, targetPos, options)
    options = options or {}
    if enabled then
        FarmState.savedBoatFly = Config.BoatFly
        FarmState.boatFlyTarget = targetPos
        FarmState.farmBoatFlyActive = true
        FarmState.boatFlyFastDescent = options.fastDescent == true
        FarmState.boatFlyPushForward = options.pushForward == true
        FarmState.boatFlyHoldAltitude = options.holdAltitude == true
        Config.BoatFly = true
    else
        FarmState.boatFlyTarget = nil
        FarmState.farmBoatFlyActive = false
        FarmState.boatFlyFastDescent = false
        FarmState.boatFlyPushForward = false
        FarmState.boatFlyHoldAltitude = false
        Config.BoatFly = FarmState.savedBoatFly or false
        if not Config.BoatFly then
            if BoatFlyState.bv then BoatFlyState.bv:Destroy() BoatFlyState.bv = nil end
            if BoatFlyState.bg then BoatFlyState.bg:Destroy() BoatFlyState.bg = nil end
        end
    end
end

local function boatFlyTowardPartnerSeat(timeout)
    return boatFlyGlideToTarget(function()
        return getBoatFlyTargetForPartnerAlign()
    end, PARTNER_SEAT_TOUCH_DIST, timeout or 45, { partnerSeatStop = true })
end

local function boatFlyToFarmStart()
    if not MainFarmState.active or not isPlayerSeated() then
        return false
    end
    setFarmStatus("Flying to farm start...", "info")
    return boatFlyGlideToTarget(function()
        return getFarmStageStartPos(1)
    end, 8, 90, { breakOnPartnerSeated = false })
end

local function boatFlyTowardPartner(timeout, stopDistance)
    stopDistance = stopDistance or 10
    return boatFlyGlideToTarget(function()
        return getPartnerHRPTargetPos(10)
    end, stopDistance, timeout or 45)
end

local function waitForPartnerAtSeatPosition(stableSeconds, timeout)
    stableSeconds = stableSeconds or 0.5
    timeout = timeout or 45
    local startT = tick()
    local stableStart = nil

    setFarmStatus("Waiting for partner at their seat...", "info")

    while MainFarmState.active and tick() - startT < timeout do
        refreshFarmSeats()

        if isPartnerAtPartnerSeatPosition() then
            if not stableStart then
                stableStart = tick()
            elseif tick() - stableStart >= stableSeconds then
                cleanupPartnerGlide()
                setFarmBoatFlyEnabled(false)
                return true
            end
        else
            stableStart = nil
            if MainFarmState.partnerSeat and MainFarmState.partner
                and not isPartnerSeatedOnFarmSeat()
                and not PartnerGlideState.active then
                gentleMovePartnerSeatToPlayer(MainFarmState.partnerSeat, MainFarmState.partner)
            end
        end

        task.wait(0.05)
    end

    cleanupPartnerGlide()
    setFarmBoatFlyEnabled(false)
    return isPartnerAtPartnerSeatPosition()
end

local function cleanupSeatGlide()
    GlideState.active = false
    if GlideState.bv then GlideState.bv:Destroy() GlideState.bv = nil end
    if GlideState.bg then GlideState.bg:Destroy() GlideState.bg = nil end
    local _, _, hum = getCharacter()
    if hum then
        pcall(function()
            hum.PlatformStand = false
        end)
    end
end

local function glideToSeat(seat, speed, timeout)
    speed = speed or 55
    timeout = timeout or 12
    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum or not seat or not seat.Parent then
        return false
    end

    cleanupSeatGlide()

    local savedNoClip = Config.NoClip
    Config.NoClip = true
    setCharacterCollisions(char, false)

    pcall(function()
        hum.Sit = false
        hum.PlatformStand = true
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 0, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    GlideState.bv = bv
    GlideState.active = true

    local startY = hrp.Position.Y
    local startT = tick()
    local reached = false

    while GlideState.active and tick() - startT < timeout do
        if not MainFarmState.active then
            break
        end
        if isYouSeatedOnFarmSeat() or isPlayerInSeat(Player, seat) then
            reached = true
            break
        end

        local _, currentHrp, currentHum = getCharacter()
        if not currentHrp or not seat.Parent then
            break
        end
        if currentHum then
            setCharacterCollisions(currentHum.Parent, false)
        end

        local targetPos = (seat.CFrame * CFrame.new(0, 2, 0)).Position
        local flatTarget = Vector3.new(targetPos.X, startY, targetPos.Z)
        local flatCurrent = Vector3.new(currentHrp.Position.X, startY, currentHrp.Position.Z)
        local flatDelta = flatTarget - flatCurrent
        local dist = flatDelta.Magnitude

        if dist < 2.5 then
            reached = true
            break
        end

        local glideVel = flatDelta.Unit * math.min(speed, math.max(dist * 2, 10))
        bv.Velocity = glideVel
        pcall(function()
            currentHrp.AssemblyAngularVelocity = Vector3.zero
            currentHrp.AssemblyLinearVelocity = Vector3.new(glideVel.X, 0, glideVel.Z)
        end)
        RunService.Heartbeat:Wait()
    end

    pcall(function()
        bv.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    cleanupSeatGlide()

    char, _, _ = getCharacter()
    Config.NoClip = savedNoClip
    setCharacterCollisions(char, not savedNoClip)

    return reached
end

local function alignPartnerIntoSeat()
    refreshFarmSeats()
    if isPartnerSeatedOnFarmSeat() then
        return true
    end

    if PartnerGlideState.active then
        return false
    end

    return gentleMovePartnerSeatToPlayer()
end

local function glideSelfToYourSeat()
    refreshFarmSeats()
    if isYouSeatedOnFarmSeat() or isPlayerInSeat(Player, MainFarmState.yourSeat) then
        return true
    end

    local seat = MainFarmState.yourSeat
    if not seat or not seat.Parent then
        return false
    end
    if isPlayerOnPlot() then
        if not isSeatAtSavedMark(seat, MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos) then
            return false
        end
    elseif not isSeatOnPlayerPlot(seat) and not isBoatAwayFromPlot() then
        return false
    end

    setFarmStatus("Gliding to your seat...", "info")
    glideToSeat(seat, 55, 12)

    local char, hrp, hum = getCharacter()
    if hum and hrp and isSeatPart(seat) then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
        end)
        task.wait(0.1)
        pcall(function()
            seat:Sit(hum)
        end)
    end
    task.wait(0.08)
    return isYouSeatedOnFarmSeat() or isPlayerInSeat(Player, seat)
end

local function approachPartnerAfterLaunch()
    refreshFarmSeats()

    if isPartnerSeatedOnFarmSeat() then
        if MainFarmState.active and isPlayerSeated() then
            boatFlyToFarmStart()
        end
        return true
    end

    setFarmStatus("Gliding toward partner until seated...", "info")
    local startT = tick()
    while MainFarmState.active and tick() - startT < 120 do
        if isPartnerSeatedOnFarmSeat() then
            break
        end
        glideTowardPartner(20)
        trySeatPartnerOnBoat()
        alignPartnerIntoSeat()
        task.wait(0.1)
    end
    cleanupPartnerGlide()

    if isPartnerSeatedOnFarmSeat() and MainFarmState.active and isPlayerSeated() then
        boatFlyToFarmStart()
    end

    return isPartnerSeatedOnFarmSeat()
end

local function approachPartnerViaBoatFly()
    return approachPartnerAfterLaunch()
end

local function gentleSitSelfOnYourSeat()
    return glideSelfToYourSeat()
end

local function sitSelfOnYourSeat()
    return gentleSitSelfOnYourSeat()
end

local function forceTeleportToYourSeat()
    return gentleSitSelfOnYourSeat()
end

local function forceTeleportLocalPlayerToPartner()
    setFarmStatus("Force teleporting to partner...", "info")

    for _ = 1, 8 do
        if not MainFarmState.active then return false end
        refreshFarmSeats()
        upgradeFarmSeatsToLaunched()
        local targetCF = getForceTeleportTarget()
        if not targetCF then
            return false
        end
        forceTeleportTo(targetCF)
        task.wait(0.15)
    end

    return true
end

local function teleportLocalPlayerToPartner()
    return forceTeleportLocalPlayerToPartner()
end

local function teleportLocalPlayerToBoat()
    return teleportLocalPlayerToPartner()
end

local function seatPartnerOnPlot()
    if not MainFarmState.partnerSeat or not MainFarmState.partner then
        return false
    end
    forcePartnerSeatToPlayer(MainFarmState.partnerSeat, MainFarmState.partner)
    return isPlayerInSeat(MainFarmState.partner, MainFarmState.partnerSeat)
end

sitPlayerOnSeat = function(seat, plr)
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not seat or not hrp or not hum then return false end

    if isPlayerInSeat(plr, seat) then
        return true
    end

    pcall(function()
        seat.Anchored = false
        hum.PlatformStand = false
        hum.Sit = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    task.wait(0.08)

    pcall(function()
        hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 0)
    end)
    task.wait(0.08)

    pcall(function()
        if isSeatPart(seat) then
            seat:Sit(hum)
        end
    end)

    return isPlayerInSeat(plr, seat)
end

local function waitForYouSeated(timeout)
    timeout = timeout or 20
    local t = tick()
    while MainFarmState.active and tick() - t < timeout do
        refreshFarmSeats()
        if isPlayerInSeat(Player, MainFarmState.yourSeat) then
            return true
        end
        if MainFarmState.yourSeat and not isYouSeatedOnFarmSeat() then
            gentleSitSelfOnYourSeat()
        end
        task.wait(0.35)
    end
    return isPlayerInSeat(Player, MainFarmState.yourSeat)
end

local function seatPartnerAfterLaunch()
    return approachPartnerAfterLaunch()
end

local function seatFarmPlayersOnBoat()
    return seatPartnerAfterLaunch()
end

local function getBoatFromSeat(seat)
    if not seat then return nil end
    local model = seat:FindFirstAncestorWhichIsA("Model")
    if model and model.Parent then return model end
    return seat.Parent
end

local function isPlayerNearZone(plr, radius)
    radius = radius or 90
    local zone = getPlayerZone(plr)
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not zone or not hrp then return false end
    local zonePart = zone:IsA("BasePart") and zone or zone:FindFirstChildWhichIsA("BasePart", true)
    if not zonePart then return false end
    return (hrp.Position - zonePart.Position).Magnitude <= radius
end

boatPivotTo = function(boat, cf)
    if not cf then return end
    local refCF = getBoatReferenceCF()
    local delta = cf * refCF:Inverse()
    if MainFarmState.boat and not MainFarmState.boat:IsA("Folder") then
        local ok = pcall(function()
            MainFarmState.boat:PivotTo(cf)
        end)
        if ok then return end
    end
    moveBoatPartsByDelta(delta)
end

local function tweenBoatTo(boat, targetCF, duration)
    if not targetCF then return false end
    duration = duration or Config.FarmTweenTime
    local startCF = getBoatReferenceCF()
    FarmState.tweening = true
    local elapsed = 0
    while elapsed < duration do
        if not MainFarmState.active and not Config.AutoFarm then break end
        local dt = RunService.Heartbeat:Wait()
        elapsed += dt
        local alpha = math.clamp(elapsed / duration, 0, 1)
        boatPivotTo(boat, startCF:Lerp(targetCF, alpha))
    end
    boatPivotTo(boat, targetCF)
    FarmState.tweening = false
    return true
end

local function getBoatChestCFrame(chest, boat, yourSeat, partnerSeat)
    local chestPos = chest:GetPivot().Position
    local yourPos = yourSeat.Position
    local partnerPos = partnerSeat.Position
    local lead = yourPos - partnerPos
    if lead.Magnitude < 0.5 then
        lead = chestPos - yourPos
    end
    lead = Vector3.new(lead.X, 0, lead.Z)
    if lead.Magnitude < 0.1 then
        lead = Vector3.new(0, 0, -1)
    else
        lead = lead.Unit
    end
    local targetYour = chestPos - lead * 8
    local lookCF = CFrame.lookAt(targetYour, chestPos)
    local refCF = getBoatReferenceCF()
    local yourLocal = refCF:ToObjectSpace(yourSeat.CFrame)
    return lookCF * yourLocal:Inverse()
end

local function horizDistXZ(a, b)
    return (Vector3.new(a.X - b.X, 0, a.Z - b.Z)).Magnitude
end

local function getPartnerSeatOffset(yourSeat, partnerSeat)
    return yourSeat.CFrame:ToObjectSpace(partnerSeat.CFrame)
end

local function seatWorldPos(yourCF, partnerOffset)
    return (yourCF * partnerOffset).Position
end

local function findBestPartnerFirstYourCF(flatCenter, partnerOffset, partnerSeatY, minUserLead)
    minUserLead = minUserLead or 2
    local bestYourCF, bestScore = nil, math.huge
    for i = 0, 31 do
        local yaw = math.rad(i * 11.25)
        local partnerCF = CFrame.new(flatCenter.X, partnerSeatY, flatCenter.Z) * CFrame.Angles(0, yaw, 0)
        local yourCF = partnerCF * partnerOffset:Inverse()
        local partnerPos = seatWorldPos(yourCF, partnerOffset)
        local partnerDist = horizDistXZ(partnerPos, flatCenter)
        local yourDist = horizDistXZ(yourCF.Position, flatCenter)
        if yourDist >= partnerDist + minUserLead and partnerDist < bestScore then
            bestScore = partnerDist
            bestYourCF = yourCF
        end
    end
    return bestYourCF, bestScore
end

local function getBoatChestCFramePartnerFirst(chest, yourSeat, partnerSeat)
    local _, lidY, flatCenter = getGoldenChestTouchPoint(chest)
    local partnerOffset = getPartnerSeatOffset(yourSeat, partnerSeat)
    local hoverY = math.max(yourSeat.Position.Y, partnerSeat.Position.Y, lidY + 18)
    local bestYourCF = findBestPartnerFirstYourCF(flatCenter, partnerOffset, hoverY, 2)
    if bestYourCF then
        return bestYourCF
    end
    local partnerCF = CFrame.new(flatCenter.X, hoverY, flatCenter.Z)
    return partnerCF * partnerOffset:Inverse()
end

local function getBoatChestDropCFrame(chest, yourSeat, partnerSeat)
    local _, lidY, flatCenter = getGoldenChestTouchPoint(chest)
    local partnerOffset = getPartnerSeatOffset(yourSeat, partnerSeat)
    local dropSeatY = lidY + 1.5
    local bestYourCF = findBestPartnerFirstYourCF(flatCenter, partnerOffset, dropSeatY, 2)
    if bestYourCF then
        return bestYourCF
    end
    local partnerCF = CFrame.new(flatCenter.X, dropSeatY, flatCenter.Z)
    return partnerCF * partnerOffset:Inverse()
end

local function getChestSideGlidePosition(chest, yourSeat, partnerSeat)
    local _, lidY, flatCenter = getGoldenChestTouchPoint(chest)
    local chestCF = getBoatChestCFramePartnerFirst(chest, yourSeat, partnerSeat)
    local partnerOffset = getPartnerSeatOffset(yourSeat, partnerSeat)
    local yourTarget = chestCF.Position
    local partnerTarget = seatWorldPos(chestCF, partnerOffset)

    local tailDir = yourTarget - partnerTarget
    tailDir = Vector3.new(tailDir.X, 0, tailDir.Z)
    if tailDir.Magnitude < 1 then
        tailDir = yourTarget - flatCenter
        tailDir = Vector3.new(tailDir.X, 0, tailDir.Z)
    end
    if tailDir.Magnitude < 0.5 then
        tailDir = Vector3.new(0, 0, 40)
    else
        tailDir = tailDir.Unit * 42
    end

    local lateral = tailDir:Cross(Vector3.new(0, 1, 0))
    if lateral.Magnitude < 0.5 then
        lateral = Vector3.new(26, 0, 0)
    else
        lateral = lateral.Unit * 26
    end

    local height = math.max(yourSeat.Position.Y, partnerSeat.Position.Y, lidY + 20)
    return Vector3.new(flatCenter.X, height, flatCenter.Z) + tailDir + lateral
end

local function getChestLateralVector(chest, yourSeat, partnerSeat, targetCF)
    targetCF = targetCF or getBoatChestCFramePartnerFirst(chest, yourSeat, partnerSeat)
    local _, _, flatCenter = getGoldenChestTouchPoint(chest)
    local partnerOffset = getPartnerSeatOffset(yourSeat, partnerSeat)
    local yourPos = targetCF.Position
    local partnerPos = seatWorldPos(targetCF, partnerOffset)
    local away = yourPos - partnerPos
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 0.5 then
        away = yourPos - flatCenter
        away = Vector3.new(away.X, 0, away.Z)
    end
    if away.Magnitude < 0.1 then
        return Vector3.new(1, 0, 0)
    end
    return away.Unit
end

local function snapPartnerOntoGoldenChest(chest, yourSeat, partnerSeat)
    refreshFarmSeats()
    yourSeat = MainFarmState.yourSeat or yourSeat
    partnerSeat = MainFarmState.partnerSeat or partnerSeat
    local boat = MainFarmState.boat
    if not chest or not yourSeat or not partnerSeat or not boat then
        return false
    end

    local touchPoint, _, flatCenter = getGoldenChestTouchPoint(chest)
    local dropCF = getBoatChestDropCFrame(chest, yourSeat, partnerSeat)
    boatPivotTo(boat, dropCF)
    task.wait(0.08)

    local touchPart = chest:IsA("BasePart") and chest or chest:FindFirstChildWhichIsA("BasePart", true)
    local phrp = getPartnerHRP()
    if phrp then
        pcall(function()
            phrp.CFrame = CFrame.new(touchPoint)
            phrp.AssemblyLinearVelocity = Vector3.zero
            phrp.AssemblyAngularVelocity = Vector3.zero
        end)
        if touchPart then
            fireTouchInterest(touchPart, phrp)
            fireTouchInterest(phrp, touchPart)
        end
    end

    if partnerSeat and partnerSeat.Parent then
        pcall(function()
            local seatTarget = Vector3.new(flatCenter.X, partnerSeat.Position.Y, flatCenter.Z)
            local delta = seatTarget - partnerSeat.Position
            if delta.Magnitude > 0.5 then
                moveBoatPartsByDelta(CFrame.new(delta))
            end
        end)
    end

    return true
end

local function startChestFloatHold(chest, yourSeat, partnerSeat)
    local _, hrp, hum = getCharacter()
    if not hrp or not hum then return end

    for _ = 1, 10 do
        pcall(function()
            hum.Sit = false
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
        end)
        if not hum.Sit then break end
        task.wait(0.03)
    end

    local partnerSeatPos = MainFarmState.partnerSeat and MainFarmState.partnerSeat.Position
    local _, _, flatCenter = getGoldenChestTouchPoint(chest)
    local away = hrp.Position - (partnerSeatPos or flatCenter or hrp.Position)
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 0.5 and flatCenter then
        away = hrp.Position - flatCenter
        away = Vector3.new(away.X, 0, away.Z)
    end
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    else
        away = away.Unit
    end

    local floatPos = hrp.Position + Vector3.new(0, 24, 0) + away * 16

    FarmState.chestHoldActive = true
    FarmState.chestHoldPos = floatPos
    FarmState.chestPushActive = false
    Config.Fly = true
    Config.NoClip = true
    setFlyEnabled(true)
    ensureChestPushFlyPhysics(hrp, hum)

    pcall(function()
        hrp.CFrame = CFrame.new(floatPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function stopChestFloatHold()
    FarmState.chestHoldActive = false
    FarmState.chestHoldPos = nil
end

local function waitForPartnerSeated(timeout)
    timeout = timeout or 20
    local t = tick()
    while MainFarmState.active and tick() - t < timeout do
        refreshFarmSeats()
        if isPlayerInSeat(MainFarmState.partner, MainFarmState.partnerSeat) then
            return true
        end
        if MainFarmState.partnerSeat and MainFarmState.partner then
            seatPartnerOnPlot()
        end
        task.wait(0.35)
    end
    return isPlayerInSeat(MainFarmState.partner, MainFarmState.partnerSeat)
end

local function waitForYouLeaveChest(chest)
    local chestPos = chest:GetPivot().Position
    local mainPlr = Player
    while MainFarmState.active do
        local hrp = mainPlr.Character and mainPlr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - chestPos).Magnitude > 120 then
            return
        end
        if hrp and (hrp.Position - chestPos).Magnitude <= 120 then
            if isPlayerNearZone(mainPlr, 100) then
                return
            end
        end
        task.wait(1)
    end
end

local function ensureChestPushFlyPhysics(hrp, hum)
    if not hrp then return end
    if not FlyState.bv or FlyState.bv.Parent ~= hrp then
        if FlyState.bv then FlyState.bv:Destroy() end
        FlyState.bv = Instance.new("BodyVelocity")
        FlyState.bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        FlyState.bv.Velocity = Vector3.zero
        FlyState.bv.Parent = hrp
    end
    if hum then
        hum.PlatformStand = true
    end
end

local getFarmMovePart
local getHorizontalSpeed
local runBoatFarmStep

;(function()
getFarmMovePart = function()
    local flyPart = getBoatFlyPart()
    if flyPart then return flyPart end
    if MainFarmState.boat and MainFarmState.boat.Parent then
        local root = getBoatPrimaryPart(MainFarmState.boat)
        if root then return root end
    end
    local _, hrp = getCharacter()
    return hrp
end

getHorizontalSpeed = function(part)
    if not part then return 0 end
    local speed = 0
    pcall(function()
        local v = part.AssemblyLinearVelocity
        speed = Vector3.new(v.X, 0, v.Z).Magnitude
        local v2 = part.Velocity
        local h2 = Vector3.new(v2.X, 0, v2.Z).Magnitude
        if h2 > speed then
            speed = h2
        end
    end)
    return speed
end

local function waitUntilFarmRunForwardStop(timeout, relaxed)
    timeout = timeout or 30
    local wasMoving = MainFarmState.farmHadForwardMotion == true
    local stoppedSince = nil
    local startT = tick()

    while MainFarmState.active and tick() - startT < timeout do
        local hSpeed = getHorizontalSpeed(getFarmMovePart())

        if hSpeed > 6 then
            wasMoving = true
            MainFarmState.farmHadForwardMotion = true
            stoppedSince = nil
        elseif wasMoving or relaxed then
            if hSpeed <= 5 then
                if not stoppedSince then
                    stoppedSince = tick()
                elseif tick() - stoppedSince >= (relaxed and 0.15 or 0.25) then
                    return true
                end
            else
                stoppedSince = nil
            end
        end
        task.wait(0.05)
    end

    return wasMoving or relaxed
end

local function isNearGoldenChest(chest, maxDist)
    if not chest then return false end
    maxDist = maxDist or 200
    local chestPos = chest:GetPivot().Position
    local partnerHrp = getPartnerHRP()
    local _, myHrp = getCharacter()
    if partnerHrp and (partnerHrp.Position - chestPos).Magnitude <= maxDist then
        return true
    end
    if myHrp and (myHrp.Position - chestPos).Magnitude <= maxDist then
        return true
    end
    local flyPart = getBoatFlyPart()
    if flyPart and (flyPart.Position - chestPos).Magnitude <= maxDist then
        return true
    end
    if MainFarmState.boat and MainFarmState.boat.Parent then
        local root = getBoatPrimaryPart(MainFarmState.boat)
        if root and (root.Position - chestPos).Magnitude <= maxDist then
            return true
        end
    end
    return false
end

local function waitUntilFarmEndReached(chest, timeout)
    timeout = timeout or 45
    local startT = tick()
    while MainFarmState.active and tick() - startT < timeout do
        if isNearGoldenChest(chest, 220) then
            return true
        end
        task.wait(0.08)
    end
    return isNearGoldenChest(chest, 500)
end

local function waitForChestPushReady(chest, timeout)
    timeout = timeout or 35
    local chestPos = chest:GetPivot().Position
    local startT = tick()
    while MainFarmState.active and tick() - startT < timeout do
        local partnerHrp = getPartnerHRP()
        local _, myHrp = getCharacter()
        local boatGone = not MainFarmState.boat or not MainFarmState.boat.Parent
        if partnerHrp and myHrp and not isPlayerSeated() then
            local partnerDist = (partnerHrp.Position - chestPos).Magnitude
            if partnerDist < 160 and (boatGone or not isPartnerSeatedOnFarmSeat()) then
                return true
            end
        end
        task.wait(0.2)
    end
    return getPartnerHRP() ~= nil and not isPlayerSeated()
end

setCharacterCollisions = function(char, canCollide)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = canCollide
        end
    end
end

;(function()
local function expandFlingSimulation()
    pcall(function()
        setsimulationradius(2e19, 2e19)
        sethiddenproperty(Player, "SimulationRadius", 2e19)
        sethiddenproperty(Player, "MaxSimulationRadius", 2e19)
    end)
end

local function setFlingCharacterCFrame(character, rootPart, cf)
    if not rootPart or not cf then return end
    pcall(function()
        if character and not character.PrimaryPart then
            character.PrimaryPart = rootPart
        end
        if character then
            character:SetPrimaryPartCFrame(cf)
        else
            rootPart.CFrame = cf
        end
    end)
    pcall(function()
        rootPart.CFrame = cf
    end)
end

local function applySkidFlingVelocity(rootPart)
    if not rootPart then return end
    local vel = Vector3.new(9e7, 9e7 * 10, 9e7)
    local rotVel = Vector3.new(9e8, 9e8, 9e8)
    pcall(function()
        rootPart.Velocity = vel
        rootPart.RotVelocity = rotVel
        rootPart.AssemblyLinearVelocity = vel
        rootPart.AssemblyAngularVelocity = rotVel
    end)
end

local function getPartSpeed(part)
    if not part then return 0 end
    local speed = 0
    pcall(function()
        speed = part.AssemblyLinearVelocity.Magnitude
        if part.Velocity.Magnitude > speed then
            speed = part.Velocity.Magnitude
        end
    end)
    return speed
end

local function targetWasFlinged(targetCharacter, targetRoot)
    if not targetCharacter then return false end
    if targetRoot and getPartSpeed(targetRoot) > 500 then
        return true
    end
    local head = targetCharacter:FindFirstChild("Head")
    return head ~= nil and getPartSpeed(head) > 500
end

local function skidFlingOscillate(rootPart, character, basePart, targetHumanoid, angle)
    local moveDir = targetHumanoid and targetHumanoid.MoveDirection or Vector3.zero
    local targetSpeed = getPartSpeed(basePart)

    local function fpos(pos, ang)
        local cf = CFrame.new(basePart.Position) * pos * ang
        setFlingCharacterCFrame(character, rootPart, cf)
        applySkidFlingVelocity(rootPart)
    end

    fpos(CFrame.new(0, 1.5, 0) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, 0) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(2.25, 1.5, -2.25) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(-2.25, -1.5, 2.25) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
end

local function skidFlingSpin(rootPart, character, basePart, targetHumanoid, targetRoot)
    local walkSpeed = targetHumanoid and targetHumanoid.WalkSpeed or 16
    local targetSpeed = getPartSpeed(targetRoot or basePart)

    local function fpos(pos, ang)
        local cf = CFrame.new(basePart.Position) * pos * ang
        setFlingCharacterCFrame(character, rootPart, cf)
        applySkidFlingVelocity(rootPart)
    end

    fpos(CFrame.new(0, 1.5, walkSpeed), CFrame.Angles(math.rad(90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, -walkSpeed), CFrame.Angles(0, 0, 0))
    task.wait()
    fpos(CFrame.new(0, 1.5, targetSpeed / 1.25), CFrame.Angles(math.rad(90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, -targetSpeed / 1.25), CFrame.Angles(0, 0, 0))
    task.wait()
end

local function runSkidFlingOnPart(rootPart, character, humanoid, targetPlayer, targetCharacter, targetHumanoid, basePart, timeLimit)
    local angle = 0
    local started = tick()
    local targetRoot = targetHumanoid and targetHumanoid.RootPart

    repeat
        if not rootPart.Parent or not basePart.Parent or humanoid.Health <= 0 then
            break
        end
        if targetHumanoid and targetHumanoid.Sit then
            break
        end

        angle += 100
        if getPartSpeed(basePart) < 50 then
            skidFlingOscillate(rootPart, character, basePart, targetHumanoid, angle)
        else
            skidFlingSpin(rootPart, character, basePart, targetHumanoid, targetRoot)
        end
    until targetWasFlinged(targetCharacter, targetRoot)
        or basePart.Parent ~= targetCharacter
        or targetPlayer.Parent ~= Players
        or targetPlayer.Character ~= targetCharacter
        or (targetHumanoid and targetHumanoid.Sit)
        or humanoid.Health <= 0
        or tick() > started + timeLimit
end

local function skidFlingPartnerPlayer(targetPlayer)
    if MainFarmState.flingInProgress or not targetPlayer or targetPlayer == Player then
        return false
    end

    local character = Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = humanoid and humanoid.RootPart
    local targetCharacter = targetPlayer.Character
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetHumanoid and targetHumanoid.RootPart
    local targetHead = targetCharacter and targetCharacter:FindFirstChild("Head")

    if not character or not humanoid or not rootPart then
        return false
    end
    if not targetCharacter or not targetHumanoid or not targetRoot then
        return false
    end
    if not targetCharacter:FindFirstChildWhichIsA("BasePart") then
        return false
    end

    MainFarmState.flingInProgress = true
    expandFlingSimulation()

    local savedFly = Config.Fly
    local savedNoClip = Config.NoClip
    local savedBoatFly = Config.BoatFly
    Config.Fly = false
    Config.BoatFly = false
    Config.NoClip = false

    pcall(function()
        humanoid.Sit = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        humanoid.PlatformStand = false
    end)
    setCharacterCollisions(character, true)
    pcall(function()
        sethiddenproperty(targetRoot, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
    end)

    local savedFPDH = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0 / 0

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "NightFallFlingBV"
    bodyVelocity.Parent = rootPart
    bodyVelocity.Velocity = Vector3.new(9e8, 9e8, 9e8)
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    local flingPart = targetRoot
    if targetHead and (targetRoot.Position - targetHead.Position).Magnitude > 5 then
        flingPart = targetHead
    end

    local flung = false
    pcall(function()
        runSkidFlingOnPart(
            rootPart,
            character,
            humanoid,
            targetPlayer,
            targetCharacter,
            targetHumanoid,
            flingPart,
            2.5
        )
        flung = targetWasFlinged(targetCharacter, targetRoot)
    end)

    bodyVelocity:Destroy()
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    end)
    workspace.FallenPartsDestroyHeight = savedFPDH

    Config.Fly = savedFly
    Config.NoClip = savedNoClip
    Config.BoatFly = savedBoatFly
    MainFarmState.flingInProgress = false
    return flung
end

local function waitUntilGoldenChestRange(chest, radius, timeout)
    radius = radius or 200
    timeout = timeout or 40
    local startT = tick()
    while tick() - startT < timeout do
        if isNearGoldenChest(chest, radius) then
            return true
        end
        task.wait(0.08)
    end
    return isNearGoldenChest(chest, radius)
end

local function orientBoatPartnerTowardChest(chest)
    if not chest or not MainFarmState.partner then
        return false
    end

    setFarmStatus("Waiting until within 200 studs of chest...", "info")
    if not waitUntilGoldenChestRange(chest, 200, 45) then
        setFarmStatus("Not within 200 studs of golden chest", "error")
        return false
    end

    refreshFarmSeats()
    local boat = MainFarmState.boat
    local yourSeat = MainFarmState.yourSeat
    local partnerSeat = MainFarmState.partnerSeat
    if not boat or not yourSeat or not partnerSeat then
        return false
    end

    setFarmBoatFlyEnabled(false)
    setFarmStatus("Aligning partner seat to chest...", "info")

    boatFlyGlidePartnerSeatToChest(chest, {
        stopDist = PARTNER_SEAT_TOUCH_DIST,
        timeout = 45,
        fastDescent = true,
        pushForward = true,
    })

    setFarmStatus("Floating — partner will claim chest...", "info")
    startChestFloatHold(chest, yourSeat, partnerSeat)

    boatFlyGlidePartnerSeatToChest(chest, {
        stopDist = 1.5,
        timeout = 20,
        fastDescent = true,
        pushForward = true,
    })

    waitForGainedGoldPopup(20)
    autoClickClaimGold(chest)
    task.wait(0.1)
    autoClickClaimGold(chest)

    setFarmStatus("Partner claiming chest — resetting in 3s...", "info")
    task.wait(3)

    stopChestFloatHold()
    setFlyEnabled(false)
    Config.NoClip = false

    pcall(function()
        Player:LoadCharacter()
    end)

    setFarmStatus("Round complete — resetting...", "info")
    return true
end

pushPartnerIntoGoldenChest = orientBoatPartnerTowardChest
end)()

local function waitForBoatChestReward(chest)
    if waitForGainedGoldPopup() then
        setFarmStatus("Golden chest opened", "success")
        task.wait(math.clamp(Config.ChestWait or 10, 2, 30))
        return
    end

    local chestPos = chest:GetPivot().Position
    local waited = 0
    while MainFarmState.active do
        task.wait(1)
        waited += 1
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then break end
        if waited % 20 == 0 and MainFarmState.boat then
            local cf = getBoatChestCFrame(chest, MainFarmState.boat, MainFarmState.yourSeat, MainFarmState.partnerSeat)
            boatPivotTo(MainFarmState.boat, cf)
        end
        if (hrp.Position - chestPos).Magnitude > 500 then
            break
        end
    end
end

runBoatFarmStep = function()
    local boat = MainFarmState.boat
    local yourSeat = MainFarmState.yourSeat
    local partnerSeat = MainFarmState.partnerSeat
    if not boat or not yourSeat or not partnerSeat then return end

    local normalStages = getNormalStages()
    if not normalStages then return end

    if MainFarmState.stage >= CHEST_STAGE then
        MainFarmState.stage = 1
        local endpoint = normalStages:FindFirstChild("TheEnd")
        local chest = endpoint and endpoint:FindFirstChild("GoldenChest")
        if chest then
            local originalChar = Player.Character
            local chestDeadline = tick() + 10
            local function chestTimedOut()
                return tick() > chestDeadline
                    or Player.Character ~= originalChar
                    or not Player.Character
            end

            refreshFarmSeats()
            yourSeat = MainFarmState.yourSeat or yourSeat
            partnerSeat = MainFarmState.partnerSeat or partnerSeat
            boat = MainFarmState.boat or boat

            if not chestTimedOut() then
                if isPlayerSeated() and boat and boat.Parent then
                    setFarmStatus("Gliding — aligning partner seat to chest...", "info")
                    task.wait(0.1)
                    boatFlyGlidePartnerSeatToChest(chest, {
                        sideApproach = true,
                        holdAltitude = true,
                        stopDist = PARTNER_SEAT_TOUCH_DIST,
                        timeout = math.min(70, chestDeadline - tick()),
                        fastDescent = false,
                    })
                    if not chestTimedOut() then
                        boatFlyGlidePartnerSeatToChest(chest, {
                            stopDist = PARTNER_SEAT_TOUCH_DIST,
                            timeout = math.min(50, chestDeadline - tick()),
                            fastDescent = true,
                            pushForward = true,
                        })
                    end
                elseif boat and boat.Parent then
                    boatFlyGlidePartnerSeatToChest(chest, {
                        stopDist = PARTNER_SEAT_TOUCH_DIST,
                        timeout = math.min(50, chestDeadline - tick()),
                        fastDescent = true,
                    })
                end
            end

            if not chestTimedOut() then
                setFarmBoatFlyEnabled(false)
                waitUntilFarmRunForwardStop(6, true)
                refreshFarmSeats()
                MainFarmState.boat = getBoatRoot(MainFarmState.yourSeat)
                    or getBoatRoot(MainFarmState.partnerSeat)
                pushPartnerIntoGoldenChest(chest)
            end
        end
        MainFarmState.pendingRoundRestart = true
        MainFarmState.active = false
        MainFarmState.running = false
        task.spawn(restartBoatFarmAfterRound)
        return
    end

    local stage = normalStages:FindFirstChild("CaveStage" .. MainFarmState.stage)
    local darkPart = stage and stage:FindFirstChild("DarknessPart")
    if not darkPart then return end

    local approachPos = (darkPart.CFrame - Vector3.new(0, 0, 15)).Position
    local endPos = (darkPart.CFrame + Vector3.new(0, 0, 20)).Position

    if isPlayerSeated() then
        setFarmStatus("Flying to stage " .. MainFarmState.stage .. "...", "info")
        boatFlyGlideToTarget(function()
            return approachPos
        end, 10, 50, { breakOnPartnerSeated = false })
        boatFlyGlideToTarget(function()
            return endPos
        end, 10, 50, { breakOnPartnerSeated = false })
    else
        boatPivotTo(boat, darkPart.CFrame - Vector3.new(0, 0, 15))
        tweenBoatTo(boat, darkPart.CFrame + Vector3.new(0, 0, 20), Config.FarmTweenTime)
    end
    MainFarmState.stage += 1
end
end)()

;(function()
    local FarmDeathWatch = {
        localConn = nil,
        partnerConn = nil,
        partnerHealthConn = nil,
        partnerCharConn = nil,
        partnerCharRemovingConn = nil,
        partnerSeatConn = nil,
        localCharConn = nil,
        partnerMonitorConn = nil,
        partnerMissingSince = nil,
        lastPartnerCheck = 0,
        lastDeathTrigger = 0,
        partnerWasSeated = false,
        partnerAtSpawnSince = nil,
        whiteSpawnCache = nil,
        whiteSpawnCacheTime = 0,
    }

    local PARTNER_DEATH_DEBOUNCE = 0.35
    local PARTNER_MISSING_TIMEOUT = 0.55
    local PARTNER_MONITOR_INTERVAL = 0.12
    local WHITE_SPAWN_RADIUS = 16
    local WHITE_SPAWN_CONFIRM = 0.4

    local function getWhiteTeamSpawnPositions()
        if FarmDeathWatch.whiteSpawnCache and tick() - FarmDeathWatch.whiteSpawnCacheTime < 30 then
            return FarmDeathWatch.whiteSpawnCache
        end

        local positions = {}
        local whiteTeam = workspace:FindFirstChild("WhiteTeam")
        local spawnsFolder = whiteTeam and whiteTeam:FindFirstChild("Spawns")
        if spawnsFolder then
            for _, child in ipairs(spawnsFolder:GetChildren()) do
                if child:IsA("BasePart") then
                    table.insert(positions, child.Position)
                end
            end
            if #positions == 0 then
                for _, desc in ipairs(spawnsFolder:GetDescendants()) do
                    if desc:IsA("SpawnLocation") or desc:IsA("BasePart") then
                        table.insert(positions, desc.Position)
                    end
                end
            end
        end

        FarmDeathWatch.whiteSpawnCache = positions
        FarmDeathWatch.whiteSpawnCacheTime = tick()
        return positions
    end

    local function isNearWhiteTeamSpawn(position)
        local spawns = getWhiteTeamSpawnPositions()
        if #spawns == 0 then return false end
        local flatPos = Vector3.new(position.X, 0, position.Z)
        for _, spawnPos in ipairs(spawns) do
            local flatSpawn = Vector3.new(spawnPos.X, 0, spawnPos.Z)
            if (flatPos - flatSpawn).Magnitude <= WHITE_SPAWN_RADIUS then
                return true
            end
        end
        return false
    end

    local function isPartnerAtWhiteTeamSpawn(partner)
        if not partner or partner.Parent ~= Players then return false end
        local char = partner.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        return isNearWhiteTeamSpawn(hrp.Position)
    end

    local function disconnectPartnerDeath()
        if FarmDeathWatch.partnerConn then
            FarmDeathWatch.partnerConn:Disconnect()
            FarmDeathWatch.partnerConn = nil
        end
        if FarmDeathWatch.partnerHealthConn then
            FarmDeathWatch.partnerHealthConn:Disconnect()
            FarmDeathWatch.partnerHealthConn = nil
        end
        if FarmDeathWatch.partnerCharConn then
            FarmDeathWatch.partnerCharConn:Disconnect()
            FarmDeathWatch.partnerCharConn = nil
        end
        if FarmDeathWatch.partnerCharRemovingConn then
            FarmDeathWatch.partnerCharRemovingConn:Disconnect()
            FarmDeathWatch.partnerCharRemovingConn = nil
        end
        if FarmDeathWatch.partnerSeatConn then
            FarmDeathWatch.partnerSeatConn:Disconnect()
            FarmDeathWatch.partnerSeatConn = nil
        end
    end

    local function triggerPartnerFarmReset(statusMsg)
        local now = tick()
        if now - FarmDeathWatch.lastDeathTrigger < PARTNER_DEATH_DEBOUNCE then return end
        if MainFarmState.partnerDeathHandling then return end
        if not (MainFarmState.active or MainFarmState.farmEnabled or MainFarmState.autoResume) then return end

        FarmDeathWatch.lastDeathTrigger = now
        MainFarmState.partnerDeathHandling = true
        MainFarmState.active = false
        MainFarmState.running = false
        clearFarmBoatTracking()
        setFarmBoatFlyEnabled(false)
        cleanupSeatGlide()
        cleanupPartnerGlide()
        FarmState.chestPushActive = false
        FarmState.chestPushChest = nil
        FarmDeathWatch.partnerAtSpawnSince = nil
        setFarmStatus(statusMsg or "Partner reset — restarting farm...", "info")
        MainFarmState.suppressRespawnHandler = true

        task.spawn(function()
            local revived = false
            local conn
            conn = Player.CharacterAdded:Connect(function(char)
                if revived then return end
                revived = true
                if conn then
                    conn:Disconnect()
                    conn = nil
                end
                pcall(function()
                    char:WaitForChild("HumanoidRootPart", 12)
                end)
                pcall(function()
                    char:WaitForChild("Humanoid", 12)
                end)
                task.wait(0.5)
                MainFarmState.suppressRespawnHandler = false
                MainFarmState.partnerDeathHandling = false
                if MainFarmState.farmEnabled or MainFarmState.autoResume then
                    restartBoatFarmAfterRound()
                end
            end)

            pcall(function()
                local char = Player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    hum.Health = 0
                end
            end)
            pcall(function()
                Player:LoadCharacter()
            end)

            task.wait(8)
            if not revived then
                if conn then
                    conn:Disconnect()
                end
                MainFarmState.suppressRespawnHandler = false
                MainFarmState.partnerDeathHandling = false
                if MainFarmState.farmEnabled or MainFarmState.autoResume then
                    restartBoatFarmAfterRound()
                end
            end
        end)
    end

    local function onPartnerDeath()
        triggerPartnerFarmReset("Partner died — resetting you...")
    end

    local function onPartnerAtWhiteTeamSpawn()
        triggerPartnerFarmReset("Partner at team spawn — restarting farm...")
    end

    local function bindPartnerHum(plr, hum)
        if FarmDeathWatch.partnerConn then
            FarmDeathWatch.partnerConn:Disconnect()
        end
        if FarmDeathWatch.partnerHealthConn then
            FarmDeathWatch.partnerHealthConn:Disconnect()
        end
        if FarmDeathWatch.partnerSeatConn then
            FarmDeathWatch.partnerSeatConn:Disconnect()
        end
        FarmDeathWatch.partnerConn = hum.Died:Connect(onPartnerDeath)
        FarmDeathWatch.partnerHealthConn = hum.HealthChanged:Connect(function(health)
            if health <= 0 then
                onPartnerDeath()
            end
        end)
        FarmDeathWatch.partnerSeatConn = hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
            if MainFarmState.active and FarmDeathWatch.partnerWasSeated and hum.SeatPart == nil then
                task.defer(onPartnerDeath)
            end
        end)
        FarmDeathWatch.partnerWasSeated = hum.SeatPart ~= nil
    end

    rebindPartnerDeathWatch = function(plr)
        disconnectPartnerDeath()
        if not plr then return end
        if not (MainFarmState.active or MainFarmState.farmEnabled or MainFarmState.autoResume) then return end

        local function onPartnerChar(char)
            if FarmDeathWatch.partnerCharRemovingConn then
                FarmDeathWatch.partnerCharRemovingConn:Disconnect()
            end
            FarmDeathWatch.partnerCharRemovingConn = char.AncestryChanged:Connect(function(_, parent)
                if parent == nil and MainFarmState.partner == plr then
                    onPartnerDeath()
                end
            end)
            local hum = char:WaitForChild("Humanoid", 10)
            if hum and MainFarmState.partner == plr then
                bindPartnerHum(plr, hum)
            end
        end

        if plr.Character then
            onPartnerChar(plr.Character)
        end
        FarmDeathWatch.partnerCharConn = plr.CharacterAdded:Connect(onPartnerChar)
    end

    stopFarmDeathWatch = function()
        if FarmDeathWatch.localConn then
            FarmDeathWatch.localConn:Disconnect()
            FarmDeathWatch.localConn = nil
        end
        if FarmDeathWatch.localCharConn then
            FarmDeathWatch.localCharConn:Disconnect()
            FarmDeathWatch.localCharConn = nil
        end
        if FarmDeathWatch.partnerMonitorConn then
            FarmDeathWatch.partnerMonitorConn:Disconnect()
            FarmDeathWatch.partnerMonitorConn = nil
        end
        FarmDeathWatch.partnerMissingSince = nil
        FarmDeathWatch.lastPartnerCheck = 0
        FarmDeathWatch.partnerAtSpawnSince = nil
        disconnectPartnerDeath()
    end

    local function startPartnerDeathMonitor()
        if FarmDeathWatch.partnerMonitorConn then return end
        FarmDeathWatch.partnerMonitorConn = RunService.Heartbeat:Connect(function()
            if tick() - FarmDeathWatch.lastPartnerCheck < PARTNER_MONITOR_INTERVAL then return end
            FarmDeathWatch.lastPartnerCheck = tick()

            if not (MainFarmState.active or MainFarmState.farmEnabled or MainFarmState.autoResume) then return end
            if MainFarmState.partnerDeathHandling then return end

            local partner = MainFarmState.partner
            if not partner or partner.Parent ~= Players then return end

            local char = partner.Character
            if not char or not char.Parent then
                if not FarmDeathWatch.partnerMissingSince then
                    FarmDeathWatch.partnerMissingSince = tick()
                elseif tick() - FarmDeathWatch.partnerMissingSince >= PARTNER_MISSING_TIMEOUT then
                    onPartnerDeath()
                end
                return
            end

            FarmDeathWatch.partnerMissingSince = nil
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then
                onPartnerDeath()
                return
            end

            if MainFarmState.active and FarmDeathWatch.partnerWasSeated and hum.SeatPart == nil then
                onPartnerDeath()
            elseif hum.SeatPart ~= nil then
                FarmDeathWatch.partnerWasSeated = true
            end

            if MainFarmState.active
                and (MainFarmState.farmHadForwardMotion or isBoatAwayFromPlot())
                and not isPartnerSeatedOnFarmSeat()
                and isPartnerAtWhiteTeamSpawn(partner) then
                if not FarmDeathWatch.partnerAtSpawnSince then
                    FarmDeathWatch.partnerAtSpawnSince = tick()
                elseif tick() - FarmDeathWatch.partnerAtSpawnSince >= WHITE_SPAWN_CONFIRM then
                    onPartnerAtWhiteTeamSpawn()
                end
            else
                FarmDeathWatch.partnerAtSpawnSince = nil
            end
        end)
    end

    startFarmDeathWatch = function()
        stopFarmDeathWatch()

        local function onLocalDied()
            if not (MainFarmState.farmEnabled or MainFarmState.autoResume) then return end
            if MainFarmState.restartingAfterRound or MainFarmState.respawnHandling then return end
            MainFarmState.active = false
            MainFarmState.running = false
            FarmState.chestPushActive = false
            FarmState.chestPushChest = nil
            setFarmBoatFlyEnabled(false)
            setFarmStatus("You died — restarting on respawn...", "info")
        end

        local function bindLocalChar(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if hum and (MainFarmState.farmEnabled or MainFarmState.autoResume) then
                if FarmDeathWatch.localConn then
                    FarmDeathWatch.localConn:Disconnect()
                end
                FarmDeathWatch.localConn = hum.Died:Connect(onLocalDied)
            end
        end

        if Player.Character then
            bindLocalChar(Player.Character)
        end
        FarmDeathWatch.localCharConn = Player.CharacterAdded:Connect(bindLocalChar)

        if MainFarmState.partner then
            rebindPartnerDeathWatch(MainFarmState.partner)
        elseif resolveSavedFarmPartner then
            local plr = resolveSavedFarmPartner()
            if plr then
                rebindPartnerDeathWatch(plr)
            end
        end
        startPartnerDeathMonitor()
    end
end)()

;(function()
local function startBoatFarmSeatLoop()
    task.spawn(function()
        while MainFarmState.active do
            refreshFarmSeats()
            if MainFarmState.partnerSeat and MainFarmState.partner
                and not isPartnerSeatedOnFarmSeat()
                and not isBoatAwayFromPlot()
                and isSeatAtSavedMark(
                    MainFarmState.partnerSeat,
                    MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos
                ) then
                forcePartnerSeatToPlayer(MainFarmState.partnerSeat, MainFarmState.partner)
            end
            if MainFarmState.yourSeat
                and not isYouSeatedOnFarmSeat()
                and not isPlayerInSeat(Player, MainFarmState.yourSeat) then
                local _, hrp = getCharacter()
                local seat = MainFarmState.yourSeat
                local seatOk = isBoatAwayFromPlot()
                    or isSeatAtSavedMark(seat, MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos)
                if not seatOk then
                    resetFarmSeatsForPlotPrep()
                    seat = MainFarmState.yourSeat
                    seatOk = seat and isSeatAtSavedMark(seat, MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos)
                end
                if seatOk and hrp and seat and (hrp.Position - seat.Position).Magnitude > 40 then
                    glideSelfToYourSeat()
                elseif seatOk and seat then
                    sitPlayerOnSeat(seat, Player)
                end
            end
            task.wait(1)
        end
    end)
end

restartBoatFarmAfterRound = function()
    if MainFarmState.restartingAfterRound then return end
    MainFarmState.restartingAfterRound = true
    MainFarmState.pendingRoundRestart = false
    MainFarmState.suppressRespawnHandler = true
    MainFarmState.farmEnabled = true
    MainFarmState.autoResume = true

    setFarmStatus("Restarting auto farm...", "info")
    MainFarmState.active = false
    MainFarmState.running = false
    stopFarmDeathWatch()
    setFarmBoatFlyEnabled(false)
    cleanupSeatGlide()
    cleanupPartnerGlide()
    FarmState.chestPushActive = false
    FarmState.chestPushChest = nil
    stopChestFloatHold()
    setFlyEnabled(false)
    Config.NoClip = false

    task.wait(0.15)

    MainFarmState.yourSeat = nil
    MainFarmState.partnerSeat = nil
    MainFarmState.boat = nil
    MainFarmState.stage = 1
    MainFarmState.respawnHandling = false
    MainFarmState.cycleRestarting = false

    pcall(function()
        if Config.AutoLoadSave and loadFarmSaveViaClicks then
            setFarmStatus("Reloading save for next round...", "info")
            loadFarmSaveViaClicks()
            MainFarmState.skipSaveLoadOnNextPrep = true
        end
    end)

    task.wait(0.1)
    resetFarmSeatsForPlotPrep()
    if loadPersistedFarmSetup then
        loadPersistedFarmSetup()
    end
    if resolveSavedFarmPartner then
        resolveSavedFarmPartner()
    end
    MainFarmState.suppressRespawnHandler = false
    MainFarmState.restartingAfterRound = false

    if beginBoatFarmFromSetup then
        beginBoatFarmFromSetup()
        task.wait(0.35)
        if not MainFarmState.active then
            MainFarmState.farmEnabled = true
            MainFarmState.autoResume = true
            MainFarmState.running = false
            beginBoatFarmFromSetup()
        end
    else
        startBoatAutoFarm()
        if not MainFarmState.active then
            MainFarmState.farmEnabled = true
            MainFarmState.autoResume = true
            MainFarmState.running = false
            task.wait(0.5)
            startBoatAutoFarm()
        end
    end
    if not MainFarmState.active and not MainFarmState.farmEnabled then
        setFarmStatus("Restart failed — open setup and press Start Farm", "error")
    end
end

startBoatAutoFarm = function()
    if MainFarmState.running then return end
    if not MainFarmState.farmEnabled and not MainFarmState.autoResume then return end

    MainFarmState.farmEnabled = true

    local blocker = getFarmSetupBlocker({ skipBuildCheck = Config.AutoLoadSave })
    if blocker then
        setFarmStatus(blocker, "error")
        return
    end

    ensureFarmSeatNames()

    if MainFarmState.yourSeat then
        MainFarmState.savedYourAnchored = MainFarmState.yourSeat.Anchored
    end
    if MainFarmState.partnerSeat then
        MainFarmState.savedPartnerAnchored = MainFarmState.partnerSeat.Anchored
    end

    MainFarmState.running = true
    MainFarmState.stage = 1
    MainFarmState.active = true
    MainFarmState.autoResume = true
    MainFarmState.farmHadForwardMotion = false

    local prepOk = runFarmPrepAndSeat()
    if not prepOk then
        MainFarmState.yourSeat = nil
        MainFarmState.partnerSeat = nil
        MainFarmState.boat = nil
        local preserve = MainFarmState.farmEnabled and MainFarmState.autoResume
        stopBoatAutoFarm(true, preserve)
        if not preserve then
            openMainFarmSetup(true)
        end
        return
    end

    if not MainFarmState.boat then
        setFarmStatus("Could not find boat after launch — retry", "error")
        local preserve = MainFarmState.farmEnabled and MainFarmState.autoResume
        stopBoatAutoFarm(true, preserve)
        if not preserve then
            openMainFarmSetup(true)
        end
        return
    end

    clearPartnerESP()
    closeMainFarmSetup()

    startFarmDeathWatch()
    startBoatFarmSeatLoop()

    if not MainFarmState.active then return end

    while MainFarmState.active do
        if not FarmState.tweening and not MainFarmState.cycleRestarting then
            pcall(runBoatFarmStep)
        end
        if getHorizontalSpeed(getFarmMovePart()) > 7 then
            MainFarmState.farmHadForwardMotion = true
        end
        task.wait()
    end

    if MainFarmState.pendingRoundRestart and MainFarmState.autoResume then
        MainFarmState.running = false
        if not MainFarmState.restartingAfterRound then
            task.spawn(restartBoatFarmAfterRound)
        end
        return
    end

    if MainFarmState.running then
        restoreBoatFarmState()
    end
    MainFarmState.running = false
end

local function restoreBoatFarmState(gentle)
    FarmState.tweening = false
    workspace.Gravity = FarmState.savedGravity or 196.2

    if MainFarmState.yourSeat and MainFarmState.yourSeat.Parent then
        pcall(function()
            MainFarmState.yourSeat.Anchored = MainFarmState.savedYourAnchored ~= false
            MainFarmState.yourSeat.CanCollide = true
        end)
    end
    if MainFarmState.partnerSeat and MainFarmState.partnerSeat.Parent then
        pcall(function()
            MainFarmState.partnerSeat.Anchored = MainFarmState.savedPartnerAnchored ~= false
            MainFarmState.partnerSeat.CanCollide = true
        end)
    end

    if MainFarmState.boat and MainFarmState.boat.Parent then
        for _, part in ipairs(MainFarmState.boat:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end

    local zone = getPlayerZone(Player)
    if zone then
        if zone:IsA("BasePart") then
            zone.CanCollide = true
            zone.Anchored = true
        end
        for _, part in ipairs(zone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end

    local buildFolder = getPlayerBuildFolder(Player)
    if buildFolder then
        for _, block in ipairs(buildFolder:GetChildren()) do
            local pp = block:FindFirstChild("PPart")
            if pp and pp:IsA("BasePart") then
                pp.CanCollide = true
            end
        end
    end

    local char, hrp, hum = getCharacter()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    if hum and not gentle then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)
    elseif hum then
        pcall(function()
            hum.PlatformStand = false
        end)
    end
    if hrp then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        if zone then
            local zonePart = zone:IsA("BasePart") and zone or zone:FindFirstChildWhichIsA("BasePart", true)
            if zonePart and hrp.Position.Y < zonePart.Position.Y - 15 then
                hrp.CFrame = zonePart.CFrame + Vector3.new(0, 6, 0)
            end
        end
    end

    if BoatFlyState.bv then BoatFlyState.bv:Destroy() BoatFlyState.bv = nil end
    if BoatFlyState.bg then BoatFlyState.bg:Destroy() BoatFlyState.bg = nil end
end

stopBoatAutoFarm = function(gentle, preserveIntent)
    MainFarmState.active = false
    MainFarmState.running = false
    if not preserveIntent then
        MainFarmState.autoResume = false
        MainFarmState.farmEnabled = false
    end
    MainFarmState.respawnHandling = false
    stopFarmDeathWatch()
    setFarmBoatFlyEnabled(false)
    cleanupSeatGlide()
    cleanupPartnerGlide()
    clearPartnerESP()
    restoreBoatFarmState(gentle)
end

local function getOtherPlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player then
            table.insert(list, plr)
        end
    end
    return list
end

local PlayerPickerState = {
    onSelect = nil,
}

local function formatPlayerButtonTextImpl(plr)
    if not plr then return "Select player..." end
    if plr.DisplayName and plr.DisplayName ~= plr.Name then
        return plr.Name .. "  ·  " .. plr.DisplayName
    end
    return plr.Name
end
formatPlayerButtonText = formatPlayerButtonTextImpl

local function getPlayerThumbnail(plr)
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(
            plr.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size48x48
        )
    end)
    return ok and content or ""
end

closePlayerPicker = function()
    if UI.PlayerPickerPopout then
        UI.PlayerPickerPopout.Visible = false
    end
    PlayerPickerState.onSelect = nil
    if MainFarmState.setupOpen and UI.MainFarmSetup then
        UI.MainFarmSetup.Active = true
    end
end

refreshPlayerPickerList = function()
    if not UI.PickerScroll then return end
    for _, child in ipairs(UI.PickerScroll:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local players = getOtherPlayers()
    if #players == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -16, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Text = "No other players in server"
        empty.TextColor3 = COLORS.textMuted
        empty.TextSize = 12
        empty.Font = Enum.Font.GothamMedium
        empty.Parent = UI.PickerScroll
        return
    end

    for _, plr in ipairs(players) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 64)
        row.BackgroundColor3 = COLORS.surface
        row.Text = ""
        row.AutoButtonColor = false
        row.ZIndex = 32
        row.Active = true
        row.Parent = UI.PickerScroll
        applyCorner(row, RADIUS.md)

        local avatar = Instance.new("ImageLabel")
        avatar.Size = UDim2.new(0, 44, 0, 44)
        avatar.Position = UDim2.new(0, 10, 0.5, -22)
        avatar.BackgroundColor3 = COLORS.elevated
        avatar.Image = ""
        avatar.ZIndex = 33
        avatar.Active = false
        avatar.Parent = row
        applyCorner(avatar, RADIUS.sm)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -70, 0, 18)
        nameLabel.Position = UDim2.new(0, 62, 0, 14)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = plr.Name
        nameLabel.TextColor3 = COLORS.text
        nameLabel.TextSize = 13
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 33
        nameLabel.Active = false
        nameLabel.Parent = row

        local displayLabel = Instance.new("TextLabel")
        displayLabel.Size = UDim2.new(1, -70, 0, 16)
        displayLabel.Position = UDim2.new(0, 62, 0, 34)
        displayLabel.BackgroundTransparency = 1
        displayLabel.Text = "Display: " .. (plr.DisplayName or plr.Name)
        displayLabel.TextColor3 = COLORS.textMuted
        displayLabel.TextSize = 11
        displayLabel.Font = Enum.Font.GothamMedium
        displayLabel.TextXAlignment = Enum.TextXAlignment.Left
        displayLabel.ZIndex = 33
        displayLabel.Active = false
        displayLabel.Parent = row

        task.spawn(function()
            local thumb = getPlayerThumbnail(plr)
            if thumb ~= "" and avatar.Parent then
                avatar.Image = thumb
            end
        end)

        bindPickerRowHover(row, function()
            return COLORS.surface
        end)

        row.MouseButton1Click:Connect(function()
            if PlayerPickerState.onSelect then
                PlayerPickerState.onSelect(plr)
            end
            closePlayerPicker()
        end)
    end
end

openPlayerPicker = function(onSelect, title)
    PlayerPickerState.onSelect = onSelect
    if UI.PickerTitle then
        UI.PickerTitle.Text = title or "Select Player"
    end
    refreshPlayerPickerList()
    if UI.MainFarmSetup and UI.MainFarmSetup.Visible then
        UI.MainFarmSetup.Active = false
    end
    if UI.PlayerPickerPopout then
        UI.PlayerPickerPopout.Visible = true
        UI.PlayerPickerPopout.ZIndex = 100
    end
end

local SeatPickerState = {
    onSelect = nil,
    excludeSeat = nil,
}

closeSeatPicker = function()
    if UI.SeatPickerPopout then
        UI.SeatPickerPopout.Visible = false
    end
    SeatPickerState.onSelect = nil
    SeatPickerState.excludeSeat = nil
    if MainFarmState.setupOpen and UI.MainFarmSetup then
        UI.MainFarmSetup.Active = true
    end
end

local function fillSeatPreviewViewport(viewport, seat)
    if not viewport or not seat then return end

    for _, child in ipairs(viewport:GetChildren()) do
        child:Destroy()
    end

    local worldModel = Instance.new("WorldModel")
    worldModel.Parent = viewport

    local cam = Instance.new("Camera")
    cam.Parent = viewport
    viewport.CurrentCamera = cam

    local ok, clone = pcall(function()
        return seat:Clone()
    end)
    if not ok or not clone then
        return
    end

    clone.Anchored = true
    clone.CanCollide = false
    clone.CFrame = CFrame.new(0, 0, 0)
    clone.Parent = worldModel

    local maxSize = math.max(clone.Size.X, clone.Size.Y, clone.Size.Z, 1)
    local dist = maxSize * 2.4
    cam.CFrame = CFrame.new(Vector3.new(dist, dist * 0.45, dist), Vector3.zero)
end

refreshSeatPickerList = function()
    if not UI.SeatPickerScroll then return end

    for _, child in ipairs(UI.SeatPickerScroll:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local seats = getAllSeatsOnPlayerBoat()
    if #seats == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -16, 0, 48)
        empty.BackgroundTransparency = 1
        empty.Text = "No seats found — load your boat from Saves first"
        empty.TextColor3 = COLORS.textMuted
        empty.TextSize = 12
        empty.Font = Enum.Font.GothamMedium
        empty.TextWrapped = true
        empty.ZIndex = 52
        empty.Parent = UI.SeatPickerScroll
        return
    end

    for index, seat in ipairs(seats) do
        if seat ~= SeatPickerState.excludeSeat then
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 72)
        row.BackgroundColor3 = COLORS.surface
        row.Text = ""
        row.AutoButtonColor = false
        row.ZIndex = 52
        row.Active = true
        row.Parent = UI.SeatPickerScroll
        applyCorner(row, RADIUS.md)

        local preview = Instance.new("ViewportFrame")
        preview.Size = UDim2.new(0, 52, 0, 52)
        preview.Position = UDim2.new(0, 10, 0.5, -26)
        preview.BackgroundColor3 = seat.Color
        preview.BorderSizePixel = 0
        preview.ZIndex = 53
        preview.Active = false
        preview.Parent = row
        applyCorner(preview, RADIUS.sm)
        fillSeatPreviewViewport(preview, seat)

        local colorTag = Instance.new("Frame")
        colorTag.Size = UDim2.new(0, 10, 0, 52)
        colorTag.Position = UDim2.new(0, 68, 0.5, -26)
        colorTag.BackgroundColor3 = seat.Color
        colorTag.BorderSizePixel = 0
        colorTag.ZIndex = 53
        colorTag.Active = false
        colorTag.Parent = row
        applyCorner(colorTag, RADIUS.sm)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -92, 0, 20)
        nameLabel.Position = UDim2.new(0, 84, 0, 14)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = string.format("#%d  %s", index, seat.Name)
        nameLabel.TextColor3 = COLORS.text
        nameLabel.TextSize = 13
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 53
        nameLabel.Active = false
        nameLabel.Parent = row

        local detailLabel = Instance.new("TextLabel")
        detailLabel.Size = UDim2.new(1, -92, 0, 32)
        detailLabel.Position = UDim2.new(0, 84, 0, 34)
        detailLabel.BackgroundTransparency = 1
        detailLabel.Text = getSeatAppearanceText(seat)
        detailLabel.TextColor3 = COLORS.textMuted
        detailLabel.TextSize = 11
        detailLabel.Font = Enum.Font.GothamMedium
        detailLabel.TextXAlignment = Enum.TextXAlignment.Left
        detailLabel.TextWrapped = true
        detailLabel.ZIndex = 53
        detailLabel.Active = false
        detailLabel.Parent = row

        bindPickerRowHover(row, function()
            return COLORS.surface
        end)

        row.MouseButton1Click:Connect(function()
            if SeatPickerState.onSelect then
                SeatPickerState.onSelect(seat)
            end
            closeSeatPicker()
        end)
        row.Activated:Connect(function()
            if SeatPickerState.onSelect then
                SeatPickerState.onSelect(seat)
            end
            closeSeatPicker()
        end)
        end
    end
end

openSeatPicker = function(onSelect, title, excludeSeat)
    SeatPickerState.onSelect = onSelect
    SeatPickerState.excludeSeat = excludeSeat
    if UI.SeatPickerTitle then
        UI.SeatPickerTitle.Text = title or "Select Seat"
    end
    refreshSeatPickerList()
    if UI.MainFarmSetup and UI.MainFarmSetup.Visible then
        UI.MainFarmSetup.Active = false
    end
    if UI.SeatPickerPopout then
        UI.SeatPickerPopout.Visible = true
        UI.SeatPickerPopout.ZIndex = 100
    end
end

updateBuildPlayerLabel = function()
    if UI.BuildSelectBtn then
        local plr = BuildState.targetPlayer
        UI.BuildSelectBtn.Text = formatPlayerButtonText(plr)
        UI.BuildSelectBtn.TextColor3 = plr and COLORS.text or COLORS.textMuted
    end
end

scanBuildFromPlayer = function(plr)
    local folder = getPlayerBuildFolder(plr)
    if not folder then return {} end
    local hisBase = getPlayerZone(plr)
    local blocks = {}
    for _, block in ipairs(folder:GetChildren()) do
        local pp = block:FindFirstChild("PPart")
        if pp then
            local rel = hisBase and hisBase.CFrame:ToObjectSpace(pp.CFrame) or pp.CFrame
            table.insert(blocks, {
                Name = block.Name,
                Rel = cframeToArray(rel),
                Size = { pp.Size.X, pp.Size.Y, pp.Size.Z },
                Color = { pp.Color.R, pp.Color.G, pp.Color.B },
                Anchored = pp.Anchored,
                Transparency = pp.Transparency,
            })
        end
    end
    return blocks
end

clearBuildPreview = function()
    if BuildState.previewFolder then
        BuildState.previewFolder:Destroy()
        BuildState.previewFolder = nil
    end
end

showBuildPreview = function(blocks)
    clearBuildPreview()
    if not blocks or #blocks == 0 then return end
    local myBase = getPlayerZone(Player)
    if not myBase then return end

    local folder = Instance.new("Folder")
    folder.Name = "NightFallBuildPreview"
    folder.Parent = workspace
    BuildState.previewFolder = folder

    for i, data in ipairs(blocks) do
        if i > 400 then break end
        local part = Instance.new("Part")
        part.Name = data.Name .. "_Preview"
        part.Size = Vector3.new(unpack(data.Size))
        part.Color = Color3.new(unpack(data.Color))
        part.Transparency = math.clamp(data.Transparency + 0.25, 0, 0.85)
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.CFrame = myBase.CFrame * arrayToCframe(data.Rel)
        part.Parent = folder
    end
end

wirePreviewHandlers = function(onBtn, offBtn, setPreviewButtons)
    local function previewOn()
        if not BuildState.clipboard or #BuildState.clipboard == 0 then
            if UI.BuildStatusLabel then
                UI.BuildStatusLabel.Text = "Scan or load a build first, then turn preview on"
            end
            return
        end
        showBuildPreview(BuildState.clipboard)
        BuildState.previewActive = true
        setPreviewButtons(true)
        if UI.BuildStatusLabel then
            UI.BuildStatusLabel.Text = "Preview on (" .. #BuildState.clipboard .. " blocks)"
        end
    end

    local function previewOff()
        clearBuildPreview()
        BuildState.previewActive = false
        setPreviewButtons(false)
        if UI.BuildStatusLabel then
            UI.BuildStatusLabel.Text = "Preview off"
        end
    end

    onBtn.MouseButton1Click:Connect(previewOn)
    offBtn.MouseButton1Click:Connect(previewOff)
    onBtn.Activated:Connect(previewOn)
    offBtn.Activated:Connect(previewOff)
end
end)() -- farm cycle + picker UI (Luau 200 local register limit)

;(function()
local FARM_BUILD_PATH = "ScriptHub/babft_farm_build.json"

local function getBuildingTool()
    local char, _, hum = getCharacter()
    if not char or not hum then return nil end
    local tool = char:FindFirstChild("BuildingTool")
    if tool then return tool end
    local bp = Player.Backpack:FindFirstChild("BuildingTool")
    if bp then
        pcall(function() hum:EquipTool(bp) end)
        task.wait(0.15)
        return char:FindFirstChild("BuildingTool")
    end
    return nil
end

local function placeBuildBlockWith(tool, myBase, data)
    if not tool or not myBase or not data then return false end
    local worldCF = myBase.CFrame * arrayToCframe(data.Rel)
    local args = {
        data.Name,
        getBlockID(data.Name),
        myBase,
        myBase.CFrame:ToObjectSpace(worldCF),
        data.Anchored == true,
        worldCF,
        false,
    }
    pcall(function()
        tool.RF:InvokeServer(unpack(args))
    end)
    return true
end

hasFarmBuildOnPlot = function()
    if countSeatsOnPlot() >= 2 then
        return true
    end
    local folder = getPlayerBuildFolder(Player)
    if not folder then
        return false
    end
    local blockCount = 0
    for _, child in ipairs(folder:GetChildren()) do
        if child:FindFirstChild("PPart") then
            blockCount += 1
        end
    end
    return blockCount >= 4
end

local function saveFarmBuildTemplate(blocks)
    if not blocks or #blocks == 0 then
        return
    end
    BuildState.farmTemplate = blocks
    pcall(function()
        if writefile then
            if makefolder and isfolder and not isfolder("ScriptHub") then
                makefolder("ScriptHub")
            end
            writefile(FARM_BUILD_PATH, HttpService:JSONEncode(blocks))
        end
    end)
end

scanAndSaveFarmBuild = function(plr)
    plr = plr or BuildState.targetPlayer or Player
    local blocks = scanBuildFromPlayer(plr)
    if not blocks or #blocks == 0 then
        return false, 0, plr.Name
    end
    BuildState.clipboard = blocks
    saveFarmBuildTemplate(blocks)
    if BuildState.previewActive then
        showBuildPreview(blocks)
    end
    return true, #blocks, plr.Name
end

local function loadFarmBuildTemplateFromDisk()
    local ok, raw = pcall(function()
        if isfile and readfile and isfile(FARM_BUILD_PATH) then
            return readfile(FARM_BUILD_PATH)
        end
    end)
    if not ok or not raw then
        return nil
    end
    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if decodeOk and type(data) == "table" and #data > 0 then
        BuildState.farmTemplate = data
        return data
    end
    return nil
end

local function pasteBuildBlocksSync(blocks)
    if not blocks or #blocks == 0 then
        return false
    end
    while BuildState.isPasting do
        task.wait(0.05)
    end
    BuildState.isPasting = true
    local tool = getBuildingTool()
    local myBase = getPlayerZone(Player)
    if not tool or not myBase then
        BuildState.isPasting = false
        return false
    end
    for _, data in ipairs(blocks) do
        placeBuildBlockWith(tool, myBase, data)
        task.wait(0.03)
    end
    BuildState.isPasting = false
    task.wait(0.8)
    return true
end

ensureFarmBuildOnPlot = function()
    if hasFarmBuildOnPlot() then
        return true
    end
    local blocks = BuildState.farmTemplate or BuildState.clipboard or loadFarmBuildTemplateFromDisk()
    if not blocks or #blocks == 0 then
        setFarmStatus("No build saved — scan your farm boat in Auto Build tab first", "error")
        return false
    end
    setFarmStatus("Auto-building farm boat on plot...", "info")
    if not pasteBuildBlocksSync(blocks) then
        setFarmStatus("Auto build failed — need BuildingTool on your plot", "error")
        return false
    end
    task.wait(0.5)
    refreshFarmSeats()
    return hasFarmBuildOnPlot()
end

pasteBuildBlocks = function(blocks)
    if BuildState.isPasting or not blocks or #blocks == 0 then return end
    BuildState.isPasting = true
    task.spawn(function()
        local tool = getBuildingTool()
        local myBase = getPlayerZone(Player)
        if not tool or not myBase then
            BuildState.isPasting = false
            if UI.BuildStatusLabel then
                UI.BuildStatusLabel.Text = "Need BuildingTool and build zone to paste"
            end
            return
        end
        for _, data in ipairs(blocks) do
            placeBuildBlockWith(tool, myBase, data)
        end
        BuildState.isPasting = false
        if UI.BuildStatusLabel then
            UI.BuildStatusLabel.Text = "Pasted " .. #blocks .. " blocks"
        end
    end)
end

loadFarmBuildTemplateFromDisk()
end)()

;(function()
local TEXT_CELL = 3
local TEXT_BLOCK = "WoodBlock"

local TEXT_FONT = {
    A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
    B = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
    C = { "01111", "10000", "10000", "10000", "10000", "10000", "01111" },
    D = { "11110", "10001", "10001", "10001", "10001", "10001", "11110" },
    E = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
    F = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
    G = { "01111", "10000", "10000", "10011", "10001", "10001", "01111" },
    H = { "10001", "10001", "10001", "11111", "10001", "10001", "10001" },
    I = { "11111", "00100", "00100", "00100", "00100", "00100", "11111" },
    J = { "00111", "00010", "00010", "00010", "00010", "10010", "01100" },
    K = { "10001", "10010", "10100", "11000", "10100", "10010", "10001" },
    L = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
    M = { "10001", "11011", "10101", "10001", "10001", "10001", "10001" },
    N = { "10001", "11001", "10101", "10011", "10001", "10001", "10001" },
    O = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" },
    P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
    Q = { "01110", "10001", "10001", "10001", "10101", "10010", "01101" },
    R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
    S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
    T = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
    U = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
    V = { "10001", "10001", "10001", "10001", "10001", "01010", "00100" },
    W = { "10001", "10001", "10001", "10001", "10101", "11011", "10001" },
    X = { "10001", "10001", "01010", "00100", "01010", "10001", "10001" },
    Y = { "10001", "10001", "01010", "00100", "00100", "00100", "00100" },
    Z = { "11111", "00001", "00010", "00100", "01000", "10000", "11111" },
    ["0"] = { "01110", "10001", "10011", "10101", "11001", "10001", "01110" },
    ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
    ["2"] = { "01110", "10001", "00001", "00110", "01000", "10000", "11111" },
    ["3"] = { "01110", "10001", "00001", "00110", "00001", "10001", "01110" },
    ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" },
    ["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
    ["6"] = { "01110", "10000", "10000", "11110", "10001", "10001", "01110" },
    ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
    ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" },
    ["9"] = { "01110", "10001", "10001", "01111", "00001", "00001", "01110" },
    [" "] = {},
}

local function getTextGlyph(ch)
    return TEXT_FONT[ch] or TEXT_FONT["?"] or TEXT_FONT.A
end

local function textToBlockList(text)
    local blocks = {}
    local col = 0
    for i = 1, #text do
        local ch = string.upper(string.sub(text, i, i))
        local glyph = getTextGlyph(ch)
        for row, line in ipairs(glyph) do
            for c = 1, #line do
                if string.sub(line, c, c) == "1" then
                    table.insert(blocks, {
                        col = col + c - 1,
                        row = row,
                    })
                end
            end
        end
        col += 6
    end
    return blocks
end

local function getTextBuilderTool()
    local char, _, hum = getCharacter()
    if not char or not hum then return nil end
    local tool = char:FindFirstChild("BuildingTool")
    if tool then return tool end
    local bp = Player.Backpack:FindFirstChild("BuildingTool")
    if bp then
        pcall(function() hum:EquipTool(bp) end)
        task.wait(0.15)
        return char:FindFirstChild("BuildingTool")
    end
    return nil
end

local function placeTextBlock(tool, myBase, worldPos)
    local rel = myBase.CFrame:ToObjectSpace(CFrame.new(worldPos))
    local args = {
        TEXT_BLOCK,
        getBlockID(TEXT_BLOCK),
        myBase,
        rel,
        true,
        CFrame.new(worldPos),
        false,
    }
    pcall(function()
        tool.RF:InvokeServer(unpack(args))
    end)
end

local function buildTextAtOrigin(text, origin)
    if not text or text == "" then return false, "Enter text first" end
    if not origin then return false, "Pick a placement position first" end
    local tool = getTextBuilderTool()
    local myBase = getPlayerZone(Player)
    if not tool or not myBase then
        return false, "Need BuildingTool on your plot"
    end
    local pixels = textToBlockList(text)
    if #pixels == 0 then return false, "No buildable characters" end
    for _, pixel in ipairs(pixels) do
        local worldPos = origin + Vector3.new(pixel.col * TEXT_CELL, (7 - pixel.row) * TEXT_CELL, 0)
        placeTextBlock(tool, myBase, worldPos)
        task.wait(0.03)
    end
    return true, "Built " .. #pixels .. " blocks for \"" .. text .. "\""
end

local TextPickerState = { conn = nil, hoverConn = nil, marker = nil }

local function clearTextPickerMarker()
    if TextPickerState.marker then
        TextPickerState.marker:Destroy()
        TextPickerState.marker = nil
    end
end

local function setTextPickerMarker(pos)
    clearTextPickerMarker()
    local part = Instance.new("Part")
    part.Name = "NightFallTextOrigin"
    part.Size = Vector3.new(2, 0.4, 2)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = COLORS.accent
    part.Transparency = 0.35
    part.CFrame = CFrame.new(pos)
    part.Parent = workspace
    TextPickerState.marker = part
end

local function raycastFromScreen(screenPos)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { Player.Character, TextPickerState.marker }
    if UI.HubScreenGui then table.insert(ignore, UI.HubScreenGui) end
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    if hit then return hit.Position + Vector3.new(0, TEXT_CELL, 0) end
    return ray.Origin + ray.Direction * 80
end

local function stopTextPositionPicker()
    if TextPickerState.conn then
        TextPickerState.conn:Disconnect()
        TextPickerState.conn = nil
    end
    if TextPickerState.hoverConn then
        TextPickerState.hoverConn:Disconnect()
        TextPickerState.hoverConn = nil
    end
    BuildState.textBuilderPicking = false
end

local function startTextPositionPicker(onPick)
    stopTextPositionPicker()
    BuildState.textBuilderPicking = true
    if UI.TextBuilderStatusLabel then
        UI.TextBuilderStatusLabel.Text = "Tap/click the plot to set text origin"
        UI.TextBuilderStatusLabel.TextColor3 = COLORS.accentLight
    end

    TextPickerState.hoverConn = RunService.RenderStepped:Connect(function()
        if not BuildState.textBuilderPicking then return end
        local pos
        local mouse = Player:GetMouse()
        if mouse and mouse.Hit then
            pos = mouse.Hit.Position + Vector3.new(0, TEXT_CELL, 0)
        end
        if pos then setTextPickerMarker(pos) end
    end)

    TextPickerState.conn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not BuildState.textBuilderPicking then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local pos = raycastFromScreen(input.Position)
        if not pos then return end
        stopTextPositionPicker()
        BuildState.textBuilderOrigin = pos
        setTextPickerMarker(pos)
        if onPick then onPick(pos) end
    end)
end

local function wirePremiumTextBuilderImpl()
    if not UI.PremiumPage then return end

    local premiumBadge = Instance.new("TextLabel")
    premiumBadge.Size = UDim2.new(1, -8, 0, 22)
    premiumBadge.BackgroundTransparency = 1
    premiumBadge.Text = "Premium features — free during NightFall preview"
    premiumBadge.TextColor3 = COLORS.accentLight
    premiumBadge.TextSize = 11
    premiumBadge.Font = Enum.Font.GothamBold
    premiumBadge.TextXAlignment = Enum.TextXAlignment.Left
    premiumBadge.Parent = UI.PremiumPage

    local textHeader = Instance.new("TextLabel")
    textHeader.Size = UDim2.new(1, -8, 0, 18)
    textHeader.BackgroundTransparency = 1
    textHeader.Text = "TEXT BUILDER"
    textHeader.TextColor3 = COLORS.text
    textHeader.TextSize = 12
    textHeader.Font = Enum.Font.GothamBold
    textHeader.TextXAlignment = Enum.TextXAlignment.Left
    textHeader.Parent = UI.PremiumPage

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -8, 0, 34)
    textBox.BackgroundColor3 = COLORS.elevated
    textBox.TextColor3 = COLORS.text
    textBox.PlaceholderText = "Type text (A-Z, 0-9)"
    textBox.PlaceholderColor3 = COLORS.textMuted
    textBox.Font = Enum.Font.GothamSemibold
    textBox.TextSize = 14
    textBox.ClearTextOnFocus = false
    textBox.Text = ""
    textBox.Parent = UI.PremiumPage
    applyCorner(textBox, RADIUS.sm)
    UI.TextBuilderInput = textBox

    local pickPosBtn = createActionButton(UI.PremiumPage, "Pick Position", "Click/tap your plot where text should start")
    pickPosBtn.MouseButton1Click:Connect(function()
        startTextPositionPicker(function(pos)
            if UI.TextBuilderStatusLabel then
                UI.TextBuilderStatusLabel.Text = string.format(
                    "Origin set @ %.0f, %.0f, %.0f",
                    pos.X, pos.Y, pos.Z
                )
                UI.TextBuilderStatusLabel.TextColor3 = COLORS.success
            end
        end)
    end)
    pickPosBtn.Activated:Connect(function()
        startTextPositionPicker(function(pos)
            if UI.TextBuilderStatusLabel then
                UI.TextBuilderStatusLabel.Text = string.format(
                    "Origin set @ %.0f, %.0f, %.0f",
                    pos.X, pos.Y, pos.Z
                )
                UI.TextBuilderStatusLabel.TextColor3 = COLORS.success
            end
        end)
    end)

    local buildTextBtn = createActionButton(UI.PremiumPage, "Build Text", "Place WoodBlock letters on your plot")
    buildTextBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            local ok, msg = buildTextAtOrigin(textBox.Text, BuildState.textBuilderOrigin)
            if UI.TextBuilderStatusLabel then
                UI.TextBuilderStatusLabel.Text = msg
                UI.TextBuilderStatusLabel.TextColor3 = ok and COLORS.success or COLORS.danger
            end
        end)
    end)
    buildTextBtn.Activated:Connect(function()
        task.spawn(function()
            local ok, msg = buildTextAtOrigin(textBox.Text, BuildState.textBuilderOrigin)
            if UI.TextBuilderStatusLabel then
                UI.TextBuilderStatusLabel.Text = msg
                UI.TextBuilderStatusLabel.TextColor3 = ok and COLORS.success or COLORS.danger
            end
        end)
    end)

    UI.TextBuilderStatusLabel = Instance.new("TextLabel")
    UI.TextBuilderStatusLabel.Size = UDim2.new(1, -8, 0, 40)
    UI.TextBuilderStatusLabel.BackgroundTransparency = 1
    UI.TextBuilderStatusLabel.Text = "Enter text, pick origin, then Build"
    UI.TextBuilderStatusLabel.TextColor3 = COLORS.textMuted
    UI.TextBuilderStatusLabel.TextSize = 10
    UI.TextBuilderStatusLabel.Font = Enum.Font.GothamMedium
    UI.TextBuilderStatusLabel.TextWrapped = true
    UI.TextBuilderStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    UI.TextBuilderStatusLabel.Parent = UI.PremiumPage
end

wirePremiumTextBuilder = wirePremiumTextBuilderImpl
end)()

;(function()
runFarmPrepAndSeat = function()
    ensureFarmSeatNames()
    resetFarmSeatsForPlotPrep()

    if Config.AutoLoadSave and loadFarmSaveViaClicks then
        if MainFarmState.skipSaveLoadOnNextPrep then
            MainFarmState.skipSaveLoadOnNextPrep = false
            syncClientBuildAfterSave()
        else
            setFarmStatus("Auto loading save...", "info")
            loadFarmSaveViaClicks()
        end
        refreshFarmSeats()
    elseif not hasFarmBuildOnPlot() then
        if not ensureFarmBuildOnPlot() then
            return false
        end
    end

    if not reloadBuildUntilSeatsFound(30) then
        setFarmStatus("Seats not found on boat — re-mark seats after load", "error")
        return false
    end

    local blocker = getFarmSetupBlocker()
    if blocker then
        setFarmStatus(blocker, "error")
        return false
    end

    refreshFarmSeats()

    if not hasFarmBuildOnPlot() then
        setFarmStatus("Boat not on plot — load save or paste build first", "error")
        return false
    end

    if not MainFarmState.yourSeat or not MainFarmState.partnerSeat then
        setFarmStatus("Seats not found — re-mark both seats on your boat", "error")
        return false
    end
    if not isSeatAtSavedMark(MainFarmState.yourSeat, MainFarmState.yourSeatMarkPos or MainFarmState.yourSeatPos)
        or not isSeatAtSavedMark(MainFarmState.partnerSeat, MainFarmState.partnerSeatMarkPos or MainFarmState.partnerSeatPos) then
        setFarmStatus("Seats moved — re-mark seats on your plot boat", "error")
        return false
    end
    if MainFarmState.yourSeat == MainFarmState.partnerSeat then
        setFarmStatus("Same seat picked twice — mark two different seats", "error")
        return false
    end

    setFarmStatus("Gliding to your seat...", "info")
    if not isYouSeatedOnFarmSeat() and not isPlayerInSeat(Player, MainFarmState.yourSeat) then
        glideSelfToYourSeat()
    end
    if not isYouSeatedOnFarmSeat() and not isPlayerInSeat(Player, MainFarmState.yourSeat) then
        setFarmStatus("Could not reach your seat — choose seats and retry", "error")
        return false
    end

    setFarmStatus("Launching boat...", "info")
    quickLaunchBoat()
    task.wait(0.3)

    seatPartnerAfterLaunch()

    refreshFarmSeats()
    upgradeFarmSeatsToLaunched()
    refreshFarmSeats()

    MainFarmState.boat = getBoatRoot(MainFarmState.yourSeat) or getBoatRoot(MainFarmState.partnerSeat)
    if not MainFarmState.boat then
        refreshFarmSeats()
        MainFarmState.boat = getBoatRoot(MainFarmState.yourSeat) or getBoatRoot(MainFarmState.partnerSeat)
    end
    if not MainFarmState.boat then
        setFarmStatus("Could not find boat after launch", "error")
        return false
    end

    if not isPartnerSeatedOnFarmSeat() then
        setFarmStatus("Partner not seated yet — retry", "error")
        return false
    end

    setFarmStatus("Farm running", "ok")
    return true
end

prepareBoatFarmSession = function()
    return runFarmPrepAndSeat()
end

restartBoatFarmCycle = function()
    if MainFarmState.cycleRestarting then
        return false
    end
    if not (MainFarmState.active or MainFarmState.farmEnabled or MainFarmState.autoResume) then
        return false
    end
    MainFarmState.cycleRestarting = true
    MainFarmState.active = true
    MainFarmState.stage = 1
    local ok = runFarmPrepAndSeat()
    MainFarmState.cycleRestarting = false
    return ok
end

local function resumeBoatFarmAfterRespawn()
    MainFarmState.farmEnabled = true
    MainFarmState.autoResume = true
    MainFarmState.active = true

    if MainFarmState.running then
        return restartBoatFarmCycle()
    end

    MainFarmState.running = false
    if beginBoatFarmFromSetup then
        beginBoatFarmFromSetup()
    else
        task.spawn(startBoatAutoFarm)
    end
    return true
end

handleBoatFarmRespawn = function(char)
    if not (MainFarmState.farmEnabled or MainFarmState.autoResume) then return end
    if MainFarmState.suppressRespawnHandler then return end
    if MainFarmState.restartingAfterRound then return end
    if MainFarmState.respawnHandling or MainFarmState.cycleRestarting then return end
    MainFarmState.respawnHandling = true

    task.spawn(function()
        pcall(function()
            char:WaitForChild("HumanoidRootPart", 8)
        end)
        pcall(function()
            char:WaitForChild("Humanoid", 8)
        end)

        local readyT = tick()
        while tick() - readyT < 1.2 do
            local _, hrp = getCharacter()
            if hrp then break end
            task.wait(0.05)
        end

        if not (MainFarmState.farmEnabled or MainFarmState.autoResume) then
            MainFarmState.respawnHandling = false
            return
        end

        setFarmStatus("Respawned — loading save...", "info")

        if Config.AutoLoadSave and loadFarmSaveViaClicks then
            loadFarmSaveViaClicks()
            MainFarmState.skipSaveLoadOnNextPrep = true
        elseif not hasFarmBuildOnPlot() then
            ensureFarmBuildOnPlot()
        end
        task.wait(0.15)
        resetFarmSeatsForPlotPrep()
        refreshFarmSeats()
        MainFarmState.boat = getBoatRoot(MainFarmState.yourSeat)
            or getBoatRoot(MainFarmState.partnerSeat)

        resumeBoatFarmAfterRespawn()
        MainFarmState.respawnHandling = false
    end)
end
end)() -- farm prep + respawn (Luau 200 local register limit)

;(function()
local PickerState = {
    conn = nil,
    hoverConn = nil,
    hoverHighlight = nil,
    hoverTarget = nil,
}

local function clearPartHoverHighlight()
    if PickerState.hoverHighlight then
        PickerState.hoverHighlight:Destroy()
        PickerState.hoverHighlight = nil
    end
    PickerState.hoverTarget = nil
end

local function setPartHoverHighlight(part)
    if PickerState.hoverTarget == part then
        return
    end
    clearPartHoverHighlight()
    if not part or not part:IsA("BasePart") then
        return
    end
    PickerState.hoverTarget = part
    local highlight = Instance.new("Highlight")
    highlight.Name = "NightFallPickerHighlight"
    highlight.FillColor = COLORS.accent
    highlight.OutlineColor = COLORS.accentLight
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.Adornee = part
    highlight.Parent = part
    PickerState.hoverHighlight = highlight
end

stopPartPicker = function()
    if PickerState.conn then
        PickerState.conn:Disconnect()
        PickerState.conn = nil
    end
    if PickerState.hoverConn then
        PickerState.hoverConn:Disconnect()
        PickerState.hoverConn = nil
    end
    clearPartHoverHighlight()
    MainFarmState.pickerMode = nil
end

local function startPartPicker(mode, onPick)
    stopPartPicker()
    MainFarmState.pickerMode = mode

    PickerState.hoverConn = RunService.RenderStepped:Connect(function()
        if not MainFarmState.pickerMode then return end
        local mouse = Player:GetMouse()
        local target = mouse and mouse.Target
        if not target then
            clearPartHoverHighlight()
            return
        end
        local seat = target:IsA("Seat") and target
            or target:IsA("VehicleSeat") and target
            or target:FindFirstAncestorWhichIsA("Seat")
            or target:FindFirstAncestorWhichIsA("VehicleSeat")
        setPartHoverHighlight(seat or target)
    end)

    PickerState.conn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local mouse = Player:GetMouse()
        local target = mouse and mouse.Target
        if not target then return end
        local seat = target:IsA("Seat") and target
            or target:IsA("VehicleSeat") and target
            or target:FindFirstAncestorWhichIsA("Seat")
            or target:FindFirstAncestorWhichIsA("VehicleSeat")
        local part = seat or target
        stopPartPicker()
        onPick(part)
    end)
end
end)()

;(function()
local PartnerESPState = {
    highlight = nil,
    distanceConn = nil,
    charConn = nil,
    target = nil,
}

clearPartnerESP = function()
    if PartnerESPState.highlight then
        pcall(function() PartnerESPState.highlight:Destroy() end)
        PartnerESPState.highlight = nil
    end
    if PartnerESPState.distanceConn then
        PartnerESPState.distanceConn:Disconnect()
        PartnerESPState.distanceConn = nil
    end
    if PartnerESPState.charConn then
        PartnerESPState.charConn:Disconnect()
        PartnerESPState.charConn = nil
    end
    PartnerESPState.target = nil
    if UI.PartnerDistanceLabel then
        UI.PartnerDistanceLabel.Text = "Distance: —"
        UI.PartnerDistanceLabel.TextColor3 = COLORS.textMuted
    end
end

local function applyPartnerHighlight(plr)
    if not plr then return end
    local char = plr.Character
    if not char then return end

    if PartnerESPState.highlight then
        PartnerESPState.highlight.Adornee = char
        if PartnerESPState.highlight.Parent ~= char then
            PartnerESPState.highlight.Parent = char
        end
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "NightFallPartnerESP"
    highlight.FillColor = COLORS.accent
    highlight.OutlineColor = COLORS.success
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
    highlight.Parent = char
    PartnerESPState.highlight = highlight
end

startPartnerESP = function(plr)
    clearPartnerESP()
    if not plr then return end

    PartnerESPState.target = plr
    applyPartnerHighlight(plr)

    PartnerESPState.charConn = plr.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        if PartnerESPState.target == plr then
            applyPartnerHighlight(plr)
        end
    end)

    PartnerESPState.distanceConn = RunService.RenderStepped:Connect(function()
        if PartnerESPState.target ~= MainFarmState.partner then
            clearPartnerESP()
            return
        end

        local _, hrp = getCharacter()
        local partnerHrp = getPartnerHRP(plr)
        if UI.PartnerDistanceLabel then
            if hrp and partnerHrp then
                local dist = math.floor((hrp.Position - partnerHrp.Position).Magnitude + 0.5)
                UI.PartnerDistanceLabel.Text = "Distance: " .. dist .. " studs"
                UI.PartnerDistanceLabel.TextColor3 = COLORS.accentLight
            else
                UI.PartnerDistanceLabel.Text = "Distance: —"
                UI.PartnerDistanceLabel.TextColor3 = COLORS.textMuted
            end
        end

        if plr.Character and (not PartnerESPState.highlight or not PartnerESPState.highlight.Parent) then
            applyPartnerHighlight(plr)
        end
    end)
end

end)()

;(function()
local function formatSeatLabel(prefix, seat, seatPos)
    if not seat then return prefix .. ": not set" end
    local posTag = seatPos and string.format(" @ %.0f,%.0f", seatPos.X, seatPos.Z) or ""
    return prefix .. ": " .. seat.Name .. posTag
end

updateMainFarmSetupLabels = function()
    if UI.YourSeatLabel then
        UI.YourSeatLabel.Text = formatSeatLabel("You", MainFarmState.yourSeat, MainFarmState.yourSeatPos)
    end
    if UI.PartnerSeatLabel then
        UI.PartnerSeatLabel.Text = formatSeatLabel("Partner seat", MainFarmState.partnerSeat, MainFarmState.partnerSeatPos)
    end
    if UI.PartnerLabel then
        if MainFarmState.partner then
            UI.PartnerLabel.Text = "Partner player: " .. MainFarmState.partner.Name
                .. (MainFarmState.partner.DisplayName ~= MainFarmState.partner.Name
                    and (" (" .. MainFarmState.partner.DisplayName .. ")") or "")
        else
            UI.PartnerLabel.Text = "Partner player: not chosen"
        end
    end
    if UI.PartnerSelectBtn then
        UI.PartnerSelectBtn.Text = MainFarmState.partner and formatPlayerButtonText(MainFarmState.partner) or "Choose Partner..."
    end
end

local function isMainFarmReady()
    return getFarmSetupBlocker({ skipBuildCheck = Config.AutoLoadSave }) == nil
end

openMainFarmSetup = function(preserveStatus)
    if UI.MainFarmSetup then
        if loadPersistedFarmSetup then
            loadPersistedFarmSetup()
        end
        if resolveSavedFarmPartner then
            resolveSavedFarmPartner()
        end
        UI.MainFarmSetup.Visible = true
        MainFarmState.setupOpen = true
        updateMainFarmSetupLabels()
        updateSaveClickStatusLabel()
        if MainFarmState.partner then
            startPartnerESP(MainFarmState.partner)
        end
        if not preserveStatus then
            local seatCount = #getAllSeatsOnPlayerBoat()
            if seatCount >= 2 then
                setFarmStatus("Choose your seat and partner seat from the list", "info")
            elseif seatCount == 1 then
                setFarmStatus("Only 1 seat found — your boat needs 2 seats", "error")
            else
                setFarmStatus("Scan your farm boat in Auto Build tab, then choose seats", "info")
            end
        end
    end
end

closeMainFarmSetup = function()
    if UI.MainFarmSetup then
        UI.MainFarmSetup.Visible = false
        MainFarmState.setupOpen = false
    end
    stopPartPicker()
    closeSeatPicker()
    if not MainFarmState.active then
        clearPartnerESP()
    end
end
end)()

--- UI ---

;(function()
for _, name in ipairs({ "NightFallBABFT", "AutoFarmUI", "CipherHub" }) do
    local old = CoreGui:FindFirstChild(name)
    if old then old:Destroy() end
    local pg = Player:FindFirstChild("PlayerGui")
    if pg then
        local pgOld = pg:FindFirstChild(name)
        if pgOld then pgOld:Destroy() end
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NightFallBABFT"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiParent()

UI.ToggleGui = Instance.new("Frame")
UI.ToggleGui.Name = "ToggleGui"
UI.ToggleGui.Size = UDim2.new(0, State.toggleCubeSize, 0, State.toggleCubeSize)
UI.ToggleGui.Position = UDim2.new(0.5, -math.floor(State.toggleCubeSize / 2), 0, 14)
UI.ToggleGui.BackgroundTransparency = 1
UI.ToggleGui.Parent = ScreenGui

UI.ToggleCube = Instance.new("TextButton")
UI.ToggleCube.Size = UDim2.new(1, 0, 1, 0)
UI.ToggleCube.BackgroundColor3 = COLORS.surface
UI.ToggleCube.Text = ""
UI.ToggleCube.AutoButtonColor = false
UI.ToggleCube.Parent = UI.ToggleGui
UI.ToggleCorner = applyCorner(UI.ToggleCube, math.clamp(math.floor(State.toggleCubeSize * 0.22), 4, 14))
applyStroke(UI.ToggleCube, COLORS.accent, 1.5, 0.2)

UI.ToggleIcon = Instance.new("TextLabel")
UI.ToggleIcon.Size = UDim2.new(1, 0, 1, 0)
UI.ToggleIcon.BackgroundTransparency = 1
UI.ToggleIcon.Text = "NF"
UI.ToggleIcon.TextColor3 = COLORS.accentLight
UI.ToggleIcon.TextSize = math.clamp(math.floor(State.toggleCubeSize * 0.44), 10, 28)
UI.ToggleIcon.Font = Enum.Font.GothamBold
UI.ToggleIcon.Parent = UI.ToggleCube

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 620, 0, 580)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -290)
MainFrame.BackgroundColor3 = COLORS.bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
applyCorner(MainFrame, RADIUS.xl)
applyStroke(MainFrame, COLORS.border, 1, 0.45)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = COLORS.sidebar
Header.BorderSizePixel = 0
Header.Parent = MainFrame
applyCorner(Header, RADIUS.xl)

local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.new(1, 0, 0, 3)
HeaderAccent.BackgroundColor3 = COLORS.accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header

local HubTitle = Instance.new("TextLabel")
HubTitle.Size = UDim2.new(1, -60, 0, 22)
HubTitle.Position = UDim2.new(0, 16, 0, 10)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "NightFall"
HubTitle.TextColor3 = COLORS.text
HubTitle.TextSize = 18
HubTitle.Font = Enum.Font.GothamBold
HubTitle.TextXAlignment = Enum.TextXAlignment.Left
HubTitle.Parent = Header

local HubSubtitle = Instance.new("TextLabel")
HubSubtitle.Size = UDim2.new(1, -60, 0, 16)
HubSubtitle.Position = UDim2.new(0, 16, 0, 30)
HubSubtitle.BackgroundTransparency = 1
HubSubtitle.Text = "Build A Boat For Treasure"
HubSubtitle.TextColor3 = COLORS.textMuted
HubSubtitle.TextSize = 11
HubSubtitle.Font = Enum.Font.GothamMedium
HubSubtitle.TextXAlignment = Enum.TextXAlignment.Left
HubSubtitle.Parent = Header

UI.CloseBtn = Instance.new("TextButton")
UI.CloseBtn.Size = UDim2.new(0, 28, 0, 28)
UI.CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
UI.CloseBtn.BackgroundColor3 = COLORS.elevated
UI.CloseBtn.Text = "–"
UI.CloseBtn.TextColor3 = COLORS.textMuted
UI.CloseBtn.TextSize = 16
UI.CloseBtn.Font = Enum.Font.GothamBold
UI.CloseBtn.AutoButtonColor = false
UI.CloseBtn.Parent = Header
applyCorner(UI.CloseBtn, RADIUS.sm)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -68)
Sidebar.Position = UDim2.new(0, 10, 0, 58)
Sidebar.BackgroundColor3 = COLORS.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
applyCorner(Sidebar, RADIUS.xl)

local NavList = Instance.new("Frame")
NavList.Size = UDim2.new(1, -12, 1, -12)
NavList.Position = UDim2.new(0, 6, 0, 6)
NavList.BackgroundTransparency = 1
NavList.Parent = Sidebar

local NavLayout = Instance.new("UIListLayout")
NavLayout.Padding = UDim.new(0, 6)
NavLayout.Parent = NavList

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -(SIDEBAR_WIDTH + 20), 1, -68)
Content.Position = UDim2.new(0, SIDEBAR_WIDTH + 10, 0, 58)
Content.BackgroundColor3 = COLORS.surface
Content.ClipsDescendants = false
Content.BorderSizePixel = 0
Content.Parent = MainFrame
applyCorner(Content, RADIUS.xl)

local pages = {}
local tabButtons = {}

local function createTab(name, icon)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -12, 1, -12)
    page.Position = UDim2.new(0, 6, 0, 6)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = COLORS.border
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = page

    pages[name] = page

    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, 0, 0, 36)
    tabBtn.BackgroundColor3 = COLORS.sidebar
    tabBtn.Text = ""
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = NavList
    applyCorner(tabBtn, RADIUS.md)

    local tabIcon = Instance.new("TextLabel")
    tabIcon.Size = UDim2.new(0, 18, 1, 0)
    tabIcon.Position = UDim2.new(0, 10, 0, 0)
    tabIcon.BackgroundTransparency = 1
    tabIcon.Text = icon
    tabIcon.TextColor3 = COLORS.textMuted
    tabIcon.TextSize = 12
    tabIcon.Font = Enum.Font.GothamBold
    tabIcon.Parent = tabBtn

    local tabLabel = Instance.new("TextLabel")
    tabLabel.Size = UDim2.new(1, -34, 1, 0)
    tabLabel.Position = UDim2.new(0, 28, 0, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.Text = name
    tabLabel.TextColor3 = COLORS.textMuted
    tabLabel.TextSize = #name > 8 and 11 or 13
    tabLabel.Font = Enum.Font.GothamSemibold
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Parent = tabBtn

    tabButtons[name] = tabBtn
    return page
end

local function switchTab(name)
    for tabName, page in pairs(pages) do
        page.Visible = tabName == name
        local btn = tabButtons[tabName]
        if btn then
            btn.BackgroundColor3 = tabName == name and COLORS.tabActiveBg or COLORS.sidebar
            for _, child in ipairs(btn:GetChildren()) do
                if child:IsA("TextLabel") then
                    child.TextColor3 = tabName == name and COLORS.tabActive or COLORS.textMuted
                end
            end
        end
    end
end

local MainPage = createTab("Main", "M")
local MainFarmPage = createTab("Main Farm", "F")
local AutoBuildPage = createTab("Auto Build", "B")
local PremiumPage = createTab("Premium", "★")
local PlayerPage = createTab("Player", "P")
local SettingsPage = createTab("Settings", "G")
switchTab("Main")

for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
end

UI.HubScreenGui = ScreenGui
UI.HubMainFrame = MainFrame
UI.HubHeader = Header
UI.MainPage = MainPage
UI.MainFarmPage = MainFarmPage
UI.AutoBuildPage = AutoBuildPage
UI.PremiumPage = PremiumPage
UI.PlayerPage = PlayerPage
UI.SettingsPage = SettingsPage
if wirePremiumTextBuilder then
    wirePremiumTextBuilder()
end
end)()

;(function()
local MainPage = UI.MainPage
local MainFarmPage = UI.MainFarmPage
local AutoBuildPage = UI.AutoBuildPage

UI.FarmToggle = createHubButton(MainPage, "Auto Farm", "Stages 1-10 then golden chest, repeat")
UI.CollectToggle = createHubButton(MainPage, "Auto Collect", "Touch nearby gold and coins")
UI.AntiAFKToggle = createHubButton(MainPage, "Anti AFK", "Virtual input nudge every 55s")

UI.FarmToggle.MouseButton1Click:Connect(function()
    Config.AutoFarm = not Config.AutoFarm
    setHubToggle(UI.FarmToggle, Config.AutoFarm)
    if Config.AutoFarm then
        task.spawn(startAutoFarm)
    end
end)

UI.CollectToggle.MouseButton1Click:Connect(function()
    Config.AutoCollect = not Config.AutoCollect
    setHubToggle(UI.CollectToggle, Config.AutoCollect)
    if Config.AutoCollect then
        task.spawn(startAutoCollect)
    end
end)

UI.AntiAFKToggle.MouseButton1Click:Connect(function()
    Config.AntiAFK = not Config.AntiAFK
    setHubToggle(UI.AntiAFKToggle, Config.AntiAFK)
end)

local tpChestBtn = createHubButton(MainPage, "TP to Golden Chest", "Teleport to end chest now")
tpChestBtn.MouseButton1Click:Connect(function()
    local chest = getGoldenChest()
    if chest then
        pivotTo(chest:GetPivot() + Vector3.new(0, 0, -8))
    end
end)

local resetStageBtn = createHubButton(MainPage, "Reset Farm Stage", "Start from CaveStage1 again")
resetStageBtn.MouseButton1Click:Connect(function()
    FarmState.currentStage = 1
end)

UI.BoatFarmToggle = createHubButton(MainFarmPage, "Boat Auto Farm", "You + partner dual-seat stage farm")
UI.BoatFarmToggle.MouseButton1Click:Connect(function()
    if MainFarmState.farmEnabled or MainFarmState.active then
        stopBoatAutoFarm()
        return
    end
    openMainFarmSetup()
end)

local saveClickHeader = Instance.new("TextLabel")
saveClickHeader.Size = UDim2.new(1, -8, 0, 18)
saveClickHeader.BackgroundTransparency = 1
saveClickHeader.Text = "AUTO LOAD SAVE (drag blue circles 1–6 onto buttons)"
saveClickHeader.TextColor3 = COLORS.accentLight
saveClickHeader.TextSize = 10
saveClickHeader.Font = Enum.Font.GothamBold
saveClickHeader.TextXAlignment = Enum.TextXAlignment.Left
saveClickHeader.Parent = MainFarmPage

UI.AutoLoadSaveToggle = createHubButton(MainFarmPage, "Auto Load Save", "Click saved points on death / farm start")
UI.AutoLoadSaveToggle.MouseButton1Click:Connect(function()
    Config.AutoLoadSave = not Config.AutoLoadSave
    setHubToggle(UI.AutoLoadSaveToggle, Config.AutoLoadSave)
end)

local function addMarkPointButton(parent, text, pointKey, labelNum, defaultY)
    local btn = createActionButton(parent, text, "Shows draggable blue circle " .. labelNum)
    btn.MouseButton1Click:Connect(function()
        if ensureClickPointMarker then
            ensureClickPointMarker(pointKey, labelNum)
        end
    end)
    return btn
end

addMarkPointButton(MainFarmPage, "Point 1: Menu Button", "menu", "1")
addMarkPointButton(MainFarmPage, "Point 2: Saves Button", "saves", "2")
addMarkPointButton(MainFarmPage, "Point 3: Save Slot", "slot", "3")
addMarkPointButton(MainFarmPage, "Point 4: Load Button", "load", "4")
addMarkPointButton(MainFarmPage, "Point 5: Confirm", "confirm", "5")
addMarkPointButton(MainFarmPage, "Point 6: Close Menu", "close", "6")

local testSaveClicksBtn = createActionButton(MainFarmPage, "Test Save Clicks", "Runs all 6 clicks in order")
testSaveClicksBtn.MouseButton1Click:Connect(function()
    if testFarmSaveClicks then
        task.spawn(function()
            local ok = testFarmSaveClicks()
            if UI.SaveClickStatusLabel then
                UI.SaveClickStatusLabel.Text = ok and "Test clicks finished" or "Set all 6 points first"
                UI.SaveClickStatusLabel.TextColor3 = ok and COLORS.success or COLORS.danger
            end
        end)
    end
end)

UI.SaveClickStatusLabel = Instance.new("TextLabel")
UI.SaveClickStatusLabel.Size = UDim2.new(1, -8, 0, 36)
UI.SaveClickStatusLabel.BackgroundTransparency = 1
UI.SaveClickStatusLabel.Text = "Mark points 1–6 with blue circles"
UI.SaveClickStatusLabel.TextColor3 = COLORS.textMuted
UI.SaveClickStatusLabel.TextSize = 10
UI.SaveClickStatusLabel.Font = Enum.Font.GothamMedium
UI.SaveClickStatusLabel.TextWrapped = true
UI.SaveClickStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.SaveClickStatusLabel.Parent = MainFarmPage

local plotPrepLabel = Instance.new("TextLabel")
plotPrepLabel.Size = UDim2.new(1, -8, 0, 18)
plotPrepLabel.BackgroundTransparency = 1
plotPrepLabel.Text = "TURN ON BEFORE AUTO FARM"
plotPrepLabel.TextColor3 = COLORS.accentLight
plotPrepLabel.TextSize = 11
plotPrepLabel.Font = Enum.Font.GothamBold
plotPrepLabel.TextXAlignment = Enum.TextXAlignment.Left
plotPrepLabel.Parent = MainFarmPage

local deleteTreesBtn = createActionButton(MainFarmPage, "Delete All Trees", "Remove trees from every team plot")
deleteTreesBtn.MouseButton1Click:Connect(function()
    local count = deleteAllTrees()
    local sub = deleteTreesBtn:FindFirstChild("SubLabel", true)
    if sub then
        if count > 0 then
            sub.Text = "Removed " .. count .. " tree" .. (count == 1 and "" or "s")
        else
            sub.Text = "No Trees folders found"
        end
    end
end)

local deletePolesBtn = createActionButton(MainFarmPage, "Delete All Poles", "Remove poles from every team plot")
deletePolesBtn.MouseButton1Click:Connect(function()
    local count = deleteAllPoles()
    local sub = deletePolesBtn:FindFirstChild("SubLabel", true)
    if sub then
        if count > 0 then
            sub.Text = "Removed " .. count .. " pole" .. (count == 1 and "" or "s")
        else
            sub.Text = "No poles found"
        end
    end
end)

UI.BuildPlayerDropdown, UI.BuildSelectBtn = createPlayerPickerRow(AutoBuildPage, "Target Player")
UI.BuildSelectBtn.MouseButton1Click:Connect(function()
    openPlayerPicker(function(plr)
        BuildState.targetPlayer = plr
        updateBuildPlayerLabel()
    end, "Select Target Player")
end)

local scanBuildBtn = createActionButton(AutoBuildPage, "Scan & Save Build", "Scan your boat and save it for auto-paste")
scanBuildBtn.MouseButton1Click:Connect(function()
    if not BuildState.targetPlayer then return end
    local ok, count, name = scanAndSaveFarmBuild(BuildState.targetPlayer)
    if UI.BuildStatusLabel then
        if ok then
            UI.BuildStatusLabel.Text = "Scanned " .. count .. " blocks from " .. name
        else
            UI.BuildStatusLabel.Text = "No blocks found for " .. name
        end
    end
end)

UI.PreviewRow, UI.setPreviewButtons, UI.PreviewOnBtn, UI.PreviewOffBtn = createPreviewRow(AutoBuildPage)
wirePreviewHandlers(UI.PreviewOnBtn, UI.PreviewOffBtn, UI.setPreviewButtons)

local pasteBuildBtn = createActionButton(AutoBuildPage, "Paste Build", "Load saved build onto your plot")
pasteBuildBtn.MouseButton1Click:Connect(function()
    if BuildState.clipboard then
        pasteBuildBlocks(BuildState.clipboard)
        if UI.BuildStatusLabel then
            UI.BuildStatusLabel.Text = "Pasting " .. #BuildState.clipboard .. " blocks..."
        end
    end
end)

UI.BuildStatusLabel = Instance.new("TextLabel")
UI.BuildStatusLabel.Size = UDim2.new(1, 0, 0, 44)
UI.BuildStatusLabel.BackgroundColor3 = COLORS.elevated
UI.BuildStatusLabel.Text = "Select a player, scan, preview, or paste"
UI.BuildStatusLabel.TextColor3 = COLORS.textMuted
UI.BuildStatusLabel.TextSize = 11
UI.BuildStatusLabel.Font = Enum.Font.GothamMedium
UI.BuildStatusLabel.TextWrapped = true
UI.BuildStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.BuildStatusLabel.Parent = AutoBuildPage
applyCorner(UI.BuildStatusLabel, RADIUS.sm)
end)()

;(function()
local ScreenGui = UI.HubScreenGui

UI.MainFarmSetup = Instance.new("Frame")
UI.MainFarmSetup.Name = "MainFarmSetup"
UI.MainFarmSetup.Size = UDim2.new(0, 360, 0, 380)
UI.MainFarmSetup.Position = UDim2.new(0.5, -180, 0.5, -190)
UI.MainFarmSetup.BackgroundColor3 = COLORS.bg
UI.MainFarmSetup.Visible = false
UI.MainFarmSetup.ZIndex = 20
UI.MainFarmSetup.Active = true
UI.MainFarmSetup.Parent = ScreenGui
applyCorner(UI.MainFarmSetup, RADIUS.lg)
applyStroke(UI.MainFarmSetup, COLORS.accent, 1.5, 0.2)

local setupDragBar = Instance.new("Frame")
setupDragBar.Size = UDim2.new(1, 0, 0, 40)
setupDragBar.BackgroundTransparency = 1
setupDragBar.ZIndex = 21
setupDragBar.Parent = UI.MainFarmSetup
makeDraggable(UI.MainFarmSetup, setupDragBar)

local setupTitle = Instance.new("TextLabel")
setupTitle.Size = UDim2.new(1, -20, 0, 28)
setupTitle.Position = UDim2.new(0, 14, 0, 10)
setupTitle.BackgroundTransparency = 1
setupTitle.Text = "Boat Auto Farm Setup  (drag to move)"
setupTitle.TextColor3 = COLORS.text
setupTitle.TextSize = 15
setupTitle.Font = Enum.Font.GothamBold
setupTitle.TextXAlignment = Enum.TextXAlignment.Left
setupTitle.ZIndex = 22
setupTitle.Parent = setupDragBar

UI.YourSeatLabel = Instance.new("TextLabel")
UI.YourSeatLabel.Size = UDim2.new(1, -28, 0, 32)
UI.YourSeatLabel.Position = UDim2.new(0, 14, 0, 52)
UI.YourSeatLabel.BackgroundTransparency = 1
UI.YourSeatLabel.Text = "You: seat not set"
UI.YourSeatLabel.TextColor3 = COLORS.textMuted
UI.YourSeatLabel.TextSize = 11
UI.YourSeatLabel.Font = Enum.Font.GothamMedium
UI.YourSeatLabel.TextWrapped = true
UI.YourSeatLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.YourSeatLabel.ZIndex = 21
UI.YourSeatLabel.Parent = UI.MainFarmSetup

local markYourSeatBtn = Instance.new("TextButton")
markYourSeatBtn.Size = UDim2.new(1, -28, 0, 36)
markYourSeatBtn.Position = UDim2.new(0, 14, 0, 88)
markYourSeatBtn.BackgroundColor3 = COLORS.surface
markYourSeatBtn.Text = "Choose Your Seat"
markYourSeatBtn.TextColor3 = COLORS.text
markYourSeatBtn.TextSize = 12
markYourSeatBtn.Font = Enum.Font.GothamSemibold
markYourSeatBtn.ZIndex = 21
markYourSeatBtn.Parent = UI.MainFarmSetup
applyCorner(markYourSeatBtn, RADIUS.md)

UI.PartnerSeatLabel = Instance.new("TextLabel")
UI.PartnerSeatLabel.Size = UDim2.new(1, -28, 0, 32)
UI.PartnerSeatLabel.Position = UDim2.new(0, 14, 0, 132)
UI.PartnerSeatLabel.BackgroundTransparency = 1
UI.PartnerSeatLabel.Text = "Partner seat: not set"
UI.PartnerSeatLabel.TextColor3 = COLORS.textMuted
UI.PartnerSeatLabel.TextSize = 11
UI.PartnerSeatLabel.Font = Enum.Font.GothamMedium
UI.PartnerSeatLabel.TextWrapped = true
UI.PartnerSeatLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.PartnerSeatLabel.ZIndex = 21
UI.PartnerSeatLabel.Parent = UI.MainFarmSetup

local markPartnerSeatBtn = Instance.new("TextButton")
markPartnerSeatBtn.Size = UDim2.new(1, -28, 0, 36)
markPartnerSeatBtn.Position = UDim2.new(0, 14, 0, 168)
markPartnerSeatBtn.BackgroundColor3 = COLORS.surface
markPartnerSeatBtn.Text = "Choose Partner Seat"
markPartnerSeatBtn.TextColor3 = COLORS.text
markPartnerSeatBtn.TextSize = 12
markPartnerSeatBtn.Font = Enum.Font.GothamSemibold
markPartnerSeatBtn.ZIndex = 21
markPartnerSeatBtn.Parent = UI.MainFarmSetup
applyCorner(markPartnerSeatBtn, RADIUS.md)

UI.PartnerLabel = Instance.new("TextLabel")
UI.PartnerLabel.Size = UDim2.new(1, -28, 0, 24)
UI.PartnerLabel.Position = UDim2.new(0, 14, 0, 212)
UI.PartnerLabel.BackgroundTransparency = 1
UI.PartnerLabel.Text = "Partner: not chosen"
UI.PartnerLabel.TextColor3 = COLORS.textMuted
UI.PartnerLabel.TextSize = 11
UI.PartnerLabel.Font = Enum.Font.GothamMedium
UI.PartnerLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.PartnerLabel.ZIndex = 21
UI.PartnerLabel.Parent = UI.MainFarmSetup

UI.PartnerSelectBtn = Instance.new("TextButton")
UI.PartnerSelectBtn.Size = UDim2.new(1, -28, 0, 32)
UI.PartnerSelectBtn.Position = UDim2.new(0, 14, 0, 236)
UI.PartnerSelectBtn.BackgroundColor3 = COLORS.surface
UI.PartnerSelectBtn.Text = "Choose Partner..."
UI.PartnerSelectBtn.TextColor3 = COLORS.text
UI.PartnerSelectBtn.TextSize = 12
UI.PartnerSelectBtn.Font = Enum.Font.GothamSemibold
UI.PartnerSelectBtn.ZIndex = 21
UI.PartnerSelectBtn.AutoButtonColor = false
UI.PartnerSelectBtn.Parent = UI.MainFarmSetup
applyCorner(UI.PartnerSelectBtn, RADIUS.md)

UI.PartnerDistanceLabel = Instance.new("TextLabel")
UI.PartnerDistanceLabel.Size = UDim2.new(1, -28, 0, 18)
UI.PartnerDistanceLabel.Position = UDim2.new(0, 14, 0, 272)
UI.PartnerDistanceLabel.BackgroundTransparency = 1
UI.PartnerDistanceLabel.Text = "Distance: —"
UI.PartnerDistanceLabel.TextColor3 = COLORS.textMuted
UI.PartnerDistanceLabel.TextSize = 10
UI.PartnerDistanceLabel.Font = Enum.Font.GothamMedium
UI.PartnerDistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.PartnerDistanceLabel.ZIndex = 21
UI.PartnerDistanceLabel.Parent = UI.MainFarmSetup

updateSaveClickStatusLabel = function()
    if not UI.SaveClickStatusLabel then return end
    local pts = MainFarmState.saveClickPoints or {}
    local keys = { "menu", "saves", "slot", "load", "confirm", "close" }
    local setCount = 0
    for _, key in ipairs(keys) do
        if pts[key] and pts[key].x ~= nil then
            setCount += 1
        end
    end
    if setCount == 6 then
        UI.SaveClickStatusLabel.Text = "All 6 points set — use Test Save Clicks to verify"
        UI.SaveClickStatusLabel.TextColor3 = COLORS.success
    else
        UI.SaveClickStatusLabel.Text = "Points set: " .. setCount .. "/6 — Menu, Saves, slot, Load, Confirm, Close"
        UI.SaveClickStatusLabel.TextColor3 = COLORS.textMuted
    end
end

local function persistSaveClickPointsFromUI()
    pcall(function()
        if writefile then
            if makefolder and isfolder and not isfolder("ScriptHub") then
                makefolder("ScriptHub")
            end
            writefile("ScriptHub/babft_save_clicks.json", HttpService:JSONEncode(MainFarmState.saveClickPoints or {}))
        end
    end)
    updateSaveClickStatusLabel()
end

local function makeScreenMarkerDraggable(marker, handle, onDragEnd)
    local dragging = false
    local dragStart, frameStart

    handle.InputBegan:Connect(function(input)
        if MainFarmState.saveClickAutomation then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = marker.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or MainFarmState.saveClickAutomation then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            marker.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if onDragEnd then
                onDragEnd()
            end
        end
    end)
end

local MARKER_DEFAULTS = {
    menu = UDim2.new(0.08, -24, 0.72, -24),
    saves = UDim2.new(0.18, -24, 0.72, -24),
    slot = UDim2.new(0.35, -24, 0.42, -24),
    load = UDim2.new(0.55, -24, 0.58, -24),
    confirm = UDim2.new(0.65, -24, 0.58, -24),
    close = UDim2.new(0.75, -24, 0.72, -24),
}

ensureClickPointMarker = function(pointKey, labelText)
    local markerName = "NightFallClickPoint" .. pointKey
    if not MainFarmState.saveClickPoints then
        MainFarmState.saveClickPoints = {}
    end

    local marker = ScreenGui:FindFirstChild(markerName)
    if not marker then
        marker = Instance.new("Frame")
        marker.Name = markerName
        marker.Size = UDim2.new(0, 48, 0, 48)
        marker.BackgroundTransparency = 1
        marker.Active = true
        marker.ZIndex = 300
        marker.Parent = ScreenGui

        local circle = Instance.new("TextButton")
        circle.Name = "Circle"
        circle.Size = UDim2.new(1, 0, 1, 0)
        circle.BackgroundColor3 = Color3.fromRGB(55, 120, 255)
        circle.BackgroundTransparency = 0.2
        circle.Text = labelText
        circle.TextColor3 = Color3.fromRGB(255, 255, 255)
        circle.TextSize = 18
        circle.Font = Enum.Font.GothamBold
        circle.AutoButtonColor = false
        circle.ZIndex = 301
        circle.Parent = marker
        applyCorner(circle, 24)
        applyStroke(circle, Color3.fromRGB(120, 180, 255), 2, 0)

        makeScreenMarkerDraggable(marker, circle, function()
            if MainFarmState.saveClickAutomation then return end
            local center = marker.AbsolutePosition + marker.AbsoluteSize / 2
            MainFarmState.saveClickPoints[pointKey] = { x = center.X, y = center.Y }
            persistSaveClickPointsFromUI()
        end)
    end

    local saved = MainFarmState.saveClickPoints[pointKey]
    if saved and saved.x then
        marker.Position = UDim2.fromOffset(saved.x - 24, saved.y - 24)
    else
        marker.Position = MARKER_DEFAULTS[pointKey] or UDim2.new(0.5, -24, 0.5, -24)
    end

    marker.Visible = true
    return marker
end

task.defer(function()
    local pts = MainFarmState.saveClickPoints
    if not pts then return end
    for _, key in ipairs({ "menu", "saves", "slot", "load", "confirm", "close" }) do
        if pts[key] and pts[key].x then
            ensureClickPointMarker(key, key == "menu" and "1" or key == "saves" and "2" or key == "slot" and "3" or key == "load" and "4" or key == "confirm" and "5" or "6")
            local marker = ScreenGui:FindFirstChild("NightFallClickPoint" .. key)
            if marker then
                marker.Visible = false
            end
        end
    end
    updateSaveClickStatusLabel()
end)

UI.FarmBuildStatusLabel = Instance.new("TextLabel")
UI.FarmBuildStatusLabel.Size = UDim2.new(1, -28, 0, 24)
UI.FarmBuildStatusLabel.Position = UDim2.new(0, 14, 0, 294)
UI.FarmBuildStatusLabel.BackgroundTransparency = 1
UI.FarmBuildStatusLabel.Text = ""
UI.FarmBuildStatusLabel.TextColor3 = COLORS.textMuted
UI.FarmBuildStatusLabel.TextSize = 10
UI.FarmBuildStatusLabel.Font = Enum.Font.GothamMedium
UI.FarmBuildStatusLabel.TextWrapped = true
UI.FarmBuildStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.FarmBuildStatusLabel.ZIndex = 21
UI.FarmBuildStatusLabel.Parent = UI.MainFarmSetup

local startBoatFarmBtn = Instance.new("TextButton")
startBoatFarmBtn.Size = UDim2.new(0.48, -16, 0, 34)
startBoatFarmBtn.Position = UDim2.new(0, 14, 1, -48)
startBoatFarmBtn.BackgroundColor3 = COLORS.success
startBoatFarmBtn.Text = "Start Farm"
startBoatFarmBtn.TextColor3 = COLORS.text
startBoatFarmBtn.TextSize = 13
startBoatFarmBtn.Font = Enum.Font.GothamBold
startBoatFarmBtn.ZIndex = 21
startBoatFarmBtn.Parent = UI.MainFarmSetup
applyCorner(startBoatFarmBtn, RADIUS.md)

local cancelSetupBtn = Instance.new("TextButton")
cancelSetupBtn.Size = UDim2.new(0.48, -16, 0, 34)
cancelSetupBtn.Position = UDim2.new(0.52, 2, 1, -48)
cancelSetupBtn.BackgroundColor3 = COLORS.danger
cancelSetupBtn.Text = "Cancel"
cancelSetupBtn.TextColor3 = COLORS.text
cancelSetupBtn.TextSize = 13
cancelSetupBtn.Font = Enum.Font.GothamBold
cancelSetupBtn.ZIndex = 21
cancelSetupBtn.Parent = UI.MainFarmSetup
applyCorner(cancelSetupBtn, RADIUS.md)

markYourSeatBtn.MouseButton1Click:Connect(function()
    openSeatPicker(function(seat)
        if not seat or not isSeatPart(seat) then return end
        MainFarmState.yourSeat = seat
        MainFarmState.yourSeatName = seat.Name
        MainFarmState.yourSeatMarkPos = seat.Position
        MainFarmState.yourSeatPos = seat.Position
        if persistFarmSetup then persistFarmSetup() end
        updateMainFarmSetupLabels()
        setFarmStatus("Your seat: " .. seat.Name, "ok")
    end, "Choose Your Seat")
end)

markPartnerSeatBtn.MouseButton1Click:Connect(function()
    openSeatPicker(function(seat)
        if not seat or not isSeatPart(seat) then return end
        if seat == MainFarmState.yourSeat then
            setFarmStatus("Partner seat must be different from your seat", "error")
            return
        end
        MainFarmState.partnerSeat = seat
        MainFarmState.partnerSeatName = seat.Name
        MainFarmState.partnerSeatMarkPos = seat.Position
        MainFarmState.partnerSeatPos = seat.Position
        if persistFarmSetup then persistFarmSetup() end
        updateMainFarmSetupLabels()
        setFarmStatus("Partner seat: " .. seat.Name, "ok")
    end, "Choose Partner Seat", MainFarmState.yourSeat)
end)

UI.PartnerSelectBtn.MouseButton1Click:Connect(function()
    openPlayerPicker(function(plr)
        MainFarmState.partner = plr
        MainFarmState.savedPartnerName = plr.Name
        if persistFarmSetup then persistFarmSetup() end
        updateMainFarmSetupLabels()
        startPartnerESP(plr)
        if MainFarmState.active and rebindPartnerDeathWatch then
            rebindPartnerDeathWatch(plr)
        end
    end, "Select Farm Partner")
end)


UI.PlayerPickerPopout = Instance.new("Frame")
UI.PlayerPickerPopout.Name = "PlayerPickerPopout"
UI.PlayerPickerPopout.Size = UDim2.new(0, 320, 0, 380)
UI.PlayerPickerPopout.Position = UDim2.new(0.5, -160, 0.5, -190)
UI.PlayerPickerPopout.BackgroundColor3 = COLORS.bg
UI.PlayerPickerPopout.Visible = false
UI.PlayerPickerPopout.ZIndex = 40
UI.PlayerPickerPopout.Active = true
UI.PlayerPickerPopout.Parent = ScreenGui
applyCorner(UI.PlayerPickerPopout, RADIUS.lg)
applyStroke(UI.PlayerPickerPopout, COLORS.accent, 1.5, 0.2)

local pickerDragBar = Instance.new("Frame")
pickerDragBar.Size = UDim2.new(1, 0, 0, 44)
pickerDragBar.BackgroundTransparency = 1
pickerDragBar.ZIndex = 41
pickerDragBar.Parent = UI.PlayerPickerPopout
makeDraggable(UI.PlayerPickerPopout, pickerDragBar)

UI.PickerTitle = Instance.new("TextLabel")
UI.PickerTitle.Size = UDim2.new(1, -50, 0, 24)
UI.PickerTitle.Position = UDim2.new(0, 14, 0, 10)
UI.PickerTitle.BackgroundTransparency = 1
UI.PickerTitle.Text = "Select Player"
UI.PickerTitle.TextColor3 = COLORS.text
UI.PickerTitle.TextSize = 15
UI.PickerTitle.Font = Enum.Font.GothamBold
UI.PickerTitle.TextXAlignment = Enum.TextXAlignment.Left
UI.PickerTitle.ZIndex = 42
UI.PickerTitle.Parent = pickerDragBar

local pickerCloseBtn = Instance.new("TextButton")
pickerCloseBtn.Size = UDim2.new(0, 28, 0, 28)
pickerCloseBtn.Position = UDim2.new(1, -38, 0, 8)
pickerCloseBtn.BackgroundColor3 = COLORS.elevated
pickerCloseBtn.Text = "×"
pickerCloseBtn.TextColor3 = COLORS.textMuted
pickerCloseBtn.TextSize = 18
pickerCloseBtn.Font = Enum.Font.GothamBold
pickerCloseBtn.ZIndex = 42
pickerCloseBtn.AutoButtonColor = false
pickerCloseBtn.Parent = pickerDragBar
applyCorner(pickerCloseBtn, RADIUS.sm)
pickerCloseBtn.MouseButton1Click:Connect(closePlayerPicker)
pickerCloseBtn.Activated:Connect(closePlayerPicker)

UI.PickerScroll = Instance.new("ScrollingFrame")
UI.PickerScroll.Size = UDim2.new(1, -20, 1, -56)
UI.PickerScroll.Position = UDim2.new(0, 10, 0, 48)
UI.PickerScroll.BackgroundColor3 = COLORS.surface
UI.PickerScroll.BorderSizePixel = 0
UI.PickerScroll.ScrollBarThickness = 4
UI.PickerScroll.ScrollBarImageColor3 = COLORS.border
UI.PickerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
UI.PickerScroll.CanvasSize = UDim2.new()
UI.PickerScroll.ZIndex = 41
UI.PickerScroll.Parent = UI.PlayerPickerPopout
applyCorner(UI.PickerScroll, RADIUS.md)

local pickerListLayout = Instance.new("UIListLayout")
pickerListLayout.Padding = UDim.new(0, 6)
pickerListLayout.Parent = UI.PickerScroll

local pickerListPad = Instance.new("UIPadding")
pickerListPad.PaddingTop = UDim.new(0, 6)
pickerListPad.PaddingBottom = UDim.new(0, 6)
pickerListPad.PaddingLeft = UDim.new(0, 6)
pickerListPad.PaddingRight = UDim.new(0, 6)
pickerListPad.Parent = UI.PickerScroll

Players.PlayerAdded:Connect(function()
    if UI.PlayerPickerPopout and UI.PlayerPickerPopout.Visible then
        refreshPlayerPickerList()
    end
end)
Players.PlayerRemoving:Connect(function()
    if UI.PlayerPickerPopout and UI.PlayerPickerPopout.Visible then
        refreshPlayerPickerList()
    end
end)

UI.SeatPickerPopout = Instance.new("Frame")
UI.SeatPickerPopout.Name = "SeatPickerPopout"
UI.SeatPickerPopout.Size = UDim2.new(0, 340, 0, 400)
UI.SeatPickerPopout.Position = UDim2.new(0.5, -170, 0.5, -200)
UI.SeatPickerPopout.BackgroundColor3 = COLORS.bg
UI.SeatPickerPopout.Visible = false
UI.SeatPickerPopout.ZIndex = 50
UI.SeatPickerPopout.Active = true
UI.SeatPickerPopout.Parent = ScreenGui
applyCorner(UI.SeatPickerPopout, RADIUS.lg)
applyStroke(UI.SeatPickerPopout, COLORS.accent, 1.5, 0.2)

local seatPickerDragBar = Instance.new("Frame")
seatPickerDragBar.Size = UDim2.new(1, 0, 0, 44)
seatPickerDragBar.BackgroundTransparency = 1
seatPickerDragBar.ZIndex = 51
seatPickerDragBar.Parent = UI.SeatPickerPopout
makeDraggable(UI.SeatPickerPopout, seatPickerDragBar)

UI.SeatPickerTitle = Instance.new("TextLabel")
UI.SeatPickerTitle.Size = UDim2.new(1, -50, 0, 24)
UI.SeatPickerTitle.Position = UDim2.new(0, 14, 0, 10)
UI.SeatPickerTitle.BackgroundTransparency = 1
UI.SeatPickerTitle.Text = "Select Seat"
UI.SeatPickerTitle.TextColor3 = COLORS.text
UI.SeatPickerTitle.TextSize = 15
UI.SeatPickerTitle.Font = Enum.Font.GothamBold
UI.SeatPickerTitle.TextXAlignment = Enum.TextXAlignment.Left
UI.SeatPickerTitle.ZIndex = 52
UI.SeatPickerTitle.Parent = seatPickerDragBar

local seatPickerCloseBtn = Instance.new("TextButton")
seatPickerCloseBtn.Size = UDim2.new(0, 28, 0, 28)
seatPickerCloseBtn.Position = UDim2.new(1, -38, 0, 8)
seatPickerCloseBtn.BackgroundColor3 = COLORS.elevated
seatPickerCloseBtn.Text = "×"
seatPickerCloseBtn.TextColor3 = COLORS.textMuted
seatPickerCloseBtn.TextSize = 18
seatPickerCloseBtn.Font = Enum.Font.GothamBold
seatPickerCloseBtn.ZIndex = 52
seatPickerCloseBtn.AutoButtonColor = false
seatPickerCloseBtn.Parent = seatPickerDragBar
applyCorner(seatPickerCloseBtn, RADIUS.sm)
seatPickerCloseBtn.MouseButton1Click:Connect(closeSeatPicker)
seatPickerCloseBtn.Activated:Connect(closeSeatPicker)

UI.SeatPickerScroll = Instance.new("ScrollingFrame")
UI.SeatPickerScroll.Size = UDim2.new(1, -20, 1, -56)
UI.SeatPickerScroll.Position = UDim2.new(0, 10, 0, 48)
UI.SeatPickerScroll.BackgroundColor3 = COLORS.surface
UI.SeatPickerScroll.BorderSizePixel = 0
UI.SeatPickerScroll.ScrollBarThickness = 4
UI.SeatPickerScroll.ScrollBarImageColor3 = COLORS.border
UI.SeatPickerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
UI.SeatPickerScroll.CanvasSize = UDim2.new()
UI.SeatPickerScroll.ZIndex = 51
UI.SeatPickerScroll.Active = false
UI.SeatPickerScroll.Parent = UI.SeatPickerPopout
applyCorner(UI.SeatPickerScroll, RADIUS.md)

local seatPickerListLayout = Instance.new("UIListLayout")
seatPickerListLayout.Padding = UDim.new(0, 6)
seatPickerListLayout.Parent = UI.SeatPickerScroll

local seatPickerListPad = Instance.new("UIPadding")
seatPickerListPad.PaddingTop = UDim.new(0, 6)
seatPickerListPad.PaddingBottom = UDim.new(0, 6)
seatPickerListPad.PaddingLeft = UDim.new(0, 6)
seatPickerListPad.PaddingRight = UDim.new(0, 6)
seatPickerListPad.Parent = UI.SeatPickerScroll


startBoatFarmBtn.MouseButton1Click:Connect(function()
    if beginBoatFarmFromSetup then
        beginBoatFarmFromSetup()
    end
end)

beginBoatFarmFromSetup = function()
    stopPartPicker()
    if loadPersistedFarmSetup then
        loadPersistedFarmSetup()
    end
    if resolveSavedFarmPartner then
        resolveSavedFarmPartner()
    end

    local blocker = getFarmSetupBlocker({ skipBuildCheck = Config.AutoLoadSave })
    if blocker then
        setFarmStatus(blocker, "error")
        openMainFarmSetup(true)
        return false
    end

    setFarmStatus("Starting farm...", "info")
    startBoatFarmBtn.Text = "Starting..."
    startBoatFarmBtn.Active = false

    MainFarmState.farmEnabled = true
    MainFarmState.autoResume = true
    if persistFarmSetup then persistFarmSetup() end

    task.spawn(function()
        local ok, err = pcall(startBoatAutoFarm)
        startBoatFarmBtn.Text = "Start Farm"
        startBoatFarmBtn.Active = true
        if not ok then
            warn("[NightFall] Boat farm error:", err)
            setFarmStatus("Error: " .. tostring(err), "error")
            stopBoatAutoFarm(true)
            openMainFarmSetup(true)
        end
    end)

    return true
end

Players.PlayerAdded:Connect(function(plr)
    if MainFarmState.savedPartnerName and plr.Name == MainFarmState.savedPartnerName then
        MainFarmState.partner = plr
        if updateMainFarmSetupLabels then
            updateMainFarmSetupLabels()
        end
        if MainFarmState.farmEnabled and rebindPartnerDeathWatch then
            rebindPartnerDeathWatch(plr)
        end
    end
end)

cancelSetupBtn.MouseButton1Click:Connect(function()
    if MainFarmState.active then
        stopBoatAutoFarm()
        setHubToggle(UI.BoatFarmToggle, false)
    end
    closeMainFarmSetup()
end)
end)()

;(function()
local PlayerPage = UI.PlayerPage
local SettingsPage = UI.SettingsPage

UI.FlyToggle = createHubButton(PlayerPage, "Fly", "E up, look + WASD (same as boat fly)")
UI.NoClipToggle = createHubButton(PlayerPage, "No Clip", "Walk through walls")
UI.SpeedToggle = createHubButton(PlayerPage, "Speed Boost", "Increase walk speed")
UI.JumpToggle = createHubButton(PlayerPage, "Infinite Jump", "Space to jump in air")
UI.BoatFlyToggle = createHubButton(PlayerPage, "Boat Fly", "E up, look + WASD while seated")

UI.FlyToggle.MouseButton1Click:Connect(function()
    setFlyEnabled(not Config.Fly)
    setHubToggle(UI.FlyToggle, Config.Fly)
end)

UI.NoClipToggle.MouseButton1Click:Connect(function()
    Config.NoClip = not Config.NoClip
    setHubToggle(UI.NoClipToggle, Config.NoClip)
end)

UI.SpeedToggle.MouseButton1Click:Connect(function()
    Config.SpeedBoost = not Config.SpeedBoost
    setHubToggle(UI.SpeedToggle, Config.SpeedBoost)
    applySpeed()
end)

UI.JumpToggle.MouseButton1Click:Connect(function()
    Config.InfiniteJump = not Config.InfiniteJump
    setHubToggle(UI.JumpToggle, Config.InfiniteJump)
end)

UI.BoatFlyToggle.MouseButton1Click:Connect(function()
    setBoatFlyEnabled(not Config.BoatFly)
    setHubToggle(UI.BoatFlyToggle, Config.BoatFly)
end)

UI.FarmMethodBtn = createHubButton(SettingsPage, "Farm Method", "Stages 1-10 then golden chest, repeat")
if UI.FarmMethodBtn then
    UI.FarmMethodBtn.Active = false
    UI.FarmMethodBtn.AutoButtonColor = false
end

createInputRow(SettingsPage, "Farm Delay", Config.FarmDelay, function(val)
    Config.FarmDelay = math.clamp(val or 2, 0.5, 10)
end)

createInputRow(SettingsPage, "Tween Time", Config.FarmTweenTime, function(val)
    Config.FarmTweenTime = math.clamp(val or 2.5, 1, 8)
end)

createInputRow(SettingsPage, "Chest Wait", Config.ChestWait, function(val)
    Config.ChestWait = math.clamp(val or 10, 3, 30)
end)

createInputRow(SettingsPage, "Fly Speed", Config.FlySpeed, function(val)
    Config.FlySpeed = math.clamp(val or 200, 10, 200)
end)

createInputRow(SettingsPage, "Walk Speed", Config.WalkSpeed, function(val)
    Config.WalkSpeed = math.clamp(val or 50, 16, 200)
    applySpeed()
end)

createHubSlider(SettingsPage, "Toggle Button Size", 24, 100, State.toggleCubeSize, function(value)
    applyToggleCubeSize(value)
end)
end)()

;(function()
local MainFrame = UI.HubMainFrame
local Header = UI.HubHeader

local hubVisible = true
local function setHubVisible(visible)
    hubVisible = visible
    MainFrame.Visible = visible
end

UI.CloseBtn.MouseButton1Click:Connect(function()
    setHubVisible(false)
end)

local dragging = false
local dragStart, frameStart
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        frameStart = MainFrame.Position
    end
end)

local toggleDragging = false
local toggleDragStart, toggleStartPos
local toggleMoved = false
local TOGGLE_DRAG_THRESHOLD = 8

UI.ToggleCube.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleMoved = false
        toggleDragStart = input.Position
        toggleStartPos = UI.ToggleGui.Position
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if toggleDragging and not toggleMoved then
            setHubVisible(not hubVisible)
        end
        toggleDragging = false
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if toggleDragging then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - toggleDragStart
            if delta.Magnitude > TOGGLE_DRAG_THRESHOLD then
                toggleMoved = true
            end
            if toggleMoved then
                UI.ToggleGui.Position = UDim2.new(
                    toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X,
                    toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y
                )
            end
        end
    end

    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            frameStart.X.Scale, frameStart.X.Offset + delta.X,
            frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
        )
    end
end)
end)()

;(function()

--- ENGINE ---

UserInputService.JumpRequest:Connect(function()
    if Config.BoatFly and isPlayerSeated() then
        return
    elseif Config.Fly and FlyState.bv and not UserInputService.TouchEnabled then
        -- Mobile rise is handled via MobileFly.rising in getBoatFlyVelocity
        FlyState.bv.Velocity += Vector3.new(0, Config.FlySpeed, 0)
    elseif Config.InfiniteJump then
        local _, _, hum = getCharacter()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.RenderStepped:Connect(function()
    if Config.BoatFly and isPlayerSeated() then
        local _, _, hum = getCharacter()
        local flyPart = getBoatFlyPart()
        if not flyPart or not hum then return end

        if not BoatFlyState.bv or BoatFlyState.bv.Parent ~= flyPart then
            if BoatFlyState.bv then BoatFlyState.bv:Destroy() end
            BoatFlyState.bv = Instance.new("BodyVelocity")
            BoatFlyState.bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            BoatFlyState.bv.Velocity = Vector3.zero
            BoatFlyState.bv.Parent = flyPart
        end
        if not BoatFlyState.bg or BoatFlyState.bg.Parent ~= flyPart then
            if BoatFlyState.bg then BoatFlyState.bg:Destroy() end
            BoatFlyState.bg = Instance.new("BodyGyro")
            BoatFlyState.bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            BoatFlyState.bg.P = 1e6
            BoatFlyState.bg.CFrame = flyPart.CFrame
            BoatFlyState.bg.Parent = flyPart
        end

        local cam = workspace.CurrentCamera
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
        local flyVel = getFarmBoatFlyVelocity()
        BoatFlyState.bv.Velocity = flyVel
        if FarmState.farmBoatFlyActive then
            if flyVel.Magnitude > 1 then
                local flat = Vector3.new(flyVel.X, 0, flyVel.Z)
                if flat.Magnitude > 0.5 then
                    BoatFlyState.bg.CFrame = CFrame.new(flyPart.Position, flyPart.Position + flat.Unit)
                else
                    BoatFlyState.bg.CFrame = flyPart.CFrame
                end
            else
                BoatFlyState.bg.CFrame = flyPart.CFrame
            end
        else
            local look = cam.CFrame.LookVector
            BoatFlyState.bg.CFrame = CFrame.new(flyPart.Position, flyPart.Position + look)
        end
        return
    elseif BoatFlyState.bv or BoatFlyState.bg then
        if BoatFlyState.bv then BoatFlyState.bv:Destroy() BoatFlyState.bv = nil end
        if BoatFlyState.bg then BoatFlyState.bg:Destroy() BoatFlyState.bg = nil end
        local _, _, hum = getCharacter()
        if hum then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
        end
    end

    if not Config.Fly then return end
    local _, hrp, hum = getCharacter()
    if not hrp or not hum then return end

    if not FlyState.bv or not FlyState.bv.Parent then
        FlyState.bv = Instance.new("BodyVelocity")
        FlyState.bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        FlyState.bv.Velocity = Vector3.zero
        FlyState.bv.Parent = hrp
    end
    if not FlyState.bg or not FlyState.bg.Parent then
        FlyState.bg = Instance.new("BodyGyro")
        FlyState.bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        FlyState.bg.P = 1e6
        FlyState.bg.CFrame = hrp.CFrame
        FlyState.bg.Parent = hrp
    end

    -- PlatformStand disables the humanoid movement system on mobile,
    -- which zeroes MoveDirection and breaks thumbstick fly. Skip it on touch.
    if not UserInputService.TouchEnabled then
        hum.PlatformStand = true
    end
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)

    if FarmState.chestHoldActive and FarmState.chestHoldPos then
        pcall(function()
            hrp.CFrame = CFrame.new(FarmState.chestHoldPos)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        FlyState.bv.Velocity = Vector3.zero
        FlyState.bg.CFrame = hrp.CFrame
        return
    end

    local flyVel
    if FarmState.chestPushActive then
        local behindCF = getBehindPartnerCF(5)
        if behindCF then
            pcall(function()
                hrp.CFrame = behindCF
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        flyVel = getChestPushFlyVelocity()
    else
        flyVel = getNormalFlyVelocity()
    end

    FlyState.bv.Velocity = flyVel
    local flat = Vector3.new(flyVel.X, 0, flyVel.Z)
    if flat.Magnitude > 0.5 then
        FlyState.bg.CFrame = CFrame.new(hrp.Position, hrp.Position + flat.Unit)
    else
        local cam = workspace.CurrentCamera
        local look = cam.CFrame.LookVector
        FlyState.bg.CFrame = CFrame.new(hrp.Position, hrp.Position + look)
    end
end)

RunService.Stepped:Connect(function()
    if Config.NoClip then
        local char = Player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    local _, hrp, hum = getCharacter()

    setHubToggle(UI.FarmToggle, Config.AutoFarm)
    setHubToggle(UI.CollectToggle, Config.AutoCollect)
    setHubToggle(UI.AntiAFKToggle, Config.AntiAFK)
    setHubToggle(UI.BoatFarmToggle, MainFarmState.farmEnabled)
    setHubToggle(UI.AutoLoadSaveToggle, Config.AutoLoadSave)
    setHubToggle(UI.FlyToggle, Config.Fly)
    setHubToggle(UI.NoClipToggle, Config.NoClip)
    setHubToggle(UI.SpeedToggle, Config.SpeedBoost)
    setHubToggle(UI.JumpToggle, Config.InfiniteJump)
    setHubToggle(UI.BoatFlyToggle, Config.BoatFly)

    if FarmState.tweening and hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.Velocity = Vector3.zero
    end

    if hum and Config.SpeedBoost then
        hum.WalkSpeed = Config.WalkSpeed
    end
end)

task.spawn(function()
    while true do
        task.wait(10)
        if Config.AutoFarm or MainFarmState.active then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(55)
        if Config.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end
end)

Player.CharacterAdded:Connect(function(char)
    FlyState.bv = nil
    FlyState.bg = nil
    BoatFlyState.bv = nil
    BoatFlyState.bg = nil
    if Config.Fly then
        local _, _, hum = getCharacter()
        if hum then hum.PlatformStand = true end
    end
    handleBoatFarmRespawn(char)
    applySpeed()
end)

end)() -- engine hooks (separate scope: Luau 200 local register limit)

task.spawn(function()
    pcall(function()
        workspace:WaitForChild("BoatStages", 25)
    end)
    task.wait(0.25)
    local cleared = clearTheEndObstacles()
    print("[NightFall] Build A Boat For Treasure loaded")
    if cleared > 0 then
        print("[NightFall] Cleared " .. cleared .. " TheEnd wall(s)")
    end
end)

end)() -- separate function scope: Luau 200 local register limit per function
