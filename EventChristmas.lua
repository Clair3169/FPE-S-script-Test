local Workspace = game:GetService("Workspace")

-- CONFIGURACIÓN
local CARPETA_OBJETIVO = "EventPresents"
local NOMBRE_CARPETA_CACHE = "EventoCache"
local COLOR_GUI = Color3.fromRGB(0, 255, 127) 
local TAMANO_GUI = UDim2.new(1.5, 0, 1.5, 0)
local OFFSET_ADICIONAL = 2.5 

-- Crear carpeta de caché física (EventoCache)
local carpetaCache = Workspace:FindFirstChild(NOMBRE_CARPETA_CACHE) or Instance.new("Folder")
carpetaCache.Name = NOMBRE_CARPETA_CACHE
carpetaCache.Parent = Workspace

local memoriaGuis = {}
local carpetaEventos = Workspace:WaitForChild(CARPETA_OBJETIVO)

-- Cálculo de posición basado en el volumen del objeto
local function obtenerOffset(objeto)
	local altura = 0
	if objeto:IsA("Model") then
		local _, size = objeto:GetBoundingBox()
		altura = size.Y / 2
	elseif objeto:IsA("BasePart") then
		altura = objeto.Size.Y / 2
	end
	return Vector3.new(0, altura + OFFSET_ADICIONAL, 0)
end

local function crearBillboard(objeto)
	if memoriaGuis[objeto] then return end
	
	-- Crear el BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Tag_" .. objeto.Name
	billboard.Size = TAMANO_GUI
	billboard.AlwaysOnTop = true
	billboard.Adornee = objeto -- Vinculación nativa
	billboard.Parent = carpetaCache
	billboard.StudsOffset = obtenerOffset(objeto)

	-- El Círculo (UI)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = COLOR_GUI
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	
	-- Guardar en caché
	memoriaGuis[objeto] = billboard

	-- [EVENTO NATIVO EXTRA]
	-- Si el objeto es destruido directamente (no movido), limpiamos también.
	objeto.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if memoriaGuis[objeto] then
				memoriaGuis[objeto]:Destroy()
				memoriaGuis[objeto] = nil
			end
		end
	end)
end

-------------------------------------------------------------------------
-- CONEXIONES 100% NATIVAS (EVENT-DRIVEN)
-------------------------------------------------------------------------

-- 1. Se activa SOLO cuando entra un hijo
carpetaEventos.ChildAdded:Connect(function(hijo)
	task.defer(function() -- task.defer es más eficiente que wait()
		if hijo:IsDescendantOf(Workspace) then
			crearBillboard(hijo)
		end
	end)
end)

-- 2. Se activa SOLO cuando sale un hijo
carpetaEventos.ChildRemoved:Connect(function(hijo)
	if memoriaGuis[hijo] then
		memoriaGuis[hijo]:Destroy()
		memoriaGuis[hijo] = nil
	end
end)

-- 3. Carga inicial (ejecución única al iniciar)
for _, hijo in ipairs(carpetaEventos:GetChildren()) do
	crearBillboard(hijo)
end
