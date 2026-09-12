--[[
	WorldBuilder
	Generates the entire map from primitives: the graveyard plots,
	the central conveyor, the rebirth crypt, the leaderboard and the
	spawn gates. Geometry only -- behaviour (prompts, timers, income)
	is owned by the gameplay services, which read the descriptors this
	module exposes.
]]

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)
local Tags = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Tags)

local CollectionService = game:GetService("CollectionService")

local WorldBuilder = {}

WorldBuilder.Plots = {} :: { any }
WorldBuilder.Conveyor = nil :: any
WorldBuilder.Shrine = nil :: any
WorldBuilder.Leaderboard = nil :: any

local DIRT = Color3.fromRGB(74, 64, 52)
local STONE = Color3.fromRGB(108, 110, 114)
local DARK_STONE = Color3.fromRGB(62, 64, 68)
local GRASS = Color3.fromRGB(58, 74, 52)
local METAL = Color3.fromRGB(78, 82, 88)
local RUST = Color3.fromRGB(122, 74, 52)

local MAP_WIDTH = 320
local MAP_LENGTH = 360

local function newPart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function newLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextStrokeTransparency = 0.5
	for key, value in pairs(props) do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function newSurfaceGui(adornee: BasePart, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui
end

--------------------------------------------------------------------
-- Ground and perimeter
--------------------------------------------------------------------

local function buildGround(root: Folder)
	newPart(root, {
		Name = "Ground",
		Size = Vector3.new(MAP_WIDTH, 4, MAP_LENGTH),
		CFrame = CFrame.new(0, -2, 0),
		Color = GRASS,
		Material = Enum.Material.LeafyGrass,
	})

	-- Plaza floor down the middle, where the conveyor sits.
	newPart(root, {
		Name = "Plaza",
		Size = Vector3.new(90, 1, MAP_LENGTH - 20),
		CFrame = CFrame.new(0, 0.02, 0),
		Color = Color3.fromRGB(66, 62, 58),
		Material = Enum.Material.Cobblestone,
	})

	local walls = Instance.new("Folder")
	walls.Name = "Perimeter"
	walls.Parent = root

	local halfWidth = MAP_WIDTH / 2 - 2
	local halfLength = MAP_LENGTH / 2 - 2

	for _, spec in
		ipairs({
			{ Vector3.new(4, 30, MAP_LENGTH), CFrame.new(-halfWidth, 14, 0) },
			{ Vector3.new(4, 30, MAP_LENGTH), CFrame.new(halfWidth, 14, 0) },
			{ Vector3.new(MAP_WIDTH, 30, 4), CFrame.new(0, 14, -halfLength) },
			{ Vector3.new(MAP_WIDTH, 30, 4), CFrame.new(0, 14, halfLength) },
		})
	do
		newPart(walls, {
			Name = "Wall",
			Size = spec[1],
			CFrame = spec[2],
			Color = DARK_STONE,
			Material = Enum.Material.Slate,
		})
	end
end

--------------------------------------------------------------------
-- Spawn gates
--------------------------------------------------------------------

local function buildSpawn(root: Folder)
	local model = Instance.new("Model")
	model.Name = "SpawnGates"
	model.Parent = root

	local pad = Instance.new("SpawnLocation")
	pad.Name = "ZombieSpawn"
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 0
	pad.Size = Vector3.new(22, 1, 22)
	pad.CFrame = CFrame.new(0, 0.5, -130)
	pad.Color = DARK_STONE
	pad.Material = Enum.Material.Concrete
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Parent = model

	for _, x in ipairs({ -12, 12 }) do
		newPart(model, {
			Name = "GatePost",
			Size = Vector3.new(3, 22, 3),
			CFrame = CFrame.new(x, 11, -130),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	end

	local beam = newPart(model, {
		Name = "GateSign",
		Size = Vector3.new(27, 6, 1.5),
		CFrame = CFrame.new(0, 20, -130) * CFrame.Angles(0, math.rad(180), 0),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	})

	local gui = newSurfaceGui(beam, Enum.NormalId.Front)
	newLabel(gui, {
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		Text = "ROTHOLLOW CEMETERY",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(150, 220, 140),
	})
end

--------------------------------------------------------------------
-- Conveyor
--------------------------------------------------------------------

local function buildConveyor(root: Folder)
	local settings = Config.Conveyor
	local model = Instance.new("Model")
	model.Name = "Conveyor"
	model.Parent = root

	local belt = newPart(model, {
		Name = "Belt",
		Size = Vector3.new(settings.Width, settings.Height, settings.Length),
		CFrame = CFrame.new(0, settings.Height / 2, 0),
		Color = METAL,
		Material = Enum.Material.DiamondPlate,
	})
	CollectionService:AddTag(belt, Tags.Conveyor)
	model.PrimaryPart = belt

	-- Alternating slats to sell the sense of movement.
	local slatCount = math.floor(settings.Length / 6)
	for index = 1, slatCount do
		local z = -settings.Length / 2 + 3 + (index - 1) * 6
		newPart(model, {
			Name = "Slat",
			Size = Vector3.new(settings.Width - 0.8, 0.3, 4),
			CFrame = CFrame.new(0, settings.Height + 0.15, z),
			Color = index % 2 == 0 and Color3.fromRGB(58, 62, 66) or Color3.fromRGB(96, 100, 104),
			Material = Enum.Material.Metal,
		})
	end

	--[[
		The belt is long enough to cut the plaza in half, so it gets two
		crossings: gaps in the rails with loading ramps either side, which
		players can walk up and over. Brains pass through them harmlessly
		because every brain part has collisions off.
	]]
	local crossings = { -22, 22 }
	local crossingHalfWidth = 4

	-- Rail runs, split around the crossings.
	local railRuns = {}
	do
		local cursor = -settings.Length / 2
		for _, crossingZ in ipairs(crossings) do
			table.insert(railRuns, { cursor, crossingZ - crossingHalfWidth })
			cursor = crossingZ + crossingHalfWidth
		end
		table.insert(railRuns, { cursor, settings.Length / 2 })
	end

	for _, side in ipairs({ -1, 1 }) do
		for _, run in ipairs(railRuns) do
			local length = run[2] - run[1]
			if length > 0.5 then
				newPart(model, {
					Name = "Rail",
					Size = Vector3.new(0.8, 1.8, length),
					CFrame = CFrame.new(
						side * (settings.Width / 2 + 0.4),
						settings.Height + 0.9,
						(run[1] + run[2]) / 2
					),
					Color = RUST,
					Material = Enum.Material.CorrodedMetal,
				})
			end
		end

		-- Two shallow steps up to the belt surface at each crossing.
		for _, crossingZ in ipairs(crossings) do
			for step, spec in ipairs({ { 12, 0.6 }, { 7, 1.5 } }) do
				newPart(model, {
					Name = `Crossing{step}`,
					Size = Vector3.new(5, spec[2] * 2, crossingHalfWidth * 2),
					CFrame = CFrame.new(side * spec[1], spec[2], crossingZ),
					Color = Color3.fromRGB(84, 88, 92),
					Material = Enum.Material.Concrete,
				})
			end
		end

		for leg = 0, math.floor(settings.Length / 20) do
			local z = -settings.Length / 2 + leg * 20
			newPart(model, {
				Name = "Leg",
				Size = Vector3.new(1.4, settings.Height, 1.4),
				CFrame = CFrame.new(side * 3.4, settings.Height / 2, z),
				Color = METAL,
				Material = Enum.Material.CorrodedMetal,
			})
		end
	end

	-- Delivery arch at the start of the belt.
	local archZ = -settings.Length / 2 - 5
	for _, side in ipairs({ -1, 1 }) do
		newPart(model, {
			Name = "ArchPost",
			Size = Vector3.new(2.5, 18, 2.5),
			CFrame = CFrame.new(side * 8, 9, archZ),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	end

	local archSign = newPart(model, {
		Name = "ArchSign",
		Size = Vector3.new(19, 5, 1.2),
		CFrame = CFrame.new(0, 16, archZ),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	})
	local archGui = newSurfaceGui(archSign, Enum.NormalId.Front)
	newLabel(archGui, {
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		Text = "FRESH ROT DELIVERY",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(230, 200, 120),
	})

	-- Incinerator at the end: unbought brains are scrapped here.
	local grinderZ = settings.Length / 2 + 5
	local grinder = newPart(model, {
		Name = "Incinerator",
		Size = Vector3.new(14, 10, 6),
		CFrame = CFrame.new(0, 5, grinderZ),
		Color = Color3.fromRGB(52, 42, 40),
		Material = Enum.Material.CorrodedMetal,
	})

	newPart(model, {
		Name = "IncineratorGlow",
		Size = Vector3.new(9, 5, 0.4),
		CFrame = CFrame.new(0, 4, grinderZ - 3.1),
		Color = Color3.fromRGB(255, 110, 40),
		Material = Enum.Material.Neon,
	})

	local grinderGui = newSurfaceGui(grinder, Enum.NormalId.Top)
	newLabel(grinderGui, {
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		Text = "SCRAP",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(255, 130, 70),
	})

	WorldBuilder.Conveyor = {
		Model = model,
		Belt = belt,
		StartPosition = Vector3.new(0, settings.LaneHeight, -settings.Length / 2),
		Direction = Vector3.new(0, 0, 1),
		Length = settings.Length,
	}
end

--------------------------------------------------------------------
-- Graveyard plots
--------------------------------------------------------------------

-- Where plot `index` sits, and which way it faces (always toward the belt).
function WorldBuilder.GetPlotCFrame(index: number): CFrame
	local plotConfig = Config.Plot
	local side = (index % 2 == 1) and -1 or 1
	local row = math.floor((index - 1) / 2)
	local rowCount = math.ceil(plotConfig.Count / 2)

	local x = side * plotConfig.SideOffset
	local z = (row - (rowCount - 1) / 2) * plotConfig.Spacing
	local yaw = side == -1 and -90 or 90

	return CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
end

-- Local offset of slot `slotIndex` inside a plot, front row first.
local function slotOffset(slotIndex: number): Vector3
	local plotConfig = Config.Plot
	local row = math.floor((slotIndex - 1) / plotConfig.SlotsPerRow)
	local column = (slotIndex - 1) % plotConfig.SlotsPerRow

	local x = (column - (plotConfig.SlotsPerRow - 1) / 2) * plotConfig.SlotSpacing
	local z = -4 + row * plotConfig.RowSpacing
	return Vector3.new(x, 0, z)
end

local function buildPodium(model: Model, plotCFrame: CFrame, slotIndex: number)
	local offset = slotOffset(slotIndex)

	local base = newPart(model, {
		Name = "Podium" .. slotIndex,
		Size = Vector3.new(7, 3, 7),
		CFrame = plotCFrame * CFrame.new(offset.X, 2.5, offset.Z),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	CollectionService:AddTag(base, Tags.Podium)

	local slab = newPart(model, {
		Name = "Slab" .. slotIndex,
		Size = Vector3.new(8, 0.7, 8),
		CFrame = plotCFrame * CFrame.new(offset.X, 4.35, offset.Z),
		Color = DARK_STONE,
		Material = Enum.Material.Marble,
	})

	-- Headstone behind the podium, purely for looks.
	newPart(model, {
		Name = "Headstone" .. slotIndex,
		Size = Vector3.new(5.5, 7, 1),
		CFrame = plotCFrame * CFrame.new(offset.X, 4.5, offset.Z + 4.6),
		Color = STONE,
		Material = Enum.Material.Slate,
	})

	local light = Instance.new("PointLight")
	light.Name = "SlotLight"
	light.Brightness = 0
	light.Range = 12
	light.Color = Color3.fromRGB(160, 255, 170)
	light.Shadows = false
	light.Parent = slab

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SlotLabel"
	billboard.Adornee = slab
	billboard.Size = UDim2.fromScale(7, 1.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.Parent = slab

	local label = newLabel(billboard, {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = `GRAVE {slotIndex}`,
		TextColor3 = Color3.fromRGB(140, 140, 140),
		TextTransparency = 0.25,
	})

	return {
		Index = slotIndex,
		Podium = base,
		Slab = slab,
		Light = light,
		Label = label,
		-- Brains are placed with their core centred here.
		Anchor = plotCFrame * CFrame.new(offset.X, 7.1, offset.Z),
	}
end

local function buildPlot(root: Folder, index: number)
	local plotConfig = Config.Plot
	local plotCFrame = WorldBuilder.GetPlotCFrame(index)
	local half = plotConfig.Size / 2
	local wallHeight = plotConfig.WallHeight

	local model = Instance.new("Model")
	model.Name = "Graveyard" .. index
	model.Parent = root

	local floor = newPart(model, {
		Name = "Floor",
		Size = Vector3.new(plotConfig.Size, 1, plotConfig.Size),
		CFrame = plotCFrame * CFrame.new(0, 0.5, 0),
		Color = DIRT,
		Material = Enum.Material.Ground,
	})
	model.PrimaryPart = floor

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = model

	-- Back and sides.
	newPart(walls, {
		Name = "Back",
		Size = Vector3.new(plotConfig.Size, wallHeight, 2),
		CFrame = plotCFrame * CFrame.new(0, wallHeight / 2 + 1, half - 1),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	})
	for _, side in ipairs({ -1, 1 }) do
		newPart(walls, {
			Name = "Side",
			Size = Vector3.new(2, wallHeight, plotConfig.Size),
			CFrame = plotCFrame * CFrame.new(side * (half - 1), wallHeight / 2 + 1, 0),
			Color = DARK_STONE,
			Material = Enum.Material.Slate,
		})
	end

	-- Front wall, split around the entrance.
	local segmentWidth = (plotConfig.Size - plotConfig.EntranceWidth) / 2
	for _, side in ipairs({ -1, 1 }) do
		newPart(walls, {
			Name = "Front",
			Size = Vector3.new(segmentWidth, wallHeight, 2),
			CFrame = plotCFrame
				* CFrame.new(side * (plotConfig.EntranceWidth / 2 + segmentWidth / 2), wallHeight / 2 + 1, -(half - 1)),
			Color = DARK_STONE,
			Material = Enum.Material.Slate,
		})
	end

	-- The gate: intangible and invisible until the owner locks up.
	local gate = newPart(model, {
		Name = "Gate",
		Size = Vector3.new(plotConfig.EntranceWidth, wallHeight, 1.5),
		CFrame = plotCFrame * CFrame.new(0, wallHeight / 2 + 1, -(half - 1)),
		Color = Color3.fromRGB(120, 255, 170),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
	})

	-- Sign above the entrance.
	local signPart = newPart(model, {
		Name = "Sign",
		Size = Vector3.new(22, 9, 1),
		CFrame = plotCFrame * CFrame.new(0, wallHeight + 5.5, -(half - 1)),
		Color = Color3.fromRGB(42, 44, 48),
		Material = Enum.Material.Slate,
	})

	local signGui = newSurfaceGui(signPart, Enum.NormalId.Front)
	local ownerLabel = newLabel(signGui, {
		Name = "Owner",
		Size = UDim2.fromScale(1, 0.38),
		Text = `GRAVEYARD {index}`,
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(150, 220, 140),
	})
	local incomeLabel = newLabel(signGui, {
		Name = "Income",
		Position = UDim2.fromScale(0, 0.38),
		Size = UDim2.fromScale(1, 0.24),
		Text = "$0/s",
		TextColor3 = Color3.fromRGB(220, 220, 220),
	})
	local brainsLabel = newLabel(signGui, {
		Name = "Brains",
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(1, 0.2),
		Text = `0 / {Config.SlotCount} brains`,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(180, 180, 180),
	})
	local statusLabel = newLabel(signGui, {
		Name = "Status",
		Position = UDim2.fromScale(0, 0.82),
		Size = UDim2.fromScale(1, 0.18),
		Text = "UNCLAIMED",
		TextColor3 = Color3.fromRGB(160, 160, 160),
	})

	-- Lock pad just inside the entrance.
	local lockPad = newPart(model, {
		Name = "LockPad",
		Size = Vector3.new(6, 1.2, 6),
		CFrame = plotCFrame * CFrame.new(12, 1.6, -(half - 6)),
		Color = Color3.fromRGB(120, 60, 60),
		Material = Enum.Material.Metal,
	})

	local lockLight = Instance.new("PointLight")
	lockLight.Name = "LockLight"
	lockLight.Brightness = 1.5
	lockLight.Range = 16
	lockLight.Color = Color3.fromRGB(255, 120, 120)
	lockLight.Shadows = false
	lockLight.Parent = lockPad

	local lockBillboard = Instance.new("BillboardGui")
	lockBillboard.Name = "LockLabel"
	lockBillboard.Adornee = lockPad
	lockBillboard.Size = UDim2.fromScale(8, 2)
	lockBillboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	lockBillboard.MaxDistance = 70
	lockBillboard.LightInfluence = 0
	lockBillboard.Parent = lockPad

	local lockLabel = newLabel(lockBillboard, {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = "GATE CONTROL",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(255, 170, 170),
	})

	local slots = {}
	for slotIndex = 1, Config.SlotCount do
		slots[slotIndex] = buildPodium(model, plotCFrame, slotIndex)
	end

	local descriptor = {
		Index = index,
		Model = model,
		CFrame = plotCFrame,
		Floor = floor,
		Gate = gate,
		LockPad = lockPad,
		LockLight = lockLight,
		LockLabel = lockLabel,
		Sign = {
			Part = signPart,
			Owner = ownerLabel,
			Income = incomeLabel,
			Brains = brainsLabel,
			Status = statusLabel,
		},
		Slots = slots,
	}

	model:SetAttribute("PlotIndex", index)
	WorldBuilder.Plots[index] = descriptor
end

--------------------------------------------------------------------
-- Rebirth crypt
--------------------------------------------------------------------

local function buildShrine(root: Folder)
	local model = Instance.new("Model")
	model.Name = "RebirthCrypt"
	model.Parent = root

	local origin = Vector3.new(0, 0, 95)

	newPart(model, {
		Name = "Base",
		Size = Vector3.new(26, 1.5, 26),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.75, 0)),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	})
	newPart(model, {
		Name = "Step",
		Size = Vector3.new(18, 1.5, 18),
		CFrame = CFrame.new(origin + Vector3.new(0, 2.25, 0)),
		Color = STONE,
		Material = Enum.Material.Marble,
	})

	local obelisk = newPart(model, {
		Name = "Obelisk",
		Size = Vector3.new(5, 16, 5),
		CFrame = CFrame.new(origin + Vector3.new(0, 11, 0)),
		Color = Color3.fromRGB(86, 52, 132),
		Material = Enum.Material.Neon,
	})
	model.PrimaryPart = obelisk

	local light = Instance.new("PointLight")
	light.Brightness = 4
	light.Range = 40
	light.Color = Color3.fromRGB(180, 120, 255)
	light.Shadows = false
	light.Parent = obelisk

	for _, corner in ipairs({ Vector3.new(-10, 0, -10), Vector3.new(10, 0, -10), Vector3.new(-10, 0, 10), Vector3.new(10, 0, 10) }) do
		newPart(model, {
			Name = "Pillar",
			Size = Vector3.new(2.5, 12, 2.5),
			CFrame = CFrame.new(origin + corner + Vector3.new(0, 7.5, 0)),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CryptLabel"
	billboard.Adornee = obelisk
	billboard.Size = UDim2.fromScale(16, 5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	billboard.MaxDistance = 160
	billboard.LightInfluence = 0
	billboard.Parent = obelisk

	local title = newLabel(billboard, {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.5),
		Text = "CRYPT OF REBIRTH",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(200, 150, 255),
	})
	local detail = newLabel(billboard, {
		Name = "Detail",
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		Text = "Requires $1M",
		TextColor3 = Color3.fromRGB(235, 235, 235),
	})

	WorldBuilder.Shrine = {
		Model = model,
		PromptPart = obelisk,
		Title = title,
		Detail = detail,
	}
end

--------------------------------------------------------------------
-- Leaderboard
--------------------------------------------------------------------

local function buildLeaderboard(root: Folder)
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	model.Parent = root

	local origin = Vector3.new(0, 0, -95)

	for _, x in ipairs({ -13, 13 }) do
		newPart(model, {
			Name = "Post",
			Size = Vector3.new(2, 20, 2),
			CFrame = CFrame.new(origin + Vector3.new(x, 10, 0)),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	end

	local board = newPart(model, {
		Name = "Board",
		Size = Vector3.new(28, 18, 1),
		CFrame = CFrame.new(origin + Vector3.new(0, 13, 0)) * CFrame.Angles(0, math.rad(180), 0),
		Color = Color3.fromRGB(34, 36, 40),
		Material = Enum.Material.Slate,
	})
	model.PrimaryPart = board

	local gui = newSurfaceGui(board, Enum.NormalId.Front)

	newLabel(gui, {
		Name = "Header",
		Size = UDim2.fromScale(1, 0.16),
		Text = "TOP ROT BARONS",
		Font = Enum.Font.LuckiestGuy,
		TextColor3 = Color3.fromRGB(150, 220, 140),
	})

	local rows = {}
	local rowHeight = 0.84 / 8
	for rank = 1, 8 do
		rows[rank] = newLabel(gui, {
			Name = "Row" .. rank,
			Position = UDim2.fromScale(0.04, 0.16 + (rank - 1) * rowHeight),
			Size = UDim2.fromScale(0.92, rowHeight),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(220, 220, 220),
		})
	end

	WorldBuilder.Leaderboard = {
		Model = model,
		Board = board,
		Rows = rows,
	}
end

--------------------------------------------------------------------
-- Scenery
--------------------------------------------------------------------

local function buildDecor(root: Folder)
	local model = Instance.new("Model")
	model.Name = "Scenery"
	model.Parent = root

	local random = Random.new(20260912)

	local function isBlocked(x: number, z: number): boolean
		if math.abs(x) < 10 and math.abs(z) < Config.Conveyor.Length / 2 + 14 then
			return true -- conveyor corridor
		end
		if math.abs(x) < 18 and math.abs(z - 95) < 18 then
			return true -- rebirth crypt
		end
		if math.abs(x) < 18 and math.abs(z + 95) < 18 then
			return true -- leaderboard
		end
		if math.abs(x) < 18 and math.abs(z + 130) < 18 then
			return true -- spawn
		end
		return false
	end

	local function pick(): (number?, number?)
		for _ = 1, 24 do
			local x = random:NextNumber(-44, 44)
			local z = random:NextNumber(-150, 150)
			if not isBlocked(x, z) then
				return x, z
			end
		end
		return nil
	end

	for _ = 1, 46 do
		local x, z = pick()
		if x and z then
			local yaw = random:NextNumber(0, math.pi * 2)
			local height = random:NextNumber(3.5, 6.5)
			newPart(model, {
				Name = "Tombstone",
				Size = Vector3.new(random:NextNumber(2.5, 4.5), height, 0.8),
				CFrame = CFrame.new(x, height / 2, z)
					* CFrame.Angles(0, yaw, math.rad(random:NextNumber(-7, 7))),
				Color = STONE:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.35)),
				Material = Enum.Material.Slate,
			})
		end
	end

	-- Dead trees along the outer strips, behind the plots.
	for _ = 1, 26 do
		local side = random:NextInteger(0, 1) == 0 and -1 or 1
		local x = side * random:NextNumber(118, 150)
		local z = random:NextNumber(-165, 165)
		local height = random:NextNumber(14, 24)

		newPart(model, {
			Name = "Trunk",
			Size = Vector3.new(2.2, height, 2.2),
			CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, random:NextNumber(0, 6), math.rad(random:NextNumber(-5, 5))),
			Color = Color3.fromRGB(58, 44, 36),
			Material = Enum.Material.Wood,
		})
		for _ = 1, 3 do
			newPart(model, {
				Name = "Branch",
				Size = Vector3.new(1, 0.9, random:NextNumber(4, 8)),
				CFrame = CFrame.new(x, height * random:NextNumber(0.55, 0.95), z)
					* CFrame.Angles(math.rad(random:NextNumber(-40, 10)), random:NextNumber(0, 6), 0)
					* CFrame.new(0, 0, -3),
				Color = Color3.fromRGB(58, 44, 36),
				Material = Enum.Material.Wood,
			})
		end
	end
end

--------------------------------------------------------------------

function WorldBuilder:Init()
	local existing = workspace:FindFirstChild("RottingWorld")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "RottingWorld"
	root.Parent = workspace

	buildGround(root)
	buildSpawn(root)
	buildConveyor(root)
	for index = 1, Config.Plot.Count do
		buildPlot(root, index)
	end
	buildShrine(root)
	buildLeaderboard(root)
	buildDecor(root)
end

function WorldBuilder:Start() end

return WorldBuilder
