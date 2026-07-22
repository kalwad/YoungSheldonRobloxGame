--!strict
-- Restored published-image Cooper family NPCs.
-- Install this source as ServerScriptService.CooperFamilyNPCs.
--
-- This is the original roaming cutout controller with the unwanted idle text
-- removed. It owns no dialogue audio, no subtitles, no cards, and no Panic
-- state. CooperFamilyDialogue owns intentional Talk sessions; the four
-- original proximity LocalScripts own one exact catchphrase per approach.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local environment = workspace:WaitForChild("CooperHouseEnvironment", 20)
assert(environment, "CooperHouseEnvironment was not found")
local imageFolder = ReplicatedStorage:WaitForChild("CooperFamilyLocalImages", 10)
assert(imageFolder and imageFolder:IsA("Folder"), "Import the four published Cooper images before playing")

local oldWorld = environment:FindFirstChild("CooperFamilyNPCs")
if oldWorld then
	oldWorld:Destroy()
end

local world = Instance.new("Folder")
world.Name = "CooperFamilyNPCs"
world:SetAttribute("PublishedAssets", true)
world:SetAttribute("SimpleFourCharacterSystem", true)
world:SetAttribute("PanicEnabled", false)
world:SetAttribute("CharacterCount", 4)
world:SetAttribute("BoomboxDanceActive", false)
world.Parent = environment

local function descendantPart(name: string): BasePart
	local item = environment:FindFirstChild(name, true)
	assert(item and item:IsA("BasePart"), name .. " was not found")
	return item
end

local formalFloor = descendantPart("FormalLivingOatmealCarpet")
local scale = formalFloor.Size.X / 34.2

local waypointSpecs = {
	FormalLiving = { "FormalLivingOatmealCarpet", 3, 0 },
	Dining = { "DiningOatmealCarpet", -2, 1 },
	Kitchen = { "KitchenPatternLinoleum", 4, 0 },
	Den = { "DenHoneyOakFloor", -3, -1 },
	Hall = { "CrossHallFloor", -3, 0 },
	TwinsRoom = { "TwinsGreenGrayCarpet", -1, 0 },
	GeorgieRoom = { "GeorgieBrownCarpet", 0, 0 },
	Bathroom = { "BathroomMintMosaic", 0, 0 },
	FrontPorch = { "PorchDeck", 3, 0 },
	Driveway = { "SideDriveway", 0, 18 },
	Garage = { "GarageFoundation", 2.5, 2 },
}

local waypoints: { [string]: Vector3 } = {}
for name, specification in pairs(waypointSpecs) do
	local part = descendantPart(specification[1] :: string)
	waypoints[name] = Vector3.new(
		part.Position.X + (specification[2] :: number) * scale,
		part.Position.Y + part.Size.Y * 0.5 + 0.12,
		part.Position.Z + (specification[3] :: number) * scale
	)
end

local denFloor = descendantPart("DenHoneyOakFloor")
local chair = environment:FindFirstChild("GeorgeOliveRecliner", true)
if chair then
	local chairPosition = if chair:IsA("Model") then chair:GetPivot().Position
		elseif chair:IsA("BasePart") then chair.Position
		else waypoints.Den
	waypoints.GeorgeChair = Vector3.new(
		chairPosition.X,
		denFloor.Position.Y + denFloor.Size.Y * 0.5 + 0.12,
		-- Keep George's navigation point clearly in front of the recliner.  The
		-- old 2.2-stud offset sat inside the chair's navigation footprint, so
		-- PathfindingService occasionally chose the TOP of the recliner and left
		-- his cutout floating several studs above the den floor.
		chairPosition.Z - 3.6 * scale
	)
else
	waypoints.GeorgeChair = waypoints.Den
end

local definitions = {
	{
		name = "George",
		width = 4.0,
		height = 6.0,
		speed = 4.5,
		home = "GeorgeChair",
		route = { "GeorgeChair", "Den", "Kitchen", "Dining", "Hall" },
	},
	{
		name = "Mary",
		width = 3.6,
		height = 5.8,
		speed = 4.8,
		home = "Kitchen",
		route = { "Kitchen", "Dining", "FormalLiving", "Hall", "Bathroom" },
	},
	{
		name = "Missy",
		width = 3.3,
		height = 5.2,
		speed = 5.6,
		home = "TwinsRoom",
		route = { "TwinsRoom", "Hall", "FormalLiving", "Den" },
	},
	{
		name = "Georgie",
		width = 3.7,
		height = 5.9,
		speed = 5.1,
		home = "GeorgieRoom",
		route = { "GeorgieRoom", "Hall", "FrontPorch", "Driveway", "Garage" },
	},
}

local randomizer = Random.new()

type NPC = {
	model: Model,
	root: Part,
	shadow: Part,
	billboard: BillboardGui,
	definition: any,
	lastDestination: string?,
	targetDestination: string?,
}

type DanceSnapshot = {
	npc: NPC,
	rootCFrame: CFrame,
	shadowCFrame: CFrame,
	shadowSize: Vector3,
	shadowTransparency: number,
	billboardOffset: Vector3,
	billboardSize: UDim2,
	billboardEnabled: boolean,
	prompt: ProximityPrompt?,
	targetRootCFrame: CFrame,
	targetShadowCFrame: CFrame,
}

local DANCE_ORDER = { "George", "Mary", "Missy", "Georgie" }
local DANCE_LINE_LOCAL_X = { 4.6, 8.6, 12.6, 16.6 }
local DANCE_LINE_LOCAL_Z = 3.0
local DANCE_GATHER_SPEED = 11
local DANCE_GRID_STEP = 1.8
local DANCE_GRID_MAX_STEP_HEIGHT = 1.0
local DANCE_GRID_MAX_EXPANSIONS = 2500
local DANCE_GRID_MARGIN = 30
local DANCE_RUNTIME_REPLANS = 4
local DANCE_GRID_DIRECTIONS = {
	{ 1, 0 },
	{ -1, 0 },
	{ 0, 1 },
	{ 0, -1 },
	{ 1, 1 },
	{ 1, -1 },
	{ -1, 1 },
	{ -1, -1 },
}

local npcsByName: { [string]: NPC } = {}
local danceSnapshots: { DanceSnapshot } = {}
local danceActive = false
local danceSerial = 0

local function imageFor(characterName: string): string
	local value = imageFolder:FindFirstChild(characterName)
	assert(value and value:IsA("StringValue") and value.Value ~= "", "Missing published image for " .. characterName)
	return value.Value
end

local function createNPC(definition): NPC
	local model = Instance.new("Model")
	model.Name = definition.name
	model:SetAttribute("CharacterId", definition.name)
	model:SetAttribute("Cooper2DCharacter", true)
	model:SetAttribute("PublishedImage", true)
	model:SetAttribute("InConversation", false)
	model:SetAttribute("BoomboxDancing", false)
	model.Parent = world

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.6, 0.6, 0.6)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.CFrame = CFrame.new(waypoints[definition.home])
	root.Parent = model
	model.PrimaryPart = root

	local shadow = Instance.new("Part")
	shadow.Name = "GroundShadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Size = Vector3.new(0.08, definition.width * 0.62, definition.width * 0.34)
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Transparency = 0.62
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanTouch = false
	shadow.CanQuery = false
	shadow.CastShadow = false
	shadow.CFrame = CFrame.new(root.Position + Vector3.new(0, 0.025, 0)) * CFrame.Angles(0, 0, math.rad(90))
	shadow.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Cutout"
	billboard.Adornee = root
	billboard.Size = UDim2.fromScale(definition.width, definition.height)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, definition.height * 0.5, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0.08
	billboard.MaxDistance = 150
	billboard.Parent = root

	local image = Instance.new("ImageLabel")
	image.Name = "CharacterImage"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = imageFor(definition.name)
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = billboard

	return {
		model = model,
		root = root,
		shadow = shadow,
		billboard = billboard,
		definition = definition,
		lastDestination = nil,
		targetDestination = nil,
	}
end

local function pathTo(startPosition: Vector3, destination: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.35,
		AgentHeight = 5.2,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 3,
	})
	local success = pcall(function()
		path:ComputeAsync(startPosition, destination)
	end)
	if not success or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local points = path:GetWaypoints()
	-- A successful path can still terminate on the top of nearby furniture.
	-- Reject that route instead of letting a cutout climb onto a chair or table;
	-- normal roaming will simply retry another destination after its short pause.
	local endpoint = points[#points]
	if endpoint and math.abs(endpoint.Position.Y - destination.Y) > 1.35 then
		return nil
	end
	return points
end

local function movementPaused(npc: NPC): boolean
	return npc.model.Parent ~= nil
		and (npc.model:GetAttribute("InConversation") == true
			or npc.model:GetAttribute("BoomboxDancing") == true)
end

local function moveAlongPath(npc: NPC, points: { PathWaypoint }): boolean
	for index, point in ipairs(points) do
		if index > 1 then
			while npc.root.Parent do
				if movementPaused(npc) then
					-- The client animates the cutout offset while the party is active.
					-- Do not overwrite that beat-synced animation from the roaming loop.
					if npc.model:GetAttribute("BoomboxDancing") ~= true then
						npc.billboard.StudsOffsetWorldSpace = Vector3.new(0, npc.definition.height * 0.5, 0)
					end
					RunService.Heartbeat:Wait()
					continue
				end
				local delta = point.Position - npc.root.Position
				local flat = Vector3.new(delta.X, 0, delta.Z)
				if flat.Magnitude <= 0.28 then break end
				local dt = math.min(RunService.Heartbeat:Wait(), 0.08)
				local step = math.min(flat.Magnitude, npc.definition.speed * dt)
				local direction = flat.Unit
				local yStep = math.clamp(delta.Y, -step, step)
				local nextPosition = npc.root.Position + Vector3.new(direction.X * step, yStep, direction.Z * step)
				npc.root.CFrame = CFrame.lookAt(nextPosition, nextPosition + direction)
				npc.shadow.CFrame = CFrame.new(nextPosition + Vector3.new(0, 0.025, 0)) * CFrame.Angles(0, 0, math.rad(90))
				local bob = math.sin(os.clock() * 8) * 0.07
				npc.billboard.StudsOffsetWorldSpace = Vector3.new(0, npc.definition.height * 0.5 + bob, 0)
			end
		end
	end
	return true
end

-- Formation travel uses the same navigation mesh as ordinary roaming. If the
-- navigation service cannot produce a route (for example while a door is
-- changing state), a straight fallback is accepted only when an agent-sized
-- blockcast proves the entire corridor clear. Otherwise the cutout dances where
-- it already is for this song instead of ever sliding through a wall.
local danceCastParams = RaycastParams.new()
danceCastParams.FilterType = Enum.RaycastFilterType.Exclude
danceCastParams.FilterDescendantsInstances = { world }
danceCastParams.RespectCanCollide = true

local function danceCorridorClear(startPosition: Vector3, displacement: Vector3): boolean
	if displacement.Magnitude <= 0.001 then
		return true
	end
	local agentCenter = startPosition + Vector3.new(0, 2.55, 0)
	return workspace:Blockcast(
		CFrame.new(agentCenter),
		Vector3.new(2.4, 4.8, 2.4),
		displacement,
		danceCastParams
	) == nil
end

local function dancePathIsClear(startPosition: Vector3, points: { any }): boolean
	local previousPosition = startPosition
	for _, point in ipairs(points) do
		local position = point.Position
		if not danceCorridorClear(previousPosition, position - previousPosition) then
			return false
		end
		previousPosition = position
	end
	return true
end

-- PathfindingService can consider the tops of sofas and tables walkable even
-- when AgentCanJump is false.  The party route therefore has a bounded second
-- stage that searches the actual floor at the exact same collision width used
-- by visible movement.  It is deliberately dance-only: ordinary wandering
-- keeps Roblox's navigation pacing, while a party can reliably route around a
-- newly placed truck, an open door, furniture, or the porch posts.
local function danceGridPath(startPosition: Vector3, destination: Vector3): { any }?
	local castTopY = math.max(startPosition.Y, destination.Y)
	local maximumFloorY = formalFloor.Position.Y + formalFloor.Size.Y * 0.5 + 0.75
	local groundCastParams = RaycastParams.new()
	groundCastParams.FilterType = Enum.RaycastFilterType.Exclude
	groundCastParams.RespectCanCollide = true

	local function groundAt(x: number, z: number, previousGroundY: number?): number?
		-- Skip furniture tops, characters, and other horizontal props until the
		-- real house/yard walking surface is found.  All four NPC routes live on
		-- this ground level; the bunker below is intentionally unreachable here.
		local exclusions: { Instance } = { world }
		for _ = 1, 14 do
			groundCastParams.FilterDescendantsInstances = exclusions
			local result = workspace:Raycast(
				Vector3.new(x, castTopY + 4, z),
				Vector3.new(0, -12, 0),
				groundCastParams
			)
			if not result then
				return nil
			end
			local surfaceY = result.Position.Y
			if result.Normal.Y >= 0.6 and surfaceY <= maximumFloorY then
				if previousGroundY
					and math.abs(surfaceY - previousGroundY) > DANCE_GRID_MAX_STEP_HEIGHT
				then
					return nil
				end
				return surfaceY
			end
			table.insert(exclusions, result.Instance)
		end
		return nil
	end

	local startGroundY = groundAt(startPosition.X, startPosition.Z, nil)
	if not startGroundY then
		return nil
	end
	-- Preserve the cutout's current foot clearance when possible.  The upper
	-- cap is enough to glide naturally over the shallow porch steps, but never
	-- enough to climb onto a sofa, table, or cabinet.
	local navigationClearance = math.clamp(startPosition.Y - startGroundY, 0.12, 0.9)
	local horizontalDistance = (Vector3.new(destination.X, 0, destination.Z)
		- Vector3.new(startPosition.X, 0, startPosition.Z)).Magnitude
	local maxGridIndex = math.ceil((horizontalDistance + DANCE_GRID_MARGIN) / DANCE_GRID_STEP)

	type GridNode = {
		ix: number,
		iz: number,
		position: Vector3,
		groundY: number,
		cost: number,
		parent: GridNode?,
	}

	local function nodeKey(ix: number, iz: number): string
		return tostring(ix) .. ":" .. tostring(iz)
	end

	local startNode: GridNode = {
		ix = 0,
		iz = 0,
		position = startPosition,
		groundY = startGroundY,
		cost = 0,
		parent = nil,
	}
	local nodes: { [string]: GridNode } = { [nodeKey(0, 0)] = startNode }
	local open: { [string]: boolean } = { [nodeKey(0, 0)] = true }
	local closed: { [string]: boolean } = {}
	local finalNode: GridNode? = nil
	local expansions = 0

	while next(open) and expansions < DANCE_GRID_MAX_EXPANSIONS do
		local bestKey: string? = nil
		local bestNode: GridNode? = nil
		local bestScore = math.huge
		for key in pairs(open) do
			local node = nodes[key]
			local heuristic = (Vector3.new(destination.X, 0, destination.Z)
				- Vector3.new(node.position.X, 0, node.position.Z)).Magnitude
			local score = node.cost + heuristic
			if score < bestScore then
				bestKey = key
				bestNode = node
				bestScore = score
			end
		end
		if not bestKey or not bestNode then
			break
		end

		open[bestKey] = nil
		closed[bestKey] = true
		expansions += 1

		local destinationDelta = destination - bestNode.position
		local destinationFlat = Vector3.new(destinationDelta.X, 0, destinationDelta.Z)
		if destinationFlat.Magnitude <= DANCE_GRID_STEP * 1.5
			and math.abs(destinationDelta.Y) <= 1.5
			and danceCorridorClear(bestNode.position, destinationDelta)
		then
			finalNode = bestNode
			break
		end

		for _, direction in ipairs(DANCE_GRID_DIRECTIONS) do
			local ix = bestNode.ix + direction[1]
			local iz = bestNode.iz + direction[2]
			if math.abs(ix) <= maxGridIndex and math.abs(iz) <= maxGridIndex then
				local key = nodeKey(ix, iz)
				if not closed[key] then
					local x = startPosition.X + ix * DANCE_GRID_STEP
					local z = startPosition.Z + iz * DANCE_GRID_STEP
					local groundY = groundAt(x, z, bestNode.groundY)
					if groundY then
						local position = Vector3.new(x, groundY + navigationClearance, z)
						local displacement = position - bestNode.position
						if danceCorridorClear(bestNode.position, displacement) then
							local cost = bestNode.cost + displacement.Magnitude
							local existing = nodes[key]
							if not existing or cost < existing.cost then
								nodes[key] = {
									ix = ix,
									iz = iz,
									position = position,
									groundY = groundY,
									cost = cost,
									parent = bestNode,
								}
								open[key] = true
							end
						end
					end
				end
			end
		end
	end

	if not finalNode then
		return nil
	end
	local reversed: { Vector3 } = {}
	local cursor: GridNode? = finalNode
	while cursor do
		table.insert(reversed, cursor.position)
		cursor = cursor.parent
	end
	local points: { any } = {}
	for index = #reversed, 1, -1 do
		table.insert(points, { Position = reversed[index] })
	end
	table.insert(points, { Position = destination })
	return points
end

local function safeDancePath(npc: NPC, destination: Vector3): { any }?
	local points = pathTo(npc.root.Position, destination)
	if points and #points > 1 and dancePathIsClear(npc.root.Position, points :: any) then
		return points
	end

	local delta = destination - npc.root.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.28 then
		return {
			{ Position = npc.root.Position },
			{ Position = destination },
		}
	end

	local gridPoints = danceGridPath(npc.root.Position, destination)
	if gridPoints then
		return gridPoints
	end
	return nil
end

local function gatherAlongSafePath(snapshot: DanceSnapshot, points: { any }, serial: number): boolean
	local npc = snapshot.npc
	for index, point in ipairs(points) do
		if index > 1 then
			while npc.root.Parent and danceActive and danceSerial == serial do
				local delta = point.Position - npc.root.Position
				local flat = Vector3.new(delta.X, 0, delta.Z)
				if flat.Magnitude <= 0.28 then
					break
				end
				local dt = math.min(RunService.Heartbeat:Wait(), 0.08)
				if not danceActive or danceSerial ~= serial then
					return false
				end
				local step = math.min(flat.Magnitude, DANCE_GATHER_SPEED * dt)
				local direction = flat.Unit
				local yStep = math.clamp(delta.Y, -step, step)
				local nextPosition = npc.root.Position + Vector3.new(
					direction.X * step,
					yStep,
					direction.Z * step
				)
				if not danceCorridorClear(npc.root.Position, nextPosition - npc.root.Position) then
					return false
				end
				npc.root.CFrame = CFrame.lookAt(nextPosition, nextPosition + direction)
				if npc.shadow.Parent then
					npc.shadow.CFrame = CFrame.new(nextPosition + Vector3.new(0, 0.025, 0))
						* snapshot.shadowCFrame.Rotation
				end
			end
		end
	end

	if not npc.root.Parent or not danceActive or danceSerial ~= serial then
		return false
	end
	npc.root.CFrame = snapshot.targetRootCFrame
	if npc.shadow.Parent then
		npc.shadow.CFrame = snapshot.targetShadowCFrame
	end
	return true
end

local function chooseDestination(npc: NPC): (string, Vector3)
	local route = npc.definition.route
	local available: { string } = {}
	for _, routeName in ipairs(route) do
		local reserved = false
		for _, other in pairs(npcsByName) do
			if other ~= npc
				and (other.targetDestination == routeName or other.lastDestination == routeName)
			then
				reserved = true
				break
			end
		end
		if routeName ~= npc.lastDestination and not reserved then
			table.insert(available, routeName)
		end
	end
	-- Every character has several routes, so this fallback is only defensive if
	-- a future edit gives one NPC a single fully reserved destination.
	if #available == 0 then
		for _, routeName in ipairs(route) do
			if routeName ~= npc.lastDestination then
				table.insert(available, routeName)
			end
		end
	end
	local choices = #available > 0 and available or route
	local chosen = choices[randomizer:NextInteger(1, #choices)]
	return chosen, waypoints[chosen]
end

local function talkPromptFor(npc: NPC): ProximityPrompt?
	local prompt = npc.root:FindFirstChild("TalkPrompt")
	return if prompt and prompt:IsA("ProximityPrompt") then prompt else nil
end

local function restoreTalkPrompt(npc: NPC, prompt: ProximityPrompt?)
	local currentPrompt = if prompt and prompt.Parent then prompt else talkPromptFor(npc)
	if not currentPrompt then
		return
	end
	currentPrompt.Enabled = npc.model:GetAttribute("InConversation") ~= true
		and currentPrompt:GetAttribute("CooperComputerPrioritySuppressed") ~= true
end

local function finishBoomboxDance()
	if not danceActive then
		world:SetAttribute("BoomboxDanceActive", false)
		return
	end

	danceActive = false
	danceSerial += 1
	local snapshots = danceSnapshots
	danceSnapshots = {}

	-- Keep BoomboxDancing true until every saved transform is back in place.
	-- This prevents a paused path coroutine from moving an NPC halfway through
	-- restoration and guarantees the exact pre-party state wins.
	for _, snapshot in ipairs(snapshots) do
		local npc = snapshot.npc
		if npc.root.Parent then
			npc.root.CFrame = snapshot.rootCFrame
		end
		if npc.shadow.Parent then
			npc.shadow.CFrame = snapshot.shadowCFrame
			npc.shadow.Size = snapshot.shadowSize
			npc.shadow.Transparency = snapshot.shadowTransparency
		end
		if npc.billboard.Parent then
			npc.billboard.StudsOffsetWorldSpace = snapshot.billboardOffset
			npc.billboard.Size = snapshot.billboardSize
			npc.billboard.Enabled = snapshot.billboardEnabled
		end
	end
	for _, snapshot in ipairs(snapshots) do
		if snapshot.npc.model.Parent then
			snapshot.npc.model:SetAttribute("BoomboxDancing", false)
		end
	end
	world:SetAttribute("BoomboxDanceActive", false)
	for _, snapshot in ipairs(snapshots) do
		restoreTalkPrompt(snapshot.npc, snapshot.prompt)
	end
end

local function beginBoomboxDance()
	if danceActive then
		return
	end

	danceActive = true
	danceSerial += 1
	local serial = danceSerial
	local snapshots: { DanceSnapshot } = {}
	local floorUp = formalFloor.CFrame.UpVector
	local floorY = formalFloor.Size.Y * 0.5 + 0.12

	-- Snapshot all four characters without yielding, then lock their roaming
	-- controllers before the smooth gather begins.
	for index, characterName in ipairs(DANCE_ORDER) do
		local npc = npcsByName[characterName]
		if npc and npc.model.Parent and npc.root.Parent and npc.shadow.Parent and npc.billboard.Parent then
			local rootCFrame = npc.root.CFrame
			local shadowCFrame = npc.shadow.CFrame
			local targetPosition = formalFloor.CFrame:PointToWorldSpace(Vector3.new(
				DANCE_LINE_LOCAL_X[index],
				floorY,
				DANCE_LINE_LOCAL_Z
			))
			local targetRootCFrame = CFrame.new(targetPosition) * rootCFrame.Rotation
			local targetShadowCFrame = CFrame.new(targetPosition + floorUp * 0.025) * shadowCFrame.Rotation
			local prompt = talkPromptFor(npc)
			table.insert(snapshots, {
				npc = npc,
				rootCFrame = rootCFrame,
				shadowCFrame = shadowCFrame,
				shadowSize = npc.shadow.Size,
				shadowTransparency = npc.shadow.Transparency,
				billboardOffset = npc.billboard.StudsOffsetWorldSpace,
				billboardSize = npc.billboard.Size,
				billboardEnabled = npc.billboard.Enabled,
				prompt = prompt,
				targetRootCFrame = targetRootCFrame,
				targetShadowCFrame = targetShadowCFrame,
			})
			npc.model:SetAttribute("BoomboxDancing", true)
			if prompt then
				prompt.Enabled = false
			end
		end
	end

	danceSnapshots = snapshots
	world:SetAttribute("BoomboxDanceActive", true)

	for _, snapshot in ipairs(snapshots) do
		task.spawn(function()
			-- A player, a moving delivery, or a door can enter a route after its
			-- preflight. Replan a small, fixed number of times from the NPC's actual
			-- stopped position instead of abandoning the formation for the song.
			for _ = 1, DANCE_RUNTIME_REPLANS + 1 do
				if not danceActive or danceSerial ~= serial then
					break
				end
				local points = safeDancePath(snapshot.npc, snapshot.targetRootCFrame.Position)
				if not points then
					break
				end
				if gatherAlongSafePath(snapshot, points, serial) then
					break
				end
				task.wait(0.1)
			end
		end)
	end

	task.spawn(function()
		-- Dialogue and computer-priority systems can also change prompt.Enabled.
		-- Hold it off for the whole path-based gather and performance.
		while danceActive and danceSerial == serial do
			for _, snapshot in ipairs(snapshots) do
				local prompt = talkPromptFor(snapshot.npc)
				if prompt then
					snapshot.prompt = prompt
					if prompt.Enabled then
						prompt.Enabled = false
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

for _, definition in ipairs(definitions) do
	local npc = createNPC(definition)
	npcsByName[definition.name :: string] = npc
	task.spawn(function()
		task.wait(randomizer:NextNumber(0.5, 2.5))
		while npc.root.Parent do
			while npc.root.Parent and movementPaused(npc) do
				task.wait(0.1)
			end
			if not npc.root.Parent then break end
			-- Quiet pauses preserve the original movement pacing without ever
			-- producing random bubbles, subtitles, or ambient voice lines.
			task.wait(randomizer:NextNumber(1.5, 4.0))
			if movementPaused(npc) then continue end
			local destinationName, destination = chooseDestination(npc)
			-- Reserve before ComputeAsync yields so two roaming coroutines cannot
			-- choose the same exact room point and stack their PNG cutouts together.
			npc.targetDestination = destinationName
			local points = pathTo(npc.root.Position, destination)
			if points and #points > 1 then
				moveAlongPath(npc, points)
				npc.lastDestination = destinationName
			else
				task.wait(randomizer:NextNumber(1, 2.5))
			end
			npc.targetDestination = nil
		end
	end)
end

-- CooperTaskWorld owns playback authorization and always toggles the shared
-- model's Playing attribute on start/finish. Observing that single lifecycle
-- signal keeps natural completion, interruption, watchdog cleanup, and player
-- departure on the same restoration path.
task.spawn(function()
	local taskWorld = environment:WaitForChild("CooperFamilyTaskWorld", 30)
	local boombox = taskWorld and taskWorld:FindFirstChild("CooperIncomeBoombox", true)
	if not boombox or not boombox:IsA("Model") then
		warn("[CooperFamilyNPCs] Income boombox was not found; family dance is unavailable")
		return
	end

	local function syncDanceState()
		if boombox:GetAttribute("Playing") == true then
			beginBoomboxDance()
		else
			finishBoomboxDance()
		end
	end

	boombox:GetAttributeChangedSignal("Playing"):Connect(syncDanceState)
	boombox.Destroying:Connect(finishBoomboxDance)
	syncDanceState()
end)

script.Destroying:Connect(finishBoomboxDance)

print("[CooperFamilyNPCs] Four pure-PNG roaming NPCs ready with boombox party formation; no idle dialogue or Panic state")
