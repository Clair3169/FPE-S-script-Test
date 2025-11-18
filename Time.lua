-- Versión avanzada: pausa, carpetas excluidas, color rojo, fade, prioridad por volumen, glitch Student y parpadeo final
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer or Players:GetPlayers()[1]
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = playerGui:FindFirstChild("TimerGui") or Instance.new("ScreenGui")
screenGui.Name = "TimerGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local label = screenGui:FindFirstChild("TimerLabel") or Instance.new("TextLabel")
label.Name = "TimerLabel"
label.Size = UDim2.new(0, 90, 0, 28)
label.Position = UDim2.new(0.5, -45, 0, -3)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(255,255,255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = "0:00"
label.Visible = true
label.ZIndex = 20
label.Parent = screenGui

-- Sonidos
local phaseSongs = SoundService:WaitForChild("AllMusic"):WaitForChild("PhaseSongs")
local baseFolder = phaseSongs:WaitForChild("Base")
local phase2Folder = phaseSongs:WaitForChild("Phase2")

local quietHalls      = baseFolder:WaitForChild("QuietHalls")
local properBehavior  = baseFolder:WaitForChild("ProperBehavior")
local studentSound    = phase2Folder:WaitForChild("Student")

local trackedSounds = { quietHalls, properBehavior, studentSound }

-- 	[quietHalls]     = (6*60)+2,
-- Duraciones personalizables
local soundDurations = {
	[properBehavior] = (2*60)+1,
	[studentSound]   = (3*60)+16
}

local currentSound = nil
local hbConn = nil
local zeroBlinkConn = nil

local function format(sec)
	return string.format("%d:%02d", math.floor(sec/60), math.floor(sec%60))
end

-- Verifica si el personaje está en carpetas excluidas
local function isExcluded()
	local char = player.Character
	if not char or not char.Parent then return false end
	local parentName = char.Parent.Name
	return parentName == "Teachers" or parentName == "Alices"
end

-- Fade para mostrar/ocultar label
local function fadeLabel(show)
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if show then
		label.Visible = true
		local tween = TweenService:Create(label, tweenInfo, {TextTransparency = 0})
		tween:Play()
	else
		local tween = TweenService:Create(label, tweenInfo, {TextTransparency = 1})
		tween:Play()
		tween.Completed:Connect(function() label.Visible = false end)
	end
end

-- Parpadeo final 0:00
local function zeroBlink()
	if zeroBlinkConn then zeroBlinkConn:Disconnect() end
	local start = tick()
	zeroBlinkConn = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - start
		label.Visible = true
		label.TextColor3 = (math.floor(elapsed / 0.5) % 2 == 0) and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,255,255)
		if elapsed >= 7 then
			zeroBlinkConn:Disconnect()
			zeroBlinkConn = nil
			label.TextColor3 = Color3.fromRGB(255,255,255)
		end
	end)
end

local function stopTimer()
	if hbConn then hbConn:Disconnect() end
	hbConn = nil
	currentSound = nil
	label.Text = "0:00"
	zeroBlink()
end

local glitchSymbols = {"∆∆∆∆", "!!¡!!¡¿!", "¡!#¡!!¡¡¡", "?¿!¡?", "¿?!¿¡?", "XDD"}

-- Animación glitch para Student
local function studentGlitchAnim()
	local startTime = tick()
	local duration = 4.3
	local interval = 0.07 -- rápido
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration then
			conn:Disconnect()
			hbConn = RunService.Heartbeat:Connect(update)
			update()
			return
		end
		local index = math.floor(elapsed / interval) % #glitchSymbols + 1
		label.Text = glitchSymbols[index]
		label.TextColor3 = Color3.fromRGB(255,0,0)
		label.Visible = true
	end)
end

local function update()
	if isExcluded() then
		if label.Visible then
			fadeLabel(false)
		end
		return
	else
		if not label.Visible then
			fadeLabel(true)
		end
	end

	if not currentSound or not currentSound.Parent then
		local allDestroyed = true
		for _, s in ipairs(trackedSounds) do
			if s and s.Parent then
				allDestroyed = false
				break
			end
		end
		if allDestroyed then
			stopTimer()
		end
		return
	end

	local dur = soundDurations[currentSound] or currentSound.TimeLength or 0
	local tp  = currentSound.TimePosition or 0
	local rem = math.max(dur - tp, 0)

	label.Text = format(rem)
	label.Visible = true

	-- Color rojo si pausa o <=26s
	if tp > 0 and not currentSound.IsPlaying then
		label.TextColor3 = Color3.fromRGB(255,0,0)
	elseif rem <= 26 then
		label.TextColor3 = Color3.fromRGB(255,0,0)
	else
		label.TextColor3 = Color3.fromRGB(255,255,255)
	end

	if rem <= 0 then
		stopTimer()
	end
end

local function beginTimer(s)
	if hbConn then hbConn:Disconnect() end
	currentSound = s
	if s == studentSound and s.TimePosition <= 0.05 then
		studentGlitchAnim()
	else
		hbConn = RunService.Heartbeat:Connect(update)
		update()
	end
end

local function selectBestSound()
	local best = nil
	local maxVol = 0
	for _, s in ipairs(trackedSounds) do
		if s and (s.IsPlaying or (s.TimePosition and s.TimePosition > 0)) and s.Volume > 0 then
			if s.Volume > maxVol then
				maxVol = s.Volume
				best = s
			end
		end
	end
	return best
end

local function refreshState()
	if isExcluded() then
		if label.Visible then
			fadeLabel(false)
		end
		return
	else
		if not label.Visible then
			fadeLabel(true)
		end
	end

	local best = selectBestSound()
	currentSound = best

	if best then
		beginTimer(best)
	else
		local allDestroyed = true
		for _, s in ipairs(trackedSounds) do
			if s and s.Parent then
				allDestroyed = false
				break
			end
		end

		if allDestroyed then
			stopTimer()
		else
			for _, s in ipairs(trackedSounds) do
				if s and s.Parent and s.TimePosition and s.TimePosition > 0 then
					currentSound = s
					beginTimer(s)
					break
				end
			end
		end
	end
end

local function bind(s)
	s.Played:Connect(refreshState)
	s.Paused:Connect(refreshState)
	s.Stopped:Connect(refreshState)
	s:GetPropertyChangedSignal("IsPlaying"):Connect(refreshState)
	s:GetPropertyChangedSignal("TimePosition"):Connect(refreshState)
	if s.IsPlaying or (s.TimePosition and s.TimePosition > 0) then
		task.defer(refreshState)
	end
end

for _, s in ipairs(trackedSounds) do
	bind(s)
end

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	refreshState()
	local char = player.Character
	if char then
		char:GetPropertyChangedSignal("Parent"):Connect(refreshState)
	end
end)

task.defer(refreshState)
