--// ==================================================
--// TrustHub UI v13.0 — 7 tabs + Anti-Fling
--// ==================================================

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

local UI = {}

local Theme = {
    Bg         = Color3.fromRGB(16, 16, 22),
    Panel      = Color3.fromRGB(24, 24, 32),
    PanelLight = Color3.fromRGB(32, 32, 42),
    Element    = Color3.fromRGB(40, 40, 52),
    ElementHov = Color3.fromRGB(50, 50, 64),
    Accent     = Color3.fromRGB(120, 140, 255),
    Success    = Color3.fromRGB(90, 220, 130),
    Danger     = Color3.fromRGB(240, 80, 90),
    Murderer   = Color3.fromRGB(255, 50, 50),
    Sheriff    = Color3.fromRGB(50, 150, 255),
    Innocent   = Color3.fromRGB(50, 220, 100),
    Text       = Color3.fromRGB(235, 235, 245),
    TextDim    = Color3.fromRGB(145, 145, 165),
    Stroke     = Color3.fromRGB(58, 58, 78),
}

--// HELPERS
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

--// TOGGLE
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

    Btn.MouseEnter:Connect(function() tween(Btn, 0.15, {BackgroundColor3 = Theme.ElementHov}) end)
    Btn.MouseLeave:Connect(function() tween(Btn, 0.15, {BackgroundColor3 = Theme.Element}) end)
    return Btn
end

--// SLIDER
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

    local Knob = Instance.new("Frame")
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.Size = UDim2.new(0, 12, 0, 12)
    Knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Bar
    corner(Knob, 999)

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
            dragging = true; update(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    return Frame
end

--// SECTION
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
    return Lbl
end

--// ACTION BUTTON
local function createActionButton(parent, text, color, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -16, 0, 46)
    Btn.BackgroundColor3 = color
    Btn.Text = text
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 14
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    corner(Btn, 8)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(
            math.min(255, color.R * 255 + 50),
            math.min(255, color.G * 255 + 50),
            math.min(255, color.B * 255 + 50)
        )),
    })
    grad.Rotation = 45
    grad.Parent = Btn

    Btn.MouseEnter:Connect(function() tween(Btn, 0.15, {Size = UDim2.new(1, -16, 0, 50)}) end)
    Btn.MouseLeave:Connect(function() tween(Btn, 0.15, {Size = UDim2.new(1, -16, 0, 46)}) end)
    Btn.MouseButton1Click:Connect(function()
        createRipple(Btn, Mouse.X - Btn.AbsolutePosition.X, Mouse.Y - Btn.AbsolutePosition.Y)
        callback()
    end)
    return Btn
end

--// PLAYER ROW
local function createPlayerRow(parent, plr, role, roleColor, callback)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -8, 0, 46)
    row.BackgroundColor3 = Theme.Element
    row.Text = ""
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Parent = parent
    corner(row, 8)

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 3, 0.6, 0)
    stripe.Position = UDim2.new(0, 0, 0.2, 0)
    stripe.BackgroundColor3 = roleColor
    stripe.BorderSizePixel = 0
    stripe.Parent = row
    corner(stripe, 999)

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 34, 0, 34)
    avatar.Position = UDim2.new(0, 10, 0.5, -17)
    avatar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    avatar.BorderSizePixel = 0
    avatar.Image = "rbxassetid://0"
    avatar.Parent = row
    corner(avatar, 999)

    task.spawn(function()
        local ok, thumb = pcall(function()
            return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and thumb and avatar.Parent then avatar.Image = thumb end
    end)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -100, 0, 18)
    nameLbl.Position = UDim2.new(0, 52, 0, 5)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.Name
    nameLbl.TextColor3 = Theme.Text
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = row

    local roleLbl = Instance.new("TextLabel")
    roleLbl.Size = UDim2.new(1, -100, 0, 14)
    roleLbl.Position = UDim2.new(0, 52, 0, 23)
    roleLbl.BackgroundTransparency = 1
    roleLbl.Text = role
    roleLbl.TextColor3 = roleColor
    roleLbl.Font = Enum.Font.GothamBold
    roleLbl.TextSize = 11
    roleLbl.TextXAlignment = Enum.TextXAlignment.Left
    roleLbl.Parent = row

    local flingIcon = Instance.new("TextLabel")
    flingIcon.Size = UDim2.new(0, 30, 1, 0)
    flingIcon.Position = UDim2.new(1, -36, 0, 0)
    flingIcon.BackgroundTransparency = 1
    flingIcon.Text = "💥"
    flingIcon.TextSize = 16
    flingIcon.Parent = row

    row.MouseEnter:Connect(function() tween(row, 0.15, {BackgroundColor3 = Theme.ElementHov}) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, {BackgroundColor3 = Theme.Element}) end)
    row.MouseButton1Click:Connect(function()
        createRipple(row, Mouse.X - row.AbsolutePosition.X, Mouse.Y - row.AbsolutePosition.Y)
        callback(plr)
    end)
    return row
end

--// ==================================================
--// UI:init
--// ==================================================
function UI:init(Features)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TrustHubUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    --// Floating Button
    local FloatingBtn = Instance.new("TextButton")
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

    FloatingBtn.MouseEnter:Connect(function()
        tween(FloatingBtn, 0.2, {Size = UDim2.new(0, 58, 0, 58)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
    FloatingBtn.MouseLeave:Connect(function()
        tween(FloatingBtn, 0.2, {Size = UDim2.new(0, 52, 0, 52)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)

    --// Main Window
    local Main = Instance.new("Frame")
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
    VersionLbl.Text = "v13.0"
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

    CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, 0.15, {BackgroundColor3 = Theme.Danger}) end)
    CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, 0.15, {BackgroundColor3 = Theme.Element}) end)

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

    local function createTab(name, letter)
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
        Emoji.Text = letter
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
            if ActiveTab ~= name then tween(Btn, 0.15, {BackgroundColor3 = Theme.PanelLight}) end
        end)
        Btn.MouseLeave:Connect(function()
            if ActiveTab ~= name then tween(Btn, 0.15, {BackgroundColor3 = Theme.Panel}) end
        end)

        return Page
    end

    --// 7 Tabs
    local AimPage       = createTab("Aimbot", "A")
    local MurdererPage  = createTab("Murderer", "🔪")
    local FlingPage     = createTab("Fling", "F")
    local VisualsPage   = createTab("Visuals", "V")
    local MovePage      = createTab("Movement", "M")
    local AnimationPage = createTab("Animation", "🎭")
    local SettingsPage  = createTab("Settings", "S")

    --// ==================================================
    --// AIMBOT TAB
    --// ==================================================
    createSection(AimPage, "Silent Aim")

    createToggle(AimPage, "Enable Silent Aim", false, function(v)
        if Features.SilentAim then Features.SilentAim:setEnabled(v) end
    end)

    createSlider(AimPage, "FOV Radius", 50, 600, 200, function(v)
        if Features.SilentAim and Features.SilentAim.setFOV then 
            Features.SilentAim:setFOV(v) 
        end
    end)

    createSlider(AimPage, "Hit Chance %", 1, 100, 100, function(v)
        if Features.SilentAim and Features.SilentAim.setHitChance then 
            Features.SilentAim:setHitChance(v) 
        end
    end)

    createSlider(AimPage, "Prediction", 0, 1, 0.135, function(v)
        if Features.SilentAim and Features.SilentAim.setPrediction then 
            Features.SilentAim:setPrediction(v) 
        end
    end)

    createToggle(AimPage, "Team Check", true, function(v)
        if Features.SilentAim and Features.SilentAim.setTeamCheck then 
            Features.SilentAim:setTeamCheck(v) 
        end
    end)

    createToggle(AimPage, "Wall Check", false, function(v)
        if Features.SilentAim and Features.SilentAim.setWallCheck then 
            Features.SilentAim:setWallCheck(v) 
        end
    end)

    createToggle(AimPage, "Show FOV Circle", true, function(v)
        if Features.SilentAim and Features.SilentAim.setShowFOV then 
            Features.SilentAim:setShowFOV(v) 
        end
    end)

    --// ==================================================
    --// MURDERER TAB
    --// ==================================================
    createSection(MurdererPage, "🔪 Murderer Actions")

    createActionButton(MurdererPage, "💀 KILL ALL PLAYERS", Color3.fromRGB(200, 30, 30), function()
        if Features.Murderer then Features.Murderer:killAll() end
    end)

    createActionButton(MurdererPage, "💥 FLING ALL PLAYERS", Color3.fromRGB(255, 100, 100), function()
        if Features.Murderer then Features.Murderer:flingAll() end
    end)

    createToggle(MurdererPage, "Auto Kill (every 2s)", false, function(v)
        if Features.Murderer then Features.Murderer:setAutoKill(v) end
    end)

    createActionButton(MurdererPage, "🔍 DIAGNOSTICS", Theme.Accent, function()
        if Features.Murderer then Features.Murderer:diagnostics() end
    end)

    local murInfo = Instance.new("TextLabel")
    murInfo.Size = UDim2.new(1, -16, 0, 90)
    murInfo.BackgroundTransparency = 1
    murInfo.Text = "⚠ Works ONLY as Murderer (with knife)"
    murInfo.TextColor3 = Theme.TextDim
    murInfo.Font = Enum.Font.Gotham
    murInfo.TextSize = 11
    murInfo.TextXAlignment = Enum.TextXAlignment.Left
    murInfo.TextYAlignment = Enum.TextYAlignment.Top
    murInfo.TextWrapped = true
    murInfo.Parent = MurdererPage

    --// ==================================================
    --// FLING TAB
    --// ==================================================
    createSection(FlingPage, "Quick Actions")

    createActionButton(FlingPage, "FLING SHERIFF", Theme.Sheriff, function()
        if Features.Fling then Features.Fling:flingSheriff() end
    end)

    createActionButton(FlingPage, "FLING MURDER", Theme.Murderer, function()
        if Features.Fling then Features.Fling:flingMurderer() end
    end)

    createSection(FlingPage, "Players — Click to Fling")

    local playerListFrame = Instance.new("Frame")
    playerListFrame.Size = UDim2.new(1, -16, 0, 320)
    playerListFrame.BackgroundColor3 = Theme.Element
    playerListFrame.BorderSizePixel = 0
    playerListFrame.Parent = FlingPage
    corner(playerListFrame, 8)

    local playerListScroll = Instance.new("ScrollingFrame")
    playerListScroll.Size = UDim2.new(1, -8, 1, -8)
    playerListScroll.Position = UDim2.new(0, 4, 0, 4)
    playerListScroll.BackgroundTransparency = 1
    playerListScroll.BorderSizePixel = 0
    playerListScroll.ScrollBarThickness = 3
    playerListScroll.ScrollBarImageColor3 = Theme.Accent
    playerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerListScroll.Parent = playerListFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = playerListScroll

    local function refreshPlayerList()
        for _, child in ipairs(playerListScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        if not Features.Fling or not Features.Fling.getPlayersWithRoles then return end
        local list = Features.Fling:getPlayersWithRoles()
        for _, data in ipairs(list) do
            createPlayerRow(
                playerListScroll, data.player, data.role, data.color,
                function(plr)
                    if Features.Fling then Features.Fling:flingPlayer(plr) end
                end
            )
        end
    end

    task.spawn(function()
        task.wait(1)
        pcall(refreshPlayerList)
        while task.wait(3) do
            pcall(refreshPlayerList)
        end
    end)

    --// ==================================================
    --// VISUALS TAB
    --// ==================================================
    createSection(VisualsPage, "ESP")

    createToggle(VisualsPage, "Enable ESP", false, function(v)
        if Features.ESP then Features.ESP:setEnabled(v) end
    end)

    local legendFrame = Instance.new("Frame")
    legendFrame.Size = UDim2.new(1, -16, 0, 90)
    legendFrame.BackgroundColor3 = Theme.Element
    legendFrame.BorderSizePixel = 0
    legendFrame.Parent = VisualsPage
    corner(legendFrame, 8)

    local legendText = Instance.new("TextLabel")
    legendText.Size = UDim2.new(1, -20, 1, 0)
    legendText.Position = UDim2.new(0, 10, 0, 0)
    legendText.BackgroundTransparency = 1
    legendText.Text = "Role Colors\n\nRed   = Murderer\nBlue  = Sheriff\nGreen = Innocent"
    legendText.TextColor3 = Theme.TextDim
    legendText.Font = Enum.Font.Gotham
    legendText.TextSize = 12
    legendText.TextXAlignment = Enum.TextXAlignment.Left
    legendText.TextYAlignment = Enum.TextYAlignment.Center
    legendText.Parent = legendFrame

    --// FOV
    createSection(VisualsPage, "Camera FOV")

    createToggle(VisualsPage, "Enable FOV Changer", false, function(v)
        if Features.FOV then Features.FOV:setEnabled(v) end
    end)

    createSlider(VisualsPage, "FOV Value", 20, 120, 70, function(v)
        if Features.FOV and Features.FOV.setValue then Features.FOV:setValue(v) end
    end)

    local fovInfo = Instance.new("TextLabel")
    fovInfo.Size = UDim2.new(1, -16, 0, 30)
    fovInfo.BackgroundTransparency = 1
    fovInfo.Text = "70 = default  •  100+ = widescreen"
    fovInfo.TextColor3 = Theme.TextDim
    fovInfo.Font = Enum.Font.Gotham
    fovInfo.TextSize = 11
    fovInfo.TextXAlignment = Enum.TextXAlignment.Left
    fovInfo.Parent = VisualsPage

    --// ==================================================
    --// MOVEMENT TAB
    --// ==================================================

    -- FLY
    createSection(MovePage, "✈ Fly")

    createToggle(MovePage, "Enable Fly", false, function(v)
        if Features.Fly then Features.Fly:setEnabled(v) end
    end)

    createSlider(MovePage, "Fly Speed", 10, 200, 60, function(v)
        if Features.Fly and Features.Fly.setSpeed then Features.Fly:setSpeed(v) end
    end)

    local flyInfo = Instance.new("TextLabel")
    flyInfo.Size = UDim2.new(1, -16, 0, 30)
    flyInfo.BackgroundTransparency = 1
    flyInfo.Text = "WASD to move  •  Space/Ctrl = up/down"
    flyInfo.TextColor3 = Theme.TextDim
    flyInfo.Font = Enum.Font.Gotham
    flyInfo.TextSize = 11
    flyInfo.TextXAlignment = Enum.TextXAlignment.Left
    flyInfo.Parent = MovePage

    -- INFINITE JUMP
    createSection(MovePage, "🦘 Infinite Jump")

    createToggle(MovePage, "Enable Infinite Jump", false, function(v)
        if Features.InfJump then Features.InfJump:setEnabled(v) end
    end)

    local infjInfo = Instance.new("TextLabel")
    infjInfo.Size = UDim2.new(1, -16, 0, 20)
    infjInfo.BackgroundTransparency = 1
    infjInfo.Text = "Hold Space to keep jumping"
    infjInfo.TextColor3 = Theme.TextDim
    infjInfo.Font = Enum.Font.Gotham
    infjInfo.TextSize = 11
    infjInfo.TextXAlignment = Enum.TextXAlignment.Left
    infjInfo.Parent = MovePage

    --// ANTI-FLING (нове)
    createSection(MovePage, "🛡 Anti-Fling")

    createToggle(MovePage, "Enable Anti-Fling", false, function(v)
        if Features.AntiFling then Features.AntiFling:setEnabled(v) end
    end)

    createSlider(MovePage, "Max Velocity", 50, 800, 220, function(v)
        if Features.AntiFling and Features.AntiFling.setLimit then 
            Features.AntiFling:setLimit(v) 
        end
    end)

    local afInfo = Instance.new("TextLabel")
    afInfo.Size = UDim2.new(1, -16, 0, 30)
    afInfo.BackgroundTransparency = 1
    afInfo.Text = "Stops sudden speed spikes from launching you"
    afInfo.TextColor3 = Theme.TextDim
    afInfo.Font = Enum.Font.Gotham
    afInfo.TextSize = 11
    afInfo.TextXAlignment = Enum.TextXAlignment.Left
    afInfo.Parent = MovePage

    -- NOCLIP
    createSection(MovePage, "Noclip")
    createToggle(MovePage, "Enable Noclip", false, function(v)
        if Features.Noclip then Features.Noclip:setEnabled(v) end
    end)

    -- AUTO GUN
    createSection(MovePage, "Auto Gun")
    createToggle(MovePage, "Auto Pickup Gun", false, function(v)
        if Features.AutoGun then Features.AutoGun:setEnabled(v) end
    end)

    -- AUTO FARM
    createSection(MovePage, "💰 Auto Farm")

    createToggle(MovePage, "Enable Auto Farm", false, function(v)
        if Features.AutoFarm then Features.AutoFarm:setEnabled(v) end
    end)

    createToggle(MovePage, "Auto Fling Murderer", true, function(v)
        if Features.AutoFarm and Features.AutoFarm.setAutoFling then 
            Features.AutoFarm:setAutoFling(v) 
        end
    end)

    local farmInfo = Instance.new("TextLabel")
    farmInfo.Size = UDim2.new(1, -16, 0, 30)
    farmInfo.BackgroundTransparency = 1
    farmInfo.Text = "Flies through walls to collect coins (Speed: 22)"
    farmInfo.TextColor3 = Theme.TextDim
    farmInfo.Font = Enum.Font.Gotham
    farmInfo.TextSize = 11
    farmInfo.TextXAlignment = Enum.TextXAlignment.Left
    farmInfo.Parent = MovePage

    -- AUTO KILL
    createSection(MovePage, "💥 Auto Kill Murderer")

    createToggle(MovePage, "Enable Auto Kill Murder", false, function(v)
        if Features.AutoFarm and Features.AutoFarm.setAutoKill then 
            Features.AutoFarm:setAutoKill(v) 
        end
    end)

    createSlider(MovePage, "Kill Delay (sec)", 1, 10, 3, function(v)
        if Features.AutoFarm and Features.AutoFarm.setKillDelay then 
            Features.AutoFarm:setKillDelay(v) 
        end
    end)

    -- SPEED
    createSection(MovePage, "Speed")
    createToggle(MovePage, "Enable Speed", false, function(v)
        if Features.Speed then Features.Speed:setEnabled(v) end
    end)
    createSlider(MovePage, "Speed Value", 16, 200, 32, function(v)
        if Features.Speed and Features.Speed.setValue then 
            Features.Speed:setValue(v) 
        end
    end)

    --// ==================================================
    --// ANIMATION TAB
    --// ==================================================
    createSection(AnimationPage, "R15 Animation Sets")

    local animInfoFrame = Instance.new("Frame")
    animInfoFrame.Size = UDim2.new(1, -16, 0, 40)
    animInfoFrame.BackgroundColor3 = Theme.Element
    animInfoFrame.BorderSizePixel = 0
    animInfoFrame.Parent = AnimationPage
    corner(animInfoFrame, 8)

    local animInfoText = Instance.new("TextLabel")
    animInfoText.Size = UDim2.new(1, -20, 1, 0)
    animInfoText.Position = UDim2.new(0, 10, 0, 0)
    animInfoText.BackgroundTransparency = 1
    animInfoText.Text = "Works only on R15 characters. Click to apply."
    animInfoText.TextColor3 = Theme.TextDim
    animInfoText.Font = Enum.Font.Gotham
    animInfoText.TextSize = 11
    animInfoText.TextXAlignment = Enum.TextXAlignment.Left
    animInfoText.TextYAlignment = Enum.TextYAlignment.Center
    animInfoText.Parent = animInfoFrame

    local animListFrame = Instance.new("Frame")
    animListFrame.Size = UDim2.new(1, -16, 0, 400)
    animListFrame.BackgroundColor3 = Theme.Element
    animListFrame.BorderSizePixel = 0
    animListFrame.Parent = AnimationPage
    corner(animListFrame, 8)

    local animScroll = Instance.new("ScrollingFrame")
    animScroll.Size = UDim2.new(1, -8, 1, -8)
    animScroll.Position = UDim2.new(0, 4, 0, 4)
    animScroll.BackgroundTransparency = 1
    animScroll.BorderSizePixel = 0
    animScroll.ScrollBarThickness = 3
    animScroll.ScrollBarImageColor3 = Theme.Accent
    animScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    animScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    animScroll.Parent = animListFrame

    local animListLayout = Instance.new("UIListLayout")
    animListLayout.Padding = UDim.new(0, 4)
    animListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    animListLayout.Parent = animScroll

    local animButtons = {}
    local activeAnimName = nil

    local function setActiveAnim(name)
        for animName, btn in pairs(animButtons) do
            if animName == name then
                tween(btn, 0.2, {BackgroundColor3 = Theme.Accent})
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                tween(btn, 0.2, {BackgroundColor3 = Theme.Element})
                btn.TextColor3 = Theme.Text
            end
        end
        activeAnimName = name
    end

    if Features.Animation and Features.Animation.getAnimationList then
        local list = Features.Animation:getAnimationList()
        for _, name in ipairs(list) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 32)
            btn.BackgroundColor3 = Theme.Element
            btn.Text = name
            btn.TextColor3 = Theme.Text
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 12
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Parent = animScroll
            corner(btn, 6)

            btn.MouseEnter:Connect(function()
                if activeAnimName ~= name then
                    tween(btn, 0.15, {BackgroundColor3 = Theme.ElementHov})
                end
            end)
            btn.MouseLeave:Connect(function()
                if activeAnimName ~= name then
                    tween(btn, 0.15, {BackgroundColor3 = Theme.Element})
                end
            end)
            btn.MouseButton1Click:Connect(function()
                createRipple(btn, Mouse.X - btn.AbsolutePosition.X, Mouse.Y - btn.AbsolutePosition.Y)
                if Features.Animation then
                    Features.Animation:playAnimationSet(name)
                    setActiveAnim(name)
                end
            end)

            animButtons[name] = btn
        end
    end

    createSection(AnimationPage, "Controls")

    createActionButton(AnimationPage, "RESET ANIMATIONS", Theme.Danger, function()
        if Features.Animation then
            Features.Animation:reset()
            for _, btn in pairs(animButtons) do
                tween(btn, 0.2, {BackgroundColor3 = Theme.Element})
                btn.TextColor3 = Theme.Text
            end
            activeAnimName = nil
        end
    end)

    --// ==================================================
    --// SETTINGS TAB
    --// ==================================================
    createSection(SettingsPage, "Info")

    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -16, 0, 180)
    infoFrame.BackgroundColor3 = Theme.Element
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = SettingsPage
    corner(infoFrame, 8)

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -20, 1, 0)
    infoText.Position = UDim2.new(0, 10, 0, 0)
    infoText.BackgroundTransparency = 1
    infoText.Text = "TrustHub v13.0\n\nF4  — toggle menu\n\nTabs:\nAimbot | Murderer | Fling | Visuals | Movement | Animation | Settings"
    infoText.TextColor3 = Theme.TextDim
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 12
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.Parent = infoFrame

    --// Activate first tab
    Tabs["Aimbot"].Page.Visible = true
    ActiveTab = "Aimbot"
    Tabs["Aimbot"].Button.BackgroundColor3 = Theme.PanelLight
    Tabs["Aimbot"].Indicator.BackgroundTransparency = 0
    Tabs["Aimbot"].Indicator.Size = UDim2.new(0, 3, 0.7, 0)
    Tabs["Aimbot"].Indicator.Position = UDim2.new(0, 0, 0.15, 0)
    Tabs["Aimbot"].Label.TextColor3 = Theme.Accent
    Tabs["Aimbot"].Emoji.TextColor3 = Theme.Accent

    --// Open / Close
    local isOpen = false
    local opening = false

    local function openPanel()
        if isOpen or opening then return end
        opening = true
        Main.Visible = true
        Main.Size = UDim2.new(0, 0, 0, 0)
        tween(Main, 0.35, {Size = UDim2.new(0, 580, 0, 520)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tween(FloatingBtn, 0.25, {BackgroundTransparency = 0.6})
        task.delay(0.35, function() isOpen = true; opening = false end)
    end

    local function closePanel()
        if not isOpen then return end
        isOpen = false
        local t = tween(Main, 0.2, {Size = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        t.Completed:Connect(function() Main.Visible = false end)
        tween(FloatingBtn, 0.25, {BackgroundTransparency = 0})
    end

    FloatingBtn.MouseButton1Click:Connect(function()
        if isOpen then closePanel() else openPanel() end
    end)

    CloseBtn.MouseButton1Click:Connect(closePanel)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F4 then
            if isOpen then closePanel() else openPanel() end
        end
    end)

    --// Drag Float
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingFloat = false end
    end)

    --// Drag Main
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    task.wait(0.3)
    openPanel()

    self.Main = Main
    self.Tabs = Tabs
    self.ScreenGui = ScreenGui
    self.FloatingBtn = FloatingBtn
end

return UI
