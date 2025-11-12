-- 🟦 Teachers/Alices ESP (BillboardGui Final, Estable, sin bucles)
repeat task.wait() until game:IsLoaded()

-- ⚙️ Servicios
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- 👤 Jugador local
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- 📁 Carpetas
local Folders = {
	Alices   = Workspace:WaitForChild("Alices"),
	Students = Workspace:WaitForChild("Students"),
	Teachers = Workspace:WaitForChild("Teachers"),
}

-- ⚙️ Configuración
local MAX = { Teachers = 4, Alices = 2 }
local MAX_RENDER_DISTANCE = 250
local BILLBOARD_SIZE = UDim2.new(0, 45, 0, 45)
local STUDS_OFFSET = Vector3.new(0, 1.6, 0)
local UPDATE_THRESHOLD = 5 -- Distancia en studs que el jugador debe moverse para actualizar

-- 🖼️ Imágenes
local BASE_IDS = {
	Bloomie     = "129090409260807",
	Circle      = "72842137403522",
	Thavel      = "126007170470250",
	Alice       = "94023609108845",
	AlicePhase2 = "78066130044573",
}
local CIRCLE_ENRAGED_ID = "108867117884833"

-- 📦 Estado
local ActiveBillboards = {}
local ActiveCounts = { Teachers = 0, Alices = 0 }

------------------------------------------------------
-- 🔧 Utilidades
------------------------------------------------------
local function getImageIdForModel(model)
	if not model then return nil end
	local tname = model:GetAttribute("TeacherName")
	if not tname then return nil end

	if tname == "Bloomie" then
		return BASE_IDS.Bloomie
	elseif tname == "Circle" then
		return model:GetAttribute("Enraged") and CIRCLE_ENRAGED_ID or BASE_IDS.Circle
	elseif tname == "Thavel" then
		return BASE_IDS.Thavel
	elseif tname == "Alice" then
		return BASE_IDS.Alice
	elseif tname == "AlicePhase2" then
		return BASE_IDS.AlicePhase2
	end
	return nil
end

local function getRealHead(model)
	if not model or not model:IsA("Model") then return nil end
	local head = model:FindFirstChild("Head")
	if model:GetAttribute("TeacherName") == "AlicePhase2" and head and head:IsA("Model") then
		return head:FindFirstChild("Head")
	end
	return head
end

local function getDistanceFromLocal(head)
	local char = LocalPlayer.Character
	local myHead = char and char:FindFirstChild("Head")
	if not (myHead and head) then return math.huge end
	return (myHead.Position - head.Position).Magnitude
end

------------------------------------------------------
-- 🧩 Billboard Handling
------------------------------------------------------
local function createBillboardFor(model, folderName)
	if not model or not folderName then return end
	if ActiveBillboards[model] then return end

	-- 🔒 Respeta límites
	if folderName == "Teachers" and ActiveCounts.Teachers >= MAX.Teachers then return end
	if folderName == "Alices" and ActiveCounts.Alices >= MAX.Alices then return end

	local head, imageId
	for i = 1, 25 do
		head = getRealHead(model)
		imageId = getImageIdForModel(model)
		if head and imageId then break end
		task.wait(0.05)
	end
	if not head or not imageId then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "RoleBillboardGui"
	bb.Size = BILLBOARD_SIZE
	bb.StudsOffset = STUDS_OFFSET
	bb.AlwaysOnTop = true
	bb.MaxDistance = MAX_RENDER_DISTANCE
	bb.Adornee = head
	bb.Parent = head

	local img = Instance.new("ImageLabel")
	img.Name = "RoleImage"
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundTransparency = 1
	img.Image = "rbxassetid://" .. tostring(imageId)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	ActiveBillboards[model] = { gui = bb, folder = folderName }

	if folderName == "Teachers" then
		ActiveCounts.Teachers += 1
	elseif folderName == "Alices" then
		ActiveCounts.Alices += 1
	end
end

local function destroyBillboard(model)
	local data = ActiveBillboards[model]
	if not data then return end
	if data.gui and data.gui.Parent then data.gui:Destroy() end

	if data.folder == "Teachers" then
		ActiveCounts.Teachers = math.max(0, ActiveCounts.Teachers - 1)
	elseif data.folder == "Alices" then
		ActiveCounts.Alices = math.max(0, ActiveCounts.Alices - 1)
	end

	ActiveBillboards[model] = nil
end

------------------------------------------------------
-- 🧩 Detección y reglas
------------------------------------------------------
local function detectLocalFolder()
	for name, folder in pairs(Folders) do
		if folder and folder:FindFirstChild(LocalPlayer.Name) then
			return name
		end
	end
	return nil
end

local function shouldLocalSeeModel(localFolder, targetFolder, model)
	if not localFolder or not targetFolder or not model then return false end
	if model.Name == LocalPlayer.Name then return false end

	if localFolder == "Students" then
		return targetFolder == "Teachers" or targetFolder == "Alices"
	elseif localFolder == "Teachers" then
		return targetFolder == "Alices"
	elseif localFolder == "Alices" then
		return targetFolder == "Teachers"
	end
	return false
end

------------------------------------------------------
-- 🧩 Visibilidad
------------------------------------------------------
local function updateAllBillboardsVisibility()
	if not LocalPlayer.Character then return end

	-- Recorre todos los billboards que hemos creado
	for model, data in pairs(ActiveBillboards) do
		-- Reutiliza tu función original para actualizar cada uno
		if data and data.gui then
			updateVisibility(model)
		end
	end
end
------------------------------------------------------
-- 🧩 Eventos por modelo
------------------------------------------------------
local function hookModelSignals(model, folderName)
	if not model or not model:IsA("Model") then return end
	if model:FindFirstChild("__BillboardHooked") then return end

	local marker = Instance.new("BoolValue")
	marker.Name = "__BillboardHooked"
	marker.Parent = model

	model:GetAttributeChangedSignal("TeacherName"):Connect(function()
		destroyBillboard(model)
		createBillboardFor(model, folderName)
	end)

	model:GetAttributeChangedSignal("Enraged"):Connect(function()
		local data = ActiveBillboards[model]
		if not data then return end
		local bb = data.gui
		local img = bb and bb:FindFirstChild("RoleImage")
		local newId = getImageIdForModel(model)
		if img and newId then img.Image = "rbxassetid://" .. tostring(newId) end
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			destroyBillboard(model)
		else
			task.defer(function()
				createBillboardFor(model, folderName)
				updateVisibility(model)
			end)
		end
	end)
	
end

------------------------------------------------------
-- 🧩 Escaneo inicial y eventos
------------------------------------------------------
local function scanAndApply(localFolder)
	local teacherCount, aliceCount = 0, 0

	for _, folderName in ipairs({"Alices", "Teachers"}) do
		local folder = Folders[folderName]
		if not folder then continue end

		for _, model in ipairs(folder:GetChildren()) do
			if not model:IsA("Model") then continue end
			if not shouldLocalSeeModel(localFolder, folderName, model) then
				destroyBillboard(model)
				continue
			end

			if folderName == "Teachers" and teacherCount >= MAX.Teachers then
				destroyBillboard(model)
				continue
			elseif folderName == "Alices" and aliceCount >= MAX.Alices then
				destroyBillboard(model)
				continue
			end

			if not ActiveBillboards[model] then
				createBillboardFor(model, folderName)
				hookModelSignals(model, folderName)
			end
			updateVisibility(model)

			if folderName == "Teachers" then teacherCount += 1 end
			if folderName == "Alices" then aliceCount += 1 end
		end
	end
end

for _, folderName in ipairs({"Alices", "Teachers"}) do
	local folder = Folders[folderName]
	if not folder then continue end

	folder.ChildAdded:Connect(function(child)
		if not child:IsA("Model") then return end
		local localFolder = detectLocalFolder()
		if shouldLocalSeeModel(localFolder, folderName, child) then
			task.defer(function()
				createBillboardFor(child, folderName)
				hookModelSignals(child, folderName)
				updateVisibility(child)
			end)
		end
	end)

	folder.ChildRemoved:Connect(function(child)
		destroyBillboard(child)
	end)
end

local function onCharacterAdded(character)
	task.wait(0.5) -- Espera a que el personaje esté listo
	scanAndApply(detectLocalFolder()) -- Escanea al aparecer
	updateAllBillboardsVisibility() -- Actualiza la visibilidad inicial

	local root = character:WaitForChild("HumanoidRootPart", 3)
	if not root then return end

	local lastPos = root.Position
	root:GetPropertyChangedSignal("Position"):Connect(function()
		local newPos = root.Position
		-- Si el jugador se mueve lo suficiente...
		if (newPos - lastPos).Magnitude > UPDATE_THRESHOLD then
			lastPos = newPos
			-- ...actualiza la visibilidad de TODOS los billboards
			updateAllBillboardsVisibility()
		end
	end)

	-- Esto es importante: si cambias de equipo (de carpeta)
	character:GetPropertyChangedSignal("Parent"):Connect(function()
		task.defer(scanAndApply, detectLocalFolder())
		task.defer(updateAllBillboardsVisibility)
	end)
end

-- Conecta la función
if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
