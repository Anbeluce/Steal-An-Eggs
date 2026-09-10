--[[
    ==================================================================
    ALL-IN-ONE GARDEN & PLAYER INCUBATING EGG INSPECTOR (v28)
    ==================================================================
    CHUẨN XÁC DỰA TRÊN BẢN GỐC V25 ĐÃ HOẠT ĐỘNG HOÀN HẢO:
    1. LOAD TRỨNG CHUẨN 100% THEO CƠ CHẾ GỐC CỦA V25:
       - Quét chuẩn xác toàn bộ trứng của bản thân và người chơi khác trong server.
       - Tên Pet theo màu Rarity của game, Mutation Tint, Cân nặng & Earning $/s.
    2. BỎ HOÀN TOÀN TÍNH NĂNG "BAY TỚI CƯỚP":
       - Thay thế tất cả thành "🎯 Tới Trứng" cho mọi quả trứng (kể cả vườn mình và người khác).
    3. DI CHUYỂN MƯỢT TỚI QUẢ TRỨNG (KHÔNG TELEPORT TỨC THỜI):
       - Không dùng set CFrame tức thì (tránh bị anti-cheat/server giật về chỗ cũ).
       - Sử dụng cơ chế di chuyển mượt liên tục (Tween/Physics Move) kèm bật Noclip xuyên chướng ngại vật.
       - Khi tới trước quả trứng (cách 2.5 studs), tự động xoay hitbox mặt trước trỏ thẳng vào tâm trứng để kích hoạt tương tác ngay lập tức.
    4. ẨN TRỨNG, TẮT HẲN HITBOX & TRIỆT TIÊU TOÀN BỘ TƯƠNG TÁC (NO PROMPTS):
       - Giữ nguyên cơ chế ẩn trứng hoàn hảo của v25.
    ==================================================================
]]

for _, oldName in ipairs({"GardenInspectorV28GUI", "GardenInspectorV27GUI", "GardenInspectorV26GUI", "GardenInspectorV25GUI", "GardenInspectorV24GUI", "GardenInspectorV23GUI", "IncubatingEggV22GUI", "GardenDumperV21GUI"}) do
    local old = game:GetService("CoreGui"):FindFirstChild(oldName)
    if old then old:Destroy() end
    pcall(function()
        local oldP = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(oldName)
        if oldP then oldP:Destroy() end
    end)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- =============================================
-- TRÍCH XUẤT CÁC MODULE GAME
-- =============================================
local AssetsCatalog = {}
pcall(function()
    local raw = require(ReplicatedStorage.Data.Assets)
    if raw then AssetsCatalog = raw.Directory or raw end
end)

local RarityCatalog = {}
pcall(function()
    local raw = require(ReplicatedStorage.Data.Rarity)
    if raw and raw.Rarities then RarityCatalog = raw.Rarities end
end)

local MutationsCatalog = {}
pcall(function()
    local m = require(ReplicatedStorage.Shared.Modules.Mutations.Catalog)
    if m then MutationsCatalog = m end
end)

local AssetItems = nil
pcall(function()
    AssetItems = require(ReplicatedStorage.Shared.Util.AssetItems)
end)

local AssetEarnings = nil
pcall(function()
    AssetEarnings = require(ReplicatedStorage.Shared.Util.AssetEarnings)
end)

-- =============================================
-- HÀM MÀU SẮC & ĐỊNH DẠNG
-- =============================================
local function getRarityColor(petCategory)
    local info = AssetsCatalog[petCategory]
    if info and info.Rarity and RarityCatalog[info.Rarity] then
        local rData = RarityCatalog[info.Rarity]
        if rData.Color then return rData.Color end
    end
    return Color3.fromRGB(230, 235, 245)
end

local function getMutationColor(mutationName)
    if mutationName and MutationsCatalog[mutationName] then
        local mData = MutationsCatalog[mutationName]
        if mData.Tint then return mData.Tint end
    end
    return Color3.fromRGB(255, 215, 0)
end

local function formatNumber(n)
    if not n or type(n) ~= "number" then return "0" end
    if n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n * 10) / 10) end
end

local function formatTime(seconds)
    if not seconds or seconds <= 0 then return "0s" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%dh %02dm %02ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function parseMutations(rec)
    local muts = {}
    local itemData = rec.ItemData or rec
    if itemData.Mutations and type(itemData.Mutations) == "table" then
        for _, m in pairs(itemData.Mutations) do
            if type(m) == "string" and m ~= "" and not table.find(muts, m) then
                table.insert(muts, m)
            end
        end
    end
    if #muts == 0 and itemData.BaseMutation and type(itemData.BaseMutation) == "string" and itemData.BaseMutation ~= "" then
        table.insert(muts, itemData.BaseMutation)
    end
    return muts
end

-- =============================================
-- QUẢN LÝ ẨN / HIỆN MÔ HÌNH, HITBOX & TƯƠNG TÁC (PROMPTS)
-- =============================================
local hiddenEggKeys = {} -- hiddenEggKeys[modelKey] = true
local originalProperties = {}
local originalPrompts = {}
local eggOriginalCFrames = {}
local eggOriginalPositions = {}

local function getEggModel(ownerIdStr, eggUid)
    local modelKey = ownerIdStr .. "_" .. eggUid
    local renders = Workspace:FindFirstChild("PlacedEggRenders")
    if renders then
        local m = renders:FindFirstChild(modelKey)
        if m and m:IsA("Model") then return m, modelKey end
    end
    -- Fallback: tìm trong Plots
    local plots = Workspace:FindFirstChild("Plots")
    if plots then
        for _, desc in ipairs(plots:GetDescendants()) do
            if desc:IsA("Model") and (desc.Name == modelKey or desc.Name == eggUid) then
                return desc, modelKey
            end
        end
    end
    return nil, modelKey
end

local function setEggHidden(ownerIdStr, eggUid, hide, eggTargetPos)
    local model, modelKey = getEggModel(ownerIdStr, eggUid)
    local targetPos = eggTargetPos

    if model and not targetPos then
        pcall(function() targetPos = model:GetPivot().Position end)
    end

    if hide then
        hiddenEggKeys[modelKey] = true
        if targetPos and not eggOriginalPositions[modelKey] then
            eggOriginalPositions[modelKey] = targetPos
        end

        if model then
            if not eggOriginalCFrames[modelKey] then
                pcall(function() eggOriginalCFrames[modelKey] = model:GetPivot() end)
            end

            -- 1. Tàng hình và tắt hitbox toàn bộ parts/prompts trong model
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("BasePart") then
                    if originalProperties[desc] == nil then
                        originalProperties[desc] = {
                            Transparency = desc.Transparency,
                            CanCollide = desc.CanCollide,
                            CanTouch = desc.CanTouch,
                            CanQuery = desc.CanQuery
                        }
                    end
                    desc.Transparency = 1
                    desc.CanCollide = false
                    desc.CanTouch = false
                    desc.CanQuery = false
                elseif desc:IsA("Decal") or desc:IsA("Texture") then
                    if originalProperties[desc] == nil then originalProperties[desc] = { Transparency = desc.Transparency } end
                    desc.Transparency = 1
                elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") or desc:IsA("Highlight") then
                    if originalProperties[desc] == nil then originalProperties[desc] = { Enabled = desc.Enabled } end
                    desc.Enabled = false
                elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
                    if originalProperties[desc] == nil then originalProperties[desc] = { Enabled = desc.Enabled } end
                    desc.Enabled = false
                elseif desc:IsA("ProximityPrompt") then
                    if originalPrompts[desc] == nil then
                        originalPrompts[desc] = {
                            Enabled = desc.Enabled,
                            MaxActivationDistance = desc.MaxActivationDistance,
                            ModelKey = modelKey
                        }
                    end
                    desc.Enabled = false
                    desc.MaxActivationDistance = 0
                end
            end

            -- 2. Dịch chuyển mô hình xuống sâu lòng đất (-2000 studs) để triệt tiêu kiểm tra khoảng cách của script game
            if eggOriginalCFrames[modelKey] then
                local origCFrame = eggOriginalCFrames[modelKey]
                pcall(function()
                    model:PivotTo(CFrame.new(origCFrame.Position.X, origCFrame.Position.Y - 2000, origCFrame.Position.Z))
                end)
            end
        end

        -- 3. Quét và tắt toàn bộ ProximityPrompt trong bán kính 14 studs của vị trí trứng (tổ trứng, smartpromptpart...)
        local searchPos = targetPos or (eggOriginalPositions[modelKey])
        if searchPos then
            pcall(function()
                for _, prompt in ipairs(Workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        local pPos = nil
                        if prompt.Parent:IsA("BasePart") then
                            pPos = prompt.Parent.Position
                        elseif prompt.Parent:IsA("Attachment") then
                            pPos = prompt.Parent.WorldPosition
                        end
                        if pPos and (pPos - searchPos).Magnitude <= 14 then
                            if originalPrompts[prompt] == nil then
                                originalPrompts[prompt] = {
                                    Enabled = prompt.Enabled,
                                    MaxActivationDistance = prompt.MaxActivationDistance,
                                    ModelKey = modelKey
                                }
                            end
                            prompt.Enabled = false
                            prompt.MaxActivationDistance = 0
                        end
                    end
                end
            end)
        end
    else
        hiddenEggKeys[modelKey] = nil

        if model then
            -- 1. Khôi phục lại CFrame ban đầu trên mặt đất
            if eggOriginalCFrames[modelKey] then
                pcall(function()
                    model:PivotTo(eggOriginalCFrames[modelKey])
                end)
                eggOriginalCFrames[modelKey] = nil
            end

            -- 2. Khôi phục lại thuộc tính các parts/prompts trong model
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("BasePart") then
                    local orig = originalProperties[desc]
                    if orig then
                        desc.Transparency = orig.Transparency
                        desc.CanCollide = orig.CanCollide
                        desc.CanTouch = orig.CanTouch
                        desc.CanQuery = orig.CanQuery
                        originalProperties[desc] = nil
                    else
                        desc.Transparency = 0
                        desc.CanCollide = false
                    end
                elseif desc:IsA("Decal") or desc:IsA("Texture") then
                    local orig = originalProperties[desc]
                    if orig then desc.Transparency = orig.Transparency; originalProperties[desc] = nil else desc.Transparency = 0 end
                elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") or desc:IsA("Highlight") then
                    local orig = originalProperties[desc]
                    if orig then desc.Enabled = orig.Enabled; originalProperties[desc] = nil else desc.Enabled = true end
                elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
                    local orig = originalProperties[desc]
                    if orig then desc.Enabled = orig.Enabled; originalProperties[desc] = nil else desc.Enabled = true end
                elseif desc:IsA("ProximityPrompt") then
                    local orig = originalPrompts[desc]
                    if orig then
                        desc.Enabled = orig.Enabled
                        desc.MaxActivationDistance = orig.MaxActivationDistance
                        originalPrompts[desc] = nil
                    else
                        desc.Enabled = true
                        desc.MaxActivationDistance = 8
                    end
                end
            end
        end

        -- 3. Khôi phục lại các ProximityPrompt xung quanh vị trí trứng
        pcall(function()
            for prompt, data in pairs(originalPrompts) do
                if data and data.ModelKey == modelKey and prompt and prompt.Parent then
                    prompt.Enabled = data.Enabled
                    prompt.MaxActivationDistance = data.MaxActivationDistance
                    originalPrompts[prompt] = nil
                end
            end
        end)

        eggOriginalPositions[modelKey] = nil
    end
end

-- Bộ đón chặn sự kiện PromptShown để ngăn chặn ngay lập tức nếu có prompt nào thuộc trứng đã ẩn
pcall(function()
    ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        local pPos = nil
        if prompt.Parent:IsA("BasePart") then
            pPos = prompt.Parent.Position
        elseif prompt.Parent:IsA("Attachment") then
            pPos = prompt.Parent.WorldPosition
        end
        if pPos then
            for mKey, isHidden in pairs(hiddenEggKeys) do
                if isHidden then
                    local origPos = eggOriginalPositions[mKey]
                    if origPos and (pPos - origPos).Magnitude <= 14 then
                        prompt.Enabled = false
                        prompt.MaxActivationDistance = 0
                        break
                    end
                end
            end
        end
    end)
end)

-- =============================================
-- THIẾT KẾ GIAO DIỆN (GUI)
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GardenInspectorV28GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local THEME = {
    BG = Color3.fromRGB(16, 18, 26),
    HEADER = Color3.fromRGB(22, 26, 38),
    CARD = Color3.fromRGB(25, 30, 44),
    BORDER = Color3.fromRGB(48, 56, 80),
    BLUE = Color3.fromRGB(50, 125, 245),
    GREEN = Color3.fromRGB(46, 204, 113),
    ORANGE = Color3.fromRGB(243, 156, 18),
    RED = Color3.fromRGB(235, 65, 65),
    TEXT = Color3.fromRGB(242, 244, 250),
    TEXT_SUB = Color3.fromRGB(150, 158, 180),
    BAR_BG = Color3.fromRGB(35, 42, 60),
    BAR_FILL = Color3.fromRGB(52, 199, 89)
}

-- 1. NÚT TRÒN NỔI (FLOATING TOGGLE)
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingEggBtn"
FloatingBtn.Size = UDim2.new(0, 46, 0, 46)
FloatingBtn.Position = UDim2.new(0, 15, 0.5, -23)
FloatingBtn.BackgroundColor3 = THEME.BG
FloatingBtn.Text = "🥚"
FloatingBtn.TextSize = 24
FloatingBtn.BorderSizePixel = 0
FloatingBtn.Active = true
FloatingBtn.Parent = ScreenGui
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(1, 0)

local fStroke = Instance.new("UIStroke", FloatingBtn)
fStroke.Color = THEME.BLUE
fStroke.Thickness = 2

local fDragging, fDragStart, fStartPos = false, nil, nil
FloatingBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fDragging = true
        fDragStart = input.Position
        fStartPos = FloatingBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then fDragging = false end
        end)
    end
end)

FloatingBtn.InputChanged:Connect(function(input)
    if fDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - fDragStart
        FloatingBtn.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + delta.X, fStartPos.Y.Scale, fStartPos.Y.Offset + delta.Y)
    end
end)

-- 2. KHUNG CHÍNH (MAIN WINDOW)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.Size = UDim2.new(0, 360, 0, 410)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -205)
MainFrame.BackgroundColor3 = THEME.BG
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local mStroke = Instance.new("UIStroke", MainFrame)
mStroke.Color = THEME.BORDER
mStroke.Thickness = 1.5

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = THEME.HEADER
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local hDragging, hDragStart, hStartPos = false, nil, nil
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        hDragging = true
        hDragStart = input.Position
        hStartPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then hDragging = false end
        end)
    end
end)
Header.InputChanged:Connect(function(input)
    if hDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - hDragStart
        MainFrame.Position = UDim2.new(hStartPos.X.Scale, hStartPos.X.Offset + delta.X, hStartPos.Y.Scale, hStartPos.Y.Offset + delta.Y)
    end
end)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🐣 SOI VƯỜN & TỚI TRỨNG (v28)"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
Title.TextColor3 = THEME.TEXT
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Nút Thu Nhỏ (—)
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.Position = UDim2.new(1, -62, 0, 6)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(48, 54, 72)
MinimizeBtn.Text = "—"
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 12
MinimizeBtn.TextColor3 = Color3.fromRGB(220, 225, 240)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Parent = Header
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

MinimizeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Nút Tắt Hẳn (✕)
local DestroyBtn = Instance.new("TextButton")
DestroyBtn.Size = UDim2.new(0, 26, 0, 26)
DestroyBtn.Position = UDim2.new(1, -32, 0, 6)
DestroyBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
DestroyBtn.Text = "✕"
DestroyBtn.Font = Enum.Font.GothamBold
DestroyBtn.TextSize = 12
DestroyBtn.TextColor3 = Color3.new(1, 1, 1)
DestroyBtn.BorderSizePixel = 0
DestroyBtn.Parent = Header
Instance.new("UICorner", DestroyBtn).CornerRadius = UDim.new(0, 6)

DestroyBtn.MouseButton1Click:Connect(function()
    -- Khôi phục lại toàn bộ trứng đã ẩn trước khi đóng
    for mKey, isHidden in pairs(hiddenEggKeys) do
        if isHidden then
            local parts = string.split(mKey, "_")
            setEggHidden(parts[1], parts[2], false)
        end
    end
    ScreenGui:Destroy()
    print("[GardenInspector v28] Đã khôi phục trứng và tắt hẳn GUI!")
end)

FloatingBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- 3. THANH CHỌN NGƯỜI CHƠI (PLAYER SELECTOR)
local PlayerSelector = Instance.new("ScrollingFrame")
PlayerSelector.Name = "PlayerSelector"
PlayerSelector.Size = UDim2.new(1, -16, 0, 28)
PlayerSelector.Position = UDim2.new(0, 8, 0, 42)
PlayerSelector.BackgroundTransparency = 1
PlayerSelector.BorderSizePixel = 0
PlayerSelector.ScrollBarThickness = 2
PlayerSelector.ScrollBarImageColor3 = THEME.BLUE
PlayerSelector.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerSelector.AutomaticCanvasSize = Enum.AutomaticSize.X
PlayerSelector.Parent = MainFrame

local pListLayout = Instance.new("UIListLayout")
pListLayout.FillDirection = Enum.FillDirection.Horizontal
pListLayout.SortOrder = Enum.SortOrder.LayoutOrder
pListLayout.Padding = UDim.new(0, 6)
pListLayout.Parent = PlayerSelector

-- 4. THANH CÔNG CỤ NHANH (QUICK ACTIONS BAR)
local ActionBar = Instance.new("Frame")
ActionBar.Size = UDim2.new(1, -16, 0, 24)
ActionBar.Position = UDim2.new(0, 8, 0, 72)
ActionBar.BackgroundTransparency = 1
ActionBar.Parent = MainFrame

local HideAllBtn = Instance.new("TextButton")
HideAllBtn.Size = UDim2.new(1, 0, 1, 0)
HideAllBtn.BackgroundColor3 = Color3.fromRGB(38, 44, 62)
HideAllBtn.Text = "👁️ Ẩn Hết Trứng Vườn Này (Tắt Tương Tác)"
HideAllBtn.Font = Enum.Font.GothamBold
HideAllBtn.TextSize = 10
HideAllBtn.TextColor3 = Color3.fromRGB(210, 220, 240)
HideAllBtn.BorderSizePixel = 0
HideAllBtn.Parent = ActionBar
Instance.new("UICorner", HideAllBtn).CornerRadius = UDim.new(0, 5)

-- 5. SCROLL DANH SÁCH TRỨNG
local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, -16, 1, -132)
ScrollList.Position = UDim2.new(0, 8, 0, 100)
ScrollList.BackgroundTransparency = 1
ScrollList.BorderSizePixel = 0
ScrollList.ScrollBarThickness = 3
ScrollList.ScrollBarImageColor3 = THEME.BLUE
ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollList.Parent = MainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = ScrollList

-- 6. THANH ĐÁY (STATUS BAR)
local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -16, 0, 24)
BottomBar.Position = UDim2.new(0, 8, 1, -28)
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = MainFrame

local StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, -85, 1, 0)
StatusBar.BackgroundTransparency = 1
StatusBar.Text = "⏳ Đang quét server..."
StatusBar.Font = Enum.Font.Gotham
StatusBar.TextSize = 10
StatusBar.TextColor3 = THEME.TEXT_SUB
StatusBar.TextXAlignment = Enum.TextXAlignment.Left
StatusBar.Parent = BottomBar

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 75, 1, 0)
RefreshBtn.Position = UDim2.new(1, -75, 0, 0)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 72)
RefreshBtn.Text = "🔄 Quét Lại"
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.TextSize = 9
RefreshBtn.TextColor3 = Color3.new(1, 1, 1)
RefreshBtn.BorderSizePixel = 0
RefreshBtn.Parent = BottomBar
Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 5)

-- =============================================
-- LOGIC QUÉT TRỨNG TẤT CẢ VƯỜN (ALL GARDENS)
-- =============================================
local allGardensData = {}
local selectedUserIdStr = tostring(LocalPlayer.UserId)

local TweenService = game:GetService("TweenService")
local currentMoveTween = nil

local function smoothMoveToTarget(targetPos, eggModel)
    if not targetPos then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return end

    if currentMoveTween then
        pcall(function() currentMoveTween:Cancel() end)
        currentMoveTween = nil
    end

    local eggGround = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
    local charPos = hrp.Position
    local delta = charPos - eggGround
    local flatDelta = Vector3.new(delta.X, 0, delta.Z)
    local forwardDir = (flatDelta.Magnitude > 0.1) and flatDelta.Unit or Vector3.new(0, 0, 1)

    local standPos = eggGround + (forwardDir * 2.5) + Vector3.new(0, 2.5, 0)
    local targetCFrame = CFrame.lookAt(standPos, Vector3.new(eggGround.X, standPos.Y, eggGround.Z))

    local dist = (charPos - standPos).Magnitude
    local moveSpeed = (hum and hum.WalkSpeed and hum.WalkSpeed > 40) and hum.WalkSpeed or 65
    local duration = math.clamp(dist / moveSpeed, 0.25, 3.0)

    -- Noclip trong khi di chuyển để không bị kẹt địa hình hay rào cản
    local noclipConn = nil
    noclipConn = game:GetService("RunService").Stepped:Connect(function()
        if char and char.Parent then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        else
            if noclipConn then noclipConn:Disconnect() end
        end
    end)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tw = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })
    currentMoveTween = tw

    tw.Completed:Connect(function()
        if noclipConn then noclipConn:Disconnect() end
        currentMoveTween = nil
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = targetCFrame
        if hum then
            pcall(function() hum:MoveTo(eggGround) end)
        end
        pcall(function()
            local cam = Workspace.CurrentCamera
            if cam then
                cam.CFrame = CFrame.lookAt(standPos + Vector3.new(0, 2.5, 0) + (forwardDir * 3.5), eggGround + Vector3.new(0, 0.8, 0))
            end
        end)
    end)

    tw:Play()

    -- Highlight quả trứng mục tiêu
    if eggModel and eggModel:IsA("Model") then
        pcall(function()
            local oldHl = eggModel:FindFirstChild("EggTargetHighlight")
            if oldHl then oldHl:Destroy() end
            local hl = Instance.new("Highlight")
            hl.Name = "EggTargetHighlight"
            hl.FillColor = Color3.fromRGB(0, 220, 255)
            hl.FillTransparency = 0.4
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.OutlineTransparency = 0
            hl.Adornee = eggModel
            hl.Parent = eggModel
            task.delay(duration + 2, function()
                if hl and hl.Parent then hl:Destroy() end
            end)
        end)
    end
end

local function scanAllPlayersGardens()
    local gardens = {}
    local allRenderPositions = {}
    pcall(function()
        local renders = Workspace:FindFirstChild("PlacedEggRenders")
        if renders then
            for _, child in ipairs(renders:GetChildren()) do
                local parts = string.split(child.Name, "_")
                local ownerId = parts[1]
                local eggUid = parts[2]
                if ownerId and eggUid then
                    if not allRenderPositions[ownerId] then allRenderPositions[ownerId] = {} end
                    local curPos = child:GetPivot().Position
                    if eggOriginalPositions[child.Name] then
                        curPos = eggOriginalPositions[child.Name]
                    end
                    allRenderPositions[ownerId][eggUid] = curPos
                end
            end
        end
    end)

    pcall(function()
        local rf = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskLiveSnapshot")
        if rf then
            local liveSnap = rf:InvokeServer()
            if liveSnap and type(liveSnap) == "table" then
                for plotKey, entry in pairs(liveSnap) do
                    if type(entry) == "table" and entry.OwnerUserId and entry.Records and type(entry.Records) == "table" then
                        local ownerIdStr = tostring(entry.OwnerUserId)
                        if not gardens[ownerIdStr] then
                            gardens[ownerIdStr] = { eggs = {}, plotKey = plotKey }
                        end

                        for uid, rec in pairs(entry.Records) do
                            if type(rec) == "table" and rec.Placement and type(rec.Placement) == "table" then
                                local cat = rec.AssetCategory or "Unknown"
                                local scale = rec.AssetScale or 1
                                local mutations = parseMutations(rec)
                                local catalogInfo = AssetsCatalog[cat] or {}
                                local eggInfo = catalogInfo.Egg or {}
                                local totalGrowth = eggInfo.GrowthTime or 300
                                local placedAt = rec.Placement.PlacedAt or 0
                                local speedMult = rec.GrowthSpeedMultiplier or 1

                                local targetPos = allRenderPositions[ownerIdStr] and allRenderPositions[ownerIdStr][tostring(uid)] or nil

                                table.insert(gardens[ownerIdStr].eggs, {
                                    UID = tostring(uid),
                                    Category = cat,
                                    Scale = scale,
                                    Mutations = mutations,
                                    PlacedAt = placedAt,
                                    SpeedMult = speedMult,
                                    TotalGrowthTime = totalGrowth,
                                    TargetPos = targetPos,
                                    CatalogInfo = catalogInfo,
                                    OwnerUserId = ownerIdStr
                                })
                            end
                        end
                    end
                end
            end
        end
    end)

    return gardens
end

-- =============================================
-- RENDER GIAO DIỆN & DANH SÁCH NGƯỜI CHƠI
-- =============================================
local activeCards = {}

local function updatePlayerSelector()
    for _, child in ipairs(PlayerSelector:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local playerList = { LocalPlayer }
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(playerList, p)
        end
    end

    for idx, p in ipairs(playerList) do
        local pIdStr = tostring(p.UserId)
        local isSelected = (pIdStr == selectedUserIdStr)
        local gData = allGardensData[pIdStr]
        local eggCount = gData and #gData.eggs or 0

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 0, 1, 0)
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.BackgroundColor3 = isSelected and THEME.BLUE or Color3.fromRGB(28, 32, 45)

        local displayName = (p == LocalPlayer) and "🌟 Vườn Của Tôi" or ("👤 " .. p.DisplayName)
        btn.Text = string.format(" %s (%d) ", displayName, eggCount)
        btn.Font = isSelected and Enum.Font.GothamBold or Enum.Font.GothamSemibold
        btn.TextSize = 10
        btn.TextColor3 = isSelected and Color3.new(1, 1, 1) or THEME.TEXT_SUB
        btn.BorderSizePixel = 0
        btn.LayoutOrder = idx
        btn.Parent = PlayerSelector
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

        btn.MouseButton1Click:Connect(function()
            selectedUserIdStr = pIdStr
            updatePlayerSelector()
            renderCurrentGardenEggs()
        end)
    end
end

function renderCurrentGardenEggs()
    for _, c in ipairs(ScrollList:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    activeCards = {}

    local currentGarden = allGardensData[selectedUserIdStr]
    local eggs = currentGarden and currentGarden.eggs or {}
    local isMyGarden = (selectedUserIdStr == tostring(LocalPlayer.UserId))

    local targetPlayerName = "Vườn nhà bạn"
    for _, p in ipairs(Players:GetPlayers()) do
        if tostring(p.UserId) == selectedUserIdStr then
            targetPlayerName = (p == LocalPlayer) and "Vườn nhà bạn" or (p.DisplayName .. " (@" .. p.Name .. ")")
            break
        end
    end

    -- Cập nhật nút Ẩn Tất Cả
    local allCurrentlyHidden = true
    for _, egg in ipairs(eggs) do
        local modelKey = egg.OwnerUserId .. "_" .. egg.UID
        if not hiddenEggKeys[modelKey] then
            allCurrentlyHidden = false
            break
        end
    end
    if #eggs == 0 then allCurrentlyHidden = false end

    HideAllBtn.Text = allCurrentlyHidden and "👁️ Hiện Lại Tất Cả Trứng" or "👁️ Ẩn Hết Trứng Vườn Này (Tắt Tương Tác)"
    HideAllBtn.BackgroundColor3 = allCurrentlyHidden and Color3.fromRGB(150, 70, 30) or Color3.fromRGB(38, 44, 62)

    if #eggs == 0 then
        local emptyCard = Instance.new("Frame")
        emptyCard.Size = UDim2.new(1, 0, 0, 110)
        emptyCard.BackgroundColor3 = THEME.CARD
        emptyCard.BorderSizePixel = 0
        emptyCard.Parent = ScrollList
        Instance.new("UICorner", emptyCard).CornerRadius = UDim.new(0, 10)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(1, 0, 0, 30)
        icon.Position = UDim2.new(0, 0, 0, 14)
        icon.BackgroundTransparency = 1
        icon.Text = "🪹"
        icon.TextSize = 28
        icon.Parent = emptyCard

        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, -24, 0, 50)
        emptyLbl.Position = UDim2.new(0, 12, 0, 48)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = string.format("%s hiện không có quả trứng nào đang ấp trong vườn.", targetPlayerName)
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.TextSize = 11
        emptyLbl.TextColor3 = THEME.TEXT_SUB
        emptyLbl.TextWrapped = true
        emptyLbl.Parent = emptyCard

        StatusBar.Text = string.format("%s: 0 trứng", targetPlayerName)
        return
    end

    local totalPotentialIncome = 0

    for idx, egg in ipairs(eggs) do
        local cat = egg.Category
        local scale = egg.Scale
        local mutations = egg.Mutations
        local catalogInfo = egg.CatalogInfo or {}
        local modelWeight = catalogInfo.ModelWeight or 1
        local petColor = getRarityColor(cat)
        local modelKey = egg.OwnerUserId .. "_" .. egg.UID
        local isHidden = hiddenEggKeys[modelKey] == true

        local itemData = {
            Category = cat,
            Scale = scale,
            Mutations = mutations,
            BaseMutation = mutations[1] or nil,
            Gender = "Male",
            EyeColor = "000000",
            ColorSeed = 0,
            ColorIndex = 0,
            HasBeenFirstPlaced = true
        }

        local weightStr = nil
        if AssetItems and AssetItems.WeightLabel then
            pcall(function() weightStr = AssetItems.WeightLabel(itemData) end)
        end
        if not weightStr then
            weightStr = string.format("%.2fKg", modelWeight * math.max(scale, 0)^3)
        end

        local rate = nil
        if AssetEarnings and AssetEarnings.RatePerSecond then
            pcall(function() rate = AssetEarnings.RatePerSecond(itemData) end)
        end
        local rateStr = rate and ("$" .. formatNumber(rate) .. "/s") or ("Base: $" .. formatNumber(catalogInfo.EarningRate or 0) .. "/s")
        if rate then totalPotentialIncome = totalPotentialIncome + rate end

        -- Card Frame
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 118)
        card.BackgroundColor3 = THEME.CARD
        card.BorderSizePixel = 0
        card.LayoutOrder = idx
        card.Parent = ScrollList
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        local cStroke = Instance.new("UIStroke", card)
        cStroke.Color = isHidden and Color3.fromRGB(150, 70, 30) or (isMyGarden and THEME.BORDER or Color3.fromRGB(90, 45, 60))
        cStroke.Thickness = 1

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = card

        -- DÒNG 1: Tên Pet & Huy hiệu Mutation
        local r1 = Instance.new("Frame")
        r1.Size = UDim2.new(1, 0, 0, 18)
        r1.BackgroundTransparency = 1
        r1.Parent = card

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -100, 1, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = (isHidden and "🚫 [ĐÃ ẨN] " or "🐣 ") .. cat
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 13
        nameLbl.TextColor3 = petColor
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = r1

        local topMut = mutations[1]
        local mutColor = topMut and getMutationColor(topMut) or THEME.TEXT_SUB
        local mutText = #mutations > 0 and table.concat(mutations, " + ") or "Normal"

        local mutBadge = Instance.new("TextLabel")
        mutBadge.Size = UDim2.new(0, 95, 1, 0)
        mutBadge.Position = UDim2.new(1, -95, 0, 0)
        mutBadge.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
        mutBadge.Text = mutText
        mutBadge.Font = Enum.Font.GothamBold
        mutBadge.TextSize = 9
        mutBadge.TextColor3 = mutColor
        mutBadge.Parent = r1
        Instance.new("UICorner", mutBadge).CornerRadius = UDim.new(0, 4)
        local bStroke = Instance.new("UIStroke", mutBadge)
        bStroke.Color = mutColor
        bStroke.Thickness = 0.8
        bStroke.Transparency = 0.4

        -- DÒNG 2: Cân nặng & Thu nhập sau khi nở
        local r2 = Instance.new("TextLabel")
        r2.Size = UDim2.new(1, 0, 0, 16)
        r2.Position = UDim2.new(0, 0, 0, 22)
        r2.BackgroundTransparency = 1
        r2.Text = string.format("⚖️ Cân nặng: %s  •  💰 Thu nhập: %s", weightStr, rateStr)
        r2.Font = Enum.Font.GothamSemibold
        r2.TextSize = 10
        r2.TextColor3 = THEME.GREEN
        r2.TextXAlignment = Enum.TextXAlignment.Left
        r2.Parent = card

        -- DÒNG 3: THANH TIẾN ĐỘ ẤP (PROGRESS BAR)
        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, 0, 0, 8)
        barBg.Position = UDim2.new(0, 0, 0, 44)
        barBg.BackgroundColor3 = THEME.BAR_BG
        barBg.BorderSizePixel = 0
        barBg.Parent = card
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = isMyGarden and THEME.BAR_FILL or THEME.ORANGE
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg
        Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

        -- DÒNG 4: Thời gian đã ấp / tổng thời gian
        local r4 = Instance.new("Frame")
        r4.Size = UDim2.new(1, 0, 0, 16)
        r4.Position = UDim2.new(0, 0, 0, 56)
        r4.BackgroundTransparency = 1
        r4.Parent = card

        local timeLbl = Instance.new("TextLabel")
        timeLbl.Size = UDim2.new(1, 0, 1, 0)
        timeLbl.BackgroundTransparency = 1
        timeLbl.Font = Enum.Font.Gotham
        timeLbl.TextSize = 10
        timeLbl.TextColor3 = THEME.TEXT_SUB
        timeLbl.TextXAlignment = Enum.TextXAlignment.Left
        timeLbl.Parent = r4

        -- DÒNG 5: TRẠNG THÁI + NÚT ẨN HITBOX + NÚT TELEPORT
        local r5 = Instance.new("Frame")
        r5.Size = UDim2.new(1, 0, 0, 24)
        r5.Position = UDim2.new(0, 0, 0, 76)
        r5.BackgroundTransparency = 1
        r5.Parent = card

        local statusTag = Instance.new("TextLabel")
        statusTag.Size = UDim2.new(1, -180, 1, 0)
        statusTag.BackgroundTransparency = 1
        statusTag.Font = Enum.Font.GothamBold
        statusTag.TextSize = 10
        statusTag.TextXAlignment = Enum.TextXAlignment.Left
        statusTag.Parent = r5

        -- Nút Ẩn / Hiện Trứng & Tắt Tương Tác
        local hideBtn = Instance.new("TextButton")
        hideBtn.Size = UDim2.new(0, 78, 1, 0)
        hideBtn.Position = UDim2.new(1, -178, 0, 0)
        hideBtn.BackgroundColor3 = isHidden and Color3.fromRGB(180, 80, 30) or Color3.fromRGB(50, 60, 80)
        hideBtn.Text = isHidden and "🚫 Đã Ẩn" or "👁️ Ẩn Trứng"
        hideBtn.Font = Enum.Font.GothamBold
        hideBtn.TextSize = 9
        hideBtn.TextColor3 = Color3.new(1, 1, 1)
        hideBtn.BorderSizePixel = 0
        hideBtn.Parent = r5
        Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 5)

        hideBtn.MouseButton1Click:Connect(function()
            local currentHidden = hiddenEggKeys[modelKey] == true
            local newHiddenState = not currentHidden

            setEggHidden(egg.OwnerUserId, egg.UID, newHiddenState, egg.TargetPos)

            hideBtn.Text = newHiddenState and "🚫 Đã Ẩn" or "👁️ Ẩn Trứng"
            hideBtn.BackgroundColor3 = newHiddenState and Color3.fromRGB(180, 80, 30) or Color3.fromRGB(50, 60, 80)
            nameLbl.Text = (newHiddenState and "🚫 [ĐÃ ẨN] " or "🐣 ") .. cat
            cStroke.Color = newHiddenState and Color3.fromRGB(150, 70, 30) or (isMyGarden and THEME.BORDER or Color3.fromRGB(90, 45, 60))
        end)

        -- Nút Teleport
        local moveBtn = Instance.new("TextButton")
        moveBtn.Size = UDim2.new(0, 95, 1, 0)
        moveBtn.Position = UDim2.new(1, -95, 0, 0)
        moveBtn.BackgroundColor3 = Color3.fromRGB(32, 128, 88)
        moveBtn.Text = "🎯 Tới Trứng"
        moveBtn.Font = Enum.Font.GothamBold
        moveBtn.TextSize = 9
        moveBtn.TextColor3 = Color3.new(1, 1, 1)
        moveBtn.BorderSizePixel = 0
        moveBtn.Parent = r5
        Instance.new("UICorner", moveBtn).CornerRadius = UDim.new(0, 5)

        moveBtn.MouseButton1Click:Connect(function()
            local targetPos = egg.TargetPos
            if not targetPos then
                local m = getEggModel(egg.OwnerUserId, egg.UID)
                if m then targetPos = m:GetPivot().Position end
            end
            if not targetPos and currentGarden and currentGarden.plotKey then
                pcall(function()
                    local plots = Workspace:FindFirstChild("Plots")
                    if plots then
                        local plotObj = plots:FindFirstChild(tostring(currentGarden.plotKey)) or plots:GetChildren()[1]
                        if plotObj and plotObj:FindFirstChild("SpawnPoint") then
                            targetPos = plotObj.SpawnPoint.Position
                        end
                    end
                end)
            end
            if targetPos then
                local m = getEggModel(egg.OwnerUserId, egg.UID)
                smoothMoveToTarget(targetPos, m)
            end
        end)

        table.insert(activeCards, {
            egg = egg,
            barFill = barFill,
            timeLbl = timeLbl,
            statusTag = statusTag,
            isMyGarden = isMyGarden
        })
    end

    StatusBar.Text = string.format("%s: %d quả | Tiềm năng: $%s/s", targetPlayerName, #eggs, formatNumber(totalPotentialIncome))
end

-- Xử lý nút Ẩn Tất Cả Trứng Vườn Này
HideAllBtn.MouseButton1Click:Connect(function()
    local currentGarden = allGardensData[selectedUserIdStr]
    local eggs = currentGarden and currentGarden.eggs or {}
    if #eggs == 0 then return end

    local allHidden = true
    for _, egg in ipairs(eggs) do
        local modelKey = egg.OwnerUserId .. "_" .. egg.UID
        if not hiddenEggKeys[modelKey] then
            allHidden = false
            break
        end
    end

    local targetState = not allHidden
    for _, egg in ipairs(eggs) do
        setEggHidden(egg.OwnerUserId, egg.UID, targetState, egg.TargetPos)
    end

    renderCurrentGardenEggs()
end)

-- =============================================
-- VÒNG LẶP COUNTDOWN & DUY TRÌ ẨN HITBOX
-- =============================================
local function updateCountdowns()
    local serverNow = 0
    pcall(function() serverNow = Workspace:GetServerTimeNow() end)
    if serverNow == 0 then serverNow = os.time() end

    for _, item in ipairs(activeCards) do
        local egg = item.egg
        local placedAt = egg.PlacedAt or 0
        local elapsed = math.max(0, (serverNow - placedAt) * (egg.SpeedMult or 1))
        local totalTime = egg.TotalGrowthTime or 300

        local pct = math.clamp(elapsed / totalTime, 0, 1)
        item.barFill.Size = UDim2.new(pct, 0, 1, 0)

        if elapsed >= totalTime then
            item.barFill.BackgroundColor3 = THEME.GREEN
            item.timeLbl.Text = string.format("Đã ấp: %s / %s (100%%)", formatTime(totalTime), formatTime(totalTime))
            if item.isMyGarden then
                item.statusTag.Text = "🎉 ĐÃ NỞ - SẴN SÀNG NHẬN!"
                item.statusTag.TextColor3 = THEME.GREEN
            else
                item.statusTag.Text = "🔥 ĐÃ NỞ - CƯỚP NGAY!"
                item.statusTag.TextColor3 = THEME.RED
            end
        else
            local remaining = math.max(0, totalTime - elapsed)
            item.barFill.BackgroundColor3 = item.isMyGarden and THEME.BLUE or THEME.ORANGE
            item.timeLbl.Text = string.format("Đã ấp: %s / %s (%.1f%%)", formatTime(elapsed), formatTime(totalTime), pct * 100)
            item.statusTag.Text = string.format("⏳ Còn lại: %s", formatTime(remaining))
            item.statusTag.TextColor3 = item.isMyGarden and THEME.ORANGE or THEME.TEXT
        end
    end

    -- Đảm bảo các mô hình đang ẩn luôn duy trì trạng thái tàng hình, không hitbox và tắt hoàn toàn tương tác (Prompts)
    local char = LocalPlayer.Character
    local hrpPos = (char and char:FindFirstChild("HumanoidRootPart")) and char.HumanoidRootPart.Position or nil

    for mKey, isHidden in pairs(hiddenEggKeys) do
        if isHidden then
            local parts = string.split(mKey, "_")
            local m = getEggModel(parts[1], parts[2])
            local origPos = eggOriginalPositions[mKey]

            if m then
                -- Nếu game script tự reset CFrame lên trên thì đẩy lại xuống lòng đất
                if origPos and m:GetPivot().Position.Y > (origPos.Y - 1000) then
                    pcall(function()
                        m:PivotTo(CFrame.new(origPos.X, origPos.Y - 2000, origPos.Z))
                    end)
                end

                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Transparency = 1
                        p.CanCollide = false
                        p.CanTouch = false
                        p.CanQuery = false
                    elseif p:IsA("ProximityPrompt") then
                        p.Enabled = false
                        p.MaxActivationDistance = 0
                    elseif p:IsA("BillboardGui") or p:IsA("SurfaceGui") or p:IsA("Highlight") then
                        p.Enabled = false
                    end
                end
            end

            -- Quét định kỳ tắt ProximityPrompt xung quanh tổ/trứng nếu game script kích hoạt lại
            if origPos then
                pcall(function()
                    for _, prompt in ipairs(Workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local pPos = nil
                            if prompt.Parent:IsA("BasePart") then
                                pPos = prompt.Parent.Position
                            elseif prompt.Parent:IsA("Attachment") then
                                pPos = prompt.Parent.WorldPosition
                            end
                            if pPos and (pPos - origPos).Magnitude <= 14 then
                                if originalPrompts[prompt] == nil then
                                    originalPrompts[prompt] = {
                                        Enabled = true,
                                        MaxActivationDistance = prompt.MaxActivationDistance,
                                        ModelKey = mKey
                                    }
                                end
                                prompt.Enabled = false
                                prompt.MaxActivationDistance = 0
                            end
                        end
                    end
                end)

                -- Nếu nhân vật đang đứng trong phạm vi trứng đã ẩn, chặn ngay các GUI tương tác trong PlayerGui
                if hrpPos and (hrpPos - origPos).Magnitude <= 14 then
                    pcall(function()
                        local ap = LocalPlayer.PlayerGui:FindFirstChild("ActionPrompts")
                        if ap and ap:FindFirstChild("Holder") then ap.Holder.Visible = false end
                        local aed = LocalPlayer.PlayerGui:FindFirstChild("AssetEggData")
                        if aed and aed:FindFirstChild("Frame") then aed.Frame.Visible = false end
                    end)
                end
            end
        end
    end
end

-- =============================================
-- ĐIỀU KHIỂN & LÀM MỚI DỮ LIỆU
-- =============================================
local isBusy = false
local function refreshAllData()
    if isBusy then return end
    isBusy = true
    StatusBar.Text = "⏳ Đang cập nhật..."

    task.spawn(function()
        allGardensData = scanAllPlayersGardens()
        updatePlayerSelector()
        renderCurrentGardenEggs()
        updateCountdowns()
        isBusy = false
    end)
end

RefreshBtn.MouseButton1Click:Connect(function()
    refreshAllData()
end)

Players.PlayerAdded:Connect(function()
    task.wait(1)
    refreshAllData()
end)

Players.PlayerRemoving:Connect(function(leftPlayer)
    if tostring(leftPlayer.UserId) == selectedUserIdStr then
        selectedUserIdStr = tostring(LocalPlayer.UserId)
    end
    task.wait(0.5)
    refreshAllData()
end)

-- Vòng lặp chính:
-- - Cập nhật countdown & duy trì tắt hitbox/tương tác mỗi 0.5s (ngay cả khi thu nhỏ)
-- - Quét lại máy chủ sau mỗi 4s khi mở bảng
coroutine.wrap(function()
    task.wait(0.5)
    refreshAllData()

    local lastFetch = tick()
    while ScreenGui.Parent do
        task.wait(0.5)
        updateCountdowns()
        if MainFrame.Visible and (tick() - lastFetch >= 4) then
            lastFetch = tick()
            refreshAllData()
        end
    end
end)()

print("[GardenInspector v28] Sẵn sàng: Giữ nguyên 100% gốc v25 + Di chuyển mượt tới trứng (Không Teleport, Không Cướp)!")
