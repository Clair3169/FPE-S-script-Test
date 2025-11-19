task.wait(6)

local player = game.Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

local hasThirdPerson = Instance.new("BoolValue")
hasThirdPerson.Name = "ThirdPersonEnabled"
hasThirdPerson.Value = false
hasThirdPerson.Parent = player

local SoundService = game:GetService("SoundService")
local warningSound = Instance.new("Sound")
warningSound.SoundId = "rbxassetid://8382337318" -- ¡Recuerda cambiar este ID!
warningSound.Volume = 1
warningSound.Parent = SoundService

local bindableFunction = Instance.new("BindableFunction")

warningSound:Play()

warningSound.Ended:Connect(function()
    warningSound:Destroy()
end)

-- FUNCIÓN DE AYUDA para convertir URL de GitHub a URL de CDN
local function toCdnUrl(rawUrl)
    -- Reemplaza la base de GitHub raw por la base de jsDelivr
    local cdnUrl = rawUrl:gsub("https://raw%.githubusercontent%.com/(.-)/refs/heads/(.-)/", "https://cdn.jsdelivr.net/gh/%1@%2/")
    
    -- Ajuste final para tu estructura específica (eliminar 'refs/heads')
    cdnUrl = cdnUrl:gsub("/refs/heads", "")
    
    return cdnUrl
end


-- ----------------------------------------------------
-- ✨ ZONA DE EDICIÓN: LISTA DE URLs RAW DE GITHUB ✨
-- Puedes añadir o quitar URLs aquí directamente.
-- ----------------------------------------------------
local RAW_URLS_TO_LOAD = {
    -- 1. Tercera persona
    "https://raw.githubusercontent.com/Clair3169/FPE-S-script/refs/heads/main/3rd_Person.lua",
    
    -- 2. Shift Lock
    "https://raw.githubusercontent.com/Clair3169/FPE-S-script/refs/heads/main/Shiftlock.lua",
    
    -- 3. Cframe Walkspeed (Nombre corregido)
    "https://raw.githubusercontent.com/Clair3169/FPE-S-script/refs/heads/main/Notification_CframeSpeed.lua",
}


-- FUNCIÓN AUXILIAR PARA CARGAR Y EJECUTAR UN SCRIPT DE FORMA SEGURA Y PARALELA
local function loadAndExecuteRawUrl(rawUrl)
    local cdnUrl = toCdnUrl(rawUrl) -- Convierte la URL a CDN
    
    task.spawn(function() -- Usa task.spawn para aislar la ejecución
        
        local success, err = pcall(function()
            -- 1. Descargar el contenido usando la URL de CDN
            local scriptContent = game:HttpGet(cdnUrl, true)
            
            -- 2. Verificar la descarga y ejecutar
            if scriptContent and type(scriptContent) == "string" and #scriptContent > 0 then
                loadstring(scriptContent)() 
            else
                error("Fallo al descargar el script o contenido vacío.")
            end
        end)
        
        if not success then
            warn("❌ Error de Carga/Ejecución del script desde CDN:", cdnUrl, "\n", err)
        else
            print("✅ Script cargado correctamente (Original URL: " .. rawUrl .. ")")
        end
    end)
end


bindableFunction.OnInvoke = function(buttonClicked)
	if buttonClicked == "Yess!!" then
		hasThirdPerson.Value = true
        
        -- Itera sobre la lista de URLs RAW y las carga usando la función auxiliar
        for _, rawUrl in ipairs(RAW_URLS_TO_LOAD) do
            loadAndExecuteRawUrl(rawUrl)
        end
        
	elseif buttonClicked == "Nha" then
		hasThirdPerson.Value = false
	end
end

StarterGui:SetCore("SendNotification", {
	Title = "Hey you!",
	Text = "Do you want to activate third person mode?",
	Icon = "rbxassetid://97207642508375",
	Duration = 20,
	Callback = bindableFunction,
	Button1 = "Yess!!",
	Button2 = "Nha"
})
