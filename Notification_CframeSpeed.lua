local player = game.Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local warningSound = Instance.new("Sound")
warningSound.SoundId = "rbxassetid://104980570072214"
warningSound.Volume = 1
warningSound.Parent = SoundService

local bindableFunction = Instance.new("BindableFunction")

warningSound:Play()

warningSound.Ended:Connect(function()
    warningSound:Destroy()
end)

local function toCdnUrl(simpleUrl)
    local cdnUrl = simpleUrl:gsub("https://raw%.githubusercontent%.com/(.-)/main/(.-)", "https://cdn.jsdelivr.net/gh/%1@main/%2")
    return cdnUrl
end

local RAW_URLS_TO_LOAD = {
    "https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/main/Cframe_Walkspeed.lua",
    "https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/main/Notification_Warning.lua",
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
	if buttonClicked == "Yes" then
        
        for _, rawUrl in ipairs(RAW_URLS_TO_LOAD) do
            loadAndExecuteRawUrl(rawUrl)
        end
        
	elseif buttonClicked == "No" then
	end
end

StarterGui:SetCore("SendNotification", {
	Title = "Hey again!",
	Text = "Do you want to activate speed mode?",
	Icon = "rbxassetid://97207642508375",
	Duration = 20,
	Callback = bindableFunction,
	Button1 = "Yes",
	Button2 = "No"
})
