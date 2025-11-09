-- LocalScript
-- Colócalo en StarterPlayerScripts o StarterCharacterScripts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local IMAGE_ID = "rbxassetid://17537434140"
local RENDER_DISTANCE = 180
local BILLBOARD_SIZE = UDim2.new(2.5, 0, 2.5, 0) -- tamaño mediano

local billboards = {}
local booksFolder
local asleep = false -- estado dormido si estamos en Alices o Teachers

------------------------------------------------------
-- Funciones auxiliares
------------------------------------------------------

local function clearAll()
	for meshPart, _ in pairs(billboards) do
		if billboards[meshPart] then
			billboards[meshPart]:Destroy()
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
-- Control de carpeta Books (creación / eliminación)
------------------------------------------------------

local function connectBookEvents()
	if not booksFolder then return end

	booksFolder.ChildAdded:Connect(function(child)
		if not asleep and child:IsA("MeshPart") then
			createBillboard(child)
		end
	end)

	booksFolder.ChildRemoved:Connect(function(child)
		removeBillboard(child)
		-- [[ CAMBIO REALIZADO ]]
		-- La siguiente comprobación es redundante.
		-- Si se elimina el último libro, removeBillboard(child) lo limpiará.
		-- Si se elimina la carpeta "Books" entera, el evento de Workspace.ChildRemoved
		-- llamará a clearAll() de todos modos.
		-- 
		-- if #booksFolder:GetChildren() == 0 then
		-- 	clearAll()
		-- end
	end)

	activateBooks()
end

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

if Workspace:FindFirstChild("Books") then
	booksFolder = Workspace.Books
	connectBookEvents()
end

------------------------------------------------------
-- Detección de si el jugador está en Alices o Teachers
------------------------------------------------------

local function checkSleepState()
	local char = player.Character or player.CharacterAdded:Wait()
	local parent = char.Parent
	local newAsleep = false

	if parent and (parent.Name == "Alices" or parent.Name == "Teachers") then
		newAsleep = true
	end

	if newAsleep ~= asleep then
		asleep = newAsleep
		if asleep then
			-- Dormir → eliminar todos los BillboardGui
			clearAll()
		else
			-- Despertar → volver a activar si hay libros
			if booksFolder and #booksFolder:GetChildren() > 0 then
				activateBooks()
			end
		end
	end
end

-- Escucha cuando cambie el parent del Character (entra o sale de carpetas)
player.CharacterAdded:Connect(function(char)
	char:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	checkSleepState()
end)

-- Si ya hay personaje cargado al inicio
if player.Character then
	player.Character:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	checkSleepState()
end
