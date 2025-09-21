-- ↓ Configurações e serviços
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerName = player.Name

local firebaseUrl = "https://gojo-hub-default-rtdb.firebaseio.com/"
local secretKey = "tAxUKU1BgidFb2xFco4FRYYz02y86gUw8ugZNjYf"

-- ↓ Flags
local jailActive = false
local remoteUsed = false
local freezeConnection -- para desconectar o RenderStepped quando desativar

-- ↓ Função para enviar Remote do Jail
local function triggerJailRemote()
    local args = {[1] = 91911156088438}
    pcall(function()
        ReplicatedStorage:WaitForChild("Remotes", 9e9):WaitForChild("Wear", 9e9):InvokeServer(unpack(args))
    end)
end

-- ↓ Função para congelar/descongelar personagem
local function freezeCharacter(active)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")

    if active then
        humanoid.PlatformStand = true
        hrp.Anchored = true

        if freezeConnection then freezeConnection:Disconnect() end
        freezeConnection = RunService.RenderStepped:Connect(function()
            if hrp then
                hrp.CFrame = hrp.CFrame
                humanoid.PlatformStand = true
                hrp.Anchored = true
            end
        end)

        -- Garantir que mesmo após respawn o freeze continue
        player.CharacterAdded:Connect(function(newChar)
            local newHumanoid = newChar:WaitForChild("Humanoid")
            local newHrp = newChar:WaitForChild("HumanoidRootPart")
            newHumanoid.PlatformStand = true
            newHrp.Anchored = true

            if freezeConnection then freezeConnection:Disconnect() end
            freezeConnection = RunService.RenderStepped:Connect(function()
                newHrp.CFrame = newHrp.CFrame
                newHumanoid.PlatformStand = true
                newHrp.Anchored = true
            end)
        end)
    else
        humanoid.PlatformStand = false
        hrp.Anchored = false
        if freezeConnection then
            freezeConnection:Disconnect()
            freezeConnection = nil
        end
    end
end

-- ↓ Função para reiniciar personagem (kill)
local function respawnPlayer()
    if player and player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
        else
            player.Character:Destroy()
        end
        warn("[GOJO HUB] Comando kill executado: personagem reiniciado.")
    end
end

-- ↓ Função para enviar mensagem local/global
local function sendChatMessage(message)
    pcall(function()
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:SendAsync(message)
        else
            local chatEvent = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest")
            chatEvent:FireServer(message, "All")
        end
    end)
end

-- ↓ Checar comando Jail do Firebase
local function checkJailCommand()
    local success, response = pcall(function()
        local url = firebaseUrl.."commands/jail_player.json?auth="..secretKey
        return game:HttpGet(url)
    end)

    if success and response and response ~= "null" then
        local data = HttpService:JSONDecode(response)
        if data.target == playerName and data.extra and data.extra.action == "jail" then
            -- ativa ou desativa dependendo do status
            if data.extra.status == true then
                if not remoteUsed then
                    triggerJailRemote()
                    remoteUsed = true
                end
                freezeCharacter(true)
                jailActive = true
            else
                if remoteUsed then
                    triggerJailRemote() -- envia de novo para destravar
                    remoteUsed = false
                end
                freezeCharacter(false)
                jailActive = false
            end
        end
    end
end

-- ↓ Checar comando Kill do Firebase
local function checkKillCommand()
    local success, response = pcall(function()
        local url = firebaseUrl.."commands/kill_player.json?auth="..secretKey
        return game:HttpGet(url)
    end)

    if success and response and response ~= "null" then
        local data = HttpService:JSONDecode(response)
        if data.target == playerName and data.extra and data.extra.action == "kill" then
            respawnPlayer()
            -- Remove comando após execução
            pcall(function()
                local requestFunc = (syn and syn.request) or http_request or request or (fluxus and fluxus.request) or http.request
                if requestFunc then
                    requestFunc({
                        Url = firebaseUrl.."commands/kill_player.json?auth="..secretKey,
                        Method = "DELETE",
                        Headers = {["Content-Type"]="application/json"}
                    })
                end
            end)
        end
    end
end

-- ↓ Checar comando Verifique do Firebase
local function checkVerifiqueCommand()
    local success, response = pcall(function()
        return game:HttpGet(firebaseUrl.."commands/verifique.json?auth="..secretKey)
    end)

    if success and response and response ~= "null" then
        sendChatMessage("GOJO_user")
        -- Remove comando após execução
        pcall(function()
            local requestFunc = (syn and syn.request) or http_request or request or (fluxus and fluxus.request) or http.request
            if requestFunc then
                requestFunc({
                    Url = firebaseUrl.."commands/verifique.json?auth="..secretKey,
                    Method = "DELETE",
                    Headers = {["Content-Type"]="application/json"}
                })
            end
        end)
    end
end

-- ↓ Checar comando de chat do admin
local function checkChatCommand()
    local success, response = pcall(function()
        return game:HttpGet(firebaseUrl.."commands/send_message.json?auth="..secretKey)
    end)

    if success and response and response ~= "null" then
        local data = HttpService:JSONDecode(response)
        if data.target == playerName and data.message then
            sendChatMessage(data.message)
            print("[GOJO HUB] Mensagem do admin enviada: "..data.message)
            -- Remove comando após execução
            pcall(function()
                local requestFunc = (syn and syn.request) or http_request or request or (fluxus and fluxus.request) or http.request
                if requestFunc then
                    requestFunc({
                        Url = firebaseUrl.."commands/send_message.json?auth="..secretKey,
                        Method = "DELETE",
                        Headers = {["Content-Type"]="application/json"}
                    })
                end
            end)
        end
    end
end

-- ↓ Loop principal em background (24/7)
task.spawn(function()
    while true do
        task.wait(1) -- verifica a cada 1 segundo
        checkJailCommand()
        checkKillCommand()
        checkVerifiqueCommand()
        checkChatCommand()
    end
end)
