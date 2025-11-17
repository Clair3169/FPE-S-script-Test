-- 🟦 ESP BillboardGui (con caché físico + arranque seguro + observación por equipo)
repeat task.wait() until game:IsLoaded()

------------------------------------------------------
-- ⚙️ Servicios y Configuración
------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local Folders = {
	Alices   = Workspace:WaitForChild("Alices"),
	Students = Workspace:WaitForChild("Students"),
	Teachers = Workspace:WaitForChild("Teachers"),
}

local MAX = { Teachers = 4, Alices = 2 }
local MAX_RENDER_DISTANCE = 250 -- <-- El motor usará este valor
local BILLBOARD_SIZE = UDim2.new(0, 45, 0, 45)
local STUDS_OFFSET = Vector3.new(0, 1.6, 0)
local UPDATE_THRESHOLD = 5 

------------------------------------------------------
-- 🖼️ IDs de imágenes
------------------------------------------------------
local BASE_IDS = {
	Bloomie     = "rbxassetid://129090409260807",
	Circle      = "rbxassetid://72842137403522",
	Thavel      = "rbxassetid://126007170470250",
	Alice       = "rbxassetid://94023609108845",
	AlicePhase2 = "rbxassetid://78066130044573",
}
local CIRCLE_ENRAGED_ID = "rbxassetid://108867117884833"

------------------------------------------------------
-- 📦 Carpeta de caché físico (seguridad de organización)
------------------------------------------------------
local BillboardCacheFolder = Workspace:FindFirstChild("BillboardTeachers_Cache")
if not BillboardCacheFolder then
	BillboardCacheFolder = Instance.new("Folder")
	BillboardCacheFolder.Name = "BillboardTeachers_Cache"
	BillboardCacheFolder.Parent = Workspace
end

------------------------------------------------------
-- 📦 Estado / Caché lógico
------------------------------------------------------
local Cache = {
	Billboards = {}, -- modelo → { gui = BillboardGui, folder = folderName, headRef = head }
	Counts = { Teachers = 0, Alices = 0 },
}

------------------------------------------------------
-- 🔧 Funciones auxiliares
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

-- ⚡ CAMBIO 1: Esta función ya no es necesaria
-- local function getDistanceFromLocal(head)
-- 	...
-- end

local function isModelInFolder(model, folderName)
	local folder = Folders[folderName]
	if not folder then return false end
	return model and model:IsDescendantOf(folder)
end

local function destroyBillboardStrict(model)
	local data = Cache.Billboards[model]
	if not data then return end
	if data.gui and data.gui.Parent then
		data.gui:Destroy()
	end

	if data.folder == "Teachers" then
		Cache.Counts.Teachers = math.max(0, Cache.Counts.Teachers - 1)
	elseif data.folder == "Alices" then
		Cache.Counts.Alices = math.max(0, Cache.Counts.Alices - 1)
	end

	Cache.Billboards[model] = nil
end

------------------------------------------------------
-- 🔍 Reglas de observación por equipo
------------------------------------------------------
local function detectLocalFolder()
	for name, folder in pairs(Folders) do
		if folder:FindFirstChild(LocalPlayer.Name) then
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
-- 👁️ Visibilidad dinámica
------------------------------------------------------
local function updateVisibility(model)
	local data = Cache.Billboards[model]
	if not data or not data.gui then return end

	if not isModelInFolder(model, data.folder) then
		destroyBillboardStrict(model)
		return
	end

	local head = data.headRef
	if not (head and head.Parent) then
		head = getRealHead(model) 
		if not head then
			data.gui.Enabled = false
			data.headRef = nil 
			return
		end
		data.headRef = head
		data.gui.Adornee = head
	end

	local localFolder = detectLocalFolder()
	local canSeeBasedOnTeam = shouldLocalSeeModel(localFolder, data.folder, model)

	-- ⚡ CAMBIO 2: Lógica de distancia eliminada.
	-- Si podemos verlo por equipo, lo habilitamos.
	-- La propiedad "MaxDistance" del GUI se encargará del resto.
	if not canSeeBasedOnTeam then
		data.gui.Enabled = false
		return
	end
	
	-- Habilitar. El motor lo ocultará si está lejos.
	data.gui.Enabled = true
end

local function updateAllVisibility()
	for model, data in pairs(Cache.Billboards) do
		if data and data.gui then
			updateVisibility(model)
		end
	end
end

------------------------------------------------------
-- 📦 Sistema de caché Billboard (con carpeta física)
------------------------------------------------------
local function createOrReuseBillboard(model, folderName)
	if not model or not folderName then return end
	if model.Name == LocalPlayer.Name then return end

	local existing = Cache.Billboards[model]
	if existing and existing.gui then
		local head = getRealHead(model)
		local imgLabel = existing.gui:FindFirstChild("RoleImage")
		if head then
			existing.gui.Adornee = head
			existing.headRef = head
		end
		if imgLabel then
			imgLabel.Image = getImageIdForModel(model) or imgLabel.Image
		end
		return
	end

	if folderName == "Teachers" and Cache.Counts.Teachers >= MAX.Teachers then return end
	if folderName == "Alices" and Cache.Counts.Alices >= MAX.Alices then return end

	local head, imageId
	for i = 1, 25 do
		head = getRealHead(model)
		imageId = getImageIdForModel(model)
		if head then break end 
		task.wait(0.05)
	end
	
	if not head then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = model.Name .. "_Billboard"
	bb.Size = BILLBOARD_SIZE
	bb.StudsOffset = STUDS_OFFSET
	bb.AlwaysOnTop = true
	
	-- ⚡ CAMBIO 3: Usar la propiedad del motor
	bb.MaxDistance = MAX_RENDER_DISTANCE 
	
	bb.Adornee = head
	bb.Parent = BillboardCacheFolder
	bb.Enabled = false 

	local img = Instance.new("ImageLabel")
	img.Name = "RoleImage"
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb
	
	if imageId then
		img.Image = imageId
	end

	Cache.Billboards[model] = { gui = bb, folder = folderName, headRef = head }

	if folderName == "Teachers" then
		Cache.Counts.Teachers = Cache.Counts.Teachers + 1
	elseif folderName == "Alices" then
		Cache.Counts.Alices = Cache.Counts.Alices + 1
	end

	task.delay(0.05, function()
		if bb and bb.Parent then
			local finalHead = getRealHead(model)
			if finalHead then
				bb.Adornee = finalHead
				if Cache.Billboards[model] then 
					Cache.Billboards[model].headRef = finalHead
				end
			end
			updateVisibility(model) 
		end
	end)
end

local function destroyAllFromFolder(folderName)
	local modelsToDestroy = {}
	for model, data in pairs(Cache.Billboards) do
		if data and data.folder == folderName then
			table.insert(modelsToDestroy, model)
		end
	end
	
	for _, model in ipairs(modelsToDestroy) do
		destroyBillboardStrict(model)
	end
end

------------------------------------------------------
-- 🧱 Enganche de señales de modelo
------------------------------------------------------
local function hookModelSignals(model, folderName)
	if not model or not model:IsA("Model") then return end
	if model:FindFirstChild("__BillboardHooked") then return end
	if model.Name == LocalPlayer.Name then return end

	local marker = Instance.new("BoolValue")
	marker.Name = "__BillboardHooked"
	marker.Parent = model

	model:GetAttributeChangedSignal("TeacherName"):Connect(function()
		createOrReuseBillboard(model, folderName) 
		local data = Cache.Billboards[model]
		if data and data.gui then
			local img = data.gui:FindFirstChild("RoleImage")
			if img then img.Image = getImageIdForModel(model) or img.Image end
		end
	end)

	model:GetAttributeChangedSignal("Enraged"):Connect(function()
		local data = Cache.Billboards[model]
		if data and data.gui then
			local img = data.gui:FindFirstChild("RoleImage")
			if img then
				local newId = getImageIdForModel(model)
				if newId then img.Image = newId end
			end
		end
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			destroyBillboardStrict(model)
		else
			task.defer(function()
				createOrReuseBillboard(model, folderName)
				updateVisibility(model)
			end)
		end
	end)
	
	-- ⚡ CAMBIO 4: El listener de movimiento del enemigo ya no es necesario.
	-- El motor lo hace automáticamente.
	-- task.spawn(function()
	-- 	...
	-- 	head:GetPropertyChangedSignal("Position"):Connect(function()
	-- 		...
	-- 	end)
	-- end)
end

------------------------------------------------------
-- 🚀 Arranque seguro (procesa modelos ya presentes)
------------------------------------------------------
local function scanAndApply(localFolder)
	
	-- Prune (Limpieza)
	local modelsInFolders = {}
	for _, folderName in ipairs({"Alices", "Teachers"}) do
		local folder = Folders[folderName]
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("Model") then
					modelsInFolders[child] = true
				end
			end
		end
	end
	local modelsToPrune = {}
	for model, data in pairs(Cache.Billboards) do
		if not modelsInFolders[model] then
			table.insert(modelsToPrune, model)
		end
	end
	for _, model in ipairs(modelsToPrune) do
		destroyBillboardStrict(model)
	end
	
	-- Aplicar
	for _, folderName in ipairs({"Alices", "Teachers"}) do
		local folder = Folders[folderName]
		if not folder then
			-- (skip)
		else
			local children = folder:GetChildren()
			if #children == 0 then
				destroyAllFromFolder(folderName)
			end

			for _, child in ipairs(children) do
				if not child or not child:IsA("Model") then
					-- (skip)
				else
					if not shouldLocalSeeModel(localFolder, folderName, child) then
						local existing = Cache.Billboards[child]
						if existing and existing.gui then
							existing.gui.Enabled = false
						end
					else
						createOrReuseBillboard(child, folderName)
						hookModelSignals(child, folderName)
						updateVisibility(child)
					end
				end
			end
		end
	end
end

------------------------------------------------------
-- 🪝 Eventos globales (nuevos modelos)
------------------------------------------------------
for _, folderName in ipairs({"Alices", "Teachers"}) do
	local folder = Folders[folderName]
	if not folder then
		-- (skip)
	else
		folder.ChildAdded:Connect(function(child)
			if not child or not child:IsA("Model") then return end
			if child.Name == LocalPlayer.Name then return end

			local localFolder = detectLocalFolder()
			if not shouldLocalSeeModel(localFolder, folderName, child) then
				return 
			end

			task.defer(function()
				createOrReuseBillboard(child, folderName)
				hookModelSignals(child, folderName)
				updateVisibility(child)
			end)
		end)

		folder.ChildRemoved:Connect(function(child)
			destroyBillboardStrict(child)
		end)
	end
end

------------------------------------------------------
-- 🧍 Control del jugador local (respawn + movimiento)
------------------------------------------------------
local function onCharacterAdded(character)
	task.wait(0.5)
	
	local localFolder = detectLocalFolder() 
	scanAndApply(localFolder)
	updateAllVisibility()

	local root = character:WaitForChild("HumanoidRootPart", 3)
	if not root then return end
	
	-- ⚡ CAMBIO 5: El listener de movimiento del jugador ya no es necesario.
	-- El motor lo hace automáticamente.
	-- root:GetPropertyChangedSignal("Position"):Connect(function()
	-- 	...
	-- 	updateAllVisibility()
	-- end)

	-- Este SÍ es necesario (para cambiar de equipo)
	character:GetPropertyChangedSignal("Parent"):Connect(function()
		task.defer(function()
			scanAndApply(detectLocalFolder())
			updateAllVisibility()
		end)
	end)
	
	character.Destroying:Connect(function()
		updateAllVisibility() 
	end)
end

if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
