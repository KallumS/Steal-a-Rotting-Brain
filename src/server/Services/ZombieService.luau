--[[
	ZombieService
	Everyone in this game is a zombie: green, slow-ish, and easy to spot
	when they are hauling someone else's brain around. This service owns
	character appearance, movement speed and overhead nametags.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local ZombieService = {}

local nametags: { [Player]: any } = {}
local stunnedUntil: { [Player]: number } = {}

local function applyZombieLook(character: Model)
	local skin = Config.Zombie.SkinColor

	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end

	bodyColors.HeadColor3 = skin
	bodyColors.TorsoColor3 = skin:Lerp(Color3.new(0, 0, 0), 0.15)
	bodyColors.LeftArmColor3 = skin
	bodyColors.RightArmColor3 = skin
	bodyColors.LeftLegColor3 = skin:Lerp(Color3.new(0, 0, 0), 0.25)
	bodyColors.RightLegColor3 = skin:Lerp(Color3.new(0, 0, 0), 0.25)
end

local function buildNametag(self: any, player: Player, character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZombieTag"
	billboard.Adornee = head
	billboard.Size = UDim2.fromScale(10, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 140
	billboard.LightInfluence = 0
	billboard.Parent = head

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.42)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.Text = player.DisplayName
	name.TextColor3 = Color3.fromRGB(180, 235, 170)
	name.TextStrokeTransparency = 0.4
	name.Parent = billboard

	local rebirth = Instance.new("TextLabel")
	rebirth.Name = "Rebirth"
	rebirth.BackgroundTransparency = 1
	rebirth.Position = UDim2.fromScale(0, 0.42)
	rebirth.Size = UDim2.fromScale(1, 0.28)
	rebirth.Font = Enum.Font.Gotham
	rebirth.TextScaled = true
	rebirth.Text = ""
	rebirth.TextColor3 = Color3.fromRGB(200, 160, 255)
	rebirth.TextStrokeTransparency = 0.5
	rebirth.Parent = billboard

	local carry = Instance.new("TextLabel")
	carry.Name = "Carrying"
	carry.BackgroundTransparency = 1
	carry.Position = UDim2.fromScale(0, 0.7)
	carry.Size = UDim2.fromScale(1, 0.3)
	carry.Font = Enum.Font.LuckiestGuy
	carry.TextScaled = true
	carry.Text = ""
	carry.TextColor3 = Color3.fromRGB(255, 140, 140)
	carry.TextStrokeTransparency = 0.35
	carry.Visible = false
	carry.Parent = billboard

	nametags[player] = { Billboard = billboard, Name = name, Rebirth = rebirth, Carry = carry }
	self:RefreshNametag(player)
end

function ZombieService:RefreshNametag(player: Player)
	local tag = nametags[player]
	if not tag then
		return
	end

	local profile = self.Services.DataService:Get(player)
	local rebirths = profile and profile.Rebirths or 0
	tag.Rebirth.Text = rebirths > 0 and `Rebirth {rebirths}` or ""
end

function ZombieService:SetCarrying(player: Player, brainName: string?)
	local tag = nametags[player]
	if not tag then
		return
	end

	if brainName then
		tag.Carry.Text = `CARRYING: {brainName}`
		tag.Carry.Visible = true
	else
		tag.Carry.Text = ""
		tag.Carry.Visible = false
	end
end

--------------------------------------------------------------------
-- Movement
--------------------------------------------------------------------

function ZombieService:IsStunned(player: Player): boolean
	return (stunnedUntil[player] or 0) > os.clock()
end

function ZombieService:RefreshSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if self:IsStunned(player) then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end

	local speed = Config.Zombie.WalkSpeed
	if self.Services.StealService:IsCarrying(player) then
		speed *= Config.Steal.CarrySpeedMultiplier
	end

	humanoid.WalkSpeed = speed
	humanoid.JumpPower = Config.Zombie.JumpPower
end

function ZombieService:Stun(player: Player, duration: number)
	stunnedUntil[player] = os.clock() + duration
	self:RefreshSpeed(player)

	task.delay(duration + 0.05, function()
		if not self:IsStunned(player) then
			self:RefreshSpeed(player)
		end
	end)
end

--------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------

function ZombieService:Init() end

function ZombieService:Start()
	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end

		humanoid.UseJumpPower = true
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

		applyZombieLook(character)
		buildNametag(self, player, character)
		self:RefreshSpeed(player)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(onCharacter, player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		nametags[player] = nil
		stunnedUntil[player] = nil
	end)

	self.Services.DataService.ProfileLoaded:Connect(function(player)
		self:RefreshNametag(player)
	end)
end

return ZombieService
