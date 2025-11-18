local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer or Players:GetPlayers()[1]
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- ⚙️ CONFIGURACIÓN GUI
---------------------------------------------------------------------
local screenGui = playerGui:FindFirstChild("TimerGui") or Instance.new("ScreenGui")
screenGui.Name = "TimerGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local label = screenGui:FindFirstChild("TimerLabel") or Instance.new("TextLabel")
label.Name = "TimerLabel"
label.Size = UDim2.new(0, 90, 0, 28)
label.Position = UDim2.new(0.5, -45, 0, -3)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(255,255,255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = "0:00"
label.Visible = true
label.ZIndex = 100
label.Parent = screenGui

---------------------------------------------------------------------
-- 🎵 SONIDOS
---------------------------------------------------------------------
local phaseSongs = SoundService:WaitForChild("AllMusic"):WaitForChild("PhaseSongs")
local baseFolder = phaseSongs:WaitForChild("Base")
local phase2Folder = phaseSongs:WaitForChild("Phase2")

local quietHalls = baseFolder:WaitForChild("QuietHalls")
local properBehavior = baseFolder:WaitForChild("ProperBehavior")
local studentSound = phase2Folder:WaitForChild("Student")

local trackedSounds = { quietHalls, properBehavior, studentSound }

-- Duraciones manuales
local soundDurations = {
	[properBehavior] = (2*60)+5,
	[studentSound] = (3*60)+13
}

---------------------------------------------------------------------
-- 💾 VARIABLES
---------------------------------------------------------------------
local currentSound = nil
local zeroBlinkConn = nil
local isFaded = false
local isGlitching = false
local glitchStartTime = 0
local glitchSymbols = {"∆∆∆∆", "!!¡!!¡¿!", "¡!#¡!!¡¡¡", "?¿!¡?", "¿?!¿¡?", "XDD"}

-- VARIABLES PARA LA FUNCIÓN FANTASMA
local ghostStart = nil
local ghostGap = 0

---------------------------------------------------------------------
-- 🛠️ FUNCIONES
---------------------------------------------------------------------
local function format(sec)
	return string.format("%d:%02d", math.floor(sec/60), math.floor(sec%60))
end

local function isExcluded()
	local char = player.Character
	if not char or not char.Parent then return false end
	local parentName = char.Parent.Name
	return parentName == "Teachers" or parentName == "Alices"
end

local function fadeLabel(show)
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if show then
		if not isFaded then return end 
		isFaded = false
		label.Visible = true
		local tween = TweenService:Create(label, tweenInfo, {TextTransparency = 0})
		tween:Play()
	else
		if isFaded then return end 
		isFaded = true
		local tween = TweenService:Create(label, tweenInfo, {TextTransparency = 1})
		tween:Play()
		tween.Completed:Connect(function() 
			if isFaded then label.Visible = false end 
		end)
	end
end

local function startZeroBlink()
	if zeroBlinkConn then return end
	zeroBlinkConn = RunService.Heartbeat:Connect(function()
		label.Visible = true
		local t = tick()
		local blink = math.floor(t / 0.5) % 2
		label.TextColor3 = (blink == 0) and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,255,255)
	end)
end

local function stopZeroBlink()
	if zeroBlinkConn then
		zeroBlinkConn:Disconnect()
		zeroBlinkConn = nil
	end
end

local function selectBestSound()
	local best = nil
	local maxVol = 0
	for _, s in ipairs(trackedSounds) do
		if not (s and s.Parent) then continue end
		if (s.IsPlaying or (s.TimePosition and s.TimePosition > 0)) and s.Volume > 0 then
			if s.Volume > maxVol then
				maxVol = s.Volume
				best = s
			end
		end
	end
	return best
end

---------------------------------------------------------------------
-- 🔄 BUCLE PRINCIPAL
---------------------------------------------------------------------
repeat task.wait() until quietHalls.TimeLength > 0 and properBehavior.TimeLength > 0 and studentSound.TimeLength > 0

task.spawn(function()
	while task.wait(0.1) do
		
		-- 1. Control de Exclusión
		if isExcluded() then
			fadeLabel(false)
			stopZeroBlink() 
			ghostStart = nil -- Resetear fantasma si se excluye
			if isGlitching then isGlitching = false end
			currentSound = nil
			continue
		else
			fadeLabel(true)
		end
		
		-- 2. Selección de Sonido
		local best = selectBestSound()
		
		-- 🛡️ PROTECCIÓN FANTASMA: Si empieza nueva música, el fantasma muere
		if best then
			ghostStart = nil 
			ghostGap = 0
		end

		if not best then
			-- Fallback: Sonidos pausados
			local foundPaused = false
			for _, s in ipairs(trackedSounds) do
				if s and s.Parent and s.TimePosition and s.TimePosition > 0 then
					best = s 
					foundPaused = true
					break
				end
			end
			
			if not foundPaused then
				-- 👻 MODO FANTASMA (AQUÍ ESTÁ LA MAGIA)
				-- Se activa si no hay música, no hay pausa, pero teníamos un sonido previo con duración manual
				if currentSound and soundDurations[currentSound] then
					
					-- Iniciar el cálculo del "Hueco" (Gap) en el primer frame de silencio
					if not ghostStart then
						ghostStart = tick()
						-- El hueco es: Lo que TÚ dijiste que dura - Lo que REALMENTE dura el archivo
						local manualDur = soundDurations[currentSound]
						local realDur = currentSound.TimeLength
						ghostGap = math.max(manualDur - realDur, 0)
					end
					
					-- Calcular tiempo restante simulado
					local timeInGhost = tick() - ghostStart
					local remGhost = ghostGap - timeInGhost
					
					if remGhost > 0 then
						-- Aún queda tiempo fantasma, mostrarlo y saltar
						label.Text = format(remGhost)
						label.TextColor3 = Color3.fromRGB(255,0,0) -- Rojo (alerta)
						stopZeroBlink()
						continue -- ⚠️ IMPORTANTE: Salta el parpadeo de 0:00
					else
						-- Se acabó el tiempo fantasma, dejar pasar al parpadeo 0:00
						ghostStart = nil
					end
				end
				
				-- Parpadeo 0:00 estándar (Si no hay fantasma o ya acabó)
				if not zeroBlinkConn then
					label.Text = "0:00"
					startZeroBlink()
				end
				-- No reseteamos currentSound a nil aquí para recordar cuál fue el último para el fantasma
				continue
			end
		end

		-- 3. Glitch Anim
		if best == studentSound and best.TimePosition < 0.15 and currentSound ~= studentSound then
			isGlitching = true
			glitchStartTime = tick()
			stopZeroBlink()
		end
		
		if isGlitching then
			local elapsed = tick() - glitchStartTime
			if elapsed >= 4.3 then
				isGlitching = false
			else
				local index = math.floor(elapsed / 0.07) % #glitchSymbols + 1
				label.Text = glitchSymbols[index]
				label.TextColor3 = Color3.fromRGB(255,0,0)
				label.Visible = true
				currentSound = best
				continue 
			end
		end
		
		-- 4. Actualizar estado
		currentSound = best
		
		-- 5. Cálculo Normal
		local dur = soundDurations[currentSound] or currentSound.TimeLength or 0
		local tp = currentSound.TimePosition or 0
		if dur < 0 then dur = 0 end
		
		-- 6. Arreglo visual (Si empieza, no mostrar negativo)
		local rem
		if not currentSound.IsPlaying and tp < 0.15 then
			rem = 0
		else
			rem = math.max(dur - tp, 0)
		end
		
		-- 7. Parpadeo vs Música
		if zeroBlinkConn then
			if rem > 0 and currentSound.IsPlaying then
				stopZeroBlink()
			else
				continue 
			end
		end
		
		-- 8. Fin de tiempo normal
		if rem <= 0 then
			label.Text = "0:00"
			startZeroBlink()
			continue
		end
		
		-- 9. Display
		label.Text = format(rem)
		
		-- 10. Colores
		if tp > 0 and not currentSound.IsPlaying then
			label.TextColor3 = Color3.fromRGB(255,0,0)
		elseif rem <= 26 then
			label.TextColor3 = Color3.fromRGB(255,0,0)
		else
			label.TextColor3 = Color3.fromRGB(255,255,255)
		end
	end
end)
