local HunterRules = {}

local APPROVED = { "George", "Mary", "Missy", "Georgie" }
local APPROVED_SET = {}
for _, name in ipairs(APPROVED) do
	APPROVED_SET[name] = true
end

local FIXED = {
	GeorgeBeer = "George",
	MaryDishes = "Mary",
	MaryTrash = "Mary",
	MissyPlush = "Missy",
}

function HunterRules.approvedHunters()
	local copied = {}
	for index, name in ipairs(APPROVED) do
		copied[index] = name
	end
	return copied
end

function HunterRules.isApproved(name)
	return APPROVED_SET[name] == true
end

function HunterRules.choose(taskId, randomSource, previousHunter)
	assert(type(taskId) == "string" and taskId ~= "", "taskId is required")
	local fixed = FIXED[taskId]
	if fixed then
		return fixed
	end
	if taskId ~= "MedfordBankHack" then
		return nil, "UnknownTask"
	end
	assert(type(randomSource) == "table" and type(randomSource.nextInteger) == "function",
		"bank hunter selection requires deterministic nextInteger(min, max)")

	local candidates = {}
	for _, name in ipairs(APPROVED) do
		if name ~= previousHunter then
			table.insert(candidates, name)
		end
	end
	if #candidates == 0 then
		candidates = HunterRules.approvedHunters()
	end
	local selected = candidates[randomSource:nextInteger(1, #candidates)]
	assert(APPROVED_SET[selected], "hunter rule selected an unapproved NPC")
	return selected
end

return HunterRules
