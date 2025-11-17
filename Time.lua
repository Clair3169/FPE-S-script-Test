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

-- Label 1: El contador principal
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

-- Label 2: Animación de pausa
local pausedLabel = screenGui:FindFirstChild("PausedLabel") or Instance.new("TextLabel")
pausedLabel.Name = "PausedLabel"
pausedLabel.Size = UDim2.new(0, 90, 0, 28)
pausedLabel.Position = UDim2.new(0.5, -45, 0, -3)
pausedLabel.BackgroundTransparency = 1
pausedLabel.TextColor3 = Color3.fromRGB(255, 80, 80) -- Color rojo para la pausa
pausedLabel.TextScaled = true
pausedLabel.Font = Enum.Font.GothamBold
pausedLabel.Text = "||"
pausedLabel.Visible = false
pausedLabel.Parent = screenGui


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
local hbConn = nil -- Conexión Heartbeat para el contador principal (label)
local blinkingConn = nil -- Conexión Heartbeat para el parpadeo de urgencia
local pausedAnimConn = nil -- Conexión Heartbeat para la animación de pausa (pausedLabel)
local lastTP = 0
local isTimerRunning = false -- ¡NUEVO! Guarda de estado
local isPausedAnimating = false
local frozenTimeText = "0:00"

local symbols = {"∆∆∆∆", "!!¡!!¡¿!", "¡!#¡!!¡¡¡", "?¿!¡?", "¿?!¿¡?", "XDD"}

-- 🟦 Helpers
local function format(sec)
	return string.format("%d:%02d", math.floor(sec/60), math.floor(sec%60))
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

-- Detiene la animación de pausa y oculta el label de pausa
local function stopPausedAnim()
	if pausedAnimConn then
		pausedAnimConn:Disconnect()
	end
	pausedAnimConn = nil
	isPausedAnimating = false
	pausedLabel.Visible = false
end

-- Detiene TODOS los bucles/conexiones
local function stopTimer()
	if hbConn then hbConn:Disconnect() end
	hbConn = nil
	currentSound = nil
	isTimerRunning = false
	stopBlink()
	stopPausedAnim()
end

-- Inicia el parpadeo de urgencia (para el label principal)
local function beginBlink()
	stopBlink()
	blinkingConn = RunService.Heartbeat:Connect(function()
		label.TextColor3 = (tick() % 1 < 0.5) and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,255,255)
	end)
end

-- 🟦 Lógica de Animación de Pausa (para pausedLabel)
local function pausedAnim(frozenTime)
	if isPausedAnimating then return end
	isPausedAnimating = true
	isTimerRunning = false

	pausedLabel.Visible = true
	pausedLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	
	stopBlink()

	local animStartTime = tick()
	local animDuration = 1.0
	local symbolInterval = 0.15

	pausedAnimConn = RunService.Heartbeat:Connect(function(dt)
		-- ¡NUEVA COMPROBACIÓN!
		-- Si el bucle de pausa detecta que la música se reanudó,
		-- fuerza el estado de "Play" y se autodestruye.
		if currentSound and currentSound.IsPlaying then
			_G.onPlay(currentSound) -- Llama a la función global (ver abajo)
			return -- onPlay se encargará de matar esta conexión
		end
		
		local elapsedTime = tick() - animStartTime
		
		if elapsedTime < animDuration then
			-- Fase 1: Animación
			local symbolIndex = math.floor(elapsedTime / symbolInterval) % #symbols + 1
			pausedLabel.Text = symbols[symbolIndex]
		else
			-- Fase 2: Congelar
			pausedLabel.Text = frozenTime
		end
	end)
end

-- 🟦 Lógica de Actualización del Contador (para label)
local function update()
	-- ¡COMPROBACIÓN MEJORADA!
	-- Si el bucle del timer detecta que la música se pausó o paró,
	-- fuerza el estado de "Pausa" y se autodestruye.
	if not currentSound or not currentSound.IsPlaying then
		if currentSound then
			_G.onPause(currentSound) -- Llama a la función global (ver abajo)
		end
		
		if hbConn then hbConn:Disconnect() end
		hbConn = nil
		isTimerRunning = false
		return
	end
	
	local dur = soundDurations[currentSound] or 0
	local tp = currentSound.TimePosition or 0
	local rem = math.max(dur - tp, 0)

	local formattedTime = format(rem)
	frozenTimeText = formattedTime -- Actualiza el tiempo para la pausa
	
	label.Text = formattedTime

	-- Lógica de parpadeo
	if rem <= 26 then
		if not blinkingConn then beginBlink() end
	else
		stopBlink()
		label.TextColor3 = Color3.fromRGB(255,255,255)
	end

	lastTP = tp
end

-- Inicia el bucle 'update'
local function beginTimer(s)
	if hbConn then hbConn:Disconnect() end
	hbConn = nil
	
	currentSound = s
	lastTP = s.TimePosition or 0
	isTimerRunning = true
	
	hbConn = RunService.Heartbeat:Connect(update) 
	update() -- Ejecuta una vez inmediatamente
end

-- 🟦 Eventos Principales
-- Los hacemos globales (con _G) para que los bucles de Heartbeat puedan llamarlos

function _G.onPlay(s)
	if isTimerRunning then return end -- Guarda de estado
	if isExcluded() then
		stopTimer()
		label.Visible = false
		pausedLabel.Visible = false
		return
	end

	-- 1. Detener la animación de pausa
	stopPausedAnim()
	
	-- 2. Mostrar el contador principal (blanco)
	label.Visible = true
	label.TextColor3 = Color3.fromRGB(255,255,255) 

	-- 3. Iniciar el bucle de actualización del contador
	isTimerRunning = true -- Marcar estado
	beginTimer(s)
end

function _G.onPause(s)
	if not table.find(trackedSounds, s) then return end
	-- Si ya estamos en pausa, no hacer nada
	if isPausedAnimating then return end 
	
	if not currentSound then currentSound = s end

	-- 1. Detener el bucle del contador principal
	if hbConn then hbConn:Disconnect() end
	hbConn = nil
	isTimerRunning = false -- Marcar estado
	
	-- 2. Ocultar el contador principal
	label.Visible = false
	stopBlink()

	-- 3. Iniciar la animación de pausa
	-- 'frozenTimeText' fue actualizado por el bucle 'update'
	if not isPausedAnimating then
		pausedAnim(frozenTimeText)
	end
end

-- bind para cada sonido
local function bind(s)
	-- Usamos los eventos como disparadores principales
	s.Played:Connect(function() _G.onPlay(s) end)
	s.Paused:Connect(function() _G.onPause(s) end)
	s.Stopped:Connect(stopTimer) -- stopTimer es una limpieza total

	-- Si el script se carga y la canción YA está sonando
	if s.IsPlaying then
		task.defer(function()
			_G.onPlay(s)
		end)
	end
	
	-- Si el script se carga y la canción YA está en pausa
	if s.TimePosition and s.TimePosition > 0 and not s.IsPlaying then
		currentSound = s
		lastTP = s.TimePosition
		
		local dur = soundDurations[currentSound] or 0
		local rem = math.max(dur - lastTP, 0)
		frozenTimeText = format(rem)
		
		_G.onPause(s)
	end
end

-- enlazar sonidos
for _, s in ipairs(trackedSounds) do
	bind(s)
end

-- checkChar (al aparecer el personaje)
local function checkChar()
	if isExcluded() then
		stopTimer()
		label.Visible = false
		pausedLabel.Visible = false
		return
	end

	local soundWasFound = false
	for _, s in ipairs(trackedSounds) do
		if s.TimePosition and s.TimePosition > 0 then
			soundWasFound = true
			if s.IsPlaying then
				_G.onPlay(s)
			else
				currentSound = s
				lastTP = s.TimePosition
				local dur = soundDurations[currentSound] or 0
				local rem = math.max(dur - lastTP, 0)
				frozenTimeText = format(rem)
				
				_G.onPause(s)
			end
			return
		end
	end

	if not soundWasFound then
		stopTimer()
		label.Text = "0:00"
		label.Visible = true
		pausedLabel.Visible = false
	end
end

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	checkChar()
end)

task.defer(checkChar)
