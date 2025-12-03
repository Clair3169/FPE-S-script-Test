local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ReliableRedEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

local TOOL_NAME = "HealPotion"
local MIN_HEALTH = 35
local RUNS_PER_HEAL = 3
local HEAL_COOLDOWN = 1

-- Estado interno
local canHeal = true
local characterConnections = {} -- Tabla para guardar conexiones y limpiarlas

-- 🔹 Función de curación (Lógica de red)
local function silentDoubleHeal(tool)
	if not canHeal then return end
	canHeal = false

	-- Disparar evento remoto
	for i = 1, RUNS_PER_HEAL do
		local args = {
			{ ["?"] = { { tool, n = 1 } } },
			{}
		}
		ReliableRedEvent:FireServer(unpack(args))
	end

	task.delay(HEAL_COOLDOWN, function()
		canHeal = true
	end)
end

-- 🔹 Lógica MAESTRA: Forzar herramienta y curar
local function enforceHealthCheck()
	local char = player.Character
	if not char then return end
	
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- 1. Si tenemos vida suficiente, NO hacemos nada y dejamos al jugador libre
	if humanoid.Health > MIN_HEALTH then 
		return 
	end

	-- >>> MODO EMERGENCIA (Vida Baja) <<<

	local backpack = player:FindFirstChild("Backpack")
	local currentTool = char:FindFirstChildOfClass("Tool")
	local healToolInBackpack = backpack and backpack:FindFirstChild(TOOL_NAME)
	
	-- CASO A: Ya tenemos la poción en la mano
	if currentTool and currentTool.Name == TOOL_NAME then
		silentDoubleHeal(currentTool) -- Curar
		return
	end

	-- CASO B: Tenemos OTRA cosa en la mano (Espada, Gun, etc)
	if currentTool and currentTool.Name ~= TOOL_NAME then
		-- La desequipamos forzosamente mandándola al backpack
		currentTool.Parent = backpack
	end

	-- CASO C: No tenemos la poción equipada, hay que buscarla y equiparla
	if healToolInBackpack then
		healToolInBackpack.Parent = char -- Equipar forzosamente
		
		-- Pequeña espera técnica para asegurar que el server registre el equipamiento antes de disparar el evento
		local equippedTool = char:FindFirstChild(TOOL_NAME)
		if equippedTool then
			silentDoubleHeal(equippedTool)
		end
	end
end

-- 🔹 Gestión de Eventos del Personaje
local function connectCharacterListeners(char)
	-- Limpiar conexiones anteriores si existen
	for _, conn in pairs(characterConnections) do
		conn:Disconnect()
	end
	characterConnections = {}

	local humanoid = char:WaitForChild("Humanoid")

	-- 1. Escuchar cambios de vida
	local healthConn = humanoid.HealthChanged:Connect(function(health)
		enforceHealthCheck()
	end)
	table.insert(characterConnections, healthConn)

	-- 2. ANTI-DESEQUIPAR: Si el jugador guarda la tool o se la quitan
	local childRemovedConn = char.ChildRemoved:Connect(function(child)
		-- Si se quita la poción y seguimos con poca vida, la función enforce la devolverá
		if child:IsA("Tool") then
			enforceHealthCheck()
		end
	end)
	table.insert(characterConnections, childRemovedConn)

	-- 3. ANTI-CAMBIO: Si el jugador intenta equipar OTRA tool
	local childAddedConn = char.ChildAdded:Connect(function(child)
		-- Si se equipa algo que NO es la poción y hay poca vida, enforceHealthCheck lo quitará
		if child:IsA("Tool") then
			-- Usamos task.defer para dejar que Roblox procese el equipamiento actual antes de revertirlo
			task.defer(enforceHealthCheck)
		end
	end)
	table.insert(characterConnections, childAddedConn)

	-- Chequeo inicial al respawnear
	enforceHealthCheck()
end

-- Inicialización
if player.Character then
	connectCharacterListeners(player.Character)
end

player.CharacterAdded:Connect(connectCharacterListeners)

-- Escuchar si la tool llega al backpack tarde (ej. al comprarla o recibirla)
local function monitorBackpack()
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		if child.Name == TOOL_NAME then
			enforceHealthCheck()
		end
	end)
end
monitorBackpack()
