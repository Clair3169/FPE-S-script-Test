-- 📜 Script: Status Labels (Eventos puros + Recursión programada)

-- Servicios
local players = game:GetService("Players")
local stats = game:GetService("Stats")
local localPlayer = players.LocalPlayer

-- Crear la interfaz principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StatusLabels"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Función reutilizable para crear etiquetas
local function createLabel(text, color, position)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 200, 0, 20) -- Tamaño base
	label.Position = position
	label.AnchorPoint = Vector2.new(0, 1)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.Parent = screenGui
	return label
end

-- ============================================================
-- 🔹 1. Contador de Jugadores (Evento Nativo)
-- ============================================================
-- Posición: Base (0 px desde abajo)
local playerCountLabel = createLabel("Players: 0", Color3.fromRGB(0, 255, 0), UDim2.new(0, 2, 1, 0))

local function updatePlayerCount()
	playerCountLabel.Text = "Players: " .. #players:GetPlayers()
end

-- Usamos eventos puros aquí porque Roblox sí los provee para jugadores
players.PlayerAdded:Connect(updatePlayerCount)
players.PlayerRemoving:Connect(updatePlayerCount)
updatePlayerCount()

-- ============================================================
-- 🔹 2. Ping Monitor (Recursión Programada - CERO BUCLES)
-- ============================================================
-- Posición: 20 px arriba (Justo encima de Players)
local pingLabel = createLabel("Ping: 0", Color3.fromRGB(255, 255, 255), UDim2.new(0, 2, 1, -20))
pingLabel.BackgroundTransparency = 0

-- Referencia directa al valor de Ping (para no buscarlo cada vez)
local performanceStats = stats:WaitForChild("Network"):WaitForChild("ServerStatsItem"):WaitForChild("Data Ping")

local function updatePingRecursive()
	-- Obtenemos valor actual
	local pingValue = performanceStats:GetValue()
	local pingInt = math.floor(pingValue + 0.5) -- Redondear a entero
	
	-- Lógica de color solicitada
	if pingInt == 0 then
		pingLabel.TextColor3 = Color3.fromRGB(139, 0, 0) -- Rojo Oscuro (0 o error)
	elseif pingInt < 100 then
		pingLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Verde (Bien)
	elseif pingInt < 250 then
		pingLabel.TextColor3 = Color3.fromRGB(255, 170, 0) -- Naranja (Medio)
	else
		pingLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Rojo (Pésimo)
	end
	
	-- Texto sin decimales
	pingLabel.Text = "Ping: " .. pingInt .. " ms"

	-- ✨ MAGIA DE OPTIMIZACIÓN:
	-- En lugar de un bucle, programamos la próxima ejecución para dentro de 1 segundo.
	-- El script muere aquí y renace en 1s. Costo de CPU: Nulo.
	task.delay(1.5, updatePingRecursive)
end

-- Iniciar la cadena recursiva
updatePingRecursive()

-- ============================================================
-- 🔹 3. Diálogos estáticos
-- ============================================================
-- Posición: Empiezan en -40 px (20 de Players + 20 de Ping) para no tapar nada

local dialogueConfig = {
	{text = "", color = Color3.fromRGB(255, 0, 0)},
	{text = "", color = Color3.fromRGB(0, 255, 255)},
}

local baseY = -40 
local offset = 21 -- 20 de altura + 1 de separación

for i, config in ipairs(dialogueConfig) do
	local posY = baseY - ((i - 1) * offset)
	createLabel(config.text, config.color, UDim2.new(0, 2, 1, posY))
end
