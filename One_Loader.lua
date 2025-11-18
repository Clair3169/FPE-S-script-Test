--// LoadOnceManager.lua
-- Coloca este script en StarterPlayerScripts o similar.

-- FUNCIÓN DE AYUDA para convertir URL de GitHub a URL de CDN
local function toCdnUrl(rawUrl)
    -- Ejemplo: Convierte 
    -- https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Script.lua
    -- A:
    -- https://cdn.jsdelivr.net/gh/Clair3169/FPE-S-script-Test@main/Script.lua

    -- Reemplaza la base de GitHub raw por la base de jsDelivr
    local cdnUrl = rawUrl:gsub("https://raw%.githubusercontent%.com/(.-)/refs/heads/(.-)/", "https://cdn.jsdelivr.net/gh/%1@%2/")
    
    -- Ajuste final para tu estructura específica (eliminar 'refs/heads')
    cdnUrl = cdnUrl:gsub("/refs/heads", "")
    
    return cdnUrl
end


-- CONFIGURACIÓN (Ahora con URLs de CDN, más rápidas y estables)
-- Nota: La conversión es automática, pero las dejo aquí con la estructura CDN para claridad.
local urls_raw = {
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Welcome_Script.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Anti_Blackout.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Delete_Areas.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/JumpPower_Perma.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Key_notification.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/AimBot.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Stamina_INF.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Stundents_Esp.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Teachers_Esp.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Time.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Visual_Enraged.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/SprintFake.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/TextLabel.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Esp_Books.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/Anti_Camera.lua",
	"https://raw.githubusercontent.com/Clair3169/FPE-S-script-Test/refs/heads/main/NO_RAGDOLL.lua"
}

-- Convertir todas las URLs a CDN
local urls = {}
for _, rawUrl in ipairs(urls_raw) do
    table.insert(urls, toCdnUrl(rawUrl))
end


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
		warn("⚠️ El script ya esta cargado.")
		return
	end

	for _, url in ipairs(urls) do
		-- Usamos task.spawn para cargar scripts en paralelo (más rápido)
		task.spawn(function()
			-- Usamos la sintaxis probada que funciona en tu entorno: pcall(loadstring(game:HttpGet(...)))
			local fullCode = string.format('pcall(loadstring(game:HttpGet("%s", true))())', url)

			local success, err = pcall(function()
				loadstring(fullCode)()
			end)
			
			if not success then
				warn("❌ Error al cargar/ejecutar el script:", url, "\n", err)
			end
		end)
	end

	setExecutedFlag()
end

-- Ejecutar una vez
loadOnce()
