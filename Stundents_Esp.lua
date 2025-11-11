-- 🧿 Student Image Highlighter (BillboardGui Optimizado Final y Estable)
repeat task.wait() until game:IsLoaded()

-- ⚙️ Servicios
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- 👤 Jugador local
local localPlayer = Players.LocalPlayer
if not localPlayer then return end

-- 📂 Carpetas principales
local studentsFolder = Workspace:WaitForChild("Students")
local VALID_FOLDERS = { "Alices", "Teachers" }

-- ⚙️ Configuración
local MAX_VISIBLE = 10
local MAX_DISTANCE = 200
local UPDATE_THRESHOLD = 5 -- distancia mínima para actualizar
local UPDATE_INTERVAL = 0.25 -- segundos entre chequeos
local systemActive = false

-- 🧠 Estado interno
local activeBillboards = {}
local visibleStudents = {}
local billboardCache = Workspace:FindFirstChild("BillboardCache_Students") or Instance.new("Folder")
billboardCache.Name = "BillboardCache_Students"
billboardCache.Parent = Workspace

------------------------------------------------------
-- 🔧 Utilidades
------------------------------------------------------

local function getModelPosition(model)
	if not model or not model:IsA("Model") then return nil end
	if model.PrimaryPart then return model.PrimaryPart.Position end
	local head = model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
	return head and head.Position
end

local function ensureAdornee(character, billboard)
	if not character or not billboard then return end
	local head = character:FindFirstChild("Head") or character:FindFirstChildWhichIsA("BasePart")
	if head and billboard.Adornee ~= head then
		billboard.Adornee = head
	end
end

local function getOrCreateBillboard(character)
	if not character or not character:IsA("Model") then return end
	if activeBillboards[character] then return activeBillboards[character] end

	local cacheName = character.Name .. "_BB_Student"
	local cached = billboardCache:FindFirstChild(cacheName)

	if cached and cached:IsA("BillboardGui") then
		ensureAdornee(character, cached)
		cached.Enabled = false
		activeBillboards[character] = cached
		return cached
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = cacheName
	billboard.Size = UDim2.new(0, 45, 0, 45)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = MAX_DISTANCE
	billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChildWhichIsA("BasePart")
	billboard.Parent = billboardCache

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.new(1, 0, 1, 0)
	image.Image = "rbxassetid://126500139798475"
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = billboard

	activeBillboards[character] = billboard
	return billboard
end

local function updateBillboardState(character, state)
	local bb = getOrCreateBillboard(character)
	if not bb then return end
	ensureAdornee(character, bb)
	bb.Enabled = state
end

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

------------------------------------------------------
-- 📡 Visibilidad de los Students
------------------------------------------------------

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

	-- 🔹 Desactivar los que ya no deben estar visibles
	for student in pairs(visibleStudents) do
		if not newVisible[student] then
			updateBillboardState(student, false)
		end
	end

	-- 🔹 Activar los nuevos visibles
	for student in pairs(newVisible) do
		if not visibleStudents[student] then
			updateBillboardState(student, true)
		end
	end

	visibleStudents = newVisible
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

------------------------------------------------------
-- 🧩 Eventos dinámicos
------------------------------------------------------

studentsFolder.ChildAdded:Connect(function(child)
	if not child:IsA("Model") or child == localPlayer.Character then return end
	task.defer(function()
		getOrCreateBillboard(child)
		if systemActive then
			updateVisibleStudents()
		end

		local head = child:FindFirstChild("Head") or child:FindFirstChildWhichIsA("BasePart")
		if head and not head:FindFirstChild("__StudentHooked") then
			local marker = Instance.new("BoolValue")
			marker.Name = "__StudentHooked"
			marker.Parent = head

			head:GetPropertyChangedSignal("Position"):Connect(function()
				if systemActive then
					updateVisibleStudents()
				end
			end)

			child.ChildAdded:Connect(function(obj)
				if obj.Name == "Head" or obj:IsA("BasePart") then
					local bb = activeBillboards[child]
					if bb then ensureAdornee(child, bb) end
				end
			end)
		end
	end)
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

------------------------------------------------------
-- 🧩 Control del personaje local
------------------------------------------------------

local function onCharacterAdded(character)
	updateSystemStatus(true)

	local root = character:WaitForChild("HumanoidRootPart", 3)
	if root then
		local lastPos = root.Position
		root:GetPropertyChangedSignal("Position"):Connect(function()
			if not systemActive then return end
			local newPos = root.Position
			if (newPos - lastPos).Magnitude > UPDATE_THRESHOLD then
				lastPos = newPos
				updateVisibleStudents()
			end
		end)
	end

	character:GetPropertyChangedSignal("Parent"):Connect(updateSystemStatus)
end

if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

------------------------------------------------------
-- 🧩 Actualización periódica liviana
------------------------------------------------------
RunService.Stepped:Connect(function(_, dt)
	if not systemActive then return end
	updateVisibleStudents()
	task.wait(UPDATE_INTERVAL)
end)

------------------------------------------------------
-- 🧩 Inicialización segura
------------------------------------------------------

for _, student in ipairs(studentsFolder:GetChildren()) do
	if student:IsA("Model") and student ~= localPlayer.Character then
		getOrCreateBillboard(student)
	end
end

task.defer(function()
	updateSystemStatus(true)
end)
