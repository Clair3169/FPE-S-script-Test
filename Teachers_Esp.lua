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
local MAX_RENDER_DISTANCE = 250
local BILLBOARD_SIZE = UDim2.new(0, 45, 0, 45)
local STUDS_OFFSET = Vector3.new(0, 1.6, 0)
local UPDATE_THRESHOLD = 5 -- <-- Restaurado

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
	-- caso especial: si Head es un Model (AlicePhase2), buscar su Head interior
	if model:GetAttribute("TeacherName") == "AlicePhase2" and head and head:IsA("Model") then
		return head:FindFirstChild("Head")
	end
	return head
end

-- --- 🔥 SOLUCIÓN 1: Restaurar la función de distancia ---
local function getDistanceFromLocal(head)
	local char = LocalPlayer.Character
	local myHead = char and char:FindFirstChild("Head")
	if not (myHead and head) then return math.huge end
	-- proteger por posiciones nil
	-- (Si 'head' es una referencia destruida, 'head.Position' será nil y esto devolverá math.huge)
	if not myHead.Position or not head.Position then return math.huge end
	return (myHead.Position - head.Position).Magnitude
end

local function isModelInFolder(model, folderName)
	local folder = Folders[folderName]
	if not folder then return false end
	-- robusto: IsDescendantOf permite subestructura
	return model and model:IsDescendantOf(folder)
end

local function destroyBillboardStrict(model)
	-- elimina sin condiciones extra (uso interno cuando queremos forzar borrado)
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
-- 📦 Sistema de caché Billboard (con carpeta física)
------------------------------------------------------
local function createOrReuseBillboard(model, folderName)
	if not model or not folderName then return end

	-- --- 🔥 NUEVA LÍNEA DE SEGURIDAD ---
	-- No crear NUNCA un billboard para el LocalPlayer
	if model.Name == LocalPlayer.Name then
		return -- Salir de la función inmediatamente
	end
	-- --- FIN DE LA SEGURIDAD ---

	-- Reusar si existe
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
		existing.gui.Enabled = true
		return
	end

	-- Límite de instancias por tipo (no crear si ya excedimos)
	if folderName == "Teachers" and Cache.Counts.Teachers >= MAX.Teachers then return end
	if folderName == "Alices" and Cache.Counts.Alices >= MAX.Alices then return end

	-- Esperar cabeza válida e imagen (pequeño loop de retry)
	local head, imageId
	for i = 1, 25 do
		head = getRealHead(model)
		imageId = getImageIdForModel(model)
		if head and imageId then break end
		task.wait(0.05)
	end
	if not head or not imageId then return end

	-- Crear Billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = model.Name .. "_Billboard"
	bb.Size = BILLBOARD_SIZE
	bb.StudsOffset = STUDS_OFFSET
	bb.AlwaysOnTop = true
	-- IMPORTANTE: Seguimos usando MaxDistance.
	-- Nuestro script manual 'Enabled' es una *adición* a esto, no un reemplazo.
	-- El script decide si DEBERÍAS verlo (equipo),
	-- y MaxDistance decide si PUEDES verlo (distancia).
	-- ... O podemos hacer el chequeo de distancia manualmente.
	-- Restauraremos tu lógica manual al 100%.
	bb.MaxDistance = math.huge -- Ponemos Infinito, para que *nuestro* script controle la distancia.
	bb.Adornee = head
	bb.Parent = BillboardCacheFolder
	bb.Enabled = false -- empezar disabled y activarlo tras asegurar parent/adorn

	local img = Instance.new("ImageLabel")
	img.Name = "RoleImage"
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundTransparency = 1
	img.Image = imageId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	-- Guardar en caché (observa que guardamos folderName)
	Cache.Billboards[model] = { gui = bb, folder = folderName, headRef = head }

	if folderName == "Teachers" then
		Cache.Counts.Teachers = Cache.Counts.Teachers + 1
	elseif folderName == "Alices" then
		Cache.Counts.Alices = Cache.Counts.Alices + 1
	end

	-- Activación segura y resync corto (evita frame donde Adornee no tiene posición)
	task.delay(0.05, function()
		if bb and bb.Parent then
			-- reasignar por seguridad
			local finalHead = getRealHead(model)
			if finalHead then
				bb.Adornee = finalHead
				Cache.Billboards[model].headRef = finalHead
			end
			-- Ya no lo habilitamos aquí, dejamos que updateVisibility lo haga
			-- bb.Enabled = true 
			updateVisibility(model) -- <-- Llamar a la lógica de visibilidad de inmediato
		end
	end)
end

local function maybeDestroyBillboardIfModelGone(model)
	-- Solo destruir si el modelo ya NO está en su carpeta original (Teacher/Alice)
	local data = Cache.Billboards[model]
	if not data then return end
	if not isModelInFolder(model, data.folder) then
		destroyBillboardStrict(model)
	end
end

-- Destruir todos billboards de un folder (por ejemplo si la carpeta quedó vacía)
local function destroyAllFromFolder(folderName)
	for model, data in pairs(Cache.Billboards) do
		if data and data.folder == folderName then
			destroyBillboardStrict(model)
		end
	end
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
	-- no mostrar billboards del propio jugador
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

	-- Si el modelo ya no está en su carpeta: destruir (es eliminación real)
	if not isModelInFolder(model, data.folder) then
		destroyBillboardStrict(model)
		return
	end

	-- Reforzar referencia a la cabeza (si se perdió)
	local head = data.headRef
	
	if not (head and head.Parent) then
		head = getRealHead(model) -- Intenta buscar la *nueva* cabeza
		if not head then
			data.gui.Enabled = false
			return
		end
		data.headRef = head
		data.gui.Adornee = head
	end

	-- 1. Chequear si el jugador local DEBE ver este modelo por reglas de equipo
	local localFolder = detectLocalFolder()
	local canSeeBasedOnTeam = shouldLocalSeeModel(localFolder, data.folder, model)

	if not canSeeBasedOnTeam then
		-- Si no debe verlo por equipo, deshabilitar y salir.
		data.gui.Enabled = false
		return
	end

	-- --- 🔥 SOLUCIÓN 2: Restaurar el chequeo de distancia manual ---
	-- 2. Si puede verlo, chequear distancia
	local dist = getDistanceFromLocal(head) -- 'head' ahora es VÁLIDA
	local shouldShow = dist <= MAX_RENDER_DISTANCE

	data.gui.Enabled = shouldShow
end

-- --- Definición de la función 'updateAllVisibility' ---
local function updateAllVisibility()
	-- Itera sobre todos los billboards que tenemos en caché
	for model, data in pairs(Cache.Billboards) do
		if data and data.gui then
			-- Re-ejecuta la lógica de visibilidad para este modelo
			updateVisibility(model)
		end
	end
end

------------------------------------------------------
-- 🧱 Enganche de señales de modelo
------------------------------------------------------
local function hookModelSignals(model, folderName)
	if not model or not model:IsA("Model") then return end
	if model:FindFirstChild("__BillboardHooked") then return end

	-- --- 🔥 NUEVA LÍNEA DE SEGURIDAD ---
	-- No enganchar NUNCA señales en el LocalPlayer
	if model.Name == LocalPlayer.Name then
		return -- Salir de la función inmediatamente
	end
	-- --- FIN DE LA SEGURIDAD ---

	local marker = Instance.new("BoolValue")
	marker.Name = "__BillboardHooked"
	marker.Parent = model

	-- TeacherName cambió -> recrear/actualizar imagen
	model:GetAttributeChangedSignal("TeacherName"):Connect(function()
		-- intenta recrear o actualizar la imagen (reuso)
		createOrReuseBillboard(model, folderName)
		local data = Cache.Billboards[model]
		if data and data.gui then
			local img = data.gui:FindFirstChild("RoleImage")
			if img then img.Image = getImageIdForModel(model) or img.Image end
		end
	end)

	-- Enraged cambió -> solo actualizar imagen si existe
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

	-- Si la jerarquía cambia (se reparenta o se elimina) -> gestionar billboard
	model.AncestryChanged:Connect(function(_, parent)
		-- si el modelo dejó de existir, destruir estrictamente
		if not parent then
			destroyBillboardStrict(model)
		else
			-- si se reparenta dentro del juego, aseguramos reuso/adornee
			task.defer(function()
				createOrReuseBillboard(model, folderName)
				updateVisibility(model)
			end)
		end
	end)
	
	-- --- 🔥 SOLUCIÓN 3: Enganchar el movimiento del *enemigo* ---
	task.spawn(function()
		local head = getRealHead(model)
		-- Intentar encontrar la cabeza varias veces si no está lista
		if not head then
			for i = 1, 10 do
				task.wait(0.2)
				head = getRealHead(model)
				if head then break end
			end
		end

		if not head then
			-- Si no se encuentra cabeza, no podemos escuchar su movimiento
			return 
		end

		-- Guardar la última posición conocida de *este* enemigo
		local lastEnemyPos = head.Position
		
		-- Escuchar cambios en la posición de la cabeza del enemigo
		head:GetPropertyChangedSignal("Position"):Connect(function()
			if not head.Parent then return end -- Cabeza destruida, no hacer nada

			local newEnemyPos = head.Position
			if not newEnemyPos or not lastEnemyPos then 
				-- Posición inválida o no hay pos anterior,
				-- actualizar por si acaso y guardar
				lastEnemyPos = newEnemyPos 
				updateVisibility(model)
				return
			end

			-- Solo actualizar la visibilidad de ESTE billboard si se movió lo suficiente
			if (newEnemyPos - lastEnemyPos).Magnitude > UPDATE_THRESHOLD then
				lastEnemyPos = newEnemyPos
				
				-- ¡Importante! No llamar a updateAll, solo al del modelo específico
				updateVisibility(model)
			end
		end)
	end)
	-- --- FIN DE LA SOLUCIÓN 3 ---
end

------------------------------------------------------
-- 🚀 Arranque seguro (procesa modelos ya presentes)
------------------------------------------------------
local function scanAndApply(localFolder)
	-- contadores locales (alternativa a los globales en Cache.Counts)
	local teachersSeen, alicesSeen = 0, 0

	for _, folderName in ipairs({"Alices", "Teachers"}) do
		local folder = Folders[folderName]
		if not folder then
			-- siguiente folder si falta
		else
			local children = folder:GetChildren()
			-- Si la carpeta está vacía -> eliminar todos billboards asociados a este folder
			if #children == 0 then
				destroyAllFromFolder(folderName)
			end

			for _, child in ipairs(children) do
				if not child or not child:IsA("Model") then
					-- skip
				else
					if not shouldLocalSeeModel(localFolder, folderName, child) then
						local existing = Cache.Billboards[child]
						if existing and existing.gui then
							existing.gui.Enabled = false
						end
					else
						-- respetar límites por tipo al crear/activar
						if folderName == "Teachers" and teachersSeen >= MAX.Teachers then
							-- skip
						elseif folderName == "Alices" and alicesSeen >= MAX.Alices then
							-- skip
						else
							createOrReuseBillboard(child, folderName)
							hookModelSignals(child, folderName)
							updateVisibility(child)
							if folderName == "Teachers" then teachersSeen = teachersSeen + 1 end
							if folderName == "Alices" then alicesSeen = alicesSeen + 1 end
						end
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
		-- el folder debería existir, pero evitamos crash
	else
		folder.ChildAdded:Connect(function(child)
			if not child or not child:IsA("Model") then return end

			-- --- 🔥 NUEVA LÍNEA DE SEGURIDAD (Eficiencia) ---
			-- Salida rápida si el que se unió es el jugador local
			if child.Name == LocalPlayer.Name then
				return
			end
			-- --- FIN DE LA SEGURIDAD ---

			-- detectar folder del local en el momento de la adición
			local localFolder = detectLocalFolder()

            -- V V V LÍNEA DE OPTIMIZACIÓN V V V
			-- Si NO deberíamos ver este modelo (es compañero), no crear nada.
			if not shouldLocalSeeModel(localFolder, folderName, child) then
				return 
			end
            -- V V V FIN DE LA OPTIMIZACIÓN V V V

			-- (El código de abajo ahora solo se ejecuta para enemigos)
			task.defer(function()
				createOrReuseBillboard(child, folderName)
				hookModelSignals(child, folderName)
				-- notamos: updateVisibility decidirá si mostrarlo
				updateVisibility(child)
			end)
		end)

		folder.ChildRemoved:Connect(function(child)
			-- si se elimina el modelo de la jerarquía, asegurar que se destruya
			destroyBillboardStrict(child)
			-- si la carpeta quedó vacía, limpiar todos billboards del folder
			if #folder:GetChildren() == 0 then
				destroyAllFromFolder(folderName)
			end
		end)
	end
end

------------------------------------------------------
-- 🧍 Control del jugador local (respawn + movimiento)
------------------------------------------------------
local function onCharacterAdded(character)
	-- esperar un poco para que todo replique
	task.wait(0.5)
	local localFolder = detectLocalFolder()

	-- Re-scan pero sin destruir por muerte del jugador local
	scanAndApply(localFolder)
	
	-- Esta es la llamada clave.
	-- Fuerza a 'updateVisibility' a ejecutarse para TODOS los billboards.
	updateAllVisibility()

	local root = character:WaitForChild("HumanoidRootPart", 3)
	if not root then return end

	local lastPos = root.Position
	
	-- --- 🔥 SOLUCIÓN 4: Restaurar el evento de movimiento del JUGADOR LOCAL ---
	-- Evento de movimiento (ya optimizado)
	root:GetPropertyChangedSignal("Position"):Connect(function()
		local newPos = root.Position
		if not newPos then return end
		
		if (newPos - lastPos).Magnitude > UPDATE_THRESHOLD then
			lastPos = newPos
			-- Cuando el JUGADOR se mueve, actualizar TODOS
			updateAllVisibility()
		end
	end)
	-- --- FIN DE LA SOLUCIÓN 4 ---

	-- si el character se reparenta (ej. respawn), re-scan y actualizar
	character:GetPropertyChangedSignal("Parent"):Connect(function()
		task.defer(function()
			scanAndApply(detectLocalFolder())
			updateAllVisibility()
		end)
	end)
end

if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
