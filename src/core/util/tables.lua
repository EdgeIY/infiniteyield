--[[═══════════════════════════════════════════════════════════════════════════
	core/util/tables · table helpers
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...

local M = {}

local unpack = table.unpack or unpack

function M.find(list, value)
	if table.find then return table.find(list, value) end
	for i = 1, #list do
		if list[i] == value then return i end
	end
	return nil
end

function M.contains(list, value)
	return M.find(list, value) ~= nil
end

--[[ Case-insensitive membership test for string lists (legacy FindInTable). ]]
function M.containsInsensitive(list, value)
	if type(list) ~= "table" or value == nil then return false end
	local needle = string.lower(tostring(value))
	for i = 1, #list do
		if type(list[i]) == "string" and string.lower(list[i]) == needle then return true end
	end
	return false
end

function M.count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

function M.isEmpty(t)
	return next(t) == nil
end

function M.keys(t, sorted)
	local out = {}
	for key in pairs(t) do out[#out + 1] = key end
	if sorted then
		table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	end
	return out
end

function M.values(t)
	local out = {}
	for _, value in pairs(t) do out[#out + 1] = value end
	return out
end

function M.copy(t)
	local out = {}
	for key, value in pairs(t) do out[key] = value end
	return out
end

function M.deepCopy(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local out = {}
	seen[t] = out
	for key, value in pairs(t) do
		out[M.deepCopy(key, seen)] = M.deepCopy(value, seen)
	end
	return out
end

--[[ Shallow merge of `source` into `target`, returning target. ]]
function M.merge(target, source)
	if type(source) ~= "table" then return target end
	for key, value in pairs(source) do target[key] = value end
	return target
end

--[[ Fill in missing keys only (recursively) -- used for settings defaults. ]]
function M.defaults(target, source)
	if type(source) ~= "table" then return target end
	for key, value in pairs(source) do
		if target[key] == nil then
			target[key] = (type(value) == "table") and M.deepCopy(value) or value
		elseif type(target[key]) == "table" and type(value) == "table" then
			M.defaults(target[key], value)
		end
	end
	return target
end

function M.append(target, source)
	for i = 1, #source do target[#target + 1] = source[i] end
	return target
end

function M.map(list, fn)
	local out = {}
	for i = 1, #list do out[i] = fn(list[i], i) end
	return out
end

function M.filter(list, predicate)
	local out = {}
	for i = 1, #list do
		if predicate(list[i], i) then out[#out + 1] = list[i] end
	end
	return out
end

function M.reject(list, predicate)
	return M.filter(list, function(v, i) return not predicate(v, i) end)
end

function M.reduce(list, fn, initial)
	local acc = initial
	for i = 1, #list do acc = fn(acc, list[i], i) end
	return acc
end

function M.some(list, predicate)
	for i = 1, #list do
		if predicate(list[i], i) then return true end
	end
	return false
end

function M.every(list, predicate)
	for i = 1, #list do
		if not predicate(list[i], i) then return false end
	end
	return true
end

--[[ Remove the first occurrence of `value`. Returns true when removed. ]]
function M.removeValue(list, value)
	local index = M.find(list, value)
	if index then
		table.remove(list, index)
		return true
	end
	return false
end

--[[ De-duplicate preserving order. `key` optionally maps an element to its
     identity (e.g. a Player to its UserId). ]]
function M.unique(list, key)
	local seen, out = {}, {}
	for i = 1, #list do
		local item = list[i]
		local identity = key and key(item) or item
		if identity ~= nil and not seen[identity] then
			seen[identity] = true
			out[#out + 1] = item
		end
	end
	return out
end

--[[ Set operations on identity, used by the player query engine. ]]
function M.intersectBy(list, other, key)
	local allowed = {}
	for i = 1, #other do allowed[key(other[i])] = true end
	return M.filter(list, function(item) return allowed[key(item)] == true end)
end

function M.differenceBy(list, other, key)
	local blocked = {}
	for i = 1, #other do blocked[key(other[i])] = true end
	return M.filter(list, function(item) return blocked[key(item)] ~= true end)
end

--[[ Stable sort by a computed key (table.sort is unstable; ties in command
     lists were reordering between runs). ]]
function M.sortBy(list, keyFn, descending)
	local decorated = {}
	for i = 1, #list do
		decorated[i] = { value = list[i], key = keyFn(list[i]), index = i }
	end
	table.sort(decorated, function(a, b)
		if a.key == b.key then return a.index < b.index end
		if descending then return a.key > b.key end
		return a.key < b.key
	end)
	local out = {}
	for i = 1, #decorated do out[i] = decorated[i].value end
	return out
end

--[[ Group a list into buckets keyed by keyFn. ]]
function M.groupBy(list, keyFn)
	local out = {}
	for i = 1, #list do
		local key = keyFn(list[i])
		local bucket = out[key]
		if not bucket then bucket = {} out[key] = bucket end
		bucket[#bucket + 1] = list[i]
	end
	return out
end

function M.slice(list, from, to)
	local out = {}
	for i = from or 1, math.min(to or #list, #list) do out[#out + 1] = list[i] end
	return out
end

function M.reverse(list)
	local out = {}
	for i = #list, 1, -1 do out[#out + 1] = list[i] end
	return out
end

function M.shuffle(list)
	local out = M.slice(list)
	for i = #out, 2, -1 do
		local j = math.random(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

--[[ Pick n random distinct elements. ]]
function M.sample(list, n)
	local pool = M.slice(list)
	local out = {}
	for _ = 1, math.min(n, #pool) do
		local index = math.random(1, #pool)
		out[#out + 1] = pool[index]
		table.remove(pool, index)
	end
	return out
end

--[[ Freeze in Luau when available so shared constant tables cannot be edited
     by a plugin by accident. ]]
function M.freeze(t)
	if table.freeze then
		local ok, frozen = pcall(table.freeze, t)
		if ok then return frozen end
	end
	return t
end

M.unpack = unpack

return M
