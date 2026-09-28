--// ==================================================
--// TrustHub - Custom Animated UI Library
--// Author: rshonchar9292-ai
--// ==================================================

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

local UI = {}

--// ==================================================
--// ТЕМА
--// ==================================================
local Theme = {
    Bg         = Color3.fromRGB(16, 16, 22),
    Panel      = Color3.fromRGB(24, 24, 32),
    PanelLight = Color3.fromRGB(32, 32, 42),
    Element    = Color3.fromRGB(40, 40, 52),
    ElementHov = Color3.fromRGB(50, 50, 64),
    Accent     = Color3.fromRGB(120, 140, 255),
    AccentDark = Color3.fromRGB(80, 100, 220),
    Success    = Color3.fromRGB(90, 220, 130),
    Danger     = Color3.fromRGB(240, 80, 90),
    Text       = Color3.fromRGB(235, 235, 245),
    TextDim    = Color3.fromRGB(145, 145, 165),
    Stroke     = Color3.fromRGB(58, 58, 78),
}

--// ==================================================
--// ХЕЛПЕРИ
--// ==================================================
local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function createRipple(parent, x, y)
    local r = Instance.new("Frame")
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.Size = UDim2.new(0, 0, 0, 0)
    r.Position = UDim2.new(0, x, 0, y)
    r.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    r.BackgroundTransparency = 0.7
    r.BorderSizePixel = 0
    r.ZIndex = 10
    r.Parent = parent
    corner(r, 999)
    
    local maxSize = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2
    local t = tween(r, 0.5, {
        Size = UDim2.new(0, maxSize, 0, maxSize),
        BackgroundTransparency = 1,
    }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    t.Completed:Connect(function() r:Destroy() end)
end

--// ==================================================
--// КОМПОНЕНТ: TOGGLE
--// ==================================================
local function createToggle(parent, text, default, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -16, 0, 36)
    Btn.BackgroundColor3 = Theme.Element
    Btn.Text = ""
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    corner(Btn, 8)
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Theme.Text
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Btn
    
    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(0, 38, 0, 20)
    Track.Position = UDim2.new(1, -50, 0.5, -10)
    Track.BackgroundColor3 = default and Theme.Success or Color3.fromRGB(58, 58, 72)
    Track.BorderSizePixel = 0
    Track.Parent = Btn
    corner(Track, 999)
    
    local Dot = Instance.new("Frame")
    Dot.Size = UDim2.new(0, 16, 0, 16)
    Dot.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    Dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Dot.BorderSizePixel = 0
    Dot.Parent = Track
    corner(Dot, 999)
    
    local state = default
    Btn.MouseButton1Click:Connect(function()
        createRipple(Btn, Mouse.X - Btn.AbsolutePosition.X, Mouse.Y - Btn.AbsolutePosition.Y)
        state = not state
        tween(Track, 0.2, {BackgroundColor3 = state and Theme.Success or Color3.fromRGB(58, 58, 72)})
        tween(Dot, 0.25, {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        callback(state)
    end)
    
    Btn.MouseEnter:Connect(function()
        tween(Btn, 0.15, {BackgroundColor3 = Theme.ElementHov})
    end)
    Btn.MouseLeave:Connect(function()
        tween(Btn, 0.15, {BackgroundColor3 = Theme.Element})
    end)
    
    return Btn
end

--// ==================================================
--// КОМПОНЕНТ: SLIDER
--// ==================================================
local function createSlider(parent, text, min, max, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -16, 0, 52)
    Frame.BackgroundColor3 = Theme.Element
    Frame.BorderSizePixel = 0
    Frame.Parent = parent
    corner(Frame, 8)
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -100, 0, 18)
    Label.Position = UDim2.new(0, 12, 0, 4)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Theme.Text
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame
    
    local ValueLbl = Instance.new("TextLabel")
    ValueLbl.Size = UDim2.new(0, 80, 0, 18)
    ValueLbl.Position = UDim2.new(1, -92, 0, 4)
    ValueLbl.BackgroundTransparency = 1
    ValueLbl.Text = tostring(default)
    ValueLbl.TextColor3 = Theme.Accent
    ValueLbl.Font = Enum.Font.GothamBold
    ValueLbl.TextSize = 12
    ValueLbl.TextXAlignment = Enum.TextXAlignment.Right
    ValueLbl.Parent = Frame
    
    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, -24, 0, 6)
    Bar.Position = UDim2.new(0, 12, 0, 34)
    Bar.BackgroundColor3 = Color3.fromRGB(52, 52, 68)
    Bar.BorderSizePixel = 0
    Bar.Parent = Frame
    corner(Bar, 999)
    
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent
    Fill.BorderSizePixel = 0
    Fill.Parent = Bar
    corner(Fill, 999)
    
    local FillGrad = Instance.new("UIGradient")
    FillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 200, 255)),
    })
    FillGrad.Parent = Fill
    
    local Knob = Instance.new("Frame")
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.Size = UDim2.new(0, 12, 0, 12)
    Knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Bar
    corner(Knob, 999)
    
    local KnobStroke = stroke(Knob, Theme.Accent, 2, 0)
    
    local dragging = false
    local function update(input)
        local alpha = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * alpha + 0.5)
        Fill.Size = UDim2.new(alpha, 0, 1, 0)
        Knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        ValueLbl.Text = tostring(value)
        callback(value)
    end
    
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
            tween(Knob, 0.2, {Size = UDim2.new(0, 16, 0, 16)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            tween(KnobStroke, 0.2, {Thickness = 3})
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            tween(Knob, 0.2, {Size = UDim2.new(0, 12, 0, 12)})
            tween(KnobStroke, 0.2, {Thickness = 2})
        end
    end)
    
    Frame.MouseEnter:Connect(function()
        tween(Frame, 0.15, {BackgroundColor3 = Theme.ElementHov})
    end)
    Frame.MouseLeave:Connect(function()
        tween(Frame, 0.15, {BackgroundColor3 = Theme.Element})
    end)
    
    return Frame
end

--// ==================================================
--// КОМПОНЕНТ: SECTION
--// ==================================================
local function createSection(parent, text)
    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -16, 0, 22)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = "  " .. text:upper()
    Lbl.TextColor3 = Theme.TextDim
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = 10
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Parent = parent
    
    local Line = Instance.new("Frame")
    Line.Size = UDim2.new(1, -20, 0, 1)
    Line.Position = UDim2.new(0, 10, 0, 20)
    Line.BackgroundColor3 = Theme.Stroke
    Line.BorderSizePixel = 0
    Line.Parent = Lbl
    
    local LineGrad = Instance.new("UIGradient")
    LineGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
    })
    LineGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    LineGrad.Parent = Line
    
    return Lbl
end

--// ==================================================
--// ГОЛОВНА ФУНКЦІЯ UI:init
--// ==================================================
function UI:init(Features)
    --// ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TrustHubUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    --// ==================================================
    --// ПЛАВАЮЧА КНОПКА
    --// ==================================================
    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = "FloatingButton"
    FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
    FloatingBtn.Position = UDim2.new(0, 30, 0.5, -26)
    FloatingBtn.BackgroundColor3 = Theme.Accent
    FloatingBtn.Text = ""
    FloatingBtn.BorderSizePixel = 0
    FloatingBtn.AutoButtonColor = false
    FloatingBtn.Parent = ScreenGui
    corner(FloatingBtn, 999)
    
    stroke(FloatingBtn, Color3.fromRGB(255, 255, 255), 2, 0.6)
    
    local FloatGrad = Instance.new("UIGradient")
    FloatGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 120, 255)),
    })
    FloatGrad.Rotation = 45
    FloatGrad.Parent = FloatingBtn
    
    local FloatIcon = Instance.new("TextLabel")
    FloatIcon.Size = UDim2.new(1, 0, 1, 0)
    FloatIcon.BackgroundTransparency = 1
    FloatIcon.Text = "T"
    FloatIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatIcon.TextSize = 24
    FloatIcon.Font = Enum.Font.GothamBold
    FloatIcon.Parent = FloatingBtn
    
    task.spawn(function()
        while FloatingBtn.Parent do
            tween(FloatIcon, 1.5, {TextSize = 26}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.5)
            tween(FloatIcon, 1.5, {TextSize = 22}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(1.5)
        end
    end)
    
    FloatingBtn.MouseEnter:Connect(function()
        tween(FloatingBtn, 0.2, {Size = UDim2.new(0, 58, 0, 58)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
    FloatingBtn.MouseLeave:Connect(function()
        tween(FloatingBtn, 0.2, {Size = UDim2.new(0, 52, 0, 52)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    
    --// Main Window
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.Size = UDim2.new(0, 0, 0, 0)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.BackgroundColor3 = Theme.Bg
    Main.BorderSizePixel = 0
    Main.Visible = false
    Main.Active = true
    Main.ClipsDescendants = true
    Main.Parent = ScreenGui
    corner(Main, 14)
    
    stroke(Main, Theme.Stroke, 1.5, 0.3)
    
    local MainGrad = Instance.new("UIGradient")
    MainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 20)),
    })
    MainGrad.Rotation = 135
    MainGrad.Parent = Main
    
    --// Header
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 44)
    Header.BackgroundColor3 = Theme.Panel
    Header.BackgroundTransparency = 0.3
    Header.BorderSizePixel = 0
    Header.Parent = Main
    corner(Header, 14)
    
    local HeaderMask = Instance.new("Frame")
    HeaderMask.Size = UDim2.new(1, 0, 0, 14)
    HeaderMask.Position = UDim2.new(0, 0, 1, -14)
    HeaderMask.BackgroundColor3 = Theme.Panel
    HeaderMask.BackgroundTransparency = 0.3
    HeaderMask.BorderSizePixel = 0
    HeaderMask.Parent = Header
    
    local Logo = Instance.new("Frame")
    Logo.Size = UDim2.new(0, 24, 0, 24)
    Logo.Position = UDim2.new(0, 16, 0.5, -12)
    Logo.BackgroundColor3 = Theme.Accent
    Logo.BorderSizePixel = 0
    Logo.Parent = Header
    corner(Logo, 7)
    
    local LogoGrad = Instance.new("UIGradient")
    LogoGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 120, 255)),
    })
    LogoGrad.Rotation = 45
    LogoGrad.Parent = Logo
    
    local LogoText = Instance.new("TextLabel")
    LogoText.Size = UDim2.new(1, 0, 1, 0)
    LogoText.BackgroundTransparency = 1
    LogoText.Text = "T"
    LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    LogoText.Font = Enum.Font.GothamBold
    LogoText.TextSize = 14
    LogoText.Parent = Logo
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0, 200, 1, 0)
    Title.Position = UDim2.new(0, 50, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "TrustHub"
    Title.TextColor3 = Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    
    local VersionLbl = Instance.new("TextLabel")
    VersionLbl.Size = UDim2.new(0, 60, 1, 0)
    VersionLbl.Position = UDim2.new(1, -100, 0, 0)
    VersionLbl.BackgroundTransparency = 1
    VersionLbl.Text = "v1.0.0"
    VersionLbl.TextColor3 = Theme.TextDim
    VersionLbl.Font = Enum.Font.Gotham
    VersionLbl.TextSize = 11
    VersionLbl.TextXAlignment = Enum.TextXAlignment.Right
    VersionLbl.Parent = Header
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -36, 0.5, -13)
    CloseBtn.BackgroundColor3 = Theme.Element
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Theme.Text
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.BorderSizePixel = 0
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = Header
    corner(CloseBtn, 8)
    
    CloseBtn.MouseEnter:Connect(function()
        tween(CloseBtn, 0.15, {BackgroundColor3 = Theme.Danger})
    end)
    CloseBtn.MouseLeave:Connect(function()
        tween(CloseBtn, 0.15, {BackgroundColor3 = Theme.Element})
    end)
    
    --// Tab Bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(0, 150, 1, -58)
    TabBar.Position = UDim2.new(0, 10, 0, 52)
    TabBar.BackgroundTransparency = 1
    TabBar.BorderSizePixel = 0
    TabBar.Parent = Main
    
    local TabLayout = Instance.new("UIListLayout")
    TabLayout.Padding = UDim.new(0, 6)
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Parent = TabBar
    
    --// Content
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -176, 1, -58)
    Content.Position = UDim2.new(0, 166, 0, 52)
    Content.BackgroundColor3 = Theme.Panel
    Content.BorderSizePixel = 0
    Content.Parent = Main
    corner(Content, 10)
    
    local ContentPad = Instance.new("UIPadding")
    ContentPad.PaddingTop = UDim.new(0, 8)
    ContentPad.PaddingLeft = UDim.new(0, 8)
    ContentPad.PaddingRight = UDim.new(0, 8)
    ContentPad.PaddingBottom = UDim.new(0, 8)
    ContentPad.Parent = Content
    
    --// Tabs System
    local Tabs = {}
    local ActiveTab = nil
    
    local function createTab(name, emoji)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 38)
        Btn.BackgroundColor3 = Theme.Panel
        Btn.Text = ""
        Btn.BorderSizePixel = 0
        Btn.AutoButtonColor = false
        Btn.Parent = TabBar
        corner(Btn, 9)
        
        local Indicator = Instance.new("Frame")
        Indicator.Size = UDim2.new(0, 3, 0.4, 0)
        Indicator.Position = UDim2.new(0, 0, 0.3, 0)
        Indicator.BackgroundColor3 = Theme.Accent
        Indicator.BorderSizePixel = 0
        Indicator.BackgroundTransparency = 1
        Indicator.Parent = Btn
        corner(Indicator, 999)
        
        local Emoji = Instance.new("TextLabel")
        Emoji.Size = UDim2.new(0, 24, 1, 0)
        Emoji.Position = UDim2.new(0, 12, 0, 0)
        Emoji.BackgroundTransparency = 1
        Emoji.Text = emoji
        Emoji.TextColor3 = Theme.Text
        Emoji.TextSize = 15
        Emoji.TextXAlignment = Enum.TextXAlignment.Left
        Emoji.Parent = Btn
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -44, 1, 0)
        Label.Position = UDim2.new(0, 40, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Theme.Text
        Label.Font = Enum.Font.GothamMedium
        Label.TextSize = 13
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Btn
        
        local Page = Instance.new("ScrollingFrame")
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.BorderSizePixel = 0
        Page.ScrollBarThickness = 3
        Page.ScrollBarImageColor3 = Theme.Accent
        Page.ScrollBarImageTransparency = 0.4
        Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Page.Visible = false
        Page.Parent = Content
        
        local Layout = Instance.new("UIListLayout")
        Layout.Padding = UDim.new(0, 6)
        Layout.SortOrder = Enum.SortOrder.LayoutOrder
        Layout.Parent = Page
        
        Tabs[name] = {Button=Btn, Page=Page, Indicator=Indicator, Label=Label, Emoji=Emoji}
        
        local function activate()
            for _, t in pairs(Tabs) do
                t.Page.Visible = false
                tween(t.Button, 0.2, {BackgroundColor3 = Theme.Panel})
                tween(t.Indicator, 0.2, {BackgroundTransparency = 1, Size = UDim2.new(0, 3, 0.4, 0)})
                tween(t.Label, 0.2, {TextColor3 = Theme.Text})
                tween(t.Emoji, 0.2, {TextColor3 = Theme.Text})
            end
            Page.Visible = true
            Page.Position = UDim2.new(0, 20, 0, 0)
            tween(Page, 0.25, {Position = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Quart)
            tween(Btn, 0.2, {BackgroundColor3 = Theme.PanelLight})
            tween(Indicator, 0.25, {
                BackgroundTransparency = 0,
                Size = UDim2.new(0, 3, 0.7, 0),
                Position = UDim2.new(0, 0, 0.15, 0),
            })
            tween(Label, 0.2, {TextColor3 = Theme.Accent})
            tween(Emoji, 0.2, {TextColor3 = Theme.Accent})
            ActiveTab = name
        end
        
        Btn.MouseButton1Click:Connect(function()
            createRipple(Btn, Mouse.X - Btn.AbsolutePosition.X, Mouse.Y - Btn.AbsolutePosition.Y)
            activate()
        end)
        
        Btn.MouseEnter:Connect(function()
            if ActiveTab ~= name then
                tween(Btn, 0.15, {BackgroundColor3 = Theme.PanelLight})
            end
        end)
        Btn.MouseLeave:Connect(function()
            if ActiveTab ~= name then
                tween(Btn, 0.15, {BackgroundColor3 = Theme.Panel})
            end
        end)
        
        return Page
    end
    
    --// Вкладки (замінені emoji на букви — щоб не було крапок)
    local AimPage      = createTab("Aimbot", "A")
    local VisualsPage  = createTab("Visuals", "V")
    local MovePage     = createTab("Movement", "M")
    local SettingsPage = createTab("Settings", "S")
    
    --// Наповнення
    createSection(AimPage, "Silent Aim")
    createToggle(AimPage, "Enable Silent Aim", false, function(v)
        if Features.SilentAim then Features.SilentAim:setEnabled(v) end
    end)
    createSlider(AimPage, "FOV Radius", 30, 600, 150, function(v)
        if Features.SilentAim then Features.SilentAim:setFOV(v) end
    end)
    
    createSection(VisualsPage, "ESP")
    createToggle(VisualsPage, "Enable ESP", false, function(v)
        if Features.ESP then Features.ESP:setEnabled(v) end
    end)
    
    createSection(MovePage, "Speed")
    createToggle(MovePage, "Enable Speed", false, function(v)
        if Features.Speed then Features.Speed:setEnabled(v) end
    end)
    createSlider(MovePage, "Speed Value", 16, 200, 32, function(v)
        if Features.Speed then Features.Speed:setValue(v) end
    end)
    
    createSection(SettingsPage, "Info")
    local InfoLbl = Instance.new("TextLabel")
    InfoLbl.Size = UDim2.new(1, -16, 0, 80)
    InfoLbl.BackgroundColor3 = Theme.Element
    InfoLbl.Text = "TrustHub v1.0.0\n\nF4 - toggle menu\nClick T - open/close\nDrag T - move"
    InfoLbl.TextColor3 = Theme.TextDim
    InfoLbl.Font = Enum.Font.Gotham
    InfoLbl.TextSize = 12
    InfoLbl.TextWrapped = true
    InfoLbl.Parent = SettingsPage
    corner(InfoLbl, 8)
    
    --// Активуємо першу вкладку
    Tabs["Aimbot"].Page.Visible = true
    ActiveTab = "Aimbot"
    Tabs["Aimbot"].Button.BackgroundColor3 = Theme.PanelLight
    Tabs["Aimbot"].Indicator.BackgroundTransparency = 0
    Tabs["Aimbot"].Indicator.Size = UDim2.new(0, 3, 0.7, 0)
    Tabs["Aimbot"].Indicator.Position = UDim2.new(0, 0, 0.15, 0)
    Tabs["Aimbot"].Label.TextColor3 = Theme.Accent
    Tabs["Aimbot"].Emoji.TextColor3 = Theme.Accent
    
    --// ==================================================
    --// MOUSE CONTROL (FIXED — простий метод)
    --// ==================================================
    local mouseUnlocked = false
    
    local function unlockMouse()
        if mouseUnlocked then return end
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        mouseUnlocked = true
    end
    
    local function lockMouse()
        if not mouseUnlocked then return end
        UserInputService.MouseIconEnabled = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        mouseUnlocked = false
    end
    
    --// ==================================================
    --// OPEN / CLOSE
    --// ==================================================
    local isOpen = false
    local opening = false
    
    local function openPanel()
        if isOpen or opening then return end
        opening = true
        unlockMouse()
        Main.Visible = true
        Main.Size = UDim2.new(0, 0, 0, 0)
        tween(Main, 0.35, {Size = UDim2.new(0, 580, 0, 420)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tween(FloatingBtn, 0.25, {BackgroundTransparency = 0.6})
        task.delay(0.35, function() isOpen = true; opening = false end)
    end
    
    local function closePanel()
        if not isOpen then return end
        isOpen = false
        local t = tween(Main, 0.2, {Size = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            Main.Visible = false
            lockMouse()
        end)
        tween(FloatingBtn, 0.25, {BackgroundTransparency = 0})
    end
    
    --// Клік на плаваючу кнопку
    FloatingBtn.MouseButton1Click:Connect(function()
        if isOpen then closePanel() else openPanel() end
    end)
    
    CloseBtn.MouseButton1Click:Connect(closePanel)
    
    --// F4 toggle
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F4 then
            if isOpen then closePanel() else openPanel() end
        end
    end)
    
    --// Drag Floating button
    local draggingFloat, dragFloatStart, floatStartPos
    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFloat = true
            dragFloatStart = input.Position
            floatStartPos = FloatingBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingFloat and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragFloatStart
            FloatingBtn.Position = UDim2.new(
                floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X,
                floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFloat = false
        end
    end)
    
    --// Drag Main window
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    --// Запуск
    task.wait(0.3)
    openPanel()
    
    self.Main = Main
    self.Tabs = Tabs
    self.ScreenGui = ScreenGui
    self.FloatingBtn = FloatingBtn
end

return UI
