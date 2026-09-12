--[[
	Config
	------------------------------------------------------------------
	Every tunable number and every piece of content for
	"Steal a Rotting Brain" lives in this module. Servers and clients
	both read it, so keep it free of side effects.
]]

local Config = {}

Config.GameName = "Steal a Rotting Brain"

Config.Currency = {
	Name = "Cash",
	Symbol = "$",
	StartingCash = 250,
}

Config.Economy = {
	IncomeInterval = 1, -- seconds between passive payouts
	AutosaveInterval = 120,
}

-- Graveyards (player bases).
Config.Plot = {
	Count = 8, -- number of graveyards built into the world
	Size = 64, -- floor is Size x Size studs
	Spacing = 72, -- distance between plot centres along the row
	SideOffset = 80, -- distance from the conveyor to a plot centre
	WallHeight = 8,
	EntranceWidth = 18,
	SlotsPerRow = 4,
	Rows = 2,
	RowSpacing = 18,
	SlotSpacing = 14,
	BoundsPadding = 3, -- shrink the "am I home?" test by this many studs
}

-- The central conveyor belt that brains ride in on.
Config.Conveyor = {
	Length = 120,
	Width = 9,
	Height = 3, -- height of the belt surface
	LaneHeight = 5.5, -- height brains float at
	Speed = 6, -- studs per second
	SpawnInterval = 4,
	MaxOnBelt = 8,
	PromptDistance = 14,
}

-- Stealing from other graveyards.
Config.Steal = {
	HoldDuration = 6, -- how long a thief must hold the prompt
	MaxActivationDistance = 12,
	CarrySpeedMultiplier = 0.7,
	RequireFreeSlot = true, -- thieves need somewhere to put it first
	ReturnOnDeath = true,
}

-- Graveyard gates.
Config.Lock = {
	BaseDuration = 30,
	DurationPerRebirth = 6,
	MaxDuration = 120,
	Cooldown = 60, -- wait after a lock ends before locking again
}

-- Selling a brain back, so a full graveyard is never a dead end.
Config.Scrap = {
	RefundRatio = 0.25,
	HoldDuration = 2,
}

-- Zombie melee used to bounce thieves.
Config.Combat = {
	Range = 11,
	Cooldown = 1.25,
	StunDuration = 3,
	FacingDot = 0.25, -- how far in front of the attacker the thief must be
}

Config.Rebirth = {
	BaseRequirement = 1e6,
	RequirementGrowth = 4, -- requirement = Base * Growth ^ rebirths
	IncomeMultiplierPerRebirth = 0.25,
	MaxRebirths = 20,
}

Config.Zombie = {
	WalkSpeed = 18,
	JumpPower = 48,
	SkinColor = Color3.fromRGB(118, 148, 96),
}

--[[
	Rarities. The rarity of a brain drives its spawn weight plus the
	colour of its label, aura and podium glow.
]]
Config.Rarities = {
	Common = { Order = 1, Weight = 1000, Color = Color3.fromRGB(178, 178, 178) },
	Uncommon = { Order = 2, Weight = 520, Color = Color3.fromRGB(96, 204, 112) },
	Rare = { Order = 3, Weight = 240, Color = Color3.fromRGB(72, 144, 255) },
	Epic = { Order = 4, Weight = 100, Color = Color3.fromRGB(172, 94, 255) },
	Legendary = { Order = 5, Weight = 34, Color = Color3.fromRGB(255, 172, 44) },
	Mythic = { Order = 6, Weight = 10, Color = Color3.fromRGB(255, 74, 96) },
	Godly = { Order = 7, Weight = 3, Color = Color3.fromRGB(255, 242, 138) },
	Secret = { Order = 8, Weight = 1, Color = Color3.fromRGB(46, 46, 52) },
}

--[[
	Variants. Standard brains come in the rotten colour palette below,
	while Gold and Rainbow brains are the chase items.
]]
Config.Variants = {
	{
		Id = "Standard",
		Weight = 1000,
		IncomeMultiplier = 1,
		PriceMultiplier = 1,
		Prefix = nil,
		Material = Enum.Material.Mud,
		LabelColor = Color3.fromRGB(228, 228, 228),
	},
	{
		Id = "Gold",
		Weight = 45,
		IncomeMultiplier = 3,
		PriceMultiplier = 4,
		Prefix = "Gold",
		Material = Enum.Material.Foil,
		Color = Color3.fromRGB(255, 198, 46),
		LabelColor = Color3.fromRGB(255, 208, 74),
		Glow = Color3.fromRGB(255, 186, 40),
	},
	{
		Id = "Rainbow",
		Weight = 10,
		IncomeMultiplier = 8,
		PriceMultiplier = 12,
		Prefix = "Rainbow",
		Material = Enum.Material.Neon,
		LabelColor = Color3.fromRGB(255, 255, 255),
		Glow = Color3.fromRGB(255, 255, 255),
		Animated = true, -- client cycles the hue
	},
}

-- Standard-quality brains roll one of these rotten colours.
Config.StandardColors = {
	{ Name = "Mossy", Color = Color3.fromRGB(122, 148, 92) },
	{ Name = "Bruised", Color = Color3.fromRGB(126, 96, 152) },
	{ Name = "Fleshy", Color = Color3.fromRGB(196, 118, 124) },
	{ Name = "Bloated", Color = Color3.fromRGB(150, 170, 175) },
	{ Name = "Bile", Color = Color3.fromRGB(186, 176, 80) },
	{ Name = "Tar", Color = Color3.fromRGB(86, 78, 84) },
	{ Name = "Frostbitten", Color = Color3.fromRGB(120, 176, 196) },
	{ Name = "Infected", Color = Color3.fromRGB(190, 96, 60) },
}

--[[
	The brains themselves. Price is what you pay on the conveyor at
	standard quality; Income is cash per second at standard quality.
	Variant multipliers are applied on top of both.
]]
Config.Brains = {
	{ Id = "gurglini", Name = "Gurglini Grotesko", Rarity = "Common", Price = 100, Income = 2, Scale = 0.85 },
	{ Id = "squishini", Name = "Squishini Splatto", Rarity = "Common", Price = 260, Income = 4.5, Scale = 0.9 },
	{ Id = "moldini", Name = "Moldini Mushroomo", Rarity = "Uncommon", Price = 780, Income = 11, Scale = 0.95 },
	{ Id = "crunchini", Name = "Cranium Crunchini", Rarity = "Uncommon", Price = 1600, Income = 20, Scale = 1 },
	{ Id = "zombino", Name = "Zombino Cerebrello", Rarity = "Rare", Price = 4200, Income = 46, Scale = 1.05 },
	{ Id = "maggoto", Name = "Maggoto Munchoso", Rarity = "Rare", Price = 8800, Income = 84, Scale = 1.1 },
	{ Id = "noodlini", Name = "Necro Noodlini", Rarity = "Epic", Price = 21000, Income = 175, Scale = 1.15 },
	{ Id = "frontalis", Name = "Fungus Frontalis", Rarity = "Epic", Price = 46000, Income = 330, Scale = 1.2 },
	{ Id = "skullini", Name = "Skullini Supremo", Rarity = "Legendary", Price = 125000, Income = 800, Scale = 1.3 },
	{ Id = "parietale", Name = "Putrido Parietale", Rarity = "Legendary", Price = 270000, Income = 1550, Scale = 1.35 },
	{ Id = "gargantuano", Name = "Grave Gargantuano", Rarity = "Mythic", Price = 620000, Income = 3300, Scale = 1.5 },
	{ Id = "cataclysmo", Name = "Cortex Cataclysmo", Rarity = "Mythic", Price = 1450000, Income = 7200, Scale = 1.55 },
	{ Id = "lobotomini", Name = "Lord Lobotomini", Rarity = "Godly", Price = 4200000, Income = 19000, Scale = 1.75 },
	{ Id = "behemothra", Name = "Brainrot Behemothra", Rarity = "Godly", Price = 12500000, Income = 52000, Scale = 1.85 },
	{ Id = "bigrotto", Name = "The Big Rotto", Rarity = "Secret", Price = 40000000, Income = 190000, Scale = 2.1 },
}

--------------------------------------------------------------------
-- Derived lookups
--------------------------------------------------------------------

Config.BrainsById = {}
for _, brain in ipairs(Config.Brains) do
	assert(Config.Rarities[brain.Rarity], `brain "{brain.Id}" has unknown rarity "{brain.Rarity}"`)
	assert(not Config.BrainsById[brain.Id], `duplicate brain id "{brain.Id}"`)
	Config.BrainsById[brain.Id] = brain
end

Config.VariantsById = {}
for _, variant in ipairs(Config.Variants) do
	Config.VariantsById[variant.Id] = variant
end

Config.SlotCount = Config.Plot.SlotsPerRow * Config.Plot.Rows

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------

function Config.GetBrain(brainId: string)
	return Config.BrainsById[brainId]
end

function Config.GetVariant(variantId: string?)
	return Config.VariantsById[variantId or "Standard"] or Config.VariantsById.Standard
end

function Config.GetRarity(rarityName: string)
	return Config.Rarities[rarityName] or Config.Rarities.Common
end

-- Cash needed for the player's next rebirth.
function Config.RebirthRequirement(rebirths: number): number
	return Config.Rebirth.BaseRequirement * Config.Rebirth.RequirementGrowth ^ rebirths
end

-- Permanent income multiplier earned from rebirths.
function Config.IncomeMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.IncomeMultiplierPerRebirth
end

-- How long a graveyard gate stays shut, which grows with rebirths.
function Config.LockDuration(rebirths: number): number
	local duration = Config.Lock.BaseDuration + rebirths * Config.Lock.DurationPerRebirth
	return math.min(duration, Config.Lock.MaxDuration)
end

-- Price of a specific brain + variant combination on the conveyor.
function Config.BrainPrice(brainId: string, variantId: string?): number
	local brain = Config.GetBrain(brainId)
	if not brain then
		return math.huge
	end
	return math.floor(brain.Price * Config.GetVariant(variantId).PriceMultiplier + 0.5)
end

-- What scrapping a brain pays back.
function Config.BrainScrapValue(brainId: string, variantId: string?): number
	return math.floor(Config.BrainPrice(brainId, variantId) * Config.Scrap.RefundRatio)
end

-- Cash per second a specific brain + variant combination generates.
function Config.BrainIncome(brainId: string, variantId: string?): number
	local brain = Config.GetBrain(brainId)
	if not brain then
		return 0
	end
	return brain.Income * Config.GetVariant(variantId).IncomeMultiplier
end

return Config
