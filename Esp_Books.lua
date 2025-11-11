-- 🧿 Books BillboardGui Optimizado Final (solo eventos, sin FPS drops)
-- LocalScript -> StarterPlayerScripts o StarterCharacterScripts

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

-- 📁 Carpeta de caché global (para evitar recrear repetidamente)
local cacheFolder = Workspace:FindFirstChild("BillboardCache_Books") or Instance.new("Folder")
cacheFolder.Name = "BillboardCache_Books"
cacheFolder.Parent = Workspace

------------------------------------------------------
-- 🧩 Funciones auxiliares
------------------------------------------------------

local function getCameraDistance(part)
	local cam = Workspace.CurrentCamera
	if not cam or not part then return math.huge end
	return (cam.CFrame.Position - part.Position).Magnitude
end

local function clearAll()
	for meshPart, billboard in pairs(billboards) do
		if billboard then
			billboard.Enabled = false
			billboard.Adornee = nil
		end
	end
	billboards = {}
end

local function getOrCreateBillboard(meshPart)
	if not meshPart or not meshPart:IsA("BasePart") then return end
	if billboards[meshPart] then return billboards[meshPart] end

	local cacheName = meshPart.Name .. "_BB_Book"
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

------------------------------------------------------
-- 🧩 Activar y manejar libros
------------------------------------------------------

local function activateBooks()
	if asleep or not booksFolder then return end

	for _, obj in ipairs(booksFolder:GetChildren()) do
		if obj:IsA("MeshPart") and not billboards[obj] then
			local bb = getOrCreateBillboard(obj)
			updateBillboardVisibility(obj)

			-- Solo conectar una vez
			if not obj:FindFirstChild("__BookHooked") then
				local marker = Instance.new("BoolValue")
				marker.Name = "__BookHooked"
				marker.Parent = obj

				obj:GetPropertyChangedSignal("Position"):Connect(function()
					if asleep then return end
					updateBillboardVisibility(obj)
				end)
			end
		end
	end
end

------------------------------------------------------
-- 🧩 Sistema de conexión
------------------------------------------------------

local function connectBookEvents()
	if not booksFolder then return end

	booksFolder.ChildAdded:Connect(function(child)
		if asleep then return end
		if child:IsA("MeshPart") then
			getOrCreateBillboard(child)
			updateBillboardVisibility(child)
		end
	end)

	booksFolder.ChildRemoved:Connect(function(child)
		if billboards[child] then
			local bb = billboards[child]
			if bb then
				bb.Enabled = false
				bb.Adornee = nil
			end
			billboards[child] = nil
		end
	end)

	activateBooks()
end

------------------------------------------------------
-- 🧩 Estado del jugador (Alices / Teachers)
------------------------------------------------------

local function checkSleepState()
	local char = player.Character
	if not char or not char.Parent then return end

	local inAllowedFolder = (char.Parent.Name == "Alices" or char.Parent.Name == "Teachers")

	if inAllowedFolder ~= asleep then
		asleep = inAllowedFolder
		if asleep then
			clearAll()
		else
			task.defer(activateBooks)
		end
	end
end

------------------------------------------------------
-- 🧩 Eventos globales
------------------------------------------------------

-- Detectar Books folder
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Books" and child:IsA("Folder") then
		booksFolder = child
		connectBookEvents()
	end
end)

Workspace.ChildRemoved:Connect(function(child)
	if child == booksFolder then
		clearAll()
		booksFolder = nil
	end
end)

-- Inicializar si ya existe
if Workspace:FindFirstChild("Books") then
	booksFolder = Workspace.Books
	connectBookEvents()
end

-- Detectar cambios de estado del jugador
player.CharacterAdded:Connect(function(char)
	char:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	checkSleepState()
end)

if player.Character then
	player.Character:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	checkSleepState()
end
