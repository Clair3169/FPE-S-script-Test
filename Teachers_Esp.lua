-- LocalScript: Teachers/Alices -> BillboardGui (Students only)
-- Requisitos:
-- • Solo corre si LocalPlayer está en Students
-- • Mapea TeacherName -> imageId (Circle usa override Enraged)
-- • Limita activos: Teachers máx 4, Alices máx 2
-- • Soporta AlicePhase2 (Head dentro de Head model)
-- • No aplica a uno mismo ni jugadores de la misma carpeta
-- • Reactiva en cambios de atributos o entrada/salida de modelos
-- • Tamaño Billboard: UDim2.new(0,60,0,60)

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local Folders = {
	Alices = Workspace:WaitForChild("Alices"),
	Students = Workspace:WaitForChild("Students"),
	Teachers = Workspace:WaitForChild("Teachers"),
}

local MAX = { Teachers = 4, Alices = 2 }
local MAX_RENDER_DISTANCE = 300
local CHECK_INTERVAL = 4

local BILLBOARD_SIZE = UDim2.new(0,60,0,60)
local STUDS_OFFSET = Vector3.new(0, 1.6, 0)

-- Imagen base
local BASE_IDS = {
	Bloomie = "129090409260807",
	Circle  = "72842137403522",
	Thavel  = "126007170470250",
	Alice   = "94023609108845",
	AlicePhase2 = "78066130044573",
}

-- Override Enraged de Circle
local CIRCLE_ENRAGED_ID = "108867117884833"

-- Cache
local ActiveBillboards = {}
local ActiveCounts = { Teachers = 0, Alices = 0 }

-- Obtener imagen según atributos del modelo
local function getImageIdForModel(model)
	if not model then return nil end
	local tname = model:GetAttribute("TeacherName")
	if not tname then return nil end

	if tname == "Bloomie" then
		return BASE_IDS.Bloomie
	elseif tname == "Circle" then
		local enragedAttr = model:GetAttribute("Enraged")
		if enragedAttr == true then
			return CIRCLE_ENRAGED_ID
		else
			return BASE_IDS.Circle
		end
	elseif tname == "Thavel" then
		return BASE_IDS.Thavel
	elseif tname == "Alice" then
		return BASE_IDS.Alice
	elseif tname == "AlicePhase2" then
		return BASE_IDS.AlicePhase2
	end
	return nil
end

-- Obtener cabeza real del modelo
local function getRealHead(model)
	if not model or not model:IsA("Model") then return nil end
	local teacherName = model:GetAttribute("TeacherName")
	local head = model:FindFirstChild("Head")
	if not head then return nil end
	if teacherName == "AlicePhase2" and head:IsA("Model") then
		local inner = head:FindFirstChild("Head")
		if inner and inner:IsA("BasePart") then
			return inner
		end
	end
	if head:IsA("BasePart") then
		return head
	end
	return nil
end

-- Crear Billboard
local function createBillboardFor(model, targetFolderName)
	if not model or not targetFolderName then return end

	if targetFolderName == "Teachers" and ActiveCounts.Teachers >= MAX.Teachers then
		return nil, "limit_reached"
	end
	if targetFolderName == "Alices" and ActiveCounts.Alices >= MAX.Alices then
		return nil, "limit_reached"
	end

	local head = getRealHead(model)
	if not head then return nil, "no_head" end
	local imageId = getImageIdForModel(model)
	if not imageId then return nil, "no_image" end

	if ActiveBillboards[model] and ActiveBillboards[model].gui and ActiveBillboards[model].gui.Parent then
		return ActiveBillboards[model].gui, "exists"
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "RoleBillboardGui"
	bb.Size = BILLBOARD_SIZE
	bb.StudsOffset = STUDS_OFFSET
	bb.AlwaysOnTop = true
	bb.Parent = head

	local img = Instance.new("ImageLabel")
	img.Name = "RoleImage"
	img.Size = UDim2.new(1,0,1,0)
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = "rbxassetid://" .. tostring(imageId)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	ActiveBillboards[model] = { gui = bb, folder = targetFolderName }

	if targetFolderName == "Teachers" then
		ActiveCounts.Teachers += 1
	elseif targetFolderName == "Alices" then
		ActiveCounts.Alices += 1
	end

	return bb, "created"
end

-- Destruir Billboard
local function destroyBillboard(model)
	local data = ActiveBillboards[model]
	if not data then return end
	if data.gui and data.gui.Parent then
		data.gui:Destroy()
	end
	if data.folder == "Teachers" then
		ActiveCounts.Teachers = math.max(0, ActiveCounts.Teachers - 1)
	elseif data.folder == "Alices" then
		ActiveCounts.Alices = math.max(0, ActiveCounts.Alices - 1)
	end
	ActiveBillboards[model] = nil
end

-- Determinar visibilidad según carpeta local
local function shouldLocalSeeModel(localFolderName, targetFolderName, model)
	if not localFolderName or not targetFolderName then return false end
	if model.Name == LocalPlayer.Name then return false end
	if localFolderName == "Teachers" then
		return targetFolderName == "Alices"
	elseif localFolderName == "Alices" then
		return targetFolderName == "Teachers"
	elseif localFolderName == "Students" then
		return targetFolderName == "Alices" or targetFolderName == "Teachers"
	end
	return false
end

-- Detectar carpeta local
local function detectLocalFolder()
	for name, folder in pairs(Folders) do
		if folder:FindFirstChild(LocalPlayer.Name) then
			return name
		end
	end
	return nil
end

-- Obtener carpeta del modelo
local function getModelFolderName(model)
	for name, folder in pairs(Folders) do
		if folder:FindFirstChild(model.Name) then
			return name
		end
	end
	return nil
end

-- Limpieza
local function sweepInvalids(localFolderName)
	for model, _ in pairs(ActiveBillboards) do
		if not model or not model.Parent then
			destroyBillboard(model)
			continue
		end
		local targetFolder = getModelFolderName(model)
		if not shouldLocalSeeModel(localFolderName, targetFolder, model) then
			destroyBillboard(model)
			continue
		end
		if not getRealHead(model) then
			destroyBillboard(model)
			continue
		end
	end
end

-- Aplicar o actualizar billboards
local function scanAndApply(localFolderName)
	if not localFolderName then return end
	for _, folderName in ipairs({"Alices", "Teachers"}) do
		local folder = Folders[folderName]
		if not folder then continue end
		for _, model in ipairs(folder:GetChildren()) do
			if not model:IsA("Model") then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end
			if model.Name == LocalPlayer.Name then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end
			if not shouldLocalSeeModel(localFolderName, folderName, model) then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end

			local head = getRealHead(model)
			if not head then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end

			if folderName == "Teachers" and ActiveCounts.Teachers >= MAX.Teachers and not ActiveBillboards[model] then
				continue
			elseif folderName == "Alices" and ActiveCounts.Alices >= MAX.Alices and not ActiveBillboards[model] then
				continue
			end

			local id = getImageIdForModel(model)
			if not id then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end

			local bb = ActiveBillboards[model] and ActiveBillboards[model].gui
			if not bb then
				createBillboardFor(model, folderName)
			else
				local img = bb:FindFirstChild("RoleImage")
				if img and img.Image ~= ("rbxassetid://"..tostring(id)) then
					img.Image = "rbxassetid://"..tostring(id)
				end
			end
		end
	end
	sweepInvalids(localFolderName)
end

-- Distancia
RunService.Heartbeat:Connect(function()
	local localChar = LocalPlayer.Character
	local myHead = localChar and getRealHead(localChar)
	if not myHead then return end
	local myPos = myHead.Position

	for model, data in pairs(ActiveBillboards) do
		local gui = data.gui
		if not gui or not gui.Parent then
			destroyBillboard(model)
			continue
		end
		local targetHead = getRealHead(model)
		if not targetHead then
			destroyBillboard(model)
			continue
		end
		local dist = (targetHead.Position - myPos).Magnitude
		gui.Enabled = dist <= MAX_RENDER_DISTANCE
	end
end)

-- Hook de atributos
local function hookModelSignals(model)
	if not model or not model:IsA("Model") then return end
	if model:FindFirstChild("__RoleHooked") then return end
	local marker = Instance.new("BoolValue")
	marker.Name = "__RoleHooked"
	marker.Value = true
	marker.Parent = model

	model:GetAttributeChangedSignal("TeacherName"):Connect(function()
		if ActiveBillboards[model] then destroyBillboard(model) end
		task.defer(function()
			local localFolder = detectLocalFolder()
			scanAndApply(localFolder)
		end)
	end)

	-- Enraged como atributo
	model:GetAttributeChangedSignal("Enraged"):Connect(function()
		if ActiveBillboards[model] then
			local bb = ActiveBillboards[model].gui
			if bb then
				local img = bb:FindFirstChild("RoleImage")
				local id = getImageIdForModel(model)
				if img and id then img.Image = "rbxassetid://"..tostring(id) end
			end
		end
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if not parent then destroyBillboard(model) end
	end)
end

local function hookFolder(folder)
	if not folder then return end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") then hookModelSignals(m) end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			hookModelSignals(child)
			task.defer(function()
				local localFolder = detectLocalFolder()
				scanAndApply(localFolder)
			end)
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if ActiveBillboards[child] then destroyBillboard(child) end
	end)
end

for _, folder in pairs(Folders) do
	hookFolder(folder)
end

-- Sin escaneo, solo eventos
LocalPlayer:GetPropertyChangedSignal("Parent"):Connect(function()
	local localFolder = detectLocalFolder()
	if localFolder == "Students" then
		scanAndApply(localFolder)
	else
		for model in pairs(ActiveBillboards) do
			destroyBillboard(model)
		end
	end
end)

for _, folder in pairs(Folders) do
	folder.ChildAdded:Connect(function(child)
		if not child:IsA("Model") then return end
		hookModelSignals(child)
		local localFolder = detectLocalFolder()
		if localFolder == "Students" then
			scanAndApply(localFolder)
		end
	end)

	folder.ChildRemoved:Connect(function(child)
		if ActiveBillboards[child] then
			destroyBillboard(child)
		end
	end)
end

-- Primer escaneo inicial único
task.delay(0.1, function()
	if detectLocalFolder() == "Students" then
		scanAndApply("Students")
	end
end)
