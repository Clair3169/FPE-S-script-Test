-- 🟦 Book BillboardGui Optimizado (estructura y lógica del Highlighter Books, adaptado a BillboardGui)
repeat task.wait() until game:IsLoaded()

------------------------------------------------------------
-- ⚙️ Servicios
------------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then return end

------------------------------------------------------------
-- ⚙️ Configuración (confirmado)
------------------------------------------------------------
local IMAGE_ID = "rbxassetid://17537434140"
local RENDER_DISTANCE = 180
local UPDATE_THRESHOLD = 5 -- umbral de movimiento del jugador para actualizar
local CLEANUP_DELAY = 50 -- segundos para limpiar cache cuando el sistema está inactivo
local AUTOVERIFIER_INTERVAL = 5 -- intervalo para el auto-verificador

------------------------------------------------------------
-- 🧠 Estado y caché
------------------------------------------------------------
local asleep = false -- "dormido" (si el jugador está en Alices o Teachers)
local billboards = {} -- mapa meshPart -> BillboardGui (activos en memoria)
local billboardsFolder = Workspace:FindFirstChild("BillboardGuiBooks_Cache")
if not billboardsFolder then
	billboardsFolder = Instance.new("Folder")
	billboardsFolder.Name = "BillboardGuiBooks_Cache"
	billboardsFolder.Parent = Workspace
end

local booksFolder = nil
local cleanupTimer = nil

------------------------------------------------------------
-- 🔧 Utilidades (paridad con Highlighter)
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
		-- Desconecta visualmente y destruye instante
		if bb.Parent then bb:Destroy() end
	end
	billboards[meshPart] = nil
end

local function createBillboard(meshPart)
	-- No crear si estamos "dormidos" o el mesh no es válido
	if asleep or not meshPart or not meshPart:IsA("BasePart") or billboards[meshPart] then return end

	-- Reutilizar si existe en cache físico
	local cacheName = meshPart:GetDebugId() .. "_BB_Book"
	local cached = billboardsFolder:FindFirstChild(cacheName)
	if cached and cached:IsA("BillboardGui") then
		-- Reasigna adornee y asegura propiedades básicas
		cached.Adornee = meshPart
		cached.Enabled = false
		billboards[meshPart] = cached
		return
	end

	-- Crear nuevo BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = cacheName
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(2.5, 0, 2.5, 0)
	bb.MaxDistance = RENDER_DISTANCE
	bb.StudsOffset = Vector3.new(0, meshPart.Size.Y + 1, 0)
	bb.Adornee = meshPart
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Parent = billboardsFolder

	local img = Instance.new("ImageLabel")
	img.Name = "BookImage"
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Image = IMAGE_ID
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	billboards[meshPart] = bb
end

local function updateBillboardsInRange()
	local localPos = getLocalPos()
	if asleep or not booksFolder or not localPos then return end

	for meshPart, bb in pairs(billboards) do
		-- Si el meshPart ya no es válido, limpiamos
		if not meshPart or not meshPart.Parent then
			if bb and bb.Parent then bb:Destroy() end
			billboards[meshPart] = nil
		else
			-- Si el Billboard fue destruido por fuera, recrearlo en cache
			if not bb or not bb.Parent then
				billboards[meshPart] = nil
				-- Re-intentar crear (pero protegiendo contra bucles intensos)
				createBillboard(meshPart)
				bb = billboards[meshPart]
			end

			if bb and bb.Adornee then
				local dist = (bb.Adornee.Position - localPos).Magnitude
				local visible = dist <= RENDER_DISTANCE
				if bb.Enabled ~= visible then
					bb.Enabled = visible
				end
			end
		end
	end
end

------------------------------------------------------------
-- 🪄 Activación inicial de libros (mantener paridad con Highlighter)
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
-- 🔗 Conexión de eventos de la carpeta Books (solo una vez)
------------------------------------------------------------
local function connectBookEvents()
	if not booksFolder then return end
	if booksFolder:GetAttribute("EventsConnected") then return end
	booksFolder:SetAttribute("EventsConnected", true)

	booksFolder.ChildAdded:Connect(function(child)
		if asleep then return end
		if child:IsA("BasePart") then
			createBillboard(child)
			updateBillboardsInRange()
		end
	end)

	booksFolder.ChildRemoved:Connect(function(child)
		-- Equivalente a removeHighlight: destruimos billboard y limpieza de cache física
		local cachedName = child and (child:GetDebugId() .. "_BB_Book")
		if cachedName then
			local cached = billboardsFolder:FindFirstChild(cachedName)
			if cached and cached:IsA("BillboardGui") then
				cached:Destroy()
			end
		end
		removeBillboard(child)
	end)
end

------------------------------------------------------------
-- 🧩 Estado dormido (Alices / Teachers) y limpieza programada
------------------------------------------------------------
local function scheduleCleanup()
	if cleanupTimer then return end
	cleanupTimer = task.delay(CLEANUP_DELAY, function()
		-- Si el sistema volvió a activarse, no limpiamos
		if not asleep then
			cleanupTimer = nil
			return
		end

		-- Destruye billboards en memoria y en carpeta de cache
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
			-- Apagamos visualmente y programamos limpieza
			for meshPart, bb in pairs(billboards) do
				if bb then
					bb.Enabled = false
					if bb.Parent then bb.Parent = billboardsFolder end
				end
			end
			scheduleCleanup()
		else
			-- Despertamos: reactivamos y (re)inicializamos
			task.defer(function()
				-- Re-aseguramos la carpeta Books y conectamos eventos
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
-- 🧍‍♂️ Eventos globales de Books (Workspace)
------------------------------------------------------------
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Books" and child:IsA("Folder") then
		booksFolder = child
		connectBookEvents()
		-- Activación segura inmediata para libros ya presentes
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

-- Si Books ya existe al iniciar, lo enlazamos inmediatamente (persistencia tras muerte)
if Workspace:FindFirstChild("Books") then
	booksFolder = Workspace.Books
	connectBookEvents()
	task.defer(activateBooks)
end

------------------------------------------------------------
-- 🔔 Hook movimiento del jugador (solo actualiza por umbral)
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

------------------------------------------------------------
-- 🧹 Limpieza cuando el jugador muere / sale
------------------------------------------------------------
player.CharacterRemoving:Connect(function()
	-- Apaga visualmente todos los billboards (persistencia en cache físico hasta limpieza)
	for meshPart, bb in pairs(billboards) do
		if bb then bb.Enabled = false end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	-- Si algún meshPart pertenece al player que se fue, limpiarlo
	for meshPart, bb in pairs(billboards) do
		if meshPart and meshPart.Name and p.Name and meshPart.Name:find(p.Name) then
			if bb and bb.Parent then bb:Destroy() end
			billboards[meshPart] = nil
		end
	end
end)

------------------------------------------------------------
-- 🔁 Auto-verificador (detecta billboards huérfanos / recrea)
------------------------------------------------------------
task.spawn(function()
	while task.wait(AUTOVERIFIER_INTERVAL) do
		-- Solo funciona si no estamos dormidos y la carpeta Books existe
		if asleep or not booksFolder then continue end

		local missing = false
		for _, obj in ipairs(booksFolder:GetChildren()) do
			if obj:IsA("BasePart") then
				if not billboards[obj] then
					missing = true
					-- Intentar crear de forma segura
					createBillboard(obj)
				end
			end
		end

		-- Limpieza de billboards que apuntan a objetos inexistentes
		for meshPart, bb in pairs(billboards) do
			if not meshPart or not meshPart.Parent then
				if bb and bb.Parent then bb:Destroy() end
				billboards[meshPart] = nil
			end
		end

		if missing then
			updateBillboardsInRange()
		end
	end
end)

------------------------------------------------------------
-- 👤 Personaje local (estructura idéntica al Highlighter)
------------------------------------------------------------
local function initializeBookSystem()
	-- 1) Aseguramos estado dormido y carpeta Books
	checkSleepState()
	booksFolder = booksFolder or Workspace:FindFirstChild("Books")

	-- 2) Conectamos eventos si hay carpeta
	if booksFolder then
		connectBookEvents()
	end

	-- 3) Activamos libros ya presentes (si no estamos dormidos)
	if booksFolder and not asleep then
		activateBooks()
	end
end

player.CharacterAdded:Connect(function(char)
	-- Mantener paridad: conectar cambio de Parent para checkSleepState
	char:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	-- Inicialización con retraso seguro
	task.defer(initializeBookSystem)
	-- Hook de movimiento
	hookPlayerMovement(char)
end)

-- Si el personaje ya existe al inicio
if player.Character then
	player.Character:GetPropertyChangedSignal("Parent"):Connect(checkSleepState)
	task.defer(initializeBookSystem)
	hookPlayerMovement(player.Character)
end
