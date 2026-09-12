--[[
	Format
	Number and time formatting shared by the HUD, signs and prompts.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234567 -> "1.23M"
function Format.Abbreviate(value: number): string
	if value ~= value then -- NaN guard
		return "0"
	end

	local sign = value < 0 and "-" or ""
	value = math.abs(value)

	if value < 1000 then
		-- Show a decimal for small fractional amounts, otherwise keep it clean.
		if value > 0 and value < 10 and value % 1 ~= 0 then
			return string.format("%s%.1f", sign, value)
		end
		return sign .. tostring(math.floor(value))
	end

	local index = math.floor(math.log(value, 1000))
	index = math.clamp(index, 1, #SUFFIXES - 1)

	local scaled = value / 1000 ^ index
	local suffix = SUFFIXES[index + 1]

	local text
	if scaled >= 100 then
		text = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.2f", scaled)
	end

	-- "1.00K" reads worse than "1K", so drop dead decimals.
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end

	return sign .. text .. suffix
end

-- 1234567 -> "1,234,567"
function Format.Comma(value: number): string
	local whole = string.format("%d", math.floor(math.abs(value)))
	local withCommas = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withCommas = withCommas:gsub("^,", "")
	return (value < 0 and "-" or "") .. withCommas
end

-- Prefixed with the currency symbol, abbreviated: "-$1.5K", not "$-1.5K".
function Format.Cash(value: number): string
	if value < 0 then
		return "-$" .. Format.Abbreviate(-value)
	end
	return "$" .. Format.Abbreviate(value)
end

-- 95 -> "1:35"
function Format.Clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%02d", minutes, seconds % 60)
end

-- 95 -> "95s", 3600 -> "60m"
function Format.Duration(seconds: number): string
	seconds = math.max(0, seconds)
	if seconds < 60 then
		return string.format("%ds", math.floor(seconds + 0.5))
	end
	return string.format("%dm", math.floor(seconds / 60 + 0.5))
end

return Format
