-- LocalScript persistente y ligero con Failsafe de Seguridad
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ReliableRedEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

-- Configuración
local TOOL_NAME = "HealPotion"
local MIN_HEALTH = 40
local RUNS_PER_HEAL = 3
local HEAL_COOLDOWN = 1
local CHECK_DELAY = 0.35

-- Estado
local canHeal = true
local currentHumanoidConn
local backpackConn

-- Anti-spam: evita múltiples animaciones o sonidos
local isPlayingAnimation = false
local isPlayingSound = false


----------------------------------------------------------------------
-- 🔹 Función para silenciar animaciones & sonidos repetidos en el Tool
----------------------------------------------------------------------
local function enforceSilentTool(tool)
	if not tool then return end
	
	-- PREVENIR SPAM DE ANIMACIONES
	if tool:FindFirstChildWhichIsA("Animation") then
		if not isPlayingAnimation then
			isPlayingAnimation = true
			task.delay(1, function()
				isPlayingAnimation = false
			end)
		else
			-- Si ya hay animación reproducida, las siguientes se destruyen o bloquean
			for _, anim in ipairs(tool:GetChildren()) do
				if anim:IsA("Animation") then
					anim:Destroy()
				end
			end
		end
	end

	-- PREVENIR SPAM DE SONIDOS
	for _, s in ipairs(tool:GetDescendants()) do
		if s:IsA("Sound") then
			if not isPlayingSound then
				isPlayingSound = true
				task.delay(1, function()
					isPlayingSound = false
				end)
			else
				-- Cancelar sonido si ya hubo uno
				s.Playing = false
				s.Volume = 0
			end
		end
	end
end


-----------------------------------------------------
-- 🔹 Función auxiliar para disparar remotos
-----------------------------------------------------
local function fireHealPackets(tool)
	for i = 1, RUNS_PER_HEAL do
		local args = {
			{
				["?"] = {
					{
						tool,
						n = 1
					}
				}
			},
			{}
		}
		ReliableRedEvent:FireServer(unpack(args))
	end
end


-----------------------------------------------------
-- 🔹 Doble curación con FAILSAFE silencioso
-----------------------------------------------------
local function silentDoubleHeal(tool)
	if not canHeal then return end
	canHeal = false

	enforceSilentTool(tool)

	-- Intento 1
	fireHealPackets(tool)

	-- FAILSAFE
	task.delay(CHECK_DELAY, function()
		local char = player.Character
		if not char then return end

		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 and humanoid.Health <= MIN_HEALTH then
			if tool.Parent == char then
				enforceSilentTool(tool)
				fireHealPackets(tool)
			end
		end
	end)

	-- Cooldown
	task.delay(HEAL_COOLDOWN, function()
		canHeal = true
	end)
end


-----------------------------------------------------
-- 🔹 Encontrar tool equipada
-----------------------------------------------------
local function findEquippedHealTool(char)
	return char:FindFirstChild(TOOL_NAME)
end


-----------------------------------------------------
-- 🔹 Lógica principal
-----------------------------------------------------
local function tryHealForCurrentCharacter()
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if humanoid.Health > MIN_HEALTH then return end

	-- 1. Ya equipada
	local equipped = findEquippedHealTool(char)
	if equipped then
		silentDoubleHeal(equipped)
		return
	end

	-- 2. Buscar en Backpack
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = backpack:FindFirstChild(TOOL_NAME)
	if not tool then return end

	-- Equipar silenciosamente
	tool.Parent = char

	local eq = char:FindFirstChild(TOOL_NAME) or char:WaitForChild(TOOL_NAME, 1)
	if eq then
		silentDoubleHeal(eq)
	end
end


-----------------------------------------------------
-- 🔹 Listener de personaje
-----------------------------------------------------
local function connectCharacterListeners(character)
	if currentHumanoidConn then
		currentHumanoidConn:Disconnect()
		currentHumanoidConn = nil
	end

	local humanoid = character:WaitForChild("Humanoid")

	currentHumanoidConn = humanoid.HealthChanged:Connect(function(h)
		if h <= MIN_HEALTH then
			tryHealForCurrentCharacter()
		end
	end)

	-- Intento inmediato
	tryHealForCurrentCharacter()
end


-----------------------------------------------------
-- 🔹 Listener del Backpack
-----------------------------------------------------
local function ensureBackpackListener()
	local backpack = player:WaitForChild("Backpack")
	if backpackConn then return end

	backpackConn = backpack.ChildAdded:Connect(function(child)
		if child.Name == TOOL_NAME then
			tryHealForCurrentCharacter()
		end
	end)
end


-----------------------------------------------------
-- 🔹 Inicialización
-----------------------------------------------------
player.CharacterAdded:Connect(connectCharacterListeners)
ensureBackpackListener()

if player.Character then
	connectCharacterListeners(player.Character)
end
