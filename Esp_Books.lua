-- 🧿 Books BillboardGui Optimizado (solo eventos, sin FPS drops)
-- LocalScript en StarterPlayerScripts o StarterCharacterScripts

repeat task.wait() until game:IsLoaded()

-- ⚙️ Servicios
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- 👤 Jugador local
local player = Players.LocalPlayer

-- ⚙️ Configuración
local IMAGE_ID = "rbxassetid://17537434140"
local RENDER_DISTANCE = 180
local BILLBOARD_SIZE = UDim2.new(2.5, 0, 2.5, 0)
local asleep = false

-- 📦 Estado
local billboards = {}
local booksFolder

------------------------------------------------------
-- 🧩 Funciones auxiliares
------------------------------------------------------

local function clearAll()
	for meshPart, billboard in pairs(billboards) do
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end
	billboards = {}
end

local function createBillboard(meshPart)
	if asleep or not meshPart:IsA("BasePart") or billboards[meshPart] then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BookBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = BILLBOARD_SIZE
	billboard.MaxDistance = RENDER_DISTANCE
	billboard.StudsOffset = Vector3.new(0, meshPart.Size.Y + 1, 0)
	billboard.Adornee = meshPart

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = IMAGE_ID
	image.Size = UDim2.new(1, 0, 1, 0)
	image.Parent = billboard

	billboard.Parent = meshPart
	billboards[meshPart] = billboard
end

local function removeBillboard(meshPart)
	if billboards[meshPart] then
		billboards[meshPart]:Destroy()
		billboards[meshPart] = nil
	end
end

local function activateBooks()
	if asleep or not booksFolder then return end
	for _, obj in ipairs(booksFolder:GetChildren()) do
		if obj:IsA("MeshPart") then
			createBillboard(obj)
		end
	end
end

------------------------------------------------------
-- 🧩 Sistema de conexión de libros
------------------------------------------------------

local function connectBookEvents()
	if not booksFolder then return end

	-- Cuando aparece un libro
	booksFolder.ChildAdded:Connect(function(child)
		if not asleep and child:IsA("MeshPart") then
			createBillboard(child)
		end
	end)

	-- Cuando desaparece un libro
	booksFolder.ChildRemoved:Connect(function(child)
		removeBillboard(child)
	end)

	-- Cuando el libro cambia de posición, solo actualiza visibilidad si es necesario
	for _, obj in ipairs(booksFolder:GetChildren()) do
		if obj:IsA("BasePart") then
			obj:GetPropertyChangedSignal("Position"):Connect(function()
				if billboards[obj] then
					local cam = Workspace.CurrentCamera
					local dist = (cam.CFrame.Position - obj.Position).Magnitude
					billboards[obj].Enabled = (dist <= RENDER_DISTANCE)
				end
			end)
		end
	end

	activateBooks()
end

------------------------------------------------------
-- 🧩 Detectar si el jugador entra en Alices / Teachers
------------------------------------------------------

local function checkSleepState()
	local char = player.Character
	if not char or not char.Parent then return end

	local inAsleepFolder = (char.Parent.Name == "Alices" or char.Parent.Name == "Teachers")

	if inAsleepFolder ~= asleep then
		asleep = inAsleepFolder

		if asleep then
			clearAll()
		else
			if booksFolder and #booksFolder:GetChildren() > 0 then
				activateBooks()
			end
		end
	end
end

------------------------------------------------------
-- 🧩 Eventos globales
------------------------------------------------------

-- Carpeta Books
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

-- Inicialización si ya existe Books
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
