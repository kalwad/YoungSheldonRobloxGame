--!nonstrict
-- Read-only Studio/source audit for server-authoritative physical prompts.
-- This verifier never triggers a prompt, moves a door, or writes game state.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local failures = {}
local checkCount = 0

local function check(condition, message)
	checkCount += 1
	if not condition then
		table.insert(failures, message)
	end
end

local function need(parent, name, className)
	local instance = parent and parent:FindFirstChild(name)
	check(instance ~= nil, (parent and parent:GetFullName() or "<missing>") .. " is missing " .. name)
	if instance and className then
		check(instance:IsA(className), instance:GetFullName() .. " must be a " .. className)
	end
	return instance
end

local function sourceOf(instance, label)
	check(instance ~= nil and instance:IsA("LuaSourceContainer"), label .. " source is missing")
	if not instance or not instance:IsA("LuaSourceContainer") then
		return nil
	end
	if instance:IsA("BaseScript") then
		check(instance.Enabled == true, label .. " must be enabled")
	end
	local ok, source = pcall(function()
		return instance.Source
	end)
	check(ok and type(source) == "string" and #source > 100, label .. " source is unreadable")
	return ok and type(source) == "string" and source or nil
end

local function contains(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local function markers(source, label, expected)
	for _, marker in ipairs(expected) do
		check(contains(source, marker), label .. " is missing security marker: " .. marker)
	end
end

local environment = need(Workspace, "CooperHouseEnvironment", "Model")
local house = need(environment, "CooperHouse", "Model")
local exterior = need(house, "ExteriorDetails", "Model")
local frontDoor = need(exterior, "InteractiveFrontDoor", "Model")
local patioDoor = need(exterior, "InteractiveDenPatioDoor", "Model")
local garage = need(environment, "DetachedGarage", "Model")
local garageDoor = need(garage, "InteractiveSectionalGarageDoor", "Model")

local doorSpecifications = {
	{
		label = "FrontDoorController",
		instance = need(frontDoor, "FrontDoorController", "Script"),
		extra = {
			"local PROMPT_RATE_SECONDS = 0.65",
			"local PROMPT_DISTANCE_HARD_CAP = 16",
			'door:GetAttribute("IsOpen") ~= isOpen',
			'door:GetAttribute("AutomationHoldOpen") == true',
			"setDoor(not isOpen)",
		},
	},
	{
		label = "PatioDoorController",
		instance = need(patioDoor, "PatioDoorController", "Script"),
		extra = {
			"local PROMPT_RATE_SECONDS = 0.65",
			"local PROMPT_DISTANCE_HARD_CAP = 16",
			'door:GetAttribute("IsOpen") ~= isOpen',
			'door:GetAttribute("AutomationHoldOpen") == true',
			"setDoor(not isOpen)",
		},
	},
	{
		label = "GeorgieGarageDoorController",
		instance = need(garageDoor, "GeorgieGarageDoorController", "Script"),
		extra = {
			"local PROMPT_RATE_SECONDS = 0.75",
			"local PROMPT_DISTANCE_HARD_CAP = 18",
			'doorModel:GetAttribute("IsOpen") ~= isOpen',
			'doorModel:GetAttribute("DoorState") ~= expectedState',
			"isDoorwayObstructed()",
			"moveDoor(not isOpen)",
		},
	},
}

for _, specification in ipairs(doorSpecifications) do
	local source = sourceOf(specification.instance, specification.label)
	if source then
		markers(source, specification.label, {
			'game:GetService("Players")',
			"local function livePlayerRoot(player",
			"player.Parent ~= Players",
			'player:GetAttribute("CooperPartyMember") ~= true',
			'player:GetAttribute("CooperGameProfileLoaded") ~= true',
			'partyState ~= "Active" and partyState ~= "HostGrace"',
			'not root:IsA("BasePart")',
			"root:IsDescendantOf(character)",
			"local function playerCanReachPrompt(player",
			"prompt.MaxActivationDistance + PROMPT_DISTANCE_SLACK",
			"PROMPT_DISTANCE_HARD_CAP",
			"local function consumePromptRate(player",
			"Workspace:GetServerTimeNow()",
			"prompt.Triggered:Connect(function(player",
			"not playerCanReachPrompt(player) or not consumePromptRate(player)",
			"or busy or",
			"Players.PlayerRemoving:Connect(function(player)",
			"nextPromptAtByPlayer[player] = nil",
		})
		markers(source, specification.label, specification.extra)
		local validatorAt = string.find(source, "local function playerCanReachPrompt", 1, true)
		local handlerAt = string.find(source, "prompt.Triggered:Connect(function(player", 1, true)
		check(
			validatorAt ~= nil and handlerAt ~= nil and validatorAt < handlerAt,
			specification.label .. " must define validation before connecting its prompt"
		)
	end
end

local bunkerController = need(ServerScriptService, "CooperBunker", "Script")
local bunkerSource = sourceOf(bunkerController, "CooperBunker")
if bunkerSource then
	markers(bunkerSource, "CooperBunker physical prompts", {
		"local physicalPromptNextAt = {}",
		"local PHYSICAL_PROMPT_RATE_SECONDS = table.freeze({",
		"Hatch = 0.70",
		"BlastDoor = 0.70",
		"MainLights = 0.45",
		"local function consumePhysicalPromptRate(player, action)",
		"local _, _, root = playerCharacterState(player)",
		"Workspace:GetServerTimeNow()",
		'consumePhysicalPromptRate(player, "Hatch")',
		'consumePhysicalPromptRate(player, "BlastDoor")',
		'consumePhysicalPromptRate(player, "MainLights")',
		"physicalPromptNextAt[player] = nil",
		"hatchOpen and hatchSweepOccupied()",
		"blastDoorOpen and blastDoorwayOccupied()",
	})
	local limiterAt = string.find(bunkerSource, "local function consumePhysicalPromptRate", 1, true)
	for _, handlerMarker in ipairs({
		"hatchPrompt.Triggered:Connect(function(player)",
		"blastDoorPrompt.Triggered:Connect(function(player)",
		"lightPrompt.Triggered:Connect(function(player)",
	}) do
		local handlerAt = string.find(bunkerSource, handlerMarker, 1, true)
		check(
			limiterAt ~= nil and handlerAt ~= nil and limiterAt < handlerAt,
			"CooperBunker rate limiter must be defined before " .. handlerMarker
		)
	end
end

if #failures > 0 then
	error(string.format(
		"[PromptSecurityAudit] FAIL (%d of %d checks):\n - %s",
		#failures,
		checkCount,
		table.concat(failures, "\n - ")
	))
end

print(string.format("[PromptSecurityAudit] PASS: %d source/structure checks", checkCount))
