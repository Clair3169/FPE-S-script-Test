-- LocalScript de Curación Segura con Supresión de Eco (Anti-Spam Audio/Visual)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ReliableRedEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

-- Configuración
local TOOL_NAME = "HealPotion"
local MIN_HEALTH = 40
local RUNS_PER_HEAL = 3        -- Enviamos 5 veces para asegurar que el servidor reciba la orden
local HEAL_COOLDOWN = 1 
local FAILSAFE_DELAY = 0.35    -- Tiempo para revisar si la cura falló

-- Estado
local canHeal = true
local currentHumanoidConn
local backpackConn
local cleanupConnection -- Variable para guardar la conexión del filtro

-- 🔹 SISTEMA DE SILENCIO (El Filtro)
-- Esto permite enviar 100 paquetes si quieres, pero tú solo escucharás 1 sonido.
local function activateEffectSuppressor(duration)
	local char = player.Character
	if not char then return end

	-- Si ya hay un filtro activo, lo reiniciamos para extender el tiempo
	if cleanupConnection then cleanupConnection:Disconnect() end

	local registeredEffects = {} -- Lista negra temporal

	cleanupConnection = char.DescendantAdded:Connect(function(obj)
		-- FILTRO DE SONIDO
		if obj:IsA("Sound") then
			task.delay(0, function() -- Espera microsegunda para leer propiedades
				local id = obj.SoundId
				if registeredEffects[id] then
					-- Si ya escuchamos este ID hace poco: ¡SILENCIAR Y BORRAR!
					obj.Volume = 0
					obj:Stop()
					pcall(function() obj:Destroy() end)
				else
					-- Si es la primera vez, lo registramos y lo dejamos sonar
					registeredEffects[id] = true
				end
			end)
		
		-- FILTRO DE ANIMACIÓN (Evita el "temblor" del personaje)
		elseif obj:IsA("AnimationTrack") or (obj:IsA("Animation") and obj.Parent:IsA("Animator")) then
			-- La lógica de animación es más compleja, generalmente borrar duplicados rápidos ayuda
			-- Pero para evitar conflictos con otros scripts, nos enfocamos principalmente en el sonido
			-- que es lo más molesto.
		end
	end)

	-- Apagar el filtro automáticamente después del tiempo
	task.delay(duration, function()
		if cleanupConnection then
			cleanupConnection:Disconnect()
			cleanupConnection = nil
		end
	end)
end

-- 🔹 Disparador de paquetes (Lo que causa el spam necesario)
local function fireHealPackets(tool)
	for i = 1, RUNS_PER_HEAL do
		local args = {
			{
				["?"] = {
					{ tool, n = 1 }
				}
			},
			{}
		}
		ReliableRedEvent:FireServer(unpack(args))
	end
end

-- 🔹 Lógica de Curación con Failsafe
local function silentDoubleHeal(tool, isFailsafe)
	if not canHeal and not isFailsafe then return end
	
	-- Si NO es un reintento, activamos el cooldown y el filtro
	if not isFailsafe then 
		canHeal = false 
		-- Activamos el filtro por 1.2 segundos (cubre los 5 paquetes y el failsafe)
		activateEffectSuppressor(1.2)
	end

	-- Disparamos los paquetes al servidor
	fireHealPackets(tool)

	-- Si es la primera vez (no failsafe), programamos la verificación de seguridad
	if not isFailsafe then
		task.delay(FAILSAFE_DELAY, function()
			local char = player.Character
			if not char then return end
			local hum = char:FindFirstChild("Humanoid")

			-- Si seguimos con vida baja (la cura falló por lag o daño)
			if hum and hum.Health > 0 and hum.Health <= MIN_HEALTH then
				-- Verificamos que la tool siga en la mano
				if tool.Parent == char then
					-- Disparamos de nuevo (El filtro de sonido seguirá activo, así que será mudo)
					silentDoubleHeal(tool, true)
				end
			end
		end)

		task.delay(HEAL_COOLDOWN, function()
			canHeal = true
		end)
	end
end

-- 🔹 Funciones base (Equipar y Detectar)
local function tryHealForCurrentCharacter()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum or hum.Health > MIN_HEALTH then return end

	-- 1. Tool equipada
	local equipped = char:FindFirstChild(TOOL_NAME)
	if equipped then
		silentDoubleHeal(equipped, false)
		return
	end

	-- 2. Tool en Backpack
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	local tool = backpack:FindFirstChild(TOOL_NAME)
	if tool then
		tool.Parent = char -- Equipar
		
		-- Pequeño hack visual: detener animación de equipar si es posible
		local animator = hum:FindFirstChild("Animator")
		if animator then
			task.delay(0, function()
				for _, t in pairs(animator:GetPlayingAnimationTracks()) do
					if t.Name == "ToolNoneAnim" then t:Stop() end
				end
			end)
		end

		local eq = char:FindFirstChild(TOOL_NAME) or char:WaitForChild(TOOL_NAME, 1)
		if eq then
			silentDoubleHeal(eq, false)
		end
	end
end

-- 🔹 Conexiones de Eventos
local function connectCharacterListeners(character)
	if currentHumanoidConn then currentHumanoidConn:Disconnect() end
	
	local humanoid = character:WaitForChild("Humanoid")
	
	currentHumanoidConn = humanoid.HealthChanged:Connect(function(h)
		if h <= MIN_HEALTH then
			tryHealForCurrentCharacter()
		end
	end)
	
	-- Chequeo inicial al spawnear
	tryHealForCurrentCharacter()
end

local function ensureBackpackListener()
	local backpack = player:WaitForChild("Backpack")
	if backpackConn then return end
	backpackConn = backpack.ChildAdded:Connect(function(child)
		if child.Name == TOOL_NAME then tryHealForCurrentCharacter() end
	end)
end

player.CharacterAdded:Connect(connectCharacterListeners)
ensureBackpackListener()
if player.Character then connectCharacterListeners(player.Character) end
