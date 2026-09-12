--[[
	BrainFactory
	Builds the rotting brain models out of primitives so the project
	needs no imported art assets. A brain is a Model whose PrimaryPart
	is "Core"; every other part is welded to it, and the whole thing
	carries its identity in attributes so any script can read it.
]]

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)
local Tags = require(script.Parent.Tags)

local BrainFactory = {}

export type BrainRecord = {
	Uid: string,
	BrainId: string,
	VariantId: string,
	ColorIndex: number,
	Model: Model?,
}

local LOBE_OFFSETS = {
	Vector3.new(-0.95, 0.35, -0.35),
	Vector3.new(0.95, 0.35, -0.35),
	Vector3.new(-0.9, 0.15, 0.6),
	Vector3.new(0.9, 0.15, 0.6),
	Vector3.new(0, 0.85, 0.1),
}

-- "Rainbow Gurglini Grotesko" / "Mossy Gurglini Grotesko"
function BrainFactory.GetDisplayName(record: BrainRecord): string
	local brain = Config.GetBrain(record.BrainId)
	if not brain then
		return "Unknown Brain"
	end

	local variant = Config.GetVariant(record.VariantId)
	if variant.Prefix then
		return `{variant.Prefix} {brain.Name}`
	end

	local palette = Config.StandardColors[record.ColorIndex]
	if palette then
		return `{palette.Name} {brain.Name}`
	end
	return brain.Name
end

-- Body colour: variants override the rolled rotten colour.
function BrainFactory.GetColor(record: BrainRecord): Color3
	local variant = Config.GetVariant(record.VariantId)
	if variant.Color then
		return variant.Color
	end
	if variant.Animated then
		return Color3.fromHSV(0.33, 0.6, 1)
	end

	local palette = Config.StandardColors[record.ColorIndex] or Config.StandardColors[1]
	return palette.Color
end

local function makePart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weldTo(core: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = core
	weld.Part1 = part
	weld.Parent = part
end

local function buildLabel(core: BasePart, record: BrainRecord, scale: number)
	local brain = Config.GetBrain(record.BrainId)
	local rarity = Config.GetRarity(brain and brain.Rarity or "Common")
	local variant = Config.GetVariant(record.VariantId)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromScale(8, 2.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.1 * scale + 1, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 90
	billboard.Parent = core

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.58)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.Text = BrainFactory.GetDisplayName(record)
	title.TextColor3 = variant.LabelColor or rarity.Color
	title.TextStrokeTransparency = 0.2
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.Parent = billboard

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromScale(0, 0.58)
	subtitle.Size = UDim2.fromScale(1, 0.42)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextScaled = true
	subtitle.Text = `{Format.Cash(Config.BrainIncome(record.BrainId, record.VariantId))}/s  •  {brain and brain.Rarity or "?"}`
	subtitle.TextColor3 = rarity.Color
	subtitle.TextStrokeTransparency = 0.35
	subtitle.TextStrokeColor3 = Color3.new(0, 0, 0)
	subtitle.Parent = billboard
end

--[[
	Create the model for a record. The model is returned unparented and
	fully anchored; callers decide where it lives.
]]
function BrainFactory.Create(record: BrainRecord): Model
	local brain = Config.GetBrain(record.BrainId)
	assert(brain, `cannot build unknown brain "{record.BrainId}"`)

	local variant = Config.GetVariant(record.VariantId)
	local rarity = Config.GetRarity(brain.Rarity)
	local scale = brain.Scale or 1
	local color = BrainFactory.GetColor(record)

	local model = Instance.new("Model")
	model.Name = BrainFactory.GetDisplayName(record)

	local core = makePart("Core", model)
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * (3.4 * scale)
	core.Color = color
	core.Material = variant.Material or Enum.Material.Mud
	model.PrimaryPart = core

	-- Wrinkly lobes give the sphere a brain-ish silhouette.
	for index, offset in ipairs(LOBE_OFFSETS) do
		local lobe = makePart("Lobe" .. index, model)
		lobe.Shape = Enum.PartType.Ball
		lobe.Size = Vector3.one * (1.9 * scale)
		lobe.Color = color
		lobe.Material = core.Material
		lobe.CFrame = core.CFrame * CFrame.new(offset * scale * 1.25)
		weldTo(core, lobe)
	end

	-- Brain stem, so it reads the right way up on a podium.
	local stem = makePart("Stem", model)
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(1.5 * scale, 1.1 * scale, 1.1 * scale)
	stem.Color = color:Lerp(Color3.fromRGB(90, 60, 60), 0.45)
	stem.Material = Enum.Material.Mud
	stem.CFrame = core.CFrame * CFrame.new(0, -1.6 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
	weldTo(core, stem)

	-- Chase variants glow; the rainbow hue itself is animated clientside.
	if variant.Glow then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = variant.Glow
		light.Brightness = 2.5
		light.Range = 14
		light.Shadows = false
		light.Parent = core
	end

	buildLabel(core, record, scale)

	model:SetAttribute("Uid", record.Uid)
	model:SetAttribute("BrainId", record.BrainId)
	model:SetAttribute("VariantId", record.VariantId)
	model:SetAttribute("ColorIndex", record.ColorIndex)
	model:SetAttribute("Rarity", brain.Rarity)
	model:SetAttribute("RarityColor", rarity.Color)
	model:SetAttribute("Income", Config.BrainIncome(record.BrainId, record.VariantId))
	model:SetAttribute("Price", Config.BrainPrice(record.BrainId, record.VariantId))

	CollectionService:AddTag(model, Tags.Brain)
	if variant.Animated then
		CollectionService:AddTag(model, Tags.AnimatedBrain)
	end

	return model
end

-- Anchor/unanchor every part at once (carried brains must be unanchored
-- so the weld to the carrier's head can move them).
function BrainFactory.SetAnchored(model: Model, anchored: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
		end
	end
end

return BrainFactory
