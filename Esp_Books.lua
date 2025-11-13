-- 🟦 Book BillboardGui Robusto (versión final funcional)
repeat task.wait() until game:IsLoaded()

------------------------------------------------------------
-- ⚙️ Servicios
------------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then return end

------------------------------------------------------------
-- ⚙️ Configuración
------------------------------------------------------------
local IMAGE_ID = "rbxassetid://17537434140"
local RENDER_DISTANCE = 180
local UPDATE_THRESHOLD = 5
local CLEANUP_DELAY = 50
local AUTOVERIFIER_INTERVAL = 5

------------------------------------------------------------
-- 🧠 Estado
------------------------------------------------------------
local asleep = false
local billboards = {}
local billboardsFolder = Workspace:FindFirstChild("BillboardGuiBooks_Cache")
if not billboardsFolder then
	billboardsFolder = Instance.new("Folder")
	billboardsFolder.Name = "BillboardGuiBooks_Cache"
	billboardsFolder.Parent = Workspace
end

local booksFolder = nil
local cleanupTimer = nil

------------------------------------------------------------
-- 🔧 Utilidades
------------------------------------------------------------
local function getLocalPos()
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- Retorna BasePart válido de un libro (soporta Model o BasePart)
local function getTargetPart(book)
	if not book then return nil end
	if book:IsA("BasePart") then return book end
	if book:IsA("Model") then
		if book.PrimaryPart then return book.PrimaryPart end
		for _, d in ipairs(book:GetDescendants()) do
			if d:IsA("BasePart") then
				return d
			end
		end
	end
	return nil
end

local function removeBillboard(part)
	local bb = billboards[part]
	if bb then
		if bb.Parent then bb:Destroy() end
		billboards[part] = nil
	end
end

------------------------------------------------------------
-- ✨ Crear Billboard
------------------------------------------------------------
local function createBillboard(target)
	if asleep or not target or not target:IsA("BasePart") then return end

	-- Evitar duplicados
	if billboards[target] then
		if billboards[target].Parent then
			billboards[target]:Destroy()
		end
		billboards[target] = nil
	end

	-- Esperar que esté en Workspace
	if not target:IsDescendantOf(Workspace) then
		task.wait(0.1)
	end

	-- Crear BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Book_Billboard_" .. target.Name
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(2.5, 0, 2.5, 0)
	bb.MaxDistance = RENDER_DISTANCE
	bb.StudsOffset = Vector3.new(0, target.Size.Y + 1, 0)
	bb.LightInfluence = 0
	bb.Enabled = true
	bb.Adornee = target
	bb.Parent = billboardsFolder

	-- Imagen
	local img = Instance.new("ImageLabel")
	img.Name = "BookImage"
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Image = IMAGE_ID
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 2
	img.Parent = bb

	billboards[target] = bb
end

------------------------------------------------------------
-- 🔁 Actualizar visibilidad según distancia
------------------------------------------------------------
local function updateBillboardsInRange()
	local localPos = getLocalPos()
	if asleep or not localPos then return end

	for part, bb in pairs(billboards) do
		if not part or not part.Parent then
			removeBillboard(part)
		else
			local dist = (part.Position - localPos).Magnitude
			local visible = dist <= RENDER_DISTANCE
			if bb.Enabled ~= visible then
				bb.Enabled = visible
			end
		end
	end
end

------------------------------------------------------------
-- 🚀 Activar libros existentes
------------------------------------------------------------
local function activateBooks()
	if asleep or not booksFolder then return end

	for _, obj in ipairs(booksFolder:GetChildren()) do
		local target = getTargetPart(obj)
		if target then
			createBillboard(target)
		end
	end
	updateBillboardsInRange()
end

------------------------------------------------------------
-- 📚 Eventos del folder Books
------------------------------------------------------------
local function connectBookEvents()
	if not booksFolder or booksFolder:GetAttribute("EventsConnected") then return end
	booksFolder:SetAttribute("EventsConnected", true)

	booksFolder.ChildAdded:Connect(function(child)
		if asleep then return end
		local target = getTargetPart(child)
		if target then
			createBillboard(target)
			updateBillboardsInRange()
		end
	end)

	booksFolder.ChildRemoved:Connect(function(child)
		local target = getTargetPart(child)
		if target then removeBillboard(target) end
	end)
end

------------------------------------------------------------
-- 😴 Estado dormido
------------------------------------------------------------
local function scheduleCleanup()
	if cleanupTimer then return end
	cleanupTimer = task.delay(CLEANUP_DELAY, function()
		if not asleep then
			cleanupTimer = nil
			return
		end
		for part, bb in pairs(billboards) do
			if bb and bb.Parent then bb:Destroy() end
			billboards[part] = nil
		end
		cleanupTimer = nil
	end)
end

local function checkSleepState()
	local char = player.Character
	if not char then return end
	local parent = char.Parent
	local newAsleep = parent and (parent.Name == "Alices" or parent.Name == "Teachers")

	if newAsleep ~= asleep then
		asleep = newAsleep
		if asleep then
			for _, bb in pairs(billboards) do
				bb.Enabled = false
			end
			scheduleCleanup()
		else
			task.defer(function()
				booksFolder = Workspace:FindFirstChild("Books")
				if booksFolder then
					connectBookEvents()
					activateBooks()
				end
			end)
		end
	end
end

------------------------------------------------------------
-- 🌍 Integración con Workspace
------------------------------------------------------------
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Books" and child:IsA("Folder") then
		booksFolder = child
		connectBookEvents()
		task.defer(activateBooks)
	end
end)

Workspace.ChildRemoved:Connect(function(child)
	if child == booksFolder then
		for part in pairs(billboards) do
			removeBillboard(part)
		end
		booksFolder = nil
	end
end)

------------------------------------------------------------
-- 🧍‍♂️ Movimiento del jugador
------------------------------------------------------------
local function hookPlayerMovement(character)
	local root = character:WaitForChild("HumanoidRootPart", 3)
	if not root then return end
	local lastPos = root.Position

	root:GetPropertyChangedSignal("Position"):Connect(function()
		if asleep then return end
		local newPos = root.Position
		if (newPos - lastPos).Magnitude > UPDATE_THRESHOLD then
			lastPos = newPos
			updateBillboardsInRange()
		end
	end)
end

player.CharacterRemoving:Connect(function()
	for _, bb in pairs(billboards) do
		if bb then bb.Enabled = false end
	end
end)

------------------------------------------------------------
-- 🔁 Auto-verificador
------------------------------------------------------------
task.spawn(function()
	while task.wait(AUTOVERIFIER_INTERVAL) do
		if asleep then continue end
		if not booksFolder then
			booksFolder = Workspace:FindFirstChild("Books")
			continue
		end

		local missing = false
		for _, obj in ipairs(booksFolder:GetChildren()) do
			local target = getTargetPart(obj)
			if target and not billboards[target] then
				createBillboard(target)
				missing = true
			end
		end

		for part, bb in pairs(billboards) do
			if not part or not part.Parent then
				removeBillboard(part)
			end
		end

		if missing then
			updateBillboardsInRange()
		end
	end
end)

------------------------------------------------------------
-- 🔧 Inicialización
------------------------------------------------------------
local function initializeBookSystem()
	checkSleepState()
	booksFolder = booksFolder or Workspace:FindFirstChild("Books")
	if booksFolder then connectBookEvents() end
	if booksFolder and not asleep then activateBooks() end
end

player.CharacterAdded:Connect(function(char)
	char:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	task.defer(initializeBookSystem)
	hookPlayerMovement(char)
end)

if player.Character then
	player.Character:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	task.defer(initializeBookSystem)
	hookPlayerMovement(player.Character)
end
