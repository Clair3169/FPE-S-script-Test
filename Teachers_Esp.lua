-- LocalScript: Teachers/Alices -> BillboardGui (Students only)
-- Requisitos implementados:
-- • Solo corre si LocalPlayer está en Students
-- • Mapea TeacherName -> imageId (Circle tiene override Enraged)
-- • Limita activos: Teachers max 4, Alices max 2
-- • Soporta AlicePhase2 (Head dentro de Head model)
-- • No aplica a uno mismo ni a jugadores de la misma carpeta
-- • Reactiva cuando cambian atributos / entra/sale gente
-- • Tamaño Billboard: UDim2.new(0,60,0,60)

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local Folders = {
	Alices = Workspace:WaitForChild("Alices"),
	Students = Workspace:WaitForChild("Students"),
	Teachers = Workspace:WaitForChild("Teachers"),
}

local MAX = { Teachers = 4, Alices = 2 }
local MAX_RENDER_DISTANCE = 300
local CHECK_INTERVAL = 2

local BILLBOARD_SIZE = UDim2.new(0,60,0,60)
local STUDS_OFFSET = Vector3.new(0, 1.6, 0)

-- Mapping base ids
local BASE_IDS = {
	Bloomie = "129090409260807",
	Circle  = "72842137403522",
	Thavel  = "126007170470250",
	Alice   = "94023609108845",
	AlicePhase2 = "78066130044573",
}
-- Circle enraged override id
local CIRCLE_ENRAGED_ID = "108867117884833"

-- Caches
local ActiveBillboards = {} -- model -> { gui = BillboardGui, folder = "Teachers"/"Alices" }
local ActiveCounts = { Teachers = 0, Alices = 0 }

-- Reemplazar la función getImageIdForModel existente por esta:
local function getImageIdForModel(model)
	if not model then return nil end
	local tname = model:GetAttribute("TeacherName")
	if not tname then return nil end

	-- Teachers
	if tname == "Bloomie" then
		return BASE_IDS.Bloomie
	end
	if tname == "Circle" then
		-- Leer Enraged desde Attributes (bool) en vez de buscar BoolValue hijo
		local enragedAttr = model:GetAttribute("Enraged")
		if enragedAttr == true then
			return CIRCLE_ENRAGED_ID
		end
		return BASE_IDS.Circle
	end
	if tname == "Thavel" then
		return BASE_IDS.Thavel
	end

	-- Alices
	if tname == "Alice" then
		return BASE_IDS.Alice
	end
	if tname == "AlicePhase2" then
		return BASE_IDS.AlicePhase2
	end

	return nil
end

-- Utility: get real head (handles AlicePhase2 where Head can be a Model)
local function getRealHead(model)
	if not model or not model:IsA("Model") then return nil end
	local teacherName = model:GetAttribute("TeacherName")
	local head = model:FindFirstChild("Head")
	if not head then return nil end
	if teacherName == "AlicePhase2" and head:IsA("Model") then
		local inner = head:FindFirstChild("Head")
		if inner and inner:IsA("BasePart") then
			return inner
		end
	end
	if head:IsA("BasePart") then
		return head
	end
	return nil
end

-- Get image id (string) for a model based on TeacherName and Enraged
local function getImageIdForModel(model)
	if not model then return nil end
	local tname = model:GetAttribute("TeacherName")
	if not tname then return nil end
	-- Teachers list
	if tname == "Bloomie" then
		return BASE_IDS.Bloomie
	end
	if tname == "Circle" then
		-- check BoolValue "Enraged" inside model
		local enr = model:FindFirstChild("Enraged")
		if enr and enr:IsA("BoolValue") and enr.Value == true then
			return CIRCLE_ENRAGED_ID
		end
		return BASE_IDS.Circle
	end
	if tname == "Thavel" then
		return BASE_IDS.Thavel
	end
	-- Alices
	if tname == "Alice" then
		return BASE_IDS.Alice
	end
	if tname == "AlicePhase2" then
		return BASE_IDS.AlicePhase2
	end
	return nil
end

-- Create BillboardGui and attach to head
local function createBillboardFor(model, targetFolderName)
	if not model or not targetFolderName then return end
	-- respect limits
	if targetFolderName == "Teachers" and ActiveCounts.Teachers >= MAX.Teachers then
		return nil, "limit_reached"
	end
	if targetFolderName == "Alices" and ActiveCounts.Alices >= MAX.Alices then
		return nil, "limit_reached"
	end

	local head = getRealHead(model)
	if not head then return nil, "no_head" end
	local imageId = getImageIdForModel(model)
	if not imageId then return nil, "no_image" end

	-- Avoid duplicate
	if ActiveBillboards[model] and ActiveBillboards[model].gui and ActiveBillboards[model].gui.Parent then
		return ActiveBillboards[model].gui, "exists"
	end

	-- Billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "RoleBillboardGui"
	bb.Size = BILLBOARD_SIZE
	bb.StudsOffset = STUDS_OFFSET
	bb.AlwaysOnTop = true
	-- Parent to head ensures it follows; safe pattern
	bb.Parent = head

	local img = Instance.new("ImageLabel")
	img.Name = "RoleImage"
	img.Size = UDim2.new(1,0,1,0)
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = "rbxassetid://" .. tostring(imageId)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	ActiveBillboards[model] = { gui = bb, folder = targetFolderName, model = model }

	if targetFolderName == "Teachers" then
		ActiveCounts.Teachers = ActiveCounts.Teachers + 1
	elseif targetFolderName == "Alices" then
		ActiveCounts.Alices = ActiveCounts.Alices + 1
	end

	return bb, "created"
end

-- Destroy billboard cleanly and update counts
local function destroyBillboard(model)
	local data = ActiveBillboards[model]
	if not data then return end
	local folder = data.folder
	local gui = data.gui
	if gui and gui.Parent then
		gui:Destroy()
	end
	ActiveBillboards[model] = nil
	if folder == "Teachers" then
		ActiveCounts.Teachers = math.max(0, ActiveCounts.Teachers - 1)
	elseif folder == "Alices" then
		ActiveCounts.Alices = math.max(0, ActiveCounts.Alices - 1)
	end
end

-- Decide whether local should see this model based on local folder
local function shouldLocalSeeModel(localFolderName, targetFolderName, model)
	if not localFolderName or not targetFolderName then return false end
	-- don't show same-folder or self
	if model.Name == LocalPlayer.Name then return false end
	if localFolderName == "Teachers" then
		return targetFolderName == "Alices"
	elseif localFolderName == "Alices" then
		return targetFolderName == "Teachers"
	elseif localFolderName == "Students" then
		return targetFolderName == "Alices" or targetFolderName == "Teachers"
	end
	return false
end

-- Detect where local player is
local function detectLocalFolder()
	for name, folder in pairs(Folders) do
		if folder:FindFirstChild(LocalPlayer.Name) then
			return name
		end
	end
	return nil
end

-- Clean up billboards for models no longer valid or no longer visible
local function sweepInvalids(localFolderName)
	for model, data in pairs(ActiveBillboards) do
		if not model or not model.Parent then
			destroyBillboard(model)
			continue
		end
		local targetFolder = getModelFolderName(model)
		if not shouldLocalSeeModel(localFolderName, targetFolder, model) then
			destroyBillboard(model)
			continue
		end
		-- check head exists
		if not getRealHead(model) then
			destroyBillboard(model)
			continue
		end
	end
end

-- Scan folder and create billboards when allowed
local function scanAndApply(localFolderName)
	if not localFolderName then return end
	-- For each candidate folder
	for _, folderName in ipairs({"Alices", "Teachers"}) do
		local folder = Folders[folderName]
		if not folder then return end
		for _, model in ipairs(folder:GetChildren()) do
			if not model:IsA("Model") then
				-- ensure no leftover
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end
			-- skip self and same-folder rules
			if model.Name == LocalPlayer.Name then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end
			if not shouldLocalSeeModel(localFolderName, folderName, model) then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end

			-- Only create if head exists and image id exists
			local head = getRealHead(model)
			if not head then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end

			-- Respect max counts
			if folderName == "Teachers" and ActiveCounts.Teachers >= MAX.Teachers then
				-- if already exists keep it, otherwise skip
				if not ActiveBillboards[model] then
					-- skip creation
					continue
				end
			end
			if folderName == "Alices" and ActiveCounts.Alices >= MAX.Alices then
				if not ActiveBillboards[model] then
					continue
				end
			end

			-- Create or update image if needed
			local id = getImageIdForModel(model)
			if not id then
				if ActiveBillboards[model] then destroyBillboard(model) end
				continue
			end

			local bb = ActiveBillboards[model] and ActiveBillboards[model].gui or nil
			if not bb then
				createBillboardFor(model, folderName)
			else
				-- update image if TeacherName / Enraged changed
				local img = bb:FindFirstChild("RoleImage")
				if img and img.Image ~= ("rbxassetid://"..tostring(id)) then
					img.Image = "rbxassetid://"..tostring(id)
				end
			end
		end
	end
	-- cleanup any billboards that are now invalid
	sweepInvalids(localFolderName)
end

-- Distance-based enable/disable
RunService.Heartbeat:Connect(function()
	local localChar = LocalPlayer.Character
	local myHead = localChar and getRealHead(localChar)
	if not myHead then return end
	local ok, myPos = pcall(function() return myHead.Position end)
	if not ok then return end

	for model, data in pairs(ActiveBillboards) do
		local gui = data.gui
		if not gui or not gui.Parent then
			destroyBillboard(model)
			continue
		end
		local targetHead = getRealHead(model)
		if not targetHead then
			destroyBillboard(model)
			continue
		end
		local succ, dist = pcall(function() return (targetHead.Position - myPos).Magnitude end)
		if succ and type(dist) == "number" then
			gui.Enabled = dist <= MAX_RENDER_DISTANCE
		else
			gui.Enabled = false
		end
	end
end)

-- Watch individual model attribute changes (TeacherName, Enraged) to update
local function hookModelSignals(model)
	if not model or not model:IsA("Model") then return end
	-- Avoid hooking twice
	if model:FindFirstChild("__RoleHooked") then return end
	local marker = Instance.new("BoolValue")
	marker.Name = "__RoleHooked"
	marker.Value = true
	marker.Parent = model

	-- Attribute change: TeacherName
	model:GetAttributeChangedSignal("TeacherName"):Connect(function()
		-- if TeacherName removed or changed, destroy existing billboard to re-evaluate
		if ActiveBillboards[model] then
			destroyBillboard(model)
		end
		-- schedule quick rescan
		task.defer(function()
			local localFolder = detectLocalFolder()
			scanAndApply(localFolder)
		end)
	end)

	-- If Enraged exists as BoolValue we watch it
	local function watchEnragedBool()
		local ev = model:FindFirstChild("Enraged")
		if ev and ev:IsA("BoolValue") then
			ev.Changed:Connect(function()
				if ActiveBillboards[model] then
					-- update image id
					local bb = ActiveBillboards[model].gui
					if bb then
						local img = bb:FindFirstChild("RoleImage")
						local id = getImageIdForModel(model)
						if img and id then img.Image = "rbxassetid://"..tostring(id) end
					end
				end
			end)
		end
	end
	watchEnragedBool()
	-- watch for Enraged child added later
	model.ChildAdded:Connect(function(child)
		if child.Name == "Enraged" then
			watchEnragedBool()
		end
	end)

	-- Clean hook on model removal
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			destroyBillboard(model)
		end
	end)
end

-- Hook existing models in folders
local function hookFolder(folder)
	if not folder then return end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") then
			hookModelSignals(m)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			hookModelSignals(child)
			-- immediate re-evaluate creation
			task.defer(function()
				local localFolder = detectLocalFolder()
				scanAndApply(localFolder)
			end)
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if ActiveBillboards[child] then destroyBillboard(child) end
	end)
end

-- Hook all three folders
for _, folder in pairs(Folders) do
	hookFolder(folder)
end

-- Main periodic scanner that enforces rules and limits
task.spawn(function()
	while task.wait(CHECK_INTERVAL) do
		local localFolder = detectLocalFolder()
		if localFolder ~= "Students" then
			-- If not Students, ensure all billboards removed
			for model, _ in pairs(ActiveBillboards) do
				destroyBillboard(model)
			end
			-- do nothing until local enters Students
		else
			-- run scan
			scanAndApply(localFolder)
		end
	end
end)

-- Also run a quick scan once on start
task.defer(function()
	local localFolder = detectLocalFolder()
	if localFolder == "Students" then
		scanAndApply(localFolder)
	end
end)
