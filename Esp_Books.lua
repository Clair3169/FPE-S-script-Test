-- 🟦 Book BillboardGui Optimizado (versión corregida y funcional)
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

local function removeBillboard(meshPart)
	local bb = billboards[meshPart]
	if bb then
		if bb.Parent then bb:Destroy() end
	end
	billboards[meshPart] = nil
end

------------------------------------------------------------
-- ✨ createBillboard (versión corregida con visibilidad garantizada)
------------------------------------------------------------
local function createBillboard(meshPart)
	if asleep or not meshPart or not meshPart:IsA("BasePart") then return end

	-- 🔄 Evita duplicados
	if billboards[meshPart] then
		if billboards[meshPart].Parent then
			billboards[meshPart]:Destroy()
		end
		billboards[meshPart] = nil
	end

	-- 🕐 Esperar a que el meshPart esté realmente en el Workspace
	if not meshPart:IsDescendantOf(Workspace) then
		task.wait(0.1)
	end

	-- ⚙️ Crear BillboardGui visible
	local bb = Instance.new("BillboardGui")
	bb.Name = meshPart:GetDebugId() .. "_BB_Book"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(2.5, 0, 2.5, 0)
	bb.MaxDistance = RENDER_DISTANCE
	bb.StudsOffset = Vector3.new(0, meshPart.Size.Y + 1, 0)
	bb.LightInfluence = 0
	bb.Enabled = true -- 👈 visible desde el inicio
	bb.Adornee = meshPart
	bb.Parent = billboardsFolder

	-- 🖼️ Imagen del libro
	local img = Instance.new("ImageLabel")
	img.Name = "BookImage"
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Image = IMAGE_ID
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 2
	img.Parent = bb

	-- 🔲 Fondo (opcional, mejora visual)
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.7
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.ZIndex = 1
	bg.Parent = bb

	billboards[meshPart] = bb
end

------------------------------------------------------------
-- 🔁 updateBillboardsInRange
------------------------------------------------------------
local function updateBillboardsInRange()
	local localPos = getLocalPos()
	if asleep or not booksFolder or not localPos then return end

	for meshPart, bb in pairs(billboards) do
		if not meshPart or not meshPart.Parent then
			removeBillboard(meshPart)
		else
			local dist = (meshPart.Position - localPos).Magnitude
			local visible = dist <= RENDER_DISTANCE
			if bb and bb.Enabled ~= visible then
				bb.Enabled = visible
			end
		end
	end
end

------------------------------------------------------------
-- 🚀 Activación inicial
------------------------------------------------------------
local function activateBooks()
	if asleep or not booksFolder then return end
	for _, obj in ipairs(booksFolder:GetChildren()) do
		if obj:IsA("BasePart") then
			createBillboard(obj)
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
		if child:IsA("BasePart") then
			createBillboard(child)
			updateBillboardsInRange()
		end
	end)

	booksFolder.ChildRemoved:Connect(function(child)
		removeBillboard(child)
	end)
end

------------------------------------------------------------
-- 😴 Estado dormido (Alices / Teachers)
------------------------------------------------------------
local function scheduleCleanup()
	if cleanupTimer then return end
	cleanupTimer = task.delay(CLEANUP_DELAY, function()
		if not asleep then
			cleanupTimer = nil
			return
		end

		for meshPart, bb in pairs(billboards) do
			if bb and bb.Parent then bb:Destroy() end
			billboards[meshPart] = nil
		end

		for _, obj in ipairs(billboardsFolder:GetChildren()) do
			if obj:IsA("BillboardGui") then
				obj:Destroy()
			end
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
				if bb then bb.Enabled = false end
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
		for meshPart in pairs(billboards) do
			removeBillboard(meshPart)
		end
		booksFolder = nil
	end
end)

------------------------------------------------------------
-- 🧍‍♂️ Player y movimiento
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
		if asleep or not booksFolder then continue end

		local missing = false
		for _, obj in ipairs(booksFolder:GetChildren()) do
			if obj:IsA("BasePart") and not billboards[obj] then
				missing = true
				createBillboard(obj)
			end
		end

		for meshPart, bb in pairs(billboards) do
			if not meshPart or not meshPart.Parent then
				removeBillboard(meshPart)
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
