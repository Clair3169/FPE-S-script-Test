task.wait(6)

local player = game.Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

local hasThirdPerson = Instance.new("BoolValue")
hasThirdPerson.Name = "ThirdPersonEnabled"
hasThirdPerson.Value = false
hasThirdPerson.Parent = player

local SoundService = game:GetService("SoundService")
local warningSound = Instance.new("Sound")
warningSound.SoundId = "rbxassetid://8382337318" -- <-- ¡Recuerda cambiar este ID!
warningSound.Volume = 1
warningSound.Parent = SoundService

local bindableFunction = Instance.new("BindableFunction")

warningSound:Play()

warningSound.Ended:Connect(function()
    warningSound:Destroy()
end)

bindableFunction.OnInvoke = function(buttonClicked)
	if buttonClicked == "Yess!!" then
		hasThirdPerson.Value = true
        
        -- Base de CDN: "https://cdn.jsdelivr.net/gh/Clair3169/FPE-S-script@main/"
        local cdn_base = "https://cdn.jsdelivr.net/gh/Clair3169/FPE-S-script@main/"

		-- Tercera persona
        local url_3rd = cdn_base .. "3rd_Person.lua"
        pcall(loadstring(game:HttpGet(url_3rd, true))())
        
		-- Shift Lock
        local url_shiftlock = cdn_base .. "Shiftlock.lua"
        pcall(loadstring(game:HttpGet(url_shiftlock, true))())
        
		-- Cframe Walkspeed (CORREGIDO: Usando Notification_CframeSpeed.lua)
		local url_walkspeed = cdn_base .. "Notification_CframeSpeed.lua"
		pcall(loadstring(game:HttpGet(url_walkspeed, true))())
		
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
