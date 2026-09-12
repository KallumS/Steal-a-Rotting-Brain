--[[
	CombatService
	A zombie swipe. If it connects with someone hauling a stolen brain,
	the brain teleports back to the graveyard it was taken from and the
	thief is stunned long enough to regret it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CombatService = {}

local nextSwing: { [Player]: number } = {}

local function flash(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ClawFlash"
	highlight.FillColor = Color3.fromRGB(255, 70, 70)
	highlight.FillTransparency = 0.45
	highlight.OutlineColor = Color3.fromRGB(255, 200, 200)
	highlight.Parent = character

	task.delay(0.45, function()
		highlight:Destroy()
	end)
end

-- Closest carrier in front of the attacker, within claw range.
function CombatService:FindTarget(attacker: Player)
	local character = attacker.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local origin = root.Position
	local facing = root.CFrame.LookVector

	local best, bestDistance = nil, math.huge

	for player in pairs(self.Services.StealService:GetCarriers()) do
		if player ~= attacker then
			local targetCharacter = player.Character
			local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
			local humanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

			if targetRoot and targetRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local offset = targetRoot.Position - origin
				local distance = offset.Magnitude

				if distance <= Config.Combat.Range and distance < bestDistance then
					local direction = distance > 0 and offset.Unit or facing
					if facing:Dot(direction) >= Config.Combat.FacingDot then
						best, bestDistance = player, distance
					end
				end
			end
		end
	end

	return best
end

function CombatService:Swing(attacker: Player)
	local now = os.clock()
	if (nextSwing[attacker] or 0) > now then
		return
	end
	nextSwing[attacker] = now + Config.Combat.Cooldown

	if self.Services.ZombieService:IsStunned(attacker) then
		return
	end

	self.Services.FeedbackService:Effect(attacker, "swing")

	local target = self:FindTarget(attacker)
	if not target then
		return
	end

	local record = self.Services.StealService:GetCarriedRecord(target)
	local name = record and self.Services.BrainService:GetDisplayName(record) or "a brain"

	self.Services.StealService:ReturnCarried(target, "attacked")
	self.Services.ZombieService:Stun(target, Config.Combat.StunDuration)

	if target.Character then
		flash(target.Character)
	end

	self.Services.FeedbackService:Notify(attacker, `You clawed {target.DisplayName} -- {name} went home!`, "good")
	self.Services.FeedbackService:Effect(attacker, "hit")
	self.Services.FeedbackService:Effect(target, "hit")
end

function CombatService:Init() end

function CombatService:Start()
	local attackRemote = Remotes.Event("Attack")

	attackRemote.OnServerEvent:Connect(function(player)
		-- Everything about the swing is decided here; the client only asks.
		local ok, err = pcall(function()
			self:Swing(player)
		end)
		if not ok then
			warn(`[CombatService] swing error for {player.Name}: {err}`)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextSwing[player] = nil
	end)
end

return CombatService
