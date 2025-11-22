-- LocalScript

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remoteEvent = ReplicatedStorage:WaitForChild("ReliableRedEvent")

-- CARPETAS
local teachersFolder = Workspace:WaitForChild("Teachers")
local alicesFolder = Workspace:WaitForChild("Alices")

-- CONFIGURACIÓN
local RANGE = 11

-- TABLA PRE-CARGADA (Velocidad Raw)
local args = { { ["^"] = { { n = 0 } } }, {} }

-- Variables del personaje local
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- 1. ACTUALIZAR PERSONAJE
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	rootPart = newCharacter:WaitForChild("HumanoidRootPart")
end)

-- 2. FUNCIÓN DE DISPARO (INSTANTÁNEO)
local function executeBlock()
	remoteEvent:FireServer(unpack(args))
end

-- 3. VERIFICACIÓN DE EQUIPO Y DISTANCIA
local function checkAndBlock(soundPart)
	if not rootPart or not rootPart.Parent then return end
	
	local attackerModel = soundPart.Parent
	if not attackerModel then return end
	
	-- A. Team Check (Evitar Fuego Amigo)
	local myTeam = character.Parent
	local attackerTeam = attackerModel.Parent
	
	if myTeam == attackerTeam then return end -- Somos del mismo equipo
	
	-- B. Distancia Check
	local distance = (rootPart.Position - soundPart.Position).Magnitude
	if distance <= RANGE then
		executeBlock()
	end
end

-- ==========================================================================
-- LÓGICA TEACHERS ("SwingSFX") -> USANDO .Played + TimePosition (NO .Playing)
-- ==========================================================================
local function monitorTeacherSound(sound)
	if sound.Name ~= "SwingSFX" or not sound:IsA("Sound") then return end

	-- MÉTODO 1: Evento Nativo .Played (Más rápido que PropertyChangedSignal)
	sound.Played:Connect(function()
		checkAndBlock(sound.Parent)
	end)

	-- MÉTODO 2: Vigilancia de TimePosition (Para combos rápidos donde Playing se queda pegado)
	sound:GetPropertyChangedSignal("TimePosition"):Connect(function()
		if sound.TimePosition == 0 and sound.Playing then
			checkAndBlock(sound.Parent)
		end
	end)
end

local function monitorTeacher(teacherModel)
	-- 1. Conectar sonidos existentes
	for _, obj in pairs(teacherModel:GetDescendants()) do
		monitorTeacherSound(obj)
	end
	-- 2. Conectar sonidos nuevos (si aparecen)
	teacherModel.DescendantAdded:Connect(monitorTeacherSound)
end

-- ==========================================================================
-- LÓGICA ALICES ("Swing") -> USANDO CREACIÓN (PRE-FIRE)
-- ==========================================================================
local function monitorAlice(aliceModel)
	-- PRIORIDAD: Disparo por creación (Lo más rápido para sonidos spawneados)
	aliceModel.DescendantAdded:Connect(function(obj)
		if obj:IsA("Sound") and obj.Name == "Swing" then
			-- ¡DISPARO RAW! (Justo al nacer el objeto)
			checkAndBlock(obj.Parent)
		end
	end)
end

-- ==========================================================================
-- INICIALIZACIÓN
-- ==========================================================================

-- A. TEACHERS
for _, child in pairs(teachersFolder:GetChildren()) do monitorTeacher(child) end
teachersFolder.ChildAdded:Connect(monitorTeacher)

-- B. ALICES
for _, child in pairs(alicesFolder:GetChildren()) do monitorAlice(child) end
alicesFolder.ChildAdded:Connect(monitorAlice)
