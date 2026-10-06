--!strict
-- Weighted random selection over a { [key] = weight } table.

local Weighted = {}

function Weighted.total(weights: { [string]: number }): number
	local sum = 0
	for _, weight in weights do
		sum += weight
	end
	return sum
end

-- `roll` is a number in [0, 1); pass math.random() or a Random:NextNumber().
function Weighted.pick(weights: { [string]: number }, roll: number): string?
	local total = Weighted.total(weights)
	if total <= 0 then
		return nil
	end
	-- Iterate in a deterministic order so equal rolls give equal results.
	local keys: { string } = {}
	for key in weights do
		table.insert(keys, key)
	end
	table.sort(keys)

	local target = roll * total
	local cumulative = 0
	for _, key in keys do
		cumulative += weights[key]
		if target < cumulative then
			return key
		end
	end
	return keys[#keys]
end

-- Percentage chance of each key, for UI display.
function Weighted.chances(weights: { [string]: number }): { [string]: number }
	local total = Weighted.total(weights)
	local result = {}
	for key, weight in weights do
		result[key] = if total > 0 then weight / total * 100 else 0
	end
	return result
end

return Weighted
