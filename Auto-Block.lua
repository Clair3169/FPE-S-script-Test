-- LocalScript
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remoteEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

-- REFERENCIAS A LAS CARPETAS (Siempre existen, así que usamos WaitForChild una vez)
local teachersFolder = Workspace:WaitForChild("Teachers")
local alicesFolder = Workspace:WaitForChild("Alices")

-- CONFIGURACIÓN DE OBJETIVOS
-- { CarpetaReal, NombreDelSonido }
local TARGET_CONFIGS = {
	{ Folder = teachersFolder, SoundName = "SwingSFX" },
	{ Folder = alicesFolder,   SoundName = "Swing" }
}

-- VARIABLES AJUSTABLES
local RANGE = 10
local COMPENSATION_DELAY = 0.0 -- Ajusta esto si sientes lag (Negativo = Pre-Fire)

-- Variables dinámicas
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- TABLA PRE-CARGADA
local args = { { ["^"] = { { n = 0 } } }, {} }

-- 1. ACTUALIZAR PERSONAJE
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	rootPart = newCharacter:WaitForChild("HumanoidRootPart")
end)

-- 2. FUNCIÓN DE DISPARO COMPENSADO
local function executeCompensatedAction()
	local fire = function()
		remoteEvent:FireServer(unpack(args))
	end
	if COMPENSATION_DELAY == 0 then fire() else task.delay(COMPENSATION_DELAY, fire) end
end

-- 3. LÓGICA PRINCIPAL (Distancia + Equipo)
local function checkAndFire(soundPart)
	-- Seguridad básica
	if not rootPart or not rootPart.Parent then return end
	
	-- A. OBTENER MODELOS Y EQUIPOS
	local attackerModel = soundPart.Parent -- El modelo del enemigo (ej. un Dummy)
	if not attackerModel then return end
	
	local attackerTeam = attackerModel.Parent -- La carpeta (Teachers o Alices)
	local myTeam = character.Parent -- Mi carpeta actual
	
	-- B. LÓGICA DE EQUIPO (La mejora que pediste)
	-- Si mi carpeta es la misma que la del atacante, es fuego amigo. NO BLOQUEAMOS.
	if myTeam == attackerTeam then 
		return 
	end

	-- C. LÓGICA DE DISTANCIA
	local distance = (rootPart.Position - soundPart.Position).Magnitude
	if distance <= RANGE then
		executeCompensatedAction()
	end
end

-- 4. LISTENERS DE SONIDO (Para sonidos que ya existen)
local function setupSoundListeners(sound, targetName)
	if not sound:IsA("Sound") or sound.Name ~= targetName then return end
	
	sound:GetPropertyChangedSignal("Playing"):Connect(function()
		if sound.Playing then checkAndFire(sound.Parent) end
	end)
end

-- 5. MONITOR DE ENEMIGOS (Pre-Fire + Carga)
local function monitorEnemy(enemyModel, soundName)
	-- A. Revisar sonidos existentes (sin disparar, solo escuchar)
	for _, desc in pairs(enemyModel:GetDescendants()) do
		setupSoundListeners(desc, soundName)
	end

	-- B. Escuchar sonidos NUEVOS (Disparo Pre-Fire)
	enemyModel.DescendantAdded:Connect(function(obj)
		if obj:IsA("Sound") and obj.Name == soundName then
			-- ¡Es un ataque nuevo! Verificamos equipo y distancia al instante
			checkAndFire(obj.Parent) 
			
			-- Dejamos conectado por si el sonido se reutiliza
			setupSoundListeners(obj, soundName)
		end
	end)
end

-- 6. INICIALIZADOR DE CARPETAS
local function initializeFolders()
	for _, config in ipairs(TARGET_CONFIGS) do
		local folder = config.Folder
		local soundName = config.SoundName
		
		-- 1. Procesar enemigos que ya estén esperando (si te unes tarde a la ronda)
		for _, enemy in pairs(folder:GetChildren()) do
			monitorEnemy(enemy, soundName)
		end
		
		-- 2. Escuchar cuando empieza la ronda y entran enemigos
		folder.ChildAdded:Connect(function(enemy)
			monitorEnemy(enemy, soundName)
		end)
	end
end

-- INICIO
initializeFolders()
