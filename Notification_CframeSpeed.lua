task.wait(15)

local player = game.Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

local bindableFunction = Instance.new("BindableFunction")
bindableFunction.OnInvoke = function(buttonClicked)
	if buttonClicked == "Yess!!" then
		loadstring(game:HttpGet("", true))()
    -- aqui va el loader
	elseif buttonClicked == "Nha" then
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
