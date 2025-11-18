local player = game.Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local warningSound = Instance.new("Sound")
-- ID de sonido: ¡Recuerda cambiar este ID si es necesario!
warningSound.SoundId = "rbxassetid://104980570072214" 
warningSound.Volume = 1
warningSound.Parent = SoundService

local bindableFunction = Instance.new("BindableFunction")

warningSound:Play()

warningSound.Ended:Connect(function()
    warningSound:Destroy()
end)

bindableFunction.OnInvoke = function(buttonClicked)
	if buttonClicked == "Yes" then
        -- 1. Script Cframe_Walkspeed
        local cdn_url_1 = "https://cdn.jsdelivr.net/gh/Clair3169/FPE-S-script-Test@main/Cframe_Walkspeed.lua"
        pcall(loadstring(game:HttpGet(cdn_url_1, true))())
        
        -- 2. Script Notification_Warning
        local cdn_url_2 = "https://cdn.jsdelivr.net/gh/Clair3169/FPE-S-script-Test@main/Notification_Warning.lua"
        pcall(loadstring(game:HttpGet(cdn_url_2, true))())
        
	elseif buttonClicked == "No" then
		-- no se hace nada
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
