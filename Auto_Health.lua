-- LocalScript persistente y ligero (funciona tras morir / respawnear)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ReliableRedEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

local TOOL_NAME = "HealPotion"
local MIN_HEALTH = 40
local RUNS_PER_HEAL = 3
local HEAL_COOLDOWN = 1 -- segundos

-- Estado
local canHeal = true
local currentHumanoidConn
local backpackConn

-------------------------------------------------------------------
-- 🔹 Función de curación normal + post-verificación de seguridad
-------------------------------------------------------------------
local function safeSilentHeal(tool, humanoid)
	if not canHeal then return end
	canHeal = false

	-- Ejecución normal de las 5 curaciones
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

	-- 🔒 Seguridad: re-curación automática si sigue <= 40
	task.defer(function()
		if humanoid and humanoid.Health <= MIN_HEALTH then
			-- Segunda aplicación, exactamente igual
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
	end)

	-- Cooldown seguro
	task.delay(HEAL_COOLDOWN, function()
		canHeal = true
	end)
end

-- Detectar SI YA está equipada
local function findEquippedHealTool(char)
	return char:FindFirstChild(TOOL_NAME)
end

-------------------------------------------------------------------
-- 🔹 Lógica principal (equipada o backpack)
-------------------------------------------------------------------
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
		safeSilentHeal(equipped, humanoid)
		return
	end

	-- 2. Si está en el backpack, equiparla
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = backpack:FindFirstChild(TOOL_NAME)
	if not tool then return end

	tool.Parent = char

	local eq = char:FindFirstChild(TOOL_NAME) or char:WaitForChild(TOOL_NAME,1)
	if eq then
		safeSilentHeal(eq, humanoid)
	end
end

-------------------------------------------------------------------
-- 🔹 Conexión por respawn
-------------------------------------------------------------------
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

	-- Intento inmediato al respawn
	tryHealForCurrentCharacter()
end

-------------------------------------------------------------------
-- 🔹 Listener único en el Backpack
-------------------------------------------------------------------
local function ensureBackpackListener()
	local backpack = player:WaitForChild("Backpack")
	if backpackConn then return end

	backpackConn = backpack.ChildAdded:Connect(function(child)
		if child.Name == TOOL_NAME then
			tryHealForCurrentCharacter()
		end
	end)
end

-------------------------------------------------------------------
-- Inicialización
-------------------------------------------------------------------
player.CharacterAdded:Connect(connectCharacterListeners)
ensureBackpackListener()

if player.Character then
	connectCharacterListeners(player.Character)
end
