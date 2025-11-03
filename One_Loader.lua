--// LoadOnceManager.lua
-- Coloca este script en StarterPlayerScripts o similar.

-- CONFIGURACIÓN
local urls = {
	"https://example.com/script1.lua",
	"https://example.com/script2.lua",
	-- Agrega más URLs aquí fácilmente.
}

-- NOMBRE DE LA MARCA PARA RECORDAR QUE YA SE EJECUTÓ
local flagName = "HasLoadedScriptsOnce"

-- SERVICIOS
local player = game.Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Función para marcar que ya se ejecutó
local function setExecutedFlag()
	local flag = Instance.new("BoolValue")
	flag.Name = flagName
	flag.Value = true
	flag.Parent = replicatedStorage
end

-- Función para verificar si ya se ejecutó
local function hasExecuted()
	return replicatedStorage:FindFirstChild(flagName) ~= nil
end

-- Función para cargar scripts desde URL (solo si no se ha ejecutado antes)
local function loadOnce()
	if hasExecuted() then
		warn("⚠️ Los scripts ya fueron cargados anteriormente.")
		return
	end

	for _, url in ipairs(urls) do
		task.spawn(function()
			local success, response = pcall(function()
				return game:HttpGet(url)
			end)
			if success and response then
				local runSuccess, err = pcall(function()
					loadstring(response)()
				end)
				if not runSuccess then
					warn("❌ Error ejecutando script desde URL:", url, "\n", err)
				else
					print("✅ Script cargado exitosamente:", url)
				end
			else
				warn("⚠️ No se pudo obtener el script desde:", url)
			end
		end)
	end

	setExecutedFlag()
end

-- Ejecutar una vez
loadOnce()
