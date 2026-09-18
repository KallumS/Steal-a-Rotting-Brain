--[[
	FeedbackService
	Thin wrapper over the Notify/Effect remotes so gameplay services can
	talk to players without each one grabbing remotes itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local FeedbackService = {}

local notifyRemote: RemoteEvent
local effectRemote: RemoteEvent

function FeedbackService:Init()
	notifyRemote = Remotes.Event("Notify")
	effectRemote = Remotes.Event("Effect")
end

function FeedbackService:Start() end

-- kind: "info" | "good" | "bad"
function FeedbackService:Notify(player: Player, text: string, kind: string?)
	if not player:IsDescendantOf(Players) then
		return
	end
	notifyRemote:FireClient(player, { Text = text, Kind = kind or "info" })
end

function FeedbackService:NotifyAll(text: string, kind: string?)
	notifyRemote:FireAllClients({ Text = text, Kind = kind or "info" })
end

-- kind: "purchase" | "steal" | "lost" | "lock" | "unlock" | "hit" | "rebirth"
function FeedbackService:Effect(player: Player, kind: string, data: any?)
	if not player:IsDescendantOf(Players) then
		return
	end
	effectRemote:FireClient(player, { Kind = kind, Data = data })
end

return FeedbackService
