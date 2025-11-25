--============================================================--
-- CONFIGURACIÓN
--============================================================--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remoteEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

local teachersFolder = Workspace:WaitForChild("Teachers")
local alicesFolder   = Workspace:WaitForChild("Alices")
local studentsFolder = Workspace:WaitForChild("Students") -- NUEVO

local RANGE = 16
local ARGS  = { { ["^"] = { { n = 0 } } }, {} }

local myRoot = nil
local myTeam = "None"
-- Valores posibles: Teachers / Alices / Students / None

--============================================================--
-- FUNCIÓN: DETECTAR EQUIPO DEL LOCALPLAYER EN TIEMPO REAL
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

	-- IMPORTANTÍSIMO:
	-- Si tu personaje cambia de carpeta (Teachers/Alices/Students/Workspace/etc),
	-- esto lo detecta al instante sin bucles.
	char:GetPropertyChangedSignal("Parent"):Connect(function()
		updateTeamFromParent(char.Parent)
	end)
end

player.CharacterAdded:Connect(detectLocalTeam)
detectLocalTeam()

--============================================================--
-- LÓGICA DE BLOQUEO SEGÚN TU EQUIPO
--============================================================--
local function shouldBlock(attackerFolder)
	if myTeam == "Teachers" then
		return attackerFolder == alicesFolder
	end
	if myTeam == "Alices" then
		return attackerFolder == teachersFolder
	end

	-- Students o None → bloquear todos
	return true
end

--============================================================--
-- NÚCLEO: BLOQUEO INSTANTÁNEO
--============================================================--
local function tryBlock()
	remoteEvent:FireServer(unpack(ARGS))
end

local function checkProximity(enemyPart)
	if not myRoot then return end
	if (myRoot.Position - enemyPart.Position).Magnitude <= RANGE then
		tryBlock()
	end
end

--============================================================--
-- OBTENER EQUIPO DEL ATACANTE
--============================================================--
local function getAttackerTeam(model)
	local parent = model.Parent
	if parent == teachersFolder then return teachersFolder end
	if parent == alicesFolder then return alicesFolder end
	return nil -- Students y otros = enemigo neutral → se bloquea siempre
end

--============================================================--
-- HANDLER DEL ATAQUE (FRAME 0)
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

			if attackerTeam then
				if shouldBlock(attackerTeam) then
					checkProximity(p)
				end
			else
				-- No está en Teachers ni Alices → enemigo neutral
				checkProximity(p)
			end
		end

		sound.Played:Connect(trigger)
		if sound.Playing then trigger() end

		sound:GetPropertyChangedSignal("Playing"):Connect(function()
			if sound.Playing then trigger() end
		end)
	end
end

--============================================================--
-- MONITOREO EN TIEMPO REAL (SIN BUCLES)
--============================================================--
local function startMonitoring(folder)
	for _, d in ipairs(folder:GetDescendants()) do
		fastHook(d)
	end
	folder.DescendantAdded:Connect(fastHook)
end

startMonitoring(teachersFolder)
startMonitoring(alicesFolder)
