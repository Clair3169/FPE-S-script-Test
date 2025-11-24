-- LocalScript persistente y ligero (funciona tras morir / respawnear)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ReliableRedEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

local TOOL_NAME = "HealPotion"
local MIN_HEALTH = 40
local RUNS_PER_HEAL = 5
local HEAL_COOLDOWN = 1 -- segundos

-- Estado
local canHeal = true
local currentHumanoidConn
local backpackConn

-- 🔹 Doble curación silenciosa
local function silentDoubleHeal(tool)
	if not canHeal then return end
	canHeal = false

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

	task.delay(HEAL_COOLDOWN, function()
		canHeal = true
	end)
end

-- 🔹 Nueva función que detecta SI LA TOOL YA ESTÁ EQUIPADA
local function findEquippedHealTool(char)
	return char:FindFirstChild(TOOL_NAME)
end

-- 🔹 Lógica principal (Backpack o equipada)
local function tryHealForCurrentCharacter()
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Solo si la salud está baja
	if humanoid.Health > MIN_HEALTH then return end

	-- 1. Si la tool ya está equipada → curar inmediatamente
	local equipped = findEquippedHealTool(char)
	if equipped then
		silentDoubleHeal(equipped)
		return
	end

	-- 2. Si NO está equipada, buscarla en el backpack
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = backpack:FindFirstChild(TOOL_NAME)
	if not tool then return end

	-- Equipar SIN animación redundante
	tool.Parent = char

	-- Una vez equipada, curar
	local eq = char:FindFirstChild(TOOL_NAME) or char:WaitForChild(TOOL_NAME,1)
	if eq then
		silentDoubleHeal(eq)
	end
end

-- 🔹 Conexión por respawn
local function connectCharacterListeners(character)
	if currentHumanoidConn then
		currentHumanoidConn:Disconnect()
		currentHumanoidConn = nil
	end

	local humanoid = character:WaitForChild("Humanoid")

	-- Detectar salud baja
	currentHumanoidConn = humanoid.HealthChanged:Connect(function(h)
		if h <= MIN_HEALTH then
			tryHealForCurrentCharacter()
		end
	end)

	-- Intento inmediato al respawn
	tryHealForCurrentCharacter()
end

-- 🔹 Listener único en el Backpack
local function ensureBackpackListener()
	local backpack = player:WaitForChild("Backpack")
	if backpackConn then return end

	backpackConn = backpack.ChildAdded:Connect(function(child)
		if child.Name == TOOL_NAME then
			tryHealForCurrentCharacter()
		end
	end)
end

-- Inicialización
player.CharacterAdded:Connect(connectCharacterListeners)
ensureBackpackListener()

if player.Character then
	connectCharacterListeners(player.Character)
end
