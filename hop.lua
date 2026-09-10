local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- 1. TÌM UI PARENT AN TOÀN
local uiParent = nil
pcall(function()
    if gethui then
        uiParent = gethui()
    elseif CoreGui:FindFirstChild("RobloxGui") then
        uiParent = CoreGui
    end
end)
if not uiParent then
    uiParent = LocalPlayer:WaitForChild("PlayerGui")
end

if uiParent:FindFirstChild("LowServerFinder") then
    uiParent.LowServerFinder:Destroy()
end

-- 2. TÌM HÀM HTTP REQUEST
local requestFunc = nil
if type(syn) == "table" and syn.request then
    requestFunc = syn.request
elseif type(http) == "table" and http.request then
    requestFunc = http.request
elseif type(fluxus) == "table" and fluxus.request then
    requestFunc = fluxus.request
elseif http_request then
    requestFunc = http_request
elseif request then
    requestFunc = request
end

local gameName = "Unknown"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    gameName = info.Name or gameName
end)

-- 3. HỆ THỐNG FILE & THỜI GIAN
local folderName = "LowServerFinderData"
local fileName = folderName .. "/" .. tostring(game.PlaceId) .. "_servers.json"

pcall(function()
    if isfolder and not isfolder(folderName) then
        if makefolder then makefolder(folderName) end
    end
end)

local function SafeIsFile(path)
    if isfile then
        local success, res = pcall(function() return isfile(path) end)
        if success then return res end
    end
    return false
end

local function FormatTime(timestamp)
    if not timestamp or timestamp == 0 then return "Chưa rõ" end
    return os.date("%H:%M:%S - %d/%m/%Y", timestamp)
end

-- 4. HÀM KÉO THẢ GIAO DIỆN
local function MakeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.AbsolutePosition
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(0, startPos.X + delta.X, 0, startPos.Y + delta.Y)
        end
    end)
end

-- 5. TẠO GIAO DIỆN
local LowServerFinder = Instance.new("ScreenGui")
LowServerFinder.Name = "LowServerFinder"
LowServerFinder.Parent = uiParent
LowServerFinder.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = LowServerFinder
MainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -350, 0.5, -200)
MainFrame.Size = UDim2.new(0, 700, 0, 400)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0.02, 0, 0.015, 0)
Title.Size = UDim2.new(0, 250, 0, 30)
Title.Font = Enum.Font.GothamBold
Title.Text = "Server Finder 💻"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Nơi hiển thị Thời gian quét
local LastScanLabel = Instance.new("TextLabel")
LastScanLabel.Name = "LastScanLabel"
LastScanLabel.Parent = MainFrame
LastScanLabel.BackgroundTransparency = 1
LastScanLabel.Position = UDim2.new(0.02, 0, 0.09, 0)
LastScanLabel.Size = UDim2.new(0, 300, 0, 14)
LastScanLabel.Font = Enum.Font.SourceSansItalic
LastScanLabel.Text = "Last Scanned: Đang tải..."
LastScanLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
LastScanLabel.TextScaled = true
LastScanLabel.TextXAlignment = Enum.TextXAlignment.Left

local ServerListFrame = Instance.new("ScrollingFrame")
ServerListFrame.Name = "ServerListFrame"
ServerListFrame.Parent = MainFrame
ServerListFrame.Active = true
ServerListFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ServerListFrame.BorderSizePixel = 0
ServerListFrame.Position = UDim2.new(0.01, 0, 0.14, 0)
ServerListFrame.Size = UDim2.new(0, 686, 0, 332)
ServerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ServerListFrame.ScrollBarThickness = 6

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ServerListFrame
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ServerListFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
end)

local ServerFrameTemplate = Instance.new("Frame")
ServerFrameTemplate.Name = "ServerFrame"
ServerFrameTemplate.BackgroundColor3 = Color3.fromRGB(75, 75, 75)
ServerFrameTemplate.Size = UDim2.new(1, -10, 0, 45)
ServerFrameTemplate.Visible = false
Instance.new("UICorner", ServerFrameTemplate).CornerRadius = UDim.new(0, 8)

local ServerInfo = Instance.new("TextLabel")
ServerInfo.Name = "ServerInfo"
ServerInfo.Parent = ServerFrameTemplate
ServerInfo.BackgroundTransparency = 1
ServerInfo.Position = UDim2.new(0.02, 0, 0, 0)
ServerInfo.Size = UDim2.new(0.75, 0, 1, 0)
ServerInfo.Font = Enum.Font.SourceSansBold
ServerInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
ServerInfo.TextScaled = true
ServerInfo.TextXAlignment = Enum.TextXAlignment.Left

local Join = Instance.new("TextButton")
Join.Name = "Join"
Join.Parent = ServerFrameTemplate
Join.BackgroundColor3 = Color3.fromRGB(85, 85, 255)
Join.Position = UDim2.new(0.83, 0, 0.1, 0)
Join.Size = UDim2.new(0, 100, 0.8, 0)
Join.Font = Enum.Font.SourceSansBold
Join.Text = "Join 🚀"
Join.TextColor3 = Color3.fromRGB(255, 255, 255)
Join.TextScaled = true
Instance.new("UICorner", Join).CornerRadius = UDim.new(0, 6)

-- Các nút trên thanh công cụ
local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Name = "RefreshBtn"
RefreshBtn.Parent = MainFrame
RefreshBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
RefreshBtn.Position = UDim2.new(0.56, 0, 0.015, 0)
RefreshBtn.Size = UDim2.new(0, 100, 0, 30)
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.Text = "Refresh 🔄"
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.TextScaled = true
Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 6)

local CopyJobIdBtn = Instance.new("TextButton")
CopyJobIdBtn.Name = "CopyJobIdBtn"
CopyJobIdBtn.Parent = MainFrame
CopyJobIdBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
CopyJobIdBtn.Position = UDim2.new(0.72, 0, 0.015, 0)
CopyJobIdBtn.Size = UDim2.new(0, 90, 0, 30)
CopyJobIdBtn.Font = Enum.Font.GothamBold
CopyJobIdBtn.Text = "Copy JobId"
CopyJobIdBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyJobIdBtn.TextScaled = true
Instance.new("UICorner", CopyJobIdBtn).CornerRadius = UDim.new(0, 6)

local Close = Instance.new("TextButton")
Close.Name = "Close"
Close.Parent = MainFrame
Close.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
Close.Position = UDim2.new(0.87, 0, 0.015, 0)
Close.Size = UDim2.new(0, 70, 0, 30)
Close.Font = Enum.Font.GothamBold
Close.Text = "Close"
Close.TextColor3 = Color3.fromRGB(255, 255, 255)
Close.TextScaled = true
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 6)

local HideShow = Instance.new("TextButton")
HideShow.Name = "HideShow"
HideShow.Parent = LowServerFinder
HideShow.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
HideShow.Position = UDim2.new(0, 20, 0, 20)
HideShow.Size = UDim2.new(0, 60, 0, 40)
HideShow.Font = Enum.Font.GothamBold
HideShow.Text = "Hide"
HideShow.TextColor3 = Color3.fromRGB(255, 255, 255)
HideShow.TextScaled = true
Instance.new("UICorner", HideShow).CornerRadius = UDim.new(0, 8)

-- Tương tác Kéo thả
MakeDraggable(MainFrame)
MakeDraggable(HideShow)

local isHidden = false
HideShow.MouseButton1Click:Connect(function()
    isHidden = not isHidden
    MainFrame.Visible = not isHidden
    HideShow.Text = isHidden and "Show" or "Hide"
    HideShow.BackgroundColor3 = isHidden and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(0, 180, 0)
end)

Close.MouseButton1Click:Connect(function()
    LowServerFinder:Destroy()
end)

-- Chức năng Copy JobId
CopyJobIdBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(tostring(game.JobId))
        CopyJobIdBtn.Text = "Copied!"
        CopyJobIdBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
        task.wait(2)
        CopyJobIdBtn.Text = "Copy JobId"
        CopyJobIdBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    else
        CopyJobIdBtn.Text = "Error"
        CopyJobIdBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        task.wait(2)
        CopyJobIdBtn.Text = "Copy JobId"
        CopyJobIdBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    end
end)

-- 6. CHỨC NĂNG XỬ LÝ DATA & API
local function RenderList(serverList, scanTime)
    for _, child in ipairs(ServerListFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    LastScanLabel.Text = "Last Scanned: " .. FormatTime(scanTime)

    if not serverList or #serverList == 0 then return end

    -- SẮP XẾP DANH SÁCH: Ưu tiên Ping thấp nhất trước, sau đó tới Player Count
    table.sort(serverList, function(a, b)
        local pingA = type(a.ping) == "number" and a.ping or math.huge -- Nếu ping lỗi/ẩn thì gán số khổng lồ (bị đẩy xuống bét)
        local pingB = type(b.ping) == "number" and b.ping or math.huge
        
        if pingA == pingB then
            return (a.playing or 0) < (b.playing or 0)
        end
        return pingA < pingB
    end)

    -- Đổ dữ liệu ra UI
    for _, serverData in ipairs(serverList) do
        local clone = ServerFrameTemplate:Clone()
        clone.Parent = ServerListFrame
        clone.Visible = true

        local serverInfoLabel = clone:FindFirstChild("ServerInfo")
        local pingInfo = type(serverData.ping) == "number" and tostring(serverData.ping) or "N/A"
        
        serverInfoLabel.Text = string.format("👥 %d / %d Players   |   📶 Ping: %s ms\nID: %s", 
            serverData.playing, serverData.maxPlayers, pingInfo, tostring(serverData.id))

        local joinButton = clone:FindFirstChild("Join")
        joinButton.MouseButton1Click:Connect(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, serverData.id, LocalPlayer)
        end)
    end
end

-- Lấy Data từ API
local function FetchFromAPI()
    if not requestFunc then return {}, false end
    local servers = {}
    local cursor = nil
    local pagesFetched = 0
    local apiSuccess = false

    repeat
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        if cursor then url = url .. "&cursor=" .. cursor end
        
        local success, response = pcall(function()
            return requestFunc({ Url = url, Method = "GET" })
        end)

        if success and response then
            if response.StatusCode == 200 and response.Body then
                local decodeSuccess, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
                if decodeSuccess and data and data.data then
                    for _, server in ipairs(data.data) do
                        if type(server.playing) == "number" and server.playing < server.maxPlayers then
                            table.insert(servers, server)
                        end
                    end
                    cursor = data.nextPageCursor
                    pagesFetched = pagesFetched + 1
                else
                    break
                end
            else
                break
            end
        else
            break
        end
        task.wait(0.2)
    until not cursor or pagesFetched >= 4

    if pagesFetched > 0 then
        apiSuccess = true
    end

    return servers, apiSuccess
end

-- Lấy Data từ File JSON
local function LoadFromFile()
    if SafeIsFile(fileName) and readfile then
        local success, savedContent = pcall(function() return readfile(fileName) end)
        if success and type(savedContent) == "string" and savedContent ~= "" then
            local decSuccess, decData = pcall(function() return HttpService:JSONDecode(savedContent) end)
            if decSuccess and type(decData) == "table" then
                if decData.servers then
                    return decData.servers, decData.lastScan
                elseif #decData > 0 then
                    return decData, 0
                end
            end
        end
    end
    return {}, 0
end

-- Hàm thực thi làm mới dữ liệu
local function DoRefresh()
    local newServers, apiSuccess = FetchFromAPI()
    
    if apiSuccess and #newServers > 0 then
        local currentTime = os.time()
        local dataToSave = {
            lastScan = currentTime,
            servers = newServers
        }
        
        if writefile then
            pcall(function() writefile(fileName, HttpService:JSONEncode(dataToSave)) end)
        end
        
        RenderList(newServers, currentTime)
        return true
    else
        local savedData, savedTime = LoadFromFile()
        RenderList(savedData, savedTime)
        return false
    end
end

-- 7. NÚT LÀM MỚI (REFRESH)
local isRefreshing = false
RefreshBtn.MouseButton1Click:Connect(function()
    if isRefreshing then return end
    isRefreshing = true
    RefreshBtn.Text = "Loading..."
    
    task.spawn(function()
        local success = DoRefresh()
        
        if success then
            RefreshBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
            RefreshBtn.Text = "Success!"
        else
            RefreshBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
            RefreshBtn.Text = "Limit! Used Old"
        end
        
        task.wait(3)
        RefreshBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
        RefreshBtn.Text = "Refresh 🔄"
        isRefreshing = false
    end)
end)

-- 8. TỰ ĐỘNG CHẠY LẦN ĐẦU
task.spawn(function()
    RefreshBtn.Text = "Starting..."
    local success = DoRefresh()
    
    if not success then
        RefreshBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        RefreshBtn.Text = "Limit! Used Old"
        task.wait(3)
    end
    
    RefreshBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    RefreshBtn.Text = "Refresh 🔄"
end)
