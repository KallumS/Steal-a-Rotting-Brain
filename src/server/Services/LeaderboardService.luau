--[[
	LeaderboardService
	Fills the board by the spawn gates with the richest rot barons on
	the server, ranked by income per second.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)

local LeaderboardService = {}

local RANK_COLORS = {
	Color3.fromRGB(255, 220, 120),
	Color3.fromRGB(220, 220, 230),
	Color3.fromRGB(220, 160, 110),
}

function LeaderboardService:Render()
	local board = self.Services.WorldBuilder.Leaderboard
	if not board then
		return
	end

	local standings = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local plot = self.Services.PlotService:GetPlotByOwner(player)
		if plot then
			table.insert(standings, {
				Player = player,
				Income = self.Services.EconomyService:GetIncomePerSecond(player),
				Brains = self.Services.PlotService:CountBrains(plot),
			})
		end
	end

	table.sort(standings, function(a, b)
		if a.Income == b.Income then
			return a.Player.Name < b.Player.Name
		end
		return a.Income > b.Income
	end)

	for rank, label in ipairs(board.Rows) do
		local entry = standings[rank]
		if entry then
			label.Text = string.format(
				"%d.  %s   %s/s   (%d)",
				rank,
				entry.Player.DisplayName,
				Format.Cash(entry.Income),
				entry.Brains
			)
			label.TextColor3 = RANK_COLORS[rank] or Color3.fromRGB(200, 200, 200)
		else
			label.Text = string.format("%d.  --", rank)
			label.TextColor3 = Color3.fromRGB(110, 110, 110)
		end
	end
end

function LeaderboardService:Init() end

function LeaderboardService:Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				self:Render()
			end)
			if not ok then
				warn("[LeaderboardService] render error: " .. tostring(err))
			end
			task.wait(2)
		end
	end)
end

return LeaderboardService
