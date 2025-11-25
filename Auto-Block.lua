--============================================================--
-- CONFIGURACIÓN
--============================================================--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remoteEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

local teachersFolder = Workspace:WaitForChild("Teachers")
local alicesFolder   = Workspace:WaitForChild("Alices")
local studentsFolder = Workspace:WaitForChild("Students")

local RANGE = 16
local PREDICTION_BUFFER = 2
local TRUE_RANGE = RANGE + PREDICTION_BUFFER

local ARGS  = { { ["^"] = { { n = 0 } } }, {} }

local myRoot = nil
local myTeam = "None"

--============================================================--
-- DETECTAR EQUIPO DEL LOCALPLAYER
--============================================================--
local function updateTeamFromParent(parent)
	if parent == teachersFolder then
		myTeam = "Teachers"
	elseif parent == alicesFolder then
		myTeam = "Alices"
	elseif parent == studentsFolder then
		myTeam = "Students"
	else
		myTeam = "None"
	end
end

local function detectLocalTeam()
	local char = player.Character
	if not char then
		myRoot = nil
		myTeam = "None"
		return
	end

	myRoot = char:FindFirstChild("HumanoidRootPart")
	updateTeamFromParent(char.Parent)

	char:GetPropertyChangedSignal("Parent"):Connect(function()
		updateTeamFromParent(char.Parent)
	end)
end

player.CharacterAdded:Connect(detectLocalTeam)
detectLocalTeam()

--============================================================--
-- LOGICA DE BLOQUEO
--============================================================--
local function shouldBlock(attackerFolder)
	if myTeam == "Teachers" then
		return attackerFolder == alicesFolder
	end
	if myTeam == "Alices" then
		return attackerFolder == teachersFolder
	end
	return true
end

local function tryBlock()
	remoteEvent:FireServer(unpack(ARGS))
end

--============================================================--
-- DISTANCIA + VELOCIDAD (BUFFER REAL)
--============================================================--
local function checkProximity(enemyPart)
	if not myRoot then return end

	local dist = (myRoot.Position - enemyPart.Position).Magnitude
	if dist <= TRUE_RANGE then

		local attackerHRP = enemyPart.Parent:FindFirstChild("HumanoidRootPart")
		if attackerHRP then

			-- Movimiento agresivo requerido
			local vel = attackerHRP.Velocity.Magnitude
			if vel > 10 then
				tryBlock()
			end

		else
			tryBlock()
		end
	end
end

--============================================================--
-- OBTENER EQUIPO ATACANTE
--============================================================--
local function getAttackerTeam(model)
	local parent = model.Parent
	if parent == teachersFolder then return teachersFolder end
	if parent == alicesFolder then return alicesFolder end
	return nil
end

--============================================================--
-- HANDLER DE ATAQUE (SOLO RANGO + BUFFER)
--============================================================--
local function fastHook(sound)
	if not sound:IsA("Sound") then return end

	local n = sound.Name
	if n == "SwingSFX" or n == "Swing" or n == "Attack" then

		local function trigger()
			local p = sound.Parent
			if not p then return end

			local attackerModel = p.Parent
			if not attackerModel then return end

			local attackerTeam = getAttackerTeam(attackerModel)

			-- Si pertenece a un equipo válido
			if attackerTeam then
				if shouldBlock(attackerTeam) then
					checkProximity(p)        -- sin bloqueo directo
				end

			else
				-- Enemigo neutral
				checkProximity(p)
			end
		end

		-- detección al instante
		sound.Played:Connect(trigger)
		if sound.Playing then trigger() end

		sound:GetPropertyChangedSignal("Playing"):Connect(function()
			if sound.Playing then trigger() end
		end)
	end
end

--============================================================--
-- MONITOREO
--============================================================--
local function startMonitoring(folder)
	for _, d in ipairs(folder:GetDescendants()) do
		fastHook(d)
	end
	folder.DescendantAdded:Connect(fastHook)
end

startMonitoring(teachersFolder)
startMonitoring(alicesFolder)
startMonitoring(studentsFolder)
