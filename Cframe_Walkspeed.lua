-- LocalScript: Fake WalkSpeed usando CFrame (cliente)
-- Simula velocidad aumentada sin modificar WalkSpeed real

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- ==== CONFIGURACIÓN ====
local FakeSpeed = 150        -- velocidad visual (WalkSpeed falsa)
local Smoothness = 0.15     -- entre 0.05 y 0.25 (menor = más responsivo, mayor = más suave)
local UseCameraShake = false
local CameraShakeMagnitude = 0.25
-- ========================

local lastPos = hrp.Position
local camera = workspace.CurrentCamera

-- Función simple de cámara shake
local function cameraShake()
	local t = tick() * 50
	local amp = CameraShakeMagnitude
	local x = math.sin(t) * amp * 0.3
	local y = math.cos(t * 1.7) * amp * 0.2
	return CFrame.new(x, y, 0)
end

-- Movimiento visual continuo
RunService.RenderStepped:Connect(function(dt)
	if not hrp or not humanoid or humanoid.MoveDirection.Magnitude == 0 then
		lastPos = hrp.Position
		return
	end

	-- dirección actual de movimiento
	local dir = humanoid.MoveDirection
	local moveDist = FakeSpeed * dt
	local newPos = hrp.Position + dir * moveDist

	-- CFrame nuevo con interpolación para suavidad
	local newCFrame = hrp.CFrame:Lerp(CFrame.new(newPos, newPos + hrp.CFrame.LookVector), Smoothness)
	hrp.CFrame = newCFrame

	if UseCameraShake then
		camera.CFrame *= cameraShake()
	end

	lastPos = hrp.Position
end)

print("[Fake WalkSpeed CFrame] activo - velocidad visual:", FakeSpeed)
