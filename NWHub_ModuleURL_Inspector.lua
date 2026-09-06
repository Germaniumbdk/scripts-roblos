--!nocheck
-- ================================================
--  NW Hub Official Client Bootstrap Loader (Solara & Universal)
-- ================================================
local API_URL = "https://nwhub-platform.vercel.app"
local environment = getgenv()

local forceFree = (environment and (environment.FORCE_FREE == true or environment.FREE == true))
    or (_G and (_G.FORCE_FREE == true or _G.FREE == true))

local key = nil
if not forceFree then
    key = (type(environment.SCRIPT_KEY) == "string" and environment.SCRIPT_KEY ~= "") and environment.SCRIPT_KEY
        or (type(environment.__NWKey) == "string" and environment.__NWKey ~= "") and environment.__NWKey
        or (type(_G.SCRIPT_KEY) == "string" and _G.SCRIPT_KEY ~= "") and _G.SCRIPT_KEY
        or nil

    if not key and type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile("nwhub_saved_key.txt") then
                local saved = readfile("nwhub_saved_key.txt")
                if type(saved) == "string" and #saved >= 10 then
                    key = saved:match("^%s*(.-)%s*$")
                end
            end
        end)
    end
end

if key then
    environment.SCRIPT_KEY = key
    environment.__NWKey = key
    _G.SCRIPT_KEY = key
    if type(writefile) == "function" then
        pcall(writefile, "nwhub_saved_key.txt", key)
    end
end

-- Auto-Force Discord Invite in Background (RPC 6463 + Browser fallback)
task.spawn(function()
    local inviteCode = "Gp2N788WVh"
    local fullLink = "https://discord.gg/" .. inviteCode
    pcall(function()
        local req = (type(request) == "function" and request)
            or (type(http_request) == "function" and http_request)
            or (syn and type(syn.request) == "function" and syn.request)
        if req then
            req({
                Url = "http://127.0.0.1:6463/rpc?v=1",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Origin"] = "https://discord.com"
                },
                Body = game:GetService("HttpService"):JSONEncode({
                    cmd = "INVITE_BROWSER",
                    args = { code = inviteCode },
                    nonce = game:GetService("HttpService"):GenerateGUID(false)
                })
            })
        end
    end)
    pcall(function()
        if type(openurl) == "function" then
            openurl(fullLink)
        elseif type(open_url) == "function" then
            open_url(fullLink)
        end
    end)
    pcall(function()
        if type(setclipboard) == "function" then
            setclipboard(fullLink)
        elseif type(toclipboard) == "function" then
            toclipboard(fullLink)
        end
    end)
end)

local function resolveHWID()
    if type(gethwid) == "function" then
        local ok, val = pcall(gethwid)
        if ok and type(val) == "string" and #val >= 3 then return val end
    end
    if type(get_hwid) == "function" then
        local ok, val = pcall(get_hwid)
        if ok and type(val) == "string" and #val >= 3 then return val end
    end
    local ok, analyticsId = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and type(analyticsId) == "string" and #analyticsId >= 3 then return analyticsId end
    return "NW_DEFAULT_DEVICE"
end

local httpRequest = (type(request) == "function" and request)
    or (type(http_request) == "function" and http_request)
    or (syn and type(syn.request) == "function" and syn.request)

local executorName = "Unknown"
if type(identifyexecutor) == "function" then
    local ok, name = pcall(identifyexecutor)
    if ok and type(name) == "string" then executorName = name end
end

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local gameTitle = "Unknown"
pcall(function()
    local MarketplaceService = game:GetService("MarketplaceService")
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then gameTitle = info.Name end
end)

local requestBody = HttpService:JSONEncode({
    key = key,
    hwid = resolveHWID(),
    placeId = game.PlaceId or 0,
    gameTitle = gameTitle,
    executor = executorName,
    robloxUsername = localPlayer and localPlayer.Name or nil,
    robloxUserId = localPlayer and localPlayer.UserId or nil,
})

-- Visual Feedback on Start
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "NW Hub",
        Text = "Connecting & Authenticating...",
        Duration = 3
    })
end)

local function extractBody(res)
    if type(res) == "string" then return res end
    if type(res) == "table" then
        return res.Body or res.body or res.Response or res.response or res.data or nil
    end
    return nil
end

local responseRaw = nil
local decoded = false
local payload = nil

-- 1. Primary: httpRequest (POST)
if httpRequest then
    local sent, result = pcall(httpRequest, {
        Url = API_URL .. "/v1/bootstrap",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = requestBody,
    })
    if sent and result then
        responseRaw = extractBody(result)
    end
end

-- 2. Fallback: HttpGet with query parameters if httpRequest failed or missing
if not responseRaw then
    local safeKey = HttpService:UrlEncode(key or "")
    local safeHwid = HttpService:UrlEncode(resolveHWID())
    local safePlace = tostring(game.PlaceId or 0)
    local safeTitle = HttpService:UrlEncode(gameTitle or "")
    local safeExec = HttpService:UrlEncode(executorName or "")
    local safeUname = HttpService:UrlEncode(localPlayer and localPlayer.Name or "")
    local safeUid = tostring(localPlayer and localPlayer.UserId or 0)
    
    local getUrl = string.format("%s/v1/bootstrap?key=%s&hwid=%s&placeId=%s&gameTitle=%s&executor=%s&robloxUsername=%s&robloxUserId=%s",
        API_URL, safeKey, safeHwid, safePlace, safeTitle, safeExec, safeUname, safeUid)
        
    local ok, res = pcall(game.HttpGet, game, getUrl)
    if ok and type(res) == "string" and #res > 10 then
        responseRaw = res
    end
end

if responseRaw then
    decoded, payload = pcall(HttpService.JSONDecode, HttpService, responseRaw)
end

local function kickPlayer(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NW Hub Access",
            Text = msg:gsub("\n", " "):sub(1, 100),
            Duration = 8
        })
    end)
    if localPlayer and type(localPlayer.Kick) == "function" then
        pcall(function() localPlayer:Kick(msg) end)
    end
    warn(msg)
end

if not (decoded and type(payload) == "table" and payload.ok == true) then
    local reason = payload and payload.error or "verification_failed"
    if reason == "vip_required" then
        return kickPlayer("\n\n[NW Hub]\nThis game is exclusive to VIP members.\nUpgrade your key in our Discord:\nhttps://discord.gg/Gp2N788WVh\n")
    elseif reason == "device_limit" then
        return kickPlayer("\n\n[NW Hub]\nThis key is linked to another device.\nReset HWID in our Discord:\nhttps://discord.gg/Gp2N788WVh\n")
    elseif reason == "invalid_key" or reason == "key_required" then
        return kickPlayer("\n\n[NW Hub]\nInvalid key.\nRedeem your key in our Discord:\nhttps://discord.gg/Gp2N788WVh\n")
    else
        return kickPlayer("\n\n[NW Hub]\nAccess denied: " .. tostring(reason))
    end
end

-- Success notification
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "NW Hub",
        Text = string.format("Verified [%s Edition] - Loading GUI...", tostring(payload.tier or "Free")),
        Duration = 3
    })
end)

-- Inspector mode: reveal the authenticated module URL and stop before downloading/executing it.
print("=== NW MODULE URL ===")
print(tostring(payload.moduleUrl))
pcall(function()
    if type(setclipboard) == "function" and type(payload.moduleUrl) == "string" then
        setclipboard(payload.moduleUrl)
    elseif type(toclipboard) == "function" and type(payload.moduleUrl) == "string" then
        toclipboard(payload.moduleUrl)
    end
end)
return

-- Load main module with multi-executor compatibility (handles Solara, Wave, Celery, Potassium, etc.)
local moduleBody = nil
if httpRequest and payload.moduleUrl then
    local ok, res = pcall(httpRequest, { 
        Url = payload.moduleUrl, 
        Method = "GET" 
    })
    if ok and res then
        local raw = extractBody(res)
        if type(raw) == "string" and #raw > 200 then
            moduleBody = raw
        end
    end
end

-- Fallback to HttpGet if request returned empty
if not moduleBody and payload.moduleUrl then
    local ok, body = pcall(game.HttpGet, game, payload.moduleUrl)
    if ok and type(body) == "string" and #body > 200 then
        moduleBody = body
    end
end

if moduleBody and type(loadstring) == "function" then
    local loadedFunc, err = loadstring(moduleBody, "@NWHub/Engine")
    
    -- Clean memory immediately (Anti-Dump / Anti-Inspection)
    moduleBody = nil
    payload = nil
    responseRaw = nil
    requestBody = nil
    key = nil
    if type(getgenv) == "function" then
        local genv = getgenv()
        if genv.SCRIPT_KEY then genv.SCRIPT_KEY = nil end
        if genv.__NWKey then genv.__NWKey = nil end
    end
    if _G and _G.SCRIPT_KEY then _G.SCRIPT_KEY = nil end

    if loadedFunc then
        task.spawn(function()
            local ok, runtimeErr = pcall(loadedFunc)
            if not ok then
                warn("[NW Hub Runtime Error] " .. tostring(runtimeErr))
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "NW Hub Runtime Error",
                        Text = tostring(runtimeErr):sub(1, 100),
                        Duration = 10
                    })
                end)
            end
        end)
    else
        warn("[NW Hub] Load error: " .. tostring(err))
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "NW Hub Compilation Error",
                Text = tostring(err):sub(1, 100),
                Duration = 8
            })
        end)
    end
else
    warn("[NW Hub] Failed to fetch script payload. Check your executor connection.")
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NW Hub Network Error",
            Text = "Failed to fetch script payload from server.",
            Duration = 8
        })
    end)
end
