-- 🧿 Books BillboardGui Optimizado FINAL y Confiable (solo eventos, sin FPS drops)
-- LocalScript -> StarterPlayerScripts

repeat task.wait() until game:IsLoaded()

-- ⚙️ Servicios
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- 👤 Jugador local
local player = Players.LocalPlayer
if not player then return end

-- ⚙️ Configuración
local IMAGE_ID = "rbxassetid://17537434140"
local RENDER_DISTANCE = 180
local BILLBOARD_SIZE = UDim2.new(2.5, 0, 2.5, 0)
local asleep = false

-- 📦 Estado
local billboards = {}
local booksFolder

-- 📁 Carpeta de caché (reutilizable)
local cacheFolder = Workspace:FindFirstChild("BillboardCache_Books") or Instance.new("Folder")
cacheFolder.Name = "BillboardCache_Books"
cacheFolder.Parent = Workspace

------------------------------------------------------
-- 🔧 Funciones auxiliares
------------------------------------------------------

local function getCameraDistance(part)
	local cam = Workspace.CurrentCamera
	if not cam or not part then return math.huge end
	return (cam.CFrame.Position - part.Position).Magnitude
end

local function getOrCreateBillboard(meshPart)
	if not meshPart or not meshPart:IsA("BasePart") then return end
	if billboards[meshPart] then return billboards[meshPart] end

	local cacheName = meshPart:GetDebugId() .. "_BB_Book"
	local cached = cacheFolder:FindFirstChild(cacheName)

	if cached and cached:IsA("BillboardGui") then
		cached.Adornee = meshPart
		cached.Enabled = true
		billboards[meshPart] = cached
		return cached
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = cacheName
	billboard.AlwaysOnTop = true
	billboard.Size = BILLBOARD_SIZE
	billboard.MaxDistance = RENDER_DISTANCE
	billboard.StudsOffset = Vector3.new(0, meshPart.Size.Y + 1, 0)
	billboard.Adornee = meshPart
	billboard.LightInfluence = 0
	billboard.Enabled = true
	billboard.Parent = cacheFolder

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = IMAGE_ID
	image.Size = UDim2.new(1, 0, 1, 0)
	image.Parent = billboard

	billboards[meshPart] = billboard
	return billboard
end

local function updateBillboardVisibility(meshPart)
	local billboard = billboards[meshPart]
	if not billboard then return end
	local dist = getCameraDistance(meshPart)
	billboard.Enabled = dist <= RENDER_DISTANCE
end

local function removeBillboard(meshPart)
	local bb = billboards[meshPart]
	if bb then
		bb.Enabled = false
		bb.Adornee = nil
	end
	billboards[meshPart] = nil
end

------------------------------------------------------
-- 📘 Sistema de activación de libros
------------------------------------------------------

local function connectBookSignals(book)
	if not book:IsA("BasePart") then return end
	if book:FindFirstChild("__HookedBook") then return end

	local flag = Instance.new("BoolValue")
	flag.Name = "__HookedBook"
	flag.Parent = book

	book:GetPropertyChangedSignal("Position"):Connect(function()
		if asleep then return end
		updateBillboardVisibility(book)
	end)

	book.AncestryChanged:Connect(function(_, parent)
		if not parent or parent ~= booksFolder then
			removeBillboard(book)
		end
	end)
end

local function activateBooks()
	if asleep or not booksFolder then return end

	for _, obj in ipairs(booksFolder:GetChildren()) do
		if obj:IsA("BasePart") then
			getOrCreateBillboard(obj)
			updateBillboardVisibility(obj)
			connectBookSignals(obj)
		end
	end
end

------------------------------------------------------
-- 🪄 Eventos de carpeta "Books"
------------------------------------------------------

local function setupBookFolder()
	if not booksFolder then return end

	-- Libros ya existentes (asegurado)
	task.defer(activateBooks)

	booksFolder.ChildAdded:Connect(function(child)
		if asleep then return end
		if child:IsA("BasePart") then
			getOrCreateBillboard(child)
			updateBillboardVisibility(child)
			connectBookSignals(child)
		end
	end)

	booksFolder.ChildRemoved:Connect(function(child)
		removeBillboard(child)
	end)
end

------------------------------------------------------
-- 🧍‍♂️ Estado del jugador (Alices / Teachers)
------------------------------------------------------

local function checkSleepState()
	local char = player.Character
	if not char or not char.Parent then return end

	local newState = (char.Parent.Name == "Alices" or char.Parent.Name == "Teachers")

	if newState ~= asleep then
		asleep = newState
		if asleep then
			for meshPart in pairs(billboards) do
				removeBillboard(meshPart)
			end
		else
			task.defer(activateBooks)
		end
	end
end

------------------------------------------------------
-- 🌍 Inicialización global
------------------------------------------------------

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Books" and child:IsA("Folder") then
		booksFolder = child
		setupBookFolder()
	end
end)

Workspace.ChildRemoved:Connect(function(child)
	if child == booksFolder then
		for meshPart in pairs(billboards) do
			removeBillboard(meshPart)
		end
		booksFolder = nil
	end
end)

-- Si Books ya existe, conéctalo de inmediato
if Workspace:FindFirstChild("Books") then
	booksFolder = Workspace.Books
	setupBookFolder()
end

-- Estado del jugador
player.CharacterAdded:Connect(function(char)
	char:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	task.defer(checkSleepState)
end)

if player.Character then
	player.Character:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	task.defer(checkSleepState)
end
