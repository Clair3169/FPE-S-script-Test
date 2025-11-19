task.wait(6)

local player = game.Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

local hasThirdPerson = Instance.new("BoolValue")
hasThirdPerson.Name = "ThirdPersonEnabled"
hasThirdPerson.Value = false
hasThirdPerson.Parent = player

local SoundService = game:GetService("SoundService")
local warningSound = Instance.new("Sound")
warningSound.SoundId = "rbxassetid://8382337318"
warningSound.Volume = 1
warningSound.Parent = SoundService

local bindableFunction = Instance.new("BindableFunction")

warningSound:Play()

warningSound.Ended:Connect(function()
    warningSound:Destroy()
end)

local function toCdnUrl(rawUrl)
    local cdnUrl = rawUrl:gsub("https://raw%.githubusercontent%.com/(.-)/refs/heads/(.-)/", "https://cdn.jsdelivr.net/gh/%1@%2/")
    cdnUrl = cdnUrl:gsub("/refs/heads", "")
    return cdnUrl
end

local RAW_URLS_TO_LOAD = {
    "https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/3rd_Person.lua",
    "https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Shiftlock.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Notification_CframeSpeed.lua"
	
}

local function loadAndExecuteRawUrl(rawUrl)
    local cdnUrl = toCdnUrl(rawUrl)
    
    task.spawn(function()
        
        local success, err = pcall(function()
            local scriptContent = game:HttpGet(cdnUrl, true)
            
            if scriptContent and type(scriptContent) == "string" and #scriptContent > 0 then
                loadstring(scriptContent)()
            else
                error("Fallo al descargar el script o contenido vacío.")
            end
        end)
        
        if not success then
            warn(err)
        end
    end)
end

bindableFunction.OnInvoke = function(buttonClicked)
	if buttonClicked == "Yess!!" then
		hasThirdPerson.Value = true
        
        for _, rawUrl in ipairs(RAW_URLS_TO_LOAD) do
            loadAndExecuteRawUrl(rawUrl)
        end
        
	elseif buttonClicked == "Nha" then
		hasThirdPerson.Value = false
	end
end

StarterGui:SetCore("SendNotification", {
	Title = "Hey you!",
	Text = "Do you want to activate third person mode?",
	Icon = "rbxassetid://97207642508375",
	Duration = 20,
	Callback = bindableFunction,
	Button1 = "Yess!!",
	Button2 = "Nha"
})
