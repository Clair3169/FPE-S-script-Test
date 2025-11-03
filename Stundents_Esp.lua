-- 🧿 Student Image Highlighter (versión BillboardGui)
repeat task.wait() until game:IsLoaded()

-- ⚙️ Servicios
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- 👤 Jugador local
local localPlayer = Players.LocalPlayer

-- 📂 Carpetas
local studentsFolder = Workspace:WaitForChild("Students")
local VALID_FOLDERS = { "Alices", "Teachers" }

-- ⚙️ Configuración
local MAX_VISIBLE = 10
local MAX_DISTANCE = 200
local UPDATE_THRESHOLD = 5
local systemActive = false

-- 🧠 Estado de caché
local activeBillboards = {}
local visibleStudents = {}
local currentCamera = Workspace.CurrentCamera

-- 🔧 Carpeta cache persistente
local billboardCache = Workspace:FindFirstChild("BillboardCache_Students") or Instance.new("Folder")
billboardCache.Name = "BillboardCache_Students"
billboardCache.Parent = Workspace

-- 🧩 Obtener posición segura del modelo
local function getModelPosition(model)
	if not model or not model:IsA("Model") then return nil end
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			return part.Position
		end
	end
	return nil
end

-- 🧩 Crear o recuperar BillboardGui del cache
local function getOrCreateBillboard(character)
	if not character or not character:IsA("Model") then return end

	if activeBillboards[character] then
		return activeBillboards[character]
	end

	local cacheName = character.Name .. "_BB_Student"
	local cached = billboardCache:FindFirstChild(cacheName)

	if cached and cached:IsA("BillboardGui") then
		cached.Adornee = character:FindFirstChild("Head") or character:FindFirstChildWhichIsA("BasePart")
		cached.Enabled = false
		activeBillboards[character] = cached
		return cached
	end

	-- Crear nuevo BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = cacheName
	billboard.Size = UDim2.new(0, 90, 0, 90)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.LightInfluence = 0
	billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChildWhichIsA("BasePart")
	billboard.Parent = billboardCache

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.new(1, 0, 1, 0)
	image.Image = "rbxassetid://129702264151627"
	image.Parent = billboard

	activeBillboards[character] = billboard
	return billboard
end

-- 🧩 Pre-generar cache de todos los Students
task.defer(function()
	for _, student in ipairs(studentsFolder:GetChildren()) do
		if student:IsA("Model") and student ~= localPlayer.Character then
			getOrCreateBillboard(student)
		end
	end
end)

-- 🧩 Activar o desactivar BillboardGui
local function updateBillboardState(character, state)
	local bb = getOrCreateBillboard(character)
	if not bb then return end
	bb.Enabled = state
end

-- 🧩 Actualizar lista de visibles
local function updateVisibleStudents()
	if not systemActive or not localPlayer.Character then return end

	local localPos = getModelPosition(localPlayer.Character)
	if not localPos then return end

	local distances = {}
	for _, student in ipairs(studentsFolder:GetChildren()) do
		if student ~= localPlayer.Character and student:IsA("Model") then
			local targetPos = getModelPosition(student)
			if targetPos then
				local dist = (localPos - targetPos).Magnitude
				if dist <= MAX_DISTANCE then
					table.insert(distances, {student, dist})
				end
			end
		end
	end

	table.sort(distances, function(a, b)
		return a[2] < b[2]
	end)

	local newVisible = {}
	for i = 1, math.min(MAX_VISIBLE, #distances) do
		newVisible[distances[i][1]] = true
	end

	for student in pairs(visibleStudents) do
		if not newVisible[student] then
			updateBillboardState(student, false)
		end
	end

	for student in pairs(newVisible) do
		if not visibleStudents[student] then
			updateBillboardState(student, true)
		end
	end

	visibleStudents = newVisible
end

-- 🧩 Verificar si el jugador local está en una carpeta válida
local function isInValidFolder()
	local char = localPlayer.Character
	if not char or not char.Parent then return false end
	for _, folderName in ipairs(VALID_FOLDERS) do
		if char.Parent.Name == folderName then
			return true
		end
	end
	return false
end

local function updateSystemStatus(force)
	local shouldBeActive = isInValidFolder()
	if shouldBeActive == systemActive and not force then return end
	systemActive = shouldBeActive

	if systemActive then
		updateVisibleStudents()
	else
		for student in pairs(visibleStudents) do
			updateBillboardState(student, false)
		end
		visibleStudents = {}
	end
end

-- 🧩 Monitorear cambios en Students
studentsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") and child ~= localPlayer.Character then
		getOrCreateBillboard(child)
		if systemActive then
			task.defer(updateVisibleStudents)
		end
	end
end)

studentsFolder.ChildRemoved:Connect(function(child)
	if activeBillboards[child] then
		local bb = activeBillboards[child]
		if bb then
			bb.Enabled = false
			bb.Adornee = nil
		end
		activeBillboards[child] = nil
	end
	visibleStudents[child] = nil
end)

-- 🧩 Control del personaje local
local function onCharacterAdded(character)
	updateSystemStatus(true)
	character:GetPropertyChangedSignal("Parent"):Connect(updateSystemStatus)
end

if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ♻️ Actualización por movimiento
task.spawn(function()
	local lastPos = Vector3.zero
	while RunService.Heartbeat:Wait() do
		if not systemActive or not localPlayer.Character then continue end
		local pos = getModelPosition(localPlayer.Character)
		if not pos then continue end
		if (pos - lastPos).Magnitude > UPDATE_THRESHOLD then
			lastPos = pos
			updateVisibleStudents()
		end
	end
end)

-- ♻️ Limpieza
RunService.Stepped:Connect(function()
	for char, billboard in pairs(activeBillboards) do
		if not char or not char.Parent then
			if billboard then
				billboard.Enabled = false
				billboard.Adornee = nil
			end
			activeBillboards[char] = nil
		end
	end
end)
