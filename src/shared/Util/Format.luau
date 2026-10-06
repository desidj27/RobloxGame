--!strict
-- Number and text formatting helpers for the UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.abbreviate(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text = if value >= 100 then string.format("%.0f", value) else string.format("%.1f", value)
	text = text:gsub("%.0$", "")
	return sign .. text .. SUFFIXES[index]
end

function Format.commas(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function Format.percent(value: number, decimals: number?): string
	local places = decimals or 1
	if value < 0.01 and value > 0 then
		return string.format("%.3f%%", value)
	end
	return string.format(`%.{places}f%%`, value)
end

function Format.stat(value: number): string
	if value == math.floor(value) then
		return tostring(value)
	end
	return string.format("%.1f", value)
end

return Format
