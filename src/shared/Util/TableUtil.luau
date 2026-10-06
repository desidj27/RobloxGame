--!strict
-- Small table helpers.

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value :: T
	end
	local copy = {}
	for key, inner in value :: any do
		copy[key] = TableUtil.deepCopy(inner)
	end
	return (copy :: any) :: T
end

-- Fills missing keys in `target` from `template` (recursively). Used to
-- migrate old profiles forward when new fields are added.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = TableUtil.deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and not TableUtil.isArray(value) then
			TableUtil.reconcile(target[key], value)
		end
	end
end

function TableUtil.isArray(value: { [any]: any }): boolean
	return #value > 0 or next(value) == nil
end

function TableUtil.indexOf<T>(array: { T }, item: T): number?
	for i, existing in array do
		if existing == item then
			return i
		end
	end
	return nil
end

function TableUtil.count(value: { [any]: any }): number
	local n = 0
	for _ in value do
		n += 1
	end
	return n
end

return TableUtil
