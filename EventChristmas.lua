local Workspace = game:GetService("Workspace")

-- CONFIGURACIÓN VISUAL
local CARPETA_OBJETIVO = "EventPresents"
local NOMBRE_CARPETA_CACHE = "EventoCache"
local COLOR_GUI = Color3.fromRGB(0, 255, 127) -- Verde brillante
local TAMANO_GUI = UDim2.new(2, 0, 2, 0) -- Tamaño mediano-pequeño (2 studs)
local ALTURA = Vector3.new(0, 2.5, 0) -- Altura sobre el objeto

-- 1. PREPARACIÓN DE LA CARPETA FÍSICA DE CACHÉ
-- Creamos la carpeta donde se guardarán físicamente los GUIs
local carpetaCache = Workspace:FindFirstChild(NOMBRE_CARPETA_CACHE)
if not carpetaCache then
	carpetaCache = Instance.new("Folder")
	carpetaCache.Name = NOMBRE_CARPETA_CACHE
	carpetaCache.Parent = Workspace
end

-- 2. TABLA LÓGICA (EL CEREBRO DEL SCRIPT)
-- Esta tabla relaciona: [Modelo Real] = [BillboardGui en la Cache]
local memoriaGuis = {}

local carpetaEventos = Workspace:WaitForChild(CARPETA_OBJETIVO)

-------------------------------------------------------------------------
-- FUNCIONES PRINCIPALES
-------------------------------------------------------------------------

local function crearBillboard(modelo)
	-- Verificamos si ya existe en memoria para no duplicar
	if memoriaGuis[modelo] then return end

	-- Creación del BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Gui_De_" .. modelo.Name -- Nombre referencial
	billboard.Size = TAMANO_GUI
	billboard.StudsOffset = ALTURA
	billboard.AlwaysOnTop = true
	
	-- [CLAVE DEL SISTEMA]
	-- Parent: Se guarda en tu carpeta 'EventoCache'
	-- Adornee: Se pega visualmente al modelo en 'EventPresents'
	billboard.Parent = carpetaCache 
	billboard.Adornee = modelo 

	-- Diseño visual (Círculo Verde Sólido)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = COLOR_GUI
	frame.BackgroundTransparency = 0 -- Totalmente sólido, como pediste
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0) -- Círculo perfecto
	corner.Parent = frame
	
	-- Guardamos la referencia en la tabla lógica
	memoriaGuis[modelo] = billboard
end

local function eliminarBillboard(modelo)
	-- Buscamos si este modelo tenía un GUI asociado
	local guiExistente = memoriaGuis[modelo]
	
	if guiExistente then
		-- Lo destruimos de la carpeta EventoCache
		guiExistente:Destroy()
		
		-- Borramos el registro de la memoria para mantenerla limpia
		memoriaGuis[modelo] = nil
	end
end

-------------------------------------------------------------------------
-- CONEXIONES DE EVENTOS
-------------------------------------------------------------------------

-- Cuando entra algo nuevo a 'EventPresents'
carpetaEventos.ChildAdded:Connect(function(hijo)
	task.wait() -- Breve espera técnica para asegurar carga
	if hijo:IsA("Model") or hijo:IsA("BasePart") then
		crearBillboard(hijo)
	end
end)

-- Cuando algo sale de 'EventPresents'
carpetaEventos.ChildRemoved:Connect(function(hijo)
	eliminarBillboard(hijo)
end)

-- Carga inicial (por si entras y ya hay cosas)
for _, hijo in ipairs(carpetaEventos:GetChildren()) do
	if hijo:IsA("Model") or hijo:IsA("BasePart") then
		crearBillboard(hijo)
	end
end
