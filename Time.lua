-- 🟦 Servicios
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- 🟦 GUI
local player = Players.LocalPlayer or Players:GetPlayers()[1]
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = playerGui:FindFirstChild("MusicTimerGui") or Instance.new("ScreenGui")
screenGui.Name = "MusicTimerGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
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
label.Parent = screenGui

-- 🟦 Sonidos
local phaseSongs = SoundService:WaitForChild("AllMusic"):WaitForChild("PhaseSongs")
local baseFolder = phaseSongs:WaitForChild("Base")
local phase2Folder = phaseSongs:WaitForChild("Phase2")

local quietHalls = baseFolder:WaitForChild("QuietHalls")
local properBehavior = baseFolder:WaitForChild("ProperBehavior")
local studentSound = phase2Folder:WaitForChild("Student")

local trackedSounds = { quietHalls, properBehavior, studentSound }

local soundDurations = {
	[quietHalls] = (6*60)+2,
	[properBehavior] = (2*60)+1,
	[studentSound] = (3*60)+16
}

-- 🟦 Variables
local currentSound = nil
local hbConn = nil
local blinkingConn = nil
local pausedAnimConn = nil
local lastTP = 0
local isPausedAnimating = false

local symbols = {"∆∆∆∆","!¡?¿","!¡!!!¿!!","??¡???!??","∆∆∆∆∆∆∆∆∆∆∆","XD"}

-- 🟦 Helpers
local function format(sec)
	return string.format("%d:%02d", sec//60, sec%60)
end

local function isExcluded()
	local char = player.Character
	if not char or not char.Parent then return false end
	local parent = char.Parent.Name
	return parent == "Alices" or parent == "Teachers"
end

local function stopBlink()
	if blinkingConn then blinkingConn:Disconnect() end
	blinkingConn = nil
end

local function stopPausedAnim()
	if pausedAnimConn then
		pausedAnimConn:Disconnect()
	end
	pausedAnimConn = nil
	isPausedAnimating = false
end

local function stopTimer()
	if hbConn then hbConn:Disconnect() end
	hbConn = nil
	currentSound = nil
	stopBlink()
	stopPausedAnim()
end

local function beginBlink()
	stopBlink()
	blinkingConn = RunService.Heartbeat:Connect(function()
		label.TextColor3 = (tick() % 1 < 0.5) and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,255,255)
	end)
end

-- 🟦 pausedAnim (mostrará tiempo en rojo mientras está pausado; no bloquea reanudación)
local function pausedAnim()
	if not currentSound then return end
	if isPausedAnimating then return end
	isPausedAnimating = true

	stopBlink()
	stopPausedAnim() -- asegura limpiar antes de crear nueva
	label.TextColor3 = Color3.fromRGB(255,0,0)

	local dur = soundDurations[currentSound]
	local i = 0

	pausedAnimConn = RunService.Heartbeat:Connect(function(dt)
		-- Si currentSound desaparece, cortar
		if not currentSound then
			stopPausedAnim()
			return
		end

		-- Si se reanuda, cortar animación y arrancar timer
		if currentSound.IsPlaying then
			-- limpiar animación ANTES de arrancar timer para evitar que siga sobreescribiendo
			stopPausedAnim()
			stopBlink()
			label.TextColor3 = Color3.fromRGB(255,255,255)

			-- Forzar actualización y empezar el heartbeat de update
			lastTP = -1
			if hbConn then
				-- si ya había heartbeat, solo forzar update
				pcall(update)
			else
				-- beginTimer se encargará de crear hbConn
				-- (usamos pcall para proteger si beginTimer está globalmente definida más abajo)
				local ok, err = pcall(function() beginTimer(currentSound) end)
				if not ok then
					-- fallback: si beginTimer no está visible aún en este scope, simplemente setea hbConn después
					hbConn = RunService.Heartbeat:Connect(function() end)
				end
			end
			return
		end

		-- Mientras sigue pausado, mostrar tiempo actual (se actualiza si TimePosition cambia)
		i = i + (dt or 0) * 20
		local tp = currentSound.TimePosition or 0
		local rem = math.max(dur - tp, 0)
		label.Text = format(rem)
	end)
end

-- 🟦 update (funciona cuando IsPlaying = true)
local function update()
	if not currentSound then return end
	local dur = soundDurations[currentSound]
	local tp = currentSound.TimePosition or 0
	local rem = math.max(dur - tp, 0)

	-- Si por alguna razón el sonido dejó de reproducir, no bloqueamos; dejamos que pausedAnim lo muestre
	if not currentSound.IsPlaying then
		-- dejar texto en rojo para pausa, pero no desconectar update aquí
		label.TextColor3 = Color3.fromRGB(255,0,0)
		label.Text = format(rem)
		lastTP = tp
		return
	end

	-- Normal playback
	stopPausedAnim()
	stopBlink()
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Text = format(rem)
	label.Visible = true

	if rem <= 26 then
		if not blinkingConn then beginBlink() end
	else
		stopBlink()
		label.TextColor3 = Color3.fromRGB(255,255,255)
	end

	lastTP = tp
end

-- beginTimer asegura que hbConn está establecido para update
function beginTimer(s)
	stopTimer()
	currentSound = s
	lastTP = s.TimePosition or 0
	hbConn = RunService.Heartbeat:Connect(update)
	-- forzamos una actualización inmediata
	update()
end

-- onPlay / onPause
local function onPlay(s)
	if not table.find(trackedSounds, s) then return end
	if isExcluded() then
		stopTimer()
		label.Visible = false
		return
	end

	-- Detener cualquier animación de pausa que esté activa y forzar update inmediato
	stopPausedAnim()
	stopBlink()
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Visible = true

	currentSound = s
	lastTP = -1
	beginTimer(s)
end

local function onPause(s)
	if currentSound == s then
		-- show paused view once
		pausedAnim()
	end
end

-- bind para cada sonido
local function bind(s)
	s.Played:Connect(function() onPlay(s) end)
	s.Paused:Connect(function() onPause(s) end)
	s.Stopped:Connect(stopTimer)

	-- Property change robusto: cuando IsPlaying cambia
	s:GetPropertyChangedSignal("IsPlaying"):Connect(function()
		if s.IsPlaying then
			-- detener animación (si existía) y arrancar timer inmediatamente
			stopPausedAnim()
			stopBlink()
			label.TextColor3 = Color3.fromRGB(255,255,255)
			currentSound = s
			lastTP = -1
			beginTimer(s)
		else
			-- iniciar la animación de pausa UNA SOLA VEZ
			if currentSound == s then
				pausedAnim()
			else
				currentSound = s
				pausedAnim()
			end
		end
	end)

	-- Si el script se inicia en medio de una canción pausada
	if s.TimePosition and s.TimePosition > 0 and not s.IsPlaying then
		currentSound = s
		lastTP = s.TimePosition
		pausedAnim()
	end

	-- Si el script se inicia y la canción ya está sonando
	if s.IsPlaying then
		task.defer(function()
			onPlay(s)
		end)
	end
end

-- enlazar sonidos
for _, s in ipairs(trackedSounds) do
	bind(s)
end

-- checkChar (mantener comportamiento)
local function checkChar()
	if isExcluded() then
		stopTimer()
		label.Visible = false
		return
	end

	label.Visible = true

	for _, s in ipairs(trackedSounds) do
		if s.TimePosition and s.TimePosition > 0 then
			if s.IsPlaying then
				onPlay(s)
			else
				currentSound = s
				lastTP = s.TimePosition
				pausedAnim()
			end
			return
		end
	end

	stopTimer()
	label.Text = "0:00"
end

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	checkChar()
end)

task.defer(checkChar)
