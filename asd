local Theme = {
    Background = Color3.fromRGB(18,20,25),
    Panel = Color3.fromRGB(28,36,50),
    Accent = Color3.fromRGB(0,150,255),
    AccentAlt = Color3.fromRGB(0,110,220),
    Text = Color3.fromRGB(238,244,250),
    MutedText = Color3.fromRGB(150,170,190),
    Border = Color3.fromRGB(10,100,200),
    BorderSize = 1.6
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hasWriteFile = type(writefile) == "function"
local hasReadFile = type(readfile) == "function"
local hasIsFile = type(isfile) == "function"

local function AddStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or Theme.BorderSize
    s.Color = color or Theme.Border
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function AddCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function HoverEffect(obj, hoverColor, defaultColor)
    local default = defaultColor or obj.BackgroundColor3
    local flash = Theme.AccentAlt
    obj.MouseEnter:Connect(function() if obj and obj.Parent then obj.BackgroundColor3 = hoverColor end end)
    obj.MouseLeave:Connect(function() if obj and obj.Parent then obj.BackgroundColor3 = default end end)
    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
        obj.MouseButton1Click:Connect(function()
            if not obj.Parent then return end
            obj.BackgroundColor3 = flash
            task.delay(0.12, function()
                if not obj.Parent then return end
                local m = nil
                pcall(function() m = Players.LocalPlayer:GetMouse() end)
                if not m then
                    obj.BackgroundColor3 = default
                    return
                end
                local inside = m.X >= obj.AbsolutePosition.X and m.X <= obj.AbsolutePosition.X + obj.AbsoluteSize.X and m.Y >= obj.AbsolutePosition.Y and m.Y <= obj.AbsolutePosition.Y + obj.AbsoluteSize.Y
                obj.BackgroundColor3 = inside and hoverColor or default
            end)
        end)
    end
end

local function CreateGui()
    local existing = playerGui:FindFirstChild("BluHubScreenGui")
    if existing and existing:IsA("ScreenGui") then
        existing:Destroy()
    end
    local g = Instance.new("ScreenGui")
    g.Name = "BluHubScreenGui"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    g.Parent = playerGui
    return g
end

local gui = CreateGui()

local Connections = {}
local function Track(conn)
    table.insert(Connections, conn)
    return conn
end

local function Cleanup()
    for _,c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
    if gui then
        pcall(function() gui:Destroy() end)
    end
end

local function MakeDraggable(header, window)
    local dragging = false
    local startPos, dragStart
    header.InputBegan:Connect(function(ip)
        if ip.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = ip.Position
            startPos = window.Position
            ip.Changed:Connect(function()
                if ip.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    local conn = UserInputService.InputChanged:Connect(function(ip)
        if dragging and ip.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = ip.Position - dragStart
            window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    Track(conn)
end

local function TweenTo(obj, props, dur, style, dir)
    local ti = TweenInfo.new(dur or 0.36, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, ti, props)
    tw:Play()
    return tw
end

local function OffscreenLeft(anchorY)
    return UDim2.new(-1.2, 0, anchorY or 0.5, 0)
end

local function CenterPos(yOffset)
    return UDim2.new(0.5, 0, yOffset or 0.5, 0)
end

local Library = {}
Library._pages = {}
Library._themeCallbacks = {}
Library._settingsPath = "bluhub_settings.json"
Library._openKey = Enum.KeyCode.RightControl
Library._openKeyName = "RightControl"
Library._visible = false
Library._toastCount = 0

local function ApplyThemeToObject(obj)
    pcall(function()
        if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("ImageLabel") then
            if obj:FindFirstChild("BluHubThemeApply") then return end
            local tag = Instance.new("BoolValue")
            tag.Name = "BluHubThemeApply"
            tag.Parent = obj
            table.insert(Library._themeCallbacks, function()
                if not obj.Parent then return end
                if obj:IsA("Frame") then
                    obj.BackgroundColor3 = Theme.Panel
                end
                if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
                    obj.TextColor3 = Theme.Text
                end
                for _,s in ipairs(obj:GetChildren()) do
                    if s:IsA("UIStroke") then s.Color = Theme.Border end
                    if s:IsA("UICorner") then end
                end
            end)
        end
    end)
end

local function SetTheme(t)
    for k,v in pairs(t) do Theme[k] = v end
    for _,cb in ipairs(Library._themeCallbacks) do
        pcall(cb)
    end
end

local function GetTheme()
    local copy = {}
    for k,v in pairs(Theme) do copy[k] = v end
    return copy
end

Library.SetTheme = SetTheme
Library.GetTheme = GetTheme

local function SaveSettings(t)
    local ok, data = pcall(function() return HttpService:JSONEncode(t) end)
    if not ok then return false end
    if hasWriteFile then
        pcall(function() writefile(Library._settingsPath, data) end)
        return true
    else
        return false
    end
end

local function LoadSettings()
    if hasIsFile and hasReadFile and isfile(Library._settingsPath) then
        local raw = readfile(Library._settingsPath)
        local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and parsed then
            return parsed
        end
    end
    return nil
end

local function RegisterHotkey(keyEnum, keyName)
    Library._openKey = keyEnum
    Library._openKeyName = keyName or tostring(keyEnum)
end

local function ToggleVisibility(root)
    Library._visible = not Library._visible
    if Library._visible then
        root.Visible = true
        TweenTo(root, {Position = CenterPos()}, 0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    else
        TweenTo(root, {Position = OffscreenLeft(0.5)}, 0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.34, function()
            if root then root.Visible = false end
        end)
    end
end

local function Toast(text, kind, duration)
    duration = duration or 3
    kind = kind or "info"
    Library._toastCount = Library._toastCount + 1
    local id = Library._toastCount
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 340, 0, 48)
    toast.Position = UDim2.new(1, -360, 0, 20 + (id-1) * 58)
    toast.AnchorPoint = Vector2.new(0, 0)
    toast.BackgroundColor3 = Theme.Panel
    toast.Parent = gui
    AddCorner(toast, 10)
    AddStroke(toast, Theme.Border, Theme.BorderSize)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = toast
    TweenTo(toast, {Position = UDim2.new(1, -360, 0, 20 + (id-1) * 58)}, 0.18)
    task.delay(duration, function()
        pcall(function()
            TweenTo(toast, {Position = UDim2.new(1, 20, 0, 20 + (id-1) * 58)}, 0.22)
            task.delay(0.23, function() toast:Destroy() end)
        end)
    end)
end

Library.Toast = Toast

local TooltipFrame = nil
local function ShowTooltip(text, parent)
    if TooltipFrame and TooltipFrame.Parent then TooltipFrame:Destroy() end
    TooltipFrame = Instance.new("Frame")
    TooltipFrame.Size = UDim2.new(0, 220, 0, 36)
    TooltipFrame.BackgroundColor3 = Theme.Panel
    TooltipFrame.Parent = gui
    AddCorner(TooltipFrame, 8)
    AddStroke(TooltipFrame, Theme.Border, Theme.BorderSize)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -16, 1, 0)
    t.Position = UDim2.new(0, 8, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = Theme.MutedText
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = TooltipFrame
    local m = player:GetMouse()
    TooltipFrame.Position = UDim2.new(0, math.clamp(m.X + 12, 8, workspace.CurrentCamera.ViewportSize.X - 240), 0, math.clamp(m.Y + 12, 8, workspace.CurrentCamera.ViewportSize.Y - 48))
end

local function HideTooltip()
    if TooltipFrame and TooltipFrame.Parent then
        pcall(function() TooltipFrame:Destroy() end)
    end
end

local function AttachTooltip(obj, text)
    obj.MouseEnter:Connect(function() ShowTooltip(text, obj) end)
    obj.MouseLeave:Connect(function() HideTooltip() end)
end

local function CreateWindow(title, width, height)
    local root = Instance.new("Frame")
    root.Size = UDim2.new(0, width or 520, 0, height or 360)
    root.Position = CenterPos()
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.BackgroundColor3 = Theme.Panel
    root.Parent = gui
    root.Visible = true
    AddCorner(root, 12)
    AddStroke(root, Theme.Border, Theme.BorderSize)
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = Color3.fromRGB(24,30,40)
    header.Parent = root
    AddCorner(header, 10)
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -64, 1, 0)
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title or "Window"
    titleLbl.TextColor3 = Theme.Text
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.TextSize = 16
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 44, 0, 30)
    closeBtn.Position = UDim2.new(1, -54, 0, 7)
    closeBtn.BackgroundColor3 = Theme.Panel
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Theme.Text
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = header
    AddCorner(closeBtn, 8)
    HoverEffect(closeBtn, Color3.fromRGB(42,60,82), Theme.Panel)
    closeBtn.MouseButton1Click:Connect(function() root:Destroy() end)
    MakeDraggable(header, root)
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -24, 1, -64)
    content.Position = UDim2.new(0, 12, 0, 56)
    content.BackgroundTransparency = 1
    content.Parent = root
    return {Root = root, Content = content}
end

Library.CreateWindow = CreateWindow

local function BuildLabel(parent, text, style)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 0, 24)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = text or ""
    if style == "Title" then
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 18
        lbl.TextColor3 = Theme.Text
    elseif style == "Subtitle" then
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextColor3 = Theme.MutedText
    elseif style == "Muted" then
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextColor3 = Theme.MutedText
    else
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextColor3 = Theme.Text
    end
    lbl.Parent = parent
    ApplyThemeToObject(lbl)
    return lbl
end

Library.BuildLabel = BuildLabel

local function BuildButton(parent, label, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -24, 0, 40)
    b.Position = UDim2.new(0, 12, 0, 6)
    b.BackgroundColor3 = Theme.Accent
    b.Text = label or "Button"
    b.TextColor3 = Color3.fromRGB(12,12,12)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 15
    b.Parent = parent
    AddCorner(b, 10)
    AddStroke(b, Theme.Border, Theme.BorderSize)
    HoverEffect(b, Theme.AccentAlt, Theme.Accent)
    if callback then
        b.MouseButton1Click:Connect(function() pcall(callback) end)
    end
    local obj = {}
    function obj.SetText(t)
        b.Text = tostring(t)
    end
    function obj.Click()
        pcall(function() b:CaptureFocus(); b:ReleaseFocus() end)
        pcall(callback)
    end
    ApplyThemeToObject(b)
    return obj
end

Library.BuildButton = BuildButton

local function BuildToggle(parent, label, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -24, 0, 48)
    container.BackgroundTransparency = 1
    container.Parent = parent
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = Theme.Panel
    btn.Text = label or "Toggle"
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.Parent = container
    AddCorner(btn, 12)
    AddStroke(btn, Theme.Border, Theme.BorderSize)
    HoverEffect(btn, Color3.fromRGB(42,60,82), Theme.Panel)
    local state = default and true or false
    local function Update()
        btn.Text = (label or "Toggle") .. ": " .. (state and "ON" or "OFF")
        btn.TextColor3 = state and Theme.Accent or Theme.Text
    end
    Update()
    btn.MouseButton1Click:Connect(function()
        state = not state
        Update()
        if callback then pcall(callback, state) end
    end)
    ApplyThemeToObject(container)
    return {Button = btn, Get = function() return state end, Set = function(v) state = v; Update() end}
end

Library.BuildToggle = BuildToggle

local function BuildSlider(parent, label, min, max, default, callback)
    min = min or 0
    max = max or 100
    default = default or min
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, -24, 0, 84)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.Position = UDim2.new(0, 0, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = (label or "Slider") .. " : " .. tostring(default)
    lbl.TextColor3 = Theme.MutedText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = wrap
    local trackWrap = Instance.new("Frame")
    trackWrap.Size = UDim2.new(1, 0, 0, 36)
    trackWrap.Position = UDim2.new(0, 0, 0, 40)
    trackWrap.BackgroundColor3 = Color3.fromRGB(36,44,60)
    trackWrap.Parent = wrap
    AddCorner(trackWrap, 10)
    AddStroke(trackWrap, Theme.Border, Theme.BorderSize)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -12, 1, 0)
    track.Position = UDim2.new(0, 6, 0, 0)
    track.BackgroundColor3 = Color3.fromRGB(46,56,76)
    track.Parent = trackWrap
    AddCorner(track, 8)
    local frac = math.clamp((default - min) / math.max(1, max - min), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(frac, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.Parent = track
    AddCorner(fill, 8)
    local knobBtn = Instance.new("ImageButton")
    knobBtn.Size = UDim2.new(0, 18, 0, 18)
    knobBtn.Position = UDim2.new(frac, -9, 0.5, -9)
    knobBtn.BackgroundTransparency = 1
    knobBtn.Parent = track
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(1, 0, 1, 0)
    knob.BackgroundColor3 = Theme.AccentAlt
    knob.Parent = knobBtn
    AddCorner(knob, 9)
    AddStroke(knob, Theme.Border, Theme.BorderSize)
    local dragging = false
    local value = default
    knobBtn.InputBegan:Connect(function(ip)
        if ip.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    local conn = UserInputService.InputChanged:Connect(function(ip)
        if dragging and ip.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((ip.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knobBtn.Position = UDim2.new(rel, -9, 0.5, -9)
            value = min + (max - min) * rel
            lbl.Text = (label or "Slider") .. " : " .. string.format("%.2f", value)
            if callback then pcall(callback, value, false) end
        end
    end)
    local conn2 = UserInputService.InputEnded:Connect(function(ip)
        if ip.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            if callback then pcall(callback, value, true) end
        end
    end)
    Track(conn)
    Track(conn2)
    ApplyThemeToObject(wrap)
    return {
        Container = wrap,
        Get = function() return value end,
        Set = function(v)
            value = math.clamp(v, min, max)
            local rel = math.clamp((value - min) / math.max(1, max - min), 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knobBtn.Position = UDim2.new(rel, -9, 0.5, -9)
            lbl.Text = (label or "Slider") .. " : " .. string.format("%.2f", value)
        end
    }
end

Library.BuildSlider = BuildSlider

local function BuildDropdownEx(parent, label, items, multi, callback)
    local dd = BuildDropdown and BuildDropdown(parent, label, items, multi) or nil
    if dd and callback then
        local origGet = dd.Get
        local origSet = dd.Set
        dd._callback = callback
        local function wrapGet() return origGet() end
        local function wrapSet(v)
            origSet(v)
            pcall(callback, v)
        end
        local tbl = {Container = dd.Container, Get = wrapGet, Set = wrapSet}
        ApplyThemeToObject(dd.Container)
        return tbl
    else
        return dd
    end
end

Library.BuildDropdown = BuildDropdownEx

local function BuildTextBoxEx(parent, label, placeholder, callback)
    local tb = BuildTextBox and BuildTextBox(parent, label, placeholder) or nil
    if tb and tb.Raw and callback then
        tb.Raw.FocusLost:Connect(function(enter)
            pcall(callback, tb.Raw.Text, enter)
        end)
    end
    ApplyThemeToObject(tb.Container)
    return tb
end

Library.BuildTextBox = BuildTextBoxEx

local function BuildKeybind(parent, label, defaultKey, callback)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, -24, 0, 48)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label or "Keybind"
    lbl.TextColor3 = Theme.MutedText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = wrap
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.36, -12, 1, 0)
    btn.Position = UDim2.new(0.64, 0, 0, 0)
    btn.BackgroundColor3 = Theme.Panel
    btn.Text = tostring(defaultKey or "None")
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextColor3 = Theme.Text
    btn.Parent = wrap
    AddCorner(btn, 10)
    AddStroke(btn, Theme.Border, Theme.BorderSize)
    HoverEffect(btn, Color3.fromRGB(42,60,82), Theme.Panel)
    local listening = false
    local current = defaultKey
    local keycode = nil
    if type(defaultKey) == "EnumItem" then
        keycode = defaultKey
        btn.Text = tostring(defaultKey.Name)
    elseif type(defaultKey) == "string" then
        btn.Text = defaultKey
    end
    local conn
    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "Press a key..."
        if conn then conn:Disconnect() end
        conn = UserInputService.InputBegan:Connect(function(ip, gp)
            if gp then return end
            if ip.KeyCode then
                current = ip.KeyCode
                btn.Text = tostring(ip.KeyCode.Name)
                listening = false
                conn:Disconnect()
                if callback then pcall(callback, current) end
            elseif ip.UserInputType == Enum.UserInputType.MouseButton1 or ip.UserInputType == Enum.UserInputType.MouseButton2 then
                current = ip.UserInputType
                btn.Text = tostring(ip.UserInputType.Name)
                listening = false
                conn:Disconnect()
                if callback then pcall(callback, current) end
            end
        end)
        Track(conn)
    end)
    ApplyThemeToObject(wrap)
    return {
        Container = wrap,
        Get = function() return current end,
        Set = function(k)
            current = k
            if type(k) == "EnumItem" then btn.Text = k.Name else btn.Text = tostring(k) end
        end
    }
end

Library.BuildKeybind = BuildKeybind

local function BuildColorPicker(parent, label, default, callback)
    default = default or Theme.Accent
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, -24, 0, 110)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Position = UDim2.new(0, 0, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = label or "Color"
    lbl.TextColor3 = Theme.MutedText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = wrap
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 44, 0, 44)
    preview.Position = UDim2.new(1, -56, 0, 24)
    preview.BackgroundColor3 = default
    preview.Parent = wrap
    AddCorner(preview, 10)
    AddStroke(preview, Theme.Border, Theme.BorderSize)
    local rsl = BuildSlider(wrap, "R", 0, 255, default.R * 255, function() end)
    rsl.Container.Position = UDim2.new(0, 0, 0, 30)
    local gsl = BuildSlider(wrap, "G", 0, 255, default.G * 255, function() end)
    gsl.Container.Position = UDim2.new(0, 0, 0, 64)
    local bsl = BuildSlider(wrap, "B", 0, 255, default.B * 255, function() end)
    bsl.Container.Position = UDim2.new(0, 0, 0, 98)
    local function updatePreview()
        local r = rsl.Get()
        local g = gsl.Get()
        local b = bsl.Get()
        local c = Color3.fromRGB(math.clamp(math.floor(r),0,255), math.clamp(math.floor(g),0,255), math.clamp(math.floor(b),0,255))
        preview.BackgroundColor3 = c
        if callback then pcall(callback, c) end
    end
    rsl.Set = rsl.Set or function(v) rsl:Get(); end
    rsl.Container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() end)
    local conn1 = nil
    conn1 = UserInputService.InputChanged:Connect(function() updatePreview() end)
    Track(conn1)
    updatePreview()
    ApplyThemeToObject(wrap)
    return {
        Container = wrap,
        Get = function() return preview.BackgroundColor3 end,
        Set = function(c)
            if type(c) == "table" or type(c) == "userdata" then
                preview.BackgroundColor3 = c
            end
        end
    }
end

Library.BuildColorPicker = BuildColorPicker

local function BuildProgressBar(parent, label, value, max)
    value = value or 0
    max = max or 100
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, -24, 0, 48)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Position = UDim2.new(0, 0, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = label or "Progress"
    lbl.TextColor3 = Theme.MutedText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = wrap
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 18)
    bar.Position = UDim2.new(0, 0, 0, 24)
    bar.BackgroundColor3 = Color3.fromRGB(36,44,60)
    bar.Parent = wrap
    AddCorner(bar, 8)
    AddStroke(bar, Theme.Border, Theme.BorderSize)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp(value/max,0,1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.Parent = bar
    AddCorner(fill, 8)
    local function Set(v)
        v = math.clamp(v, 0, max)
        fill:TweenSize(UDim2.new(v/max, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.24, true)
    end
    ApplyThemeToObject(wrap)
    return {Container = wrap, Set = Set, Get = function() return value end}
end

Library.BuildProgressBar = BuildProgressBar

local function BuildSection(parent, title, collapsible)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, -24, 0, 40)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent
    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 36)
    header.Position = UDim2.new(0, 12, 0, 4)
    header.BackgroundColor3 = Theme.Panel
    header.Text = title or "Section"
    header.TextColor3 = Theme.Text
    header.Font = Enum.Font.GothamSemibold
    header.TextSize = 14
    header.Parent = wrap
    AddCorner(header, 10)
    AddStroke(header, Theme.Border, Theme.BorderSize)
    HoverEffect(header, Color3.fromRGB(42,60,82), Theme.Panel)
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.Position = UDim2.new(0, 0, 0, 44)
    body.BackgroundTransparency = 1
    body.Parent = wrap
    body.ClipsDescendants = true
    local open = true
    if collapsible then
        open = true
        header.MouseButton1Click:Connect(function()
            open = not open
            if open then
                body:TweenSize(UDim2.new(1, 0, 0, 160), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
                wrap:TweenSize(UDim2.new(1, -24, 0, 204), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
            else
                body:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
                wrap:TweenSize(UDim2.new(1, -24, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
            end
        end)
    end
    ApplyThemeToObject(header)
    return {Container = wrap, Body = body, Header = header}
end

Library.BuildSection = BuildSection

local function BuildPlayerListEx(parent, clickCallback)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, -24, 0, 320)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 36)
    top.BackgroundTransparency = 1
    top.Position = UDim2.new(0, 0, 0, 6)
    top.Parent = wrap
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "Players"
    title.TextColor3 = Theme.MutedText
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = top
    local count = Instance.new("TextLabel")
    count.Size = UDim2.new(0.4, -12, 1, 0)
    count.Position = UDim2.new(0.6, 12, 0, 0)
    count.BackgroundTransparency = 1
    count.Text = "0"
    count.TextColor3 = Theme.MutedText
    count.Font = Enum.Font.Gotham
    count.TextSize = 13
    count.TextXAlignment = Enum.TextXAlignment.Right
    count.Parent = top
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, 0, 0, 30)
    searchBox.Position = UDim2.new(0, 0, 0, 40)
    searchBox.PlaceholderText = "Search players..."
    searchBox.BackgroundColor3 = Theme.Panel
    searchBox.TextColor3 = Theme.Text
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.Parent = wrap
    AddCorner(searchBox, 8)
    AddStroke(searchBox, Theme.Border, Theme.BorderSize)
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 0, 220)
    list.Position = UDim2.new(0, 0, 0, 76)
    list.BackgroundTransparency = 0
    list.BackgroundColor3 = Theme.Panel
    list.BorderSizePixel = 0
    list.Parent = wrap
    AddCorner(list, 12)
    AddStroke(list, Theme.Border, Theme.BorderSize)
    list.ScrollBarThickness = 8
    local layout = Instance.new("UIListLayout")
    layout.Parent = list
    layout.Padding = UDim.new(0, 10)
    local function Populate()
        for _,c in ipairs(list:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
        local q = string.lower(searchBox.Text or "")
        local players = Players:GetPlayers()
        count.Text = tostring(#players)
        for _,pl in ipairs(players) do
            if q == "" or string.find(string.lower(pl.Name), q) then
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, -12, 0, 36)
                row.Position = UDim2.new(0, 6, 0, 0)
                row.BackgroundColor3 = Theme.Panel
                row.Text = pl.Name
                row.TextColor3 = Theme.Text
                row.Font = Enum.Font.Gotham
                row.TextSize = 14
                row.Parent = list
                AddCorner(row, 8)
                AddStroke(row, Theme.Border, Theme.BorderSize)
                HoverEffect(row, Color3.fromRGB(42,60,82), Theme.Panel)
                row.MouseButton1Click:Connect(function()
                    pcall(function() if clickCallback then clickCallback(pl) end end)
                end)
            end
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(Populate)
    Players.PlayerAdded:Connect(Populate)
    Players.PlayerRemoving:Connect(Populate)
    Populate()
    ApplyThemeToObject(wrap)
    return wrap
end

Library.BuildPlayerList = BuildPlayerListEx

local function BuildTabs(parentLeft, parentRight)
    local tabs = {}
    local pages = {}
    local function AddTab(name)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 52)
        btn.BackgroundColor3 = Theme.Panel
        btn.Text = name
        btn.TextColor3 = Theme.Text
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 16
        btn.Parent = parentLeft
        AddCorner(btn, 12)
        AddStroke(btn, Theme.Border, Theme.BorderSize)
        HoverEffect(btn, Color3.fromRGB(42,60,82), Theme.Panel)
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -40, 1, -40)
        page.Position = UDim2.new(0, 20, 0, 20)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 10
        page.Parent = parentRight
        AddCorner(page, 10)
        local pl = Instance.new("UIListLayout")
        pl.Parent = page
        pl.Padding = UDim.new(0, 16)
        pages[name] = page
        btn.MouseButton1Click:Connect(function()
            for k,v in pairs(pages) do v.Visible = false end
            page.Visible = true
        end)
        return page
    end
    local function RemoveTab(name)
        if pages[name] then
            pages[name]:Destroy()
            pages[name] = nil
        end
        for i,v in ipairs(parentLeft:GetChildren()) do
            if v:IsA("TextButton") and v.Text == name then v:Destroy() end
        end
    end
    return {
        AddTab = AddTab,
        RemoveTab = RemoveTab,
        Pages = pages
    }
end

Library.BuildTabs = BuildTabs

local function BuildSectionedSettingsPage(rightParent)
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, -40, 1, -40)
    p.Position = UDim2.new(0, 20, 0, 20)
    p.BackgroundTransparency = 1
    p.ScrollBarThickness = 10
    p.Parent = rightParent
    AddCorner(p, 10)
    local pl = Instance.new("UIListLayout")
    pl.Parent = p
    pl.Padding = UDim.new(0, 16)
    do
        local section1 = BuildSection(p, "General", true)
        section1.Container.Parent = p
        local keyLabel = BuildLabel(section1.Body, "Toggle Key", "Muted")
        keyLabel.Parent = section1.Body
        local keybind = BuildKeybind(section1.Body, "Open/Close Key", Library._openKey, function(k)
            if typeof(k) == "EnumItem" then
                Library._openKey = k
                Library._openKeyName = k.Name
            else
                Library._openKeyName = tostring(k)
            end
        end)
        keybind.Container.Parent = section1.Body
        local unloadBtn = BuildButton(section1.Body, "Unload UI", function()
            Cleanup()
        end)
        unloadBtn.SetText = unloadBtn.SetText
        unloadBtn.Container = unloadBtn
        unloadBtn.SetText("Unload")
        do
            local pickerA = BuildColorPicker(section1.Body, "Accent Color", Theme.Accent, function(c)
                SetTheme({Accent = c})
            end)
            pickerA.Container.Parent = section1.Body
            local pickerB = BuildColorPicker(section1.Body, "Accent Alt", Theme.AccentAlt, function(c)
                SetTheme({AccentAlt = c})
            end)
            pickerB.Container.Parent = section1.Body
        end
    end
    do
        local section2 = BuildSection(p, "Appearance", true)
        section2.Container.Parent = p
        local themeBtn = BuildButton(section2.Body, "Reset To Default Theme", function()
            SetTheme({
                Background = Color3.fromRGB(18,20,25),
                Panel = Color3.fromRGB(28,36,50),
                Accent = Color3.fromRGB(0,150,255),
                AccentAlt = Color3.fromRGB(0,110,220),
                Text = Color3.fromRGB(238,244,250),
                MutedText = Color3.fromRGB(150,170,190),
                Border = Color3.fromRGB(10,100,200),
                BorderSize = 1.6
            })
            Toast("Theme reset", "success")
        end)
        themeBtn.Click = themeBtn.Click
        themeBtn.SetText = themeBtn.SetText
        themeBtn.SetText("Reset Theme")
        themeBtn.Container = themeBtn
    end
    do
        local section3 = BuildSection(p, "Settings", true)
        section3.Container.Parent = p
        local saveBtn = BuildButton(section3.Body, "Save Settings", function()
            local s = {
                theme = Library.GetTheme(),
                openKey = Library._openKeyName
            }
            local ok = SaveSettings(s)
            if ok then Toast("Saved settings", "success") else Toast("Save failed", "error") end
        end)
        saveBtn.Container = saveBtn
        local loadBtn = BuildButton(section3.Body, "Load Settings", function()
            local s = LoadSettings()
            if s then
                if s.theme then SetTheme(s.theme) end
                if s.openKey then Library._openKeyName = s.openKey end
                Toast("Loaded settings", "success")
            else
                Toast("No saved settings", "error")
            end
        end)
        loadBtn.Container = loadBtn
    end
    p.Visible = false
    return p
end

local HttpService = game:GetService("HttpService")
local KeySourceUrl = nil
local LocalAllowedKeys = {"FREE-KEY-123","DUCKWAREX-BETA","TESTING-ONLY"}
local FetchedKeys = nil
local FetchingKeys = false

local function ParseKeyList(raw)
    if not raw then return {} end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(parsed) == "table" then
        local out = {}
        for _,v in ipairs(parsed) do if type(v) == "string" then out[v] = true end end
        return out
    end
    local out = {}
    for line in string.gmatch(raw, "[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then out[line] = true end
    end
    return out
end

local function FetchRemoteKeysAsync(url, onDone)
    if FetchingKeys then if onDone then pcall(onDone, false) end return end
    if not url then if onDone then pcall(onDone, false) end return end
    FetchingKeys = true
    task.spawn(function()
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if ok and res then
            FetchedKeys = ParseKeyList(res)
            FetchingKeys = false
            if onDone then pcall(onDone, true) end
        else
            FetchedKeys = {}
            FetchingKeys = false
            if onDone then pcall(onDone, false) end
        end
    end)
end

local function IsKeyAllowed(key)
    if not key then return false end
    if key == "demo" then return true end
    for _,k in ipairs(LocalAllowedKeys) do if tostring(k) == tostring(key) then return true end end
    if FetchedKeys and type(FetchedKeys) == "table" and FetchedKeys[key] then return true end
    return false
end

local function CreateLaunlocal 
    local existing = gui:FindFirstChild("BluLauncher")
    if exising then existing:Destroy() end

	if launcher and type(launcher.SetVisible) == "function" then
    pcall(function() if launcher.Root and launcher.Root.Parent then launcher.Root:Destroy() end end)
end

local function CreateLauncher2()
    local existing = gui:FindFirstChild("BluLauncher")
    if existing then existing:Destroy() end

    local root = Instance.new("Frame")
    root.Name = "BluLauncher"
    root.Size = UDim2.new(0, 560, 0, 380)
    root.Position = OffscreenLeft(0.45)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.BackgroundTransparency = 1
    root.Parent = gui
    AddCorner(root, 14)

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 0, 1, 0)
    shadow.Position = UDim2.new(0, 8, 0, 8)
    shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
    shadow.BackgroundTransparency = 0.85
    shadow.BorderSizePixel = 0
    shadow.Parent = root
    AddCorner(shadow, 14)

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, -12, 1, -12)
    panel.Position = UDim2.new(0, 6, 0, 6)
    panel.BackgroundColor3 = Theme.Panel
    panel.Parent = root
    AddCorner(panel, 14)
    AddStroke(panel, Theme.Border, Theme.BorderSize)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -28, 0, 68)
    header.Position = UDim2.new(0, 14, 0, 14)
    header.BackgroundColor3 = Color3.fromRGB(24,30,40)
    header.Parent = panel
    AddCorner(header, 12)
    AddStroke(header, Theme.Border, Theme.BorderSize)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, -24, 1, 0)
    title.Position = UDim2.new(0, 18, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Enter key & choose"
    title.TextColor3 = Theme.Text
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(0, 56, 0, 36)
    logo.Position = UDim2.new(1, -160, 0, 14)
    logo.BackgroundTransparency = 1
    logo.Image = "rbxassetid://121579464174587"
    logo.Parent = header
    AddCorner(logo, 8)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 44, 0, 36)
    closeBtn.Position = UDim2.new(1, -96, 0, 14)
    closeBtn.BackgroundColor3 = Theme.Panel
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Theme.Text
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 18
    closeBtn.Parent = header
    AddCorner(closeBtn, 8)
    AddStroke(closeBtn, Theme.Border, Theme.BorderSize)
    HoverEffect(closeBtn, Color3.fromRGB(42,60,82), Theme.Panel)
    closeBtn.MouseButton1Click:Connect(function() TweenTo(root, {Position = OffscreenLeft(0.45)}, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In) task.delay(0.28, function() if root and root.Parent then root.Visible = false end end) end)

    MakeDraggable(header, root)

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -28, 1, -108)
    body.Position = UDim2.new(0, 14, 0, 86)
    body.BackgroundTransparency = 1
    body.Parent = panel

    local vlist = Instance.new("UIListLayout")
    vlist.Parent = body
    vlist.Padding = UDim.new(0, 12)

    local keyWrap = Instance.new("Frame")
    keyWrap.Size = UDim2.new(1, 0, 0, 84)
    keyWrap.BackgroundTransparency = 1
    keyWrap.Parent = body

    local keyLbl = Instance.new("TextLabel")
    keyLbl.Size = UDim2.new(1, -24, 0, 18)
    keyLbl.Position = UDim2.new(0, 12, 0, 6)
    keyLbl.BackgroundTransparency = 1
    keyLbl.Text = "Access Key"
    keyLbl.TextColor3 = Theme.MutedText
    keyLbl.Font = Enum.Font.Gotham
    keyLbl.TextSize = 13
    keyLbl.TextXAlignment = Enum.TextXAlignment.Left
    keyLbl.Parent = keyWrap

    local keyBox = Instance.new("TextBox")
    keyBox.Name = "KeyBox"
    keyBox.Size = UDim2.new(1, -156, 0, 40)
    keyBox.Position = UDim2.new(0, 12, 0, 30)
    keyBox.BackgroundColor3 = Theme.Panel
    keyBox.PlaceholderText = "Paste key (demo)"
    keyBox.TextColor3 = Theme.Text
    keyBox.Font = Enum.Font.Gotham
    keyBox.TextSize = 14
    keyBox.ClearTextOnFocus = false
    keyBox.Parent = keyWrap
    AddCorner(keyBox, 10)
    AddStroke(keyBox, Theme.Border, Theme.BorderSize)
    HoverEffect(keyBox, Color3.fromRGB(42,60,82), Theme.Panel)

    local ddBtn = Instance.new("TextButton")
    ddBtn.Size = UDim2.new(0, 120, 0, 40)
    ddBtn.Position = UDim2.new(1, -136, 0, 30)
    ddBtn.BackgroundColor3 = Theme.Panel
    ddBtn.Text = "Game: Test"
    ddBtn.TextColor3 = Theme.Text
    ddBtn.Font = Enum.Font.GothamSemibold
    ddBtn.TextSize = 13
    ddBtn.Parent = keyWrap
    AddCorner(ddBtn, 10)
    AddStroke(ddBtn, Theme.Border, Theme.BorderSize)
    HoverEffect(ddBtn, Color3.fromRGB(42,60,82), Theme.Panel)

    local ddListWrap = Instance.new("Frame")
    ddListWrap.Size = UDim2.new(1, -24, 0, 0)
    ddListWrap.Position = UDim2.new(0, 12, 0, 76)
    ddListWrap.ClipsDescendants = true
    ddListWrap.BackgroundColor3 = Theme.Panel
    ddListWrap.Parent = body
    AddCorner(ddListWrap, 10)
    AddStroke(ddListWrap, Theme.Border, Theme.BorderSize)

    local ddLayout = Instance.new("UIListLayout")
    ddLayout.Parent = ddListWrap
    ddLayout.Padding = UDim.new(0, 8)
    ddLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local games = {"Test","Game A","Game B"}
    local ddExpanded = false
    local function ToggleDD()
        ddExpanded = not ddExpanded
        if ddExpanded then
            local target = math.clamp(#games * 34 + 12, 0, 260)
            ddListWrap:TweenSize(UDim2.new(1, -24, 0, target), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        else
            ddListWrap:TweenSize(UDim2.new(1, -24, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        end
    end

    ddBtn.MouseButton1Click:Connect(ToggleDD)

    local selectedGame = games[1]
    for _,g in ipairs(games) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -28, 0, 32)
        row.BackgroundColor3 = Theme.Panel
        row.Text = g
        row.TextColor3 = Theme.Text
        row.Font = Enum.Font.Gotham
        row.TextSize = 13
        row.Parent = ddListWrap
        AddCorner(row, 8)
        AddStroke(row, Theme.Border, Theme.BorderSize)
        HoverEffect(row, Color3.fromRGB(42,60,82), Theme.Panel)
        row.MouseButton1Click:Connect(function()
            selectedGame = g
            ddBtn.Text = "Game: "..tostring(g)
            ToggleDD()
        end)
    end

    local warn = Instance.new("TextLabel")
    warn.Name = "Warning"
    warn.Size = UDim2.new(1, -24, 0, 20)
    warn.Position = UDim2.new(0, 12, 0, 180)
    warn.BackgroundTransparency = 1
    warn.Font = Enum.Font.Gotham
    warn.TextSize = 13
    warn.Text = ""
    warn.TextXAlignment = Enum.TextXAlignment.Left
    warn.TextColor3 = Color3.fromRGB(255,120,120)
    warn.Parent = body
    warn.Visible = false

    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1, -24, 0, 48)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = body
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    rowLayout.Padding = UDim.new(0, 12)
    rowLayout.Parent = btnRow

    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.new(0, 120, 1, 0)
    cancel.BackgroundColor3 = Theme.Panel
    cancel.Text = "Cancel"
    cancel.TextColor3 = Theme.Text
    cancel.Font = Enum.Font.GothamSemibold
    cancel.TextSize = 14
    cancel.Parent = btnRow
    AddCorner(cancel, 10)
    AddStroke(cancel, Theme.Border, Theme.BorderSize)
    HoverEffect(cancel, Color3.fromRGB(42,60,82), Theme.Panel)
    cancel.MouseButton1Click:Connect(function() TweenTo(root, {Position = OffscreenLeft(0.45)}, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In) task.delay(0.28, function() if root and root.Parent then root.Visible = false end end) end)

    local launch = Instance.new("TextButton")
    launch.Name = "Launch"
    launch.Size = UDim2.new(0, 160, 1, 0)
    launch.BackgroundColor3 = Theme.Accent
    launch.Text = "Launch"
    launch.TextColor3 = Color3.fromRGB(12,12,12)
    launch.Font = Enum.Font.GothamBlack
    launch.TextSize = 16
    launch.Parent = btnRow
    AddCorner(launch, 10)
    AddStroke(launch, Theme.Accent, Theme.BorderSize)
    HoverEffect(launch, Theme.AccentAlt, Theme.Accent)

    local function ShowWarn(text, color, time)
        if warn and warn.Parent then
            warn.Text = tostring(text or "")
            warn.TextColor3 = color or Color3.fromRGB(255,120,120)
            warn.Visible = true
            task.delay((time or 2), function() if warn and warn.Parent then warn.Visible = false end end)
        end
    end

    local function proceed()
        TweenTo(root, {Position = OffscreenLeft(0.45)}, 0.33, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        task.delay(0.34, function()
            if root and root.Parent then root.Visible = false end
            if hub and hub.Root then
                hub.Root.Visible = true
                hub.Root.Position = OffscreenLeft(0.5)
                task.delay(0.06, function() TweenTo(hub.Root, {Position = CenterPos()}, 0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out) end)
            end
        end)
    end

    launch.MouseButton1Click:Connect(function()
        local entered = ""
        if keyBox and keyBox:IsA("TextBox") then entered = tostring(keyBox.Text or "") end
        entered = entered:match("^%s*(.-)%s*$") or ""
        if entered == "" then
            ShowWarn("Please enter a key before launching", Color3.fromRGB(255,120,120), 2)
            return
        end
        if IsKeyAllowed(entered) then
            ShowWarn("Key accepted", Color3.fromRGB(120,255,140), 1.2)
            proceed()
            return
        end
        if KeySourceUrl and not FetchingKeys and not FetchedKeys then
            ShowWarn("Checking key server...", Color3.fromRGB(255,220,120), 4)
            FetchRemoteKeysAsync(KeySourceUrl, function(success)
                task.delay(0.06, function()
                    if success and IsKeyAllowed(entered) then
                        ShowWarn("Key accepted", Color3.fromRGB(120,255,140), 1.2)
                        proceed()
                    else
                        ShowWarn("Invalid key", Color3.fromRGB(255,120,120), 2)
                    end
                end)
            end)
            return
        end
        if IsKeyAllowed(entered) then
            ShowWarn("Key accepted", Color3.fromRGB(120,255,140), 1.2)
            proceed()
            return
        end
        ShowWarn("Invalid key", Color3.fromRGB(255,120,120), 2)
    end)

    return {
        Root = root,
        KeyBox = keyBox,
        Dropdown = {
            Get = function() return selectedGame end,
            Set = function(v) selectedGame = v ddBtn.Text = "Game: "..tostring(v) end
        },
        Launch = launch,
        Warning = warn,
        SetVisible = function(v)
            if v then
                if root and root.Parent then root.Visible = true end
                TweenTo(root, {Position = CenterPos(0.45)}, 0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            else
                TweenTo(root, {Position = OffscreenLeft(0.45)}, 0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                task.delay(0.32, function() if root and root.Parent then root.Visible = false end end)
            end
        end
    }
end

launcher = CreateLauncher2()
if launcher and launcher.SetVisible then
    launcher.SetVisible(true)
end
if hub and hub.Root then
    hub.Root.Visible = false
    hub.Root.Position = OffscreenLeft(0.5)
end


    local root = Instance.new("Frame")
    root.Name = "BluLauncher"
    root.Size = UDim2.new(0, 560, 0, 380)
    root.Position = CenterPos(0.45)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.BackgroundTransparency = 1
    root.Parent = gui
    AddCorner(root, 14)

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 0, 1, 0)
    shadow.Position = UDim2.new(0, 8, 0, 8)
    shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
    shadow.BackgroundTransparency = 0.85
    shadow.BorderSizePixel = 0
    shadow.Parent = root
    AddCorner(shadow, 14)

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, -12, 1, -12)
    panel.Position = UDim2.new(0, 6, 0, 6)
    panel.BackgroundColor3 = Theme.Panel
    panel.Parent = root
    AddCorner(panel, 14)
    AddStroke(panel, Theme.Border, Theme.BorderSize)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -28, 0, 68)
    header.Position = UDim2.new(0, 14, 0, 14)
    header.BackgroundColor3 = Color3.fromRGB(24,30,40)
    header.Parent = panel
    AddCorner(header, 12)
    AddStroke(header, Theme.Border, Theme.BorderSize)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, -24, 1, 0)
    title.Position = UDim2.new(0, 18, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Enter key & choose"
    title.TextColor3 = Theme.Text
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(0, 56, 0, 36)
    logo.Position = UDim2.new(1, -160, 0, 14)
    logo.BackgroundTransparency = 1
    logo.Image = "rbxassetid://121579464174587"
    logo.Parent = header
    AddCorner(logo, 8)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 44, 0, 36)
    closeBtn.Position = UDim2.new(1, -96, 0, 14)
    closeBtn.BackgroundColor3 = Theme.Panel
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Theme.Text
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 18
    closeBtn.Parent = header
    AddCorner(closeBtn, 8)
    AddStroke(closeBtn, Theme.Border, Theme.BorderSize)
    HoverEffect(closeBtn, Color3.fromRGB(42,60,82), Theme.Panel)
    closeBtn.MouseButton1Click:Connect(function() root.Visible = false end)

    MakeDraggable(header, root)

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -28, 1, -108)
    body.Position = UDim2.new(0, 14, 0, 86)
    body.BackgroundTransparency = 1
    body.Parent = panel

    local vlist = Instance.new("UIListLayout")
    vlist.Parent = body
    vlist.Padding = UDim.new(0, 12)

    local keyWrap = Instance.new("Frame")
    keyWrap.Size = UDim2.new(1, 0, 0, 84)
    keyWrap.BackgroundTransparency = 1
    keyWrap.Parent = body

    local keyLbl = Instance.new("TextLabel")
    keyLbl.Size = UDim2.new(1, -24, 0, 18)
    keyLbl.Position = UDim2.new(0, 12, 0, 6)
    keyLbl.BackgroundTransparency = 1
    keyLbl.Text = "Access Key"
    keyLbl.TextColor3 = Theme.MutedText
    keyLbl.Font = Enum.Font.Gotham
    keyLbl.TextSize = 13
    keyLbl.TextXAlignment = Enum.TextXAlignment.Left
    keyLbl.Parent = keyWrap

    local keyBox = Instance.new("TextBox")
    keyBox.Name = "KeyBox"
    keyBox.Size = UDim2.new(1, -156, 0, 40)
    keyBox.Position = UDim2.new(0, 12, 0, 30)
    keyBox.BackgroundColor3 = Theme.Panel
    keyBox.PlaceholderText = "Paste key (demo)"
    keyBox.TextColor3 = Theme.Text
    keyBox.Font = Enum.Font.Gotham
    keyBox.TextSize = 14
    keyBox.ClearTextOnFocus = false
    keyBox.Parent = keyWrap
    AddCorner(keyBox, 10)
    AddStroke(keyBox, Theme.Border, Theme.BorderSize)
    HoverEffect(keyBox, Color3.fromRGB(42,60,82), Theme.Panel)

    local ddBtn = Instance.new("TextButton")
    ddBtn.Size = UDim2.new(0, 120, 0, 40)
    ddBtn.Position = UDim2.new(1, -136, 0, 30)
    ddBtn.BackgroundColor3 = Theme.Panel
    ddBtn.Text = "Game: Test"
    ddBtn.TextColor3 = Theme.Text
    ddBtn.Font = Enum.Font.GothamSemibold
    ddBtn.TextSize = 13
    ddBtn.Parent = keyWrap
    AddCorner(ddBtn, 10)
    AddStroke(ddBtn, Theme.Border, Theme.BorderSize)
    HoverEffect(ddBtn, Color3.fromRGB(42,60,82), Theme.Panel)

    local ddListWrap = Instance.new("Frame")
    ddListWrap.Size = UDim2.new(1, -24, 0, 0)
    ddListWrap.Position = UDim2.new(0, 12, 0, 76)
    ddListWrap.ClipsDescendants = true
    ddListWrap.BackgroundColor3 = Theme.Panel
    ddListWrap.Parent = body
    AddCorner(ddListWrap, 10)
    AddStroke(ddListWrap, Theme.Border, Theme.BorderSize)

    local ddLayout = Instance.new("UIListLayout")
    ddLayout.Parent = ddListWrap
    ddLayout.Padding = UDim.new(0, 8)
    ddLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local games = {"Test","Game A","Game B"}
    local ddExpanded = false
    local function ToggleDD()
        ddExpanded = not ddExpanded
        if ddExpanded then
            local target = math.clamp(#games * 34 + 12, 0, 260)
            ddListWrap:TweenSize(UDim2.new(1, -24, 0, target), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        else
            ddListWrap:TweenSize(UDim2.new(1, -24, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        end
    end

    ddBtn.MouseButton1Click:Connect(ToggleDD)

    local selectedGame = games[1]
    for _,g in ipairs(games) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -28, 0, 32)
        row.BackgroundColor3 = Theme.Panel
        row.Text = g
        row.TextColor3 = Theme.Text
        row.Font = Enum.Font.Gotham
        row.TextSize = 13
        row.Parent = ddListWrap
        AddCorner(row, 8)
        AddStroke(row, Theme.Border, Theme.BorderSize)
        HoverEffect(row, Color3.fromRGB(42,60,82), Theme.Panel)
        row.MouseButton1Click:Connect(function()
            selectedGame = g
            ddBtn.Text = "Game: "..tostring(g)
            ToggleDD()
        end)
    end

    local warn = Instance.new("TextLabel")
    warn.Name = "Warning"
    warn.Size = UDim2.new(1, -24, 0, 20)
    warn.Position = UDim2.new(0, 12, 0, 180)
    warn.BackgroundTransparency = 1
    warn.Font = Enum.Font.Gotham
    warn.TextSize = 13
    warn.Text = ""
    warn.TextXAlignment = Enum.TextXAlignment.Left
    warn.TextColor3 = Color3.fromRGB(255,120,120)
    warn.Parent = body
    warn.Visible = false

    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1, -24, 0, 48)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = body
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    rowLayout.Padding = UDim.new(0, 12)
    rowLayout.Parent = btnRow

    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.new(0, 120, 1, 0)
    cancel.BackgroundColor3 = Theme.Panel
    cancel.Text = "Cancel"
    cancel.TextColor3 = Theme.Text
    cancel.Font = Enum.Font.GothamSemibold
    cancel.TextSize = 14
    cancel.Parent = btnRow
    AddCorner(cancel, 10)
    AddStroke(cancel, Theme.Border, Theme.BorderSize)
    HoverEffect(cancel, Color3.fromRGB(42,60,82), Theme.Panel)
    cancel.MouseButton1Click:Connect(function() root.Visible = false end)

    local launch = Instance.new("TextButton")
    launch.Name = "Launch"
    launch.Size = UDim2.new(0, 160, 1, 0)
    launch.BackgroundColor3 = Theme.Accent
    launch.Text = "Launch"
    launch.TextColor3 = Color3.fromRGB(12,12,12)
    launch.Font = Enum.Font.GothamBlack
    launch.TextSize = 16
    launch.Parent = btnRow
    AddCorner(launch, 10)
    AddStroke(launch, Theme.Accent, Theme.BorderSize)
    HoverEffect(launch, Theme.AccentAlt, Theme.Accent)

    local function ShowWarn(text, color, time)
        if warn and warn.Parent then
            warn.Text = tostring(text or "")
            warn.TextColor3 = color or Color3.fromRGB(255,120,120)
            warn.Visible = true
            task.delay((time or 2), function() if warn and warn.Parent then warn.Visible = false end end)
        end
    end

    local function proceed()
        if launcher and launcher.SetVisible and type(launcher.SetVisible) == "function" then
            TweenTo(launcher.Root, {Position = OffscreenLeft(0.5)}, 0.33, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            task.delay(0.32, function() if launcher and launcher.SetVisible then launcher.SetVisible(false) end end)
        elseif launcher and launcher.Root then
            TweenTo(launcher.Root, {Position = OffscreenLeft(0.5)}, 0.33, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            task.delay(0.32, function() if launcher and launcher.Root then launcher.Root.Visible = false end end)
        end
        if hub and hub.Root then
            hub.Root.Visible = true
            hub.Root.Position = OffscreenLeft(0.5)
            task.delay(0.08, function() TweenTo(hub.Root, {Position = CenterPos()}, 0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out) end)
        end
    end

    launch.MouseButton1Click:Connect(function()
        local entered = ""
        if keyBox and keyBox:IsA("TextBox") then entered = tostring(keyBox.Text or "") end
        entered = entered:match("^%s*(.-)%s*$") or ""
        if entered == "" then
            ShowWarn("Please enter a key before launching", Color3.fromRGB(255,120,120), 2)
            return
        end
        if IsKeyAllowed(entered) then
            ShowWarn("Key accepted", Color3.fromRGB(120,255,140), 1.2)
            proceed()
            return
        end
        if KeySourceUrl and not FetchingKeys and not FetchedKeys then
            ShowWarn("Checking key server...", Color3.fromRGB(255,220,120), 4)
            FetchRemoteKeysAsync(KeySourceUrl, function(success)
                task.delay(0.06, function()
                    if success and IsKeyAllowed(entered) then
                        ShowWarn("Key accepted", Color3.fromRGB(120,255,140), 1.2)
                        proceed()
                    else
                        ShowWarn("Invalid key", Color3.fromRGB(255,120,120), 2)
                    end
                end)
            end)
            return
        end
        if IsKeyAllowed(entered) then
            ShowWarn("Key accepted", Color3.fromRGB(120,255,140), 1.2)
            proceed()
            return
        end
        ShowWarn("Invalid key", Color3.fromRGB(255,120,120), 2)
    end)

    return {
        Root = root,
        KeyBox = keyBox,
        Dropdown = {
            Get = function() return selectedGame end,
            Set = function(v) selectedGame = v ddBtn.Text = "Game: "..tostring(v) end
        },
        Launch = launch,
        Warning = warn,
        SetVisible = function(v) root.Visible = v end
    }
end

launcher = CreateLauncher()


local function CreateMain()
    local root = Instance.new("Frame")
    root.Size = UDim2.new(0, 920, 0, 620)
    root.Position = OffscreenLeft(0.5)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.BackgroundTransparency = 1
    root.Parent = gui
    AddCorner(root, 16)
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 0, 1, 0)
    shadow.Position = UDim2.new(0, 8, 0, 8)
    shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
    shadow.BackgroundTransparency = 0.9
    shadow.Parent = root
    AddCorner(shadow, 16)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, -16, 1, -16)
    panel.Position = UDim2.new(0, 8, 0, 8)
    panel.BackgroundColor3 = Theme.Panel
    panel.Parent = root
    AddCorner(panel, 16)
    AddStroke(panel, Theme.Border, Theme.BorderSize)
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -40, 0, 72)
    header.Position = UDim2.new(0, 20, 0, 18)
    header.BackgroundColor3 = Color3.fromRGB(24,30,38)
    header.Parent = panel
    AddCorner(header, 12)
    AddStroke(header, Theme.Border, Theme.BorderSize)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -260, 1, 0)
    title.Position = UDim2.new(0, 24, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Blu's Hub"
    title.TextColor3 = Theme.Text
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(0, 64, 0, 44)
    logo.Position = UDim2.new(1, -200, 0, 14)
    logo.BackgroundTransparency = 1
    logo.Image = "rbxassetid://121579464174587"
    logo.Parent = header
    AddCorner(logo, 10)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 44, 0, 44)
    closeBtn.Position = UDim2.new(1, -116, 0, 14)
    closeBtn.BackgroundColor3 = Theme.Panel
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Theme.Text
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 18
    closeBtn.Parent = header
    AddCorner(closeBtn, 10)
    AddStroke(closeBtn, Theme.Border, Theme.BorderSize)
    HoverEffect(closeBtn, Color3.fromRGB(42,60,82), Theme.Panel)
    closeBtn.MouseButton1Click:Connect(function() ToggleVisibility(root) end)
    MakeDraggable(header, root)
    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1, -48, 1, -120)
    inner.Position = UDim2.new(0, 24, 0, 94)
    inner.BackgroundColor3 = Theme.Panel
    inner.Parent = panel
    AddCorner(inner, 12)
    AddStroke(inner, Theme.Border, Theme.BorderSize)
    local left = Instance.new("Frame")
    left.Size = UDim2.new(0, 300, 1, -32)
    left.Position = UDim2.new(0, 20, 0, 16)
    left.BackgroundColor3 = Theme.Panel
    left.Parent = inner
    AddCorner(left, 12)
    local leftGrad = Instance.new("UIGradient")
    leftGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Panel), ColorSequenceKeypoint.new(1, Color3.fromRGB(20,28,40))})
    leftGrad.Parent = left
    AddStroke(left, Theme.Border, Theme.BorderSize)
    local right = Instance.new("Frame")
    right.Size = UDim2.new(1, -364, 1, -32)
    right.Position = UDim2.new(0, 340, 0, 16)
    right.BackgroundColor3 = Theme.Panel
    right.Parent = inner
    AddCorner(right, 12)
    local rightGrad = Instance.new("UIGradient")
    rightGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(26,36,56)), ColorSequenceKeypoint.new(1, Theme.Panel)})
    rightGrad.Parent = right
    AddStroke(right, Theme.Border, Theme.BorderSize)
    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(0, 140, 1, 0)
    controls.Position = UDim2.new(1, -154, 0, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = header
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, 8)
    list.Parent = controls
    local function MakeControlButton(sym, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 28, 0, 28)
        b.BackgroundColor3 = Color3.fromRGB(30,36,48)
        b.Text = sym
        b.TextColor3 = color or Theme.Text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.AutoButtonColor = false
        b.Parent = controls
        AddCorner(b, 6)
        AddStroke(b, Theme.Border, Theme.BorderSize)
        HoverEffect(b, Color3.fromRGB(42,60,82), Color3.fromRGB(30,36,48))
        return b
    end
    local winMinBtn = MakeControlButton("-", Theme.Text)
    local winMaxBtn = MakeControlButton("□", Theme.Text)
    local winCloseBtn = MakeControlButton("X", Color3.fromRGB(220,60,60))
    local originalSize = root.Size
    local originalPos = root.Position
    local maximized = false
    local minimized = false
    local storedSize = nil
    local storedPos = nil
    winMinBtn.MouseButton1Click:Connect(function()
        if minimized then
            if storedSize and storedPos then
                TweenTo(root, {Size = storedSize, Position = storedPos}, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            else
                TweenTo(root, {Size = originalSize, Position = originalPos}, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            end
            task.delay(0.28, function()
                if inner then inner.Visible = true end
                minimized = false
            end)
        else
            storedSize = root.Size
            storedPos = root.Position
            local targetHeight = 92
            local currentSize = storedSize
            local delta = (currentSize.Y.Offset - targetHeight) * 0.5
            local newPos = UDim2.new(storedPos.X.Scale, storedPos.X.Offset, storedPos.Y.Scale, storedPos.Y.Offset + delta)
            TweenTo(root, {Size = UDim2.new(currentSize.X.Scale, currentSize.X.Offset, 0, targetHeight), Position = newPos}, 0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            TweenTo(inner, {Position = UDim2.new(inner.Position.X.Scale, inner.Position.X.Offset, 0, inner.Position.Y.Offset - 40)}, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.delay(0.25, function()
                if inner then inner.Visible = false end
                minimized = true
            end)
        end
    end)
    winMaxBtn.MouseButton1Click:Connect(function()
        if maximized then
            if storedSize and storedPos and not minimized then
                TweenTo(root, {Size = storedSize, Position = storedPos}, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            else
                TweenTo(root, {Size = originalSize, Position = originalPos}, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            end
            maximized = false
        else
            if not minimized then
                storedSize = root.Size
                storedPos = root.Position
            end
            TweenTo(root, {Size = UDim2.new(1, -40, 1, -40), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            maximized = true
            minimized = false
            if inner then inner.Visible = true end
        end
    end)
    winCloseBtn.MouseButton1Click:Connect(function()
        Cleanup()
    end)
    local tabsScroll = Instance.new("ScrollingFrame")
    tabsScroll.Size = UDim2.new(1, -28, 1, -28)
    tabsScroll.Position = UDim2.new(0, 14, 0, 14)
    tabsScroll.BackgroundTransparency = 1
    tabsScroll.ScrollBarThickness = 6
    tabsScroll.CanvasSize = UDim2.new(0,0,0,0)
    tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabsScroll.Parent = left
    local tabsLayout = Instance.new("UIListLayout")
    tabsLayout.Parent = tabsScroll
    tabsLayout.Padding = UDim.new(0, 12)
    tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local tabsWrap = tabsScroll
    local pages = {}
    local tabsManager = BuildTabs(tabsWrap, right)
    local coreTabs = {
        {name = "Home"},
    }
    for i=1,6 do coreTabs[#coreTabs + 1] = {name = "Tab "..i} end
    for _,t in ipairs(coreTabs) do
        local page = tabsManager.AddTab(t.name)
        pages[t.name] = page
        if t.name == "Home" then
            local quick = BuildButton(page, "Quick Action", function() Toast("Quick action ran") end)
            quick.Container = quick
            quick.SetText = quick.SetText
            quick.Click = quick.Click
            quick.SetText("Quick Action")
            quick.Container.Parent = page
            local pnl = Instance.new("Frame")
            pnl.Size = UDim2.new(1, -40, 0, 120)
            pnl.BackgroundColor3 = Color3.fromRGB(30,36,48)
            pnl.Parent = page
            AddCorner(pnl, 10)
            AddStroke(pnl, Theme.Border, Theme.BorderSize)
            local lbl = Instance.new("TextLabel")
            lbl.Parent = pnl
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(1, -20, 1, 0)
            lbl.Position = UDim2.new(0, 12, 0, 0)
            lbl.Text = "Welcome to Blu's Hub"
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 14
            lbl.TextColor3 = Theme.MutedText
        else
            local section = BuildSection(page, t.name .. " Section", false)
            section.Container.Parent = page
            local btn = BuildButton(section.Body, "Example", function() Toast(t.name .. " example") end)
            btn.Container = btn
            btn.SetText = btn.SetText
            btn.Click = btn.Click
            btn.Container.Parent = section.Body
        end
    end
    local settingsPage = tabsManager.AddTab("Settings")
    local settingsContent = BuildSectionedSettingsPage(right)
    settingsContent.Parent = right
    pages["Home"].Visible = true
    for k,v in pairs(pages) do if k ~= "Home" then v.Visible = false end end
    return {
        Root = root,
        Show = function() root.Visible = true end,
        Hide = function() root.Visible = false end,
        TabsManager = tabsManager,
        Pages = pages
    }
end

local launcher = CreateLauncher()
local hub = CreateMain()
if launcher and launcher.Root then launcher.Root.Visible = true end
if hub and hub.Root then hub.Root.Visible = false; hub.Root.Position = OffscreenLeft(0.5) end

local KeySourceUrl = nil
local LocalAllowedKeys = {
    "demo",
    "LOCALKEY123"
}

local FetchedKeys = nil
local Fetching = false
local function ParseKeyList(raw)
    if not raw then return {} end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(parsed) == "table" then
        local t = {}
        for _,v in ipairs(parsed) do if type(v) == "string" then t[v] = true end end
        return t
    end
    local t = {}
    for line in string.gmatch(raw, "[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then t[line] = true end
    end
    return t
end

local function FetchRemoteKeysAsync(url, onDone)
    if Fetching then
        if onDone then pcall(onDone, false) end
        return
    end
    if not url then
        if onDone then pcall(onDone, false) end
        return
    end
    Fetching = true
    task.spawn(function()
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if ok and res then
            FetchedKeys = ParseKeyList(res)
            Fetching = false
            if onDone then pcall(onDone, true) end
        else
            FetchedKeys = {}
            Fetching = false
            if onDone then pcall(onDone, false) end
        end
    end)
end

local function IsKeyAllowed(key)
    if not key then return false end
    if key == "demo" then return true end
    for _,k in ipairs(LocalAllowedKeys) do if tostring(k) == tostring(key) then return true end end
    if FetchedKeys and type(FetchedKeys) == "table" then
        if FetchedKeys[key] then return true end
    end
    return false
end

launcher.Launch.MouseButton1Click:Connect(function()
    if not launcher or not launcher.KeyBox or not launcher.Launch then return end

    local keyText = ""
    if launcher.KeyBox and launcher.KeyBox:IsA("TextBox") then
        keyText = tostring(launcher.KeyBox.Text or "")
    end
    keyText = keyText:match("^%s*(.-)%s*$") or ""

    if keyText == "" then
        if launcher.Warning then
            launcher.Warning.Text = "Please enter a key before launching"
            launcher.Warning.Visible = true
            task.delay(2, function() if launcher and launcher.Warning then launcher.Warning.Visible = false end end)
        end
        return
    end

    -- disable the button to prevent double clicks
    launcher.Launch.Active = false
    launcher.Launch.AutoButtonColor = false
    launcher.Launch.Text = "Launching..."

    -- animate launcher out to the left
    local outTween = TweenTo(launcher.Root, {Position = OffscreenLeft(0.5)}, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    if outTween then
        outTween.Completed:Connect(function()
            -- hide launcher after it fully slid out
            if launcher and launcher.SetVisible then
                pcall(function() launcher.SetVisible(false) end)
            elseif launcher and launcher.Root then
                launcher.Root.Visible = false
            end

            -- prepare hub — ensure it's offscreen left and visible
            if hub and hub.Root then
                hub.Root.Visible = true
                hub.Root.Position = OffscreenLeft(0.5)
                -- small delay to ensure Roblox registers position change before tweening
                task.delay(0.06, function()
                    TweenTo(hub.Root, {Position = CenterPos()}, 0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
                end)
            end

            -- restore Launch button state (optional)
            launcher.Launch.Active = true
            launcher.Launch.AutoButtonColor = true
            launcher.Launch.Text = "Launch"
        end)
    else
        -- fallback: no tween (tween creation failed) — do immediate switch
        if launcher and launcher.SetVisible then launcher.SetVisible(false) end
        if hub and hub.Root then
            hub.Root.Visible = true
            hub.Root.Position = CenterPos()
        end
        launcher.Launch.Active = true
        launcher.Launch.AutoButtonColor = true
        launcher.Launch.Text = "Launch"
    end
end)


local keyConn = UserInputService.InputBegan:Connect(KeypressHandler)
Track(keyConn)

task.spawn(function()
    local s = LoadSettings()
    if s then
        if s.theme then SetTheme(s.theme) end
        if s.openKey then Library._openKeyName = s.openKey end
    end
end)

Library.Cleanup = Cleanup
Library.Gui = gui
Library.Launcher = launcher
Library.Hub = hub

Toast("BluHub loaded", "info", 2)

return Library
