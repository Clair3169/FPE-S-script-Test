task.wait()

local player = game.Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

local bindableFunction = Instance.new("BindableFunction")
bindableFunction.OnInvoke = function(buttonClicked)
	if buttonClicked == "Yes" then
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Cframe_Walkspeed.lua", true))()
	elseif buttonClicked == "No" then
		-- no se hace nada
	end
end

StarterGui:SetCore("SendNotification", {
	Title = "HEY!",
	Text = "Do you want to activate Walkspeed? If you choose yes, you will not be able to return to your normal speed.",
	Icon = "rbxassetid://97207642508375",
	Duration = 20,
	Callback = bindableFunction,
	Button1 = "Yess!!",
	Button2 = "Nha"
})
