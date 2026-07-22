-- Show-specific Cooper-house details and original vintage TV treatment.
-- Uses only built-in Roblox primitives/UI so no copyrighted episode stills or clips are uploaded.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local house = assert(
	Workspace:FindFirstChild("CooperHouseEnvironment")
		and Workspace.CooperHouseEnvironment:FindFirstChild("CooperHouse"),
	"CooperHouse was not found"
)
local props = assert(house:FindFirstChild("FurnitureAndProps"), "FurnitureAndProps was not found")
local interior = assert(house:FindFirstChild("InteriorRooms"), "InteriorRooms was not found")

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"YoungSheldonStoryDetails",
		"Add Cooper-house story details and vintage TV"
	)
end)

local function smooth(p)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function makePart(parent, name, size, cf, color, material, collide, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.fromRGB(120, 90, 60)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = collide == true
	p.CanQuery = true
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	smooth(p)
	p.Parent = parent
	return p
end

local function makeSign(part, face, titleText, subtitleText, background, foreground)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = "OriginalArtwork"
	surface.Face = face
	surface.CanvasSize = Vector2.new(700, 420)
	surface.LightInfluence = 0.2
	surface.Brightness = 1.1
	surface.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = background
	bg.BorderSizePixel = 0
	bg.Parent = surface

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 14
	stroke.Color = foreground:Lerp(Color3.new(0, 0, 0), 0.45)
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.08)
	title.Size = UDim2.fromScale(0.88, 0.54)
	title.Font = Enum.Font.GothamBlack
	title.Text = titleText
	title.TextColor3 = foreground
	title.TextScaled = true
	title.TextWrapped = true
	title.Parent = bg

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromScale(0.08, 0.64)
	subtitle.Size = UDim2.fromScale(0.84, 0.26)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Text = subtitleText or ""
	subtitle.TextColor3 = foreground:Lerp(Color3.new(1, 1, 1), 0.18)
	subtitle.TextScaled = true
	subtitle.TextWrapped = true
	subtitle.Parent = bg

	return surface
end

local previous = props:FindFirstChild("YoungSheldonStoryDetails_V2")
if previous then
	previous:Destroy()
end
local details = Instance.new("Model")
details.Name = "YoungSheldonStoryDetails_V2"
details.Parent = props
details:SetAttribute("BuildVersion", 2)
details:SetAttribute("AssetPolicy", "Original in-game art; no episode clips or actor photos")

-- Box the fireplace into the wood-paneled wall so its side does not hang into the room.
local fireplaceNiche = Instance.new("Model")
fireplaceNiche.Name = "CompletedFireplaceWoodNiche"
fireplaceNiche.Parent = details
local panelColor = Color3.fromRGB(92, 55, 35)
makePart(fireplaceNiche, "LeftWoodReturn", Vector3.new(1.18, 10.30, 0.42), CFrame.new(15.22, 6.70, 11.94), panelColor, Enum.Material.WoodPlanks, true)
makePart(fireplaceNiche, "RightWoodReturn", Vector3.new(1.18, 10.30, 0.42), CFrame.new(15.22, 6.70, 18.52), panelColor, Enum.Material.WoodPlanks, true)
makePart(fireplaceNiche, "WoodHeader", Vector3.new(1.18, 2.65, 7.00), CFrame.new(15.22, 9.48, 15.23), panelColor, Enum.Material.WoodPlanks, true)

-- George's chair-side beverage stash: an original fictional Texas brand treatment.
local stash = Instance.new("Model")
stash.Name = "GeorgeEmergencyBeverageStash"
stash.Parent = details
makePart(stash, "WoodCrate", Vector3.new(3.10, 0.82, 2.15), CFrame.new(26.65, 1.88, 17.10), Color3.fromRGB(115, 69, 38), Enum.Material.WoodPlanks, true)
local crateLabel = makePart(stash, "CrateLabel", Vector3.new(2.45, 0.58, 0.08), CFrame.new(26.65, 1.93, 15.99), Color3.fromRGB(231, 215, 177), Enum.Material.SmoothPlastic, false)
makeSign(crateLabel, Enum.NormalId.Back, "GEORGE'S LONE ★", "EMERGENCY SUPPLY", Color3.fromRGB(37, 79, 121), Color3.fromRGB(241, 226, 188))
for row = 0, 1 do
	for col = 0, 2 do
		local x = 25.80 + col * 0.82
		local z = 16.72 + row * 0.78
		local can = makePart(
			stash,
			"TexasBeverageCan",
			Vector3.new(1.08, 0.42, 0.42),
			CFrame.new(x, 2.58, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(46, 91, 139),
			Enum.Material.Metal,
			false,
			0,
			Enum.PartType.Cylinder
		)
		can:SetAttribute("FictionalBrand", true)
	end
end

-- Kitchen deep cuts: Meemaw's guarded brisket recipe and an unmistakable family task list.
local recipeBox = Instance.new("Model")
recipeBox.Name = "MeemawSecretBrisketRecipe"
recipeBox.Parent = details
makePart(recipeBox, "RecipeBox", Vector3.new(1.65, 0.95, 1.15), CFrame.new(-25.05, 4.70, 12.45), Color3.fromRGB(194, 60, 43), Enum.Material.Wood, false)
local recipeLabel = makePart(recipeBox, "RecipeLabel", Vector3.new(0.06, 0.55, 1.35), CFrame.new(-24.19, 4.72, 12.45), Color3.fromRGB(239, 220, 174), Enum.Material.SmoothPlastic, false)
makeSign(recipeLabel, Enum.NormalId.Right, "MEEMAW'S RECIPE", "ABSOLUTELY NOT FOR SHELDON", Color3.fromRGB(235, 216, 174), Color3.fromRGB(129, 47, 35))
makePart(recipeBox, "SuspiciousSpiceEnvelope", Vector3.new(0.72, 0.08, 0.95), CFrame.new(-24.62, 5.23, 12.50) * CFrame.Angles(0, math.rad(16), 0), Color3.fromRGB(224, 199, 136), Enum.Material.SmoothPlastic, false)

local refrigerator = props:FindFirstChild("WhiteHotpointRefrigerator")
if refrigerator then
	local assignmentCard = refrigerator:FindFirstChild("MarysGroceryList", true)
	if assignmentCard and assignmentCard:IsA("BasePart") then
		makeSign(
			assignmentCard,
			Enum.NormalId.Back,
			"COOPER ASSIGNMENTS",
			"GEORGE: BEVERAGES\nSHELDON: TRAINS\nMISSY: DO NOT ANNOY\nGEORGIE: FIND A JOB",
			Color3.fromRGB(245, 232, 188),
			Color3.fromRGB(69, 68, 58)
		)
	end
	local scheduleCard = refrigerator:FindFirstChild("BathroomSchedule", true)
	if scheduleCard and scheduleCard:IsA("BasePart") then
		makeSign(
			scheduleCard,
			Enum.NormalId.Back,
			"BATHROOM SCHEDULE",
			"6:43 SHELDON\n6:51 MISSY\n6:59 EVERYONE ELSE",
			Color3.fromRGB(208, 231, 224),
			Color3.fromRGB(42, 85, 91)
		)
	end
end

-- Extra character-specific bedroom deep cuts.
local bedroomDetails = Instance.new("Model")
bedroomDetails.Name = "CharacterDeepCuts"
bedroomDetails.Parent = details

-- Sheldon's Rubik-style cube, dial phone and signed fictional science-host card.
local cubeOrigin = Vector3.new(-3.65, 4.18, 29.40)
local cubeColors = {
	Color3.fromRGB(215, 45, 42), Color3.fromRGB(244, 184, 42), Color3.fromRGB(44, 112, 183),
	Color3.fromRGB(236, 236, 222), Color3.fromRGB(54, 151, 81), Color3.fromRGB(229, 101, 35),
}
for x = -1, 1 do
	for y = -1, 1 do
		for z = -1, 1 do
			local index = ((x + 1) * 9 + (y + 1) * 3 + (z + 1)) % #cubeColors + 1
			makePart(bedroomDetails, "PuzzleCubelet", Vector3.new(0.18, 0.18, 0.18), CFrame.new(cubeOrigin + Vector3.new(x, y, z) * 0.19), cubeColors[index], Enum.Material.SmoothPlastic, false)
		end
	end
end
makePart(bedroomDetails, "SheldonDialPhone", Vector3.new(1.20, 0.48, 0.72), CFrame.new(-6.72, 4.22, 29.42), Color3.fromRGB(202, 190, 156), Enum.Material.SmoothPlastic, false)
makePart(bedroomDetails, "PhoneDial", Vector3.new(0.15, 0.42, 0.42), CFrame.new(-6.72, 4.49, 29.22) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(73, 70, 61), Enum.Material.SmoothPlastic, false, 0, Enum.PartType.Cylinder)

-- Missy's baseball and glove remain as quieter character details.
makePart(bedroomDetails, "MissyBaseball", Vector3.new(0.48, 0.48, 0.48), CFrame.new(6.20, 4.18, 29.55), Color3.fromRGB(237, 230, 209), Enum.Material.Fabric, false, 0, Enum.PartType.Ball)
makePart(bedroomDetails, "MissyBaseballGlove", Vector3.new(0.95, 0.42, 0.82), CFrame.new(5.50, 4.20, 29.55) * CFrame.Angles(0, math.rad(-22), 0), Color3.fromRGB(132, 76, 43), Enum.Material.Fabric, false, 0, Enum.PartType.Ball)

-- Parents' George-side football playbook and whistle.
local playbook = makePart(bedroomDetails, "GeorgeFootballPlaybook", Vector3.new(1.45, 0.16, 1.90), CFrame.new(-24.10, 5.08, 40.25) * CFrame.Angles(0, math.rad(6), 0), Color3.fromRGB(52, 75, 54), Enum.Material.Fabric, false)
makeSign(playbook, Enum.NormalId.Top, "MEDFORD PLAYBOOK", "DEFENSE WINS GAMES", Color3.fromRGB(47, 74, 52), Color3.fromRGB(231, 210, 147))
makePart(bedroomDetails, "CoachWhistle", Vector3.new(0.48, 0.30, 0.22), CFrame.new(-23.10, 5.14, 40.15), Color3.fromRGB(191, 195, 190), Enum.Material.Metal, false)

-- Replace the lone channel number with an original animated 4:3 vintage science broadcast.
local tv = props:FindFirstChild("WoodCabinetCRTTelevision")
if tv and tv:IsA("Model") then
	local screen = tv:FindFirstChild("CurvedGlassScreen")
	if screen and screen:IsA("BasePart") then
		for _, child in ipairs(screen:GetChildren()) do
			if child:IsA("SurfaceGui") or child:IsA("SurfaceLight") then
				child:Destroy()
			end
		end

		local surface = Instance.new("SurfaceGui")
		surface.Name = "CooperTVBroadcast"
		surface.Face = Enum.NormalId.Back
		surface.CanvasSize = Vector2.new(640, 480)
		surface.LightInfluence = 0
		surface.Brightness = 1.4
		surface.Parent = screen

		local program = Instance.new("Frame")
		program.Name = "Program"
		program.Size = UDim2.fromScale(1, 1)
		program.BackgroundColor3 = Color3.fromRGB(35, 73, 62)
		program.BorderSizePixel = 0
		program.ClipsDescendants = true
		program.Parent = surface

		local safeArea = Instance.new("Frame")
		safeArea.Name = "SafeArea"
		safeArea.Position = UDim2.fromScale(0.035, 0.04)
		safeArea.Size = UDim2.fromScale(0.93, 0.92)
		safeArea.BackgroundTransparency = 1
		safeArea.Parent = program

		local live = Instance.new("TextLabel")
		live.Name = "LiveBug"
		live.Position = UDim2.fromScale(0.03, 0.03)
		live.Size = UDim2.fromScale(0.32, 0.08)
		live.BackgroundColor3 = Color3.fromRGB(174, 55, 43)
		live.BorderSizePixel = 0
		live.Font = Enum.Font.GothamBold
		live.Text = "LIVE • MEDFORD 1989"
		live.TextColor3 = Color3.fromRGB(244, 232, 190)
		live.TextScaled = true
		live.Parent = safeArea

		local title = Instance.new("TextLabel")
		title.Name = "ProgramTitle"
		title.Position = UDim2.fromScale(0.04, 0.12)
		title.Size = UDim2.fromScale(0.92, 0.19)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.Text = "PROF. NEUTRON'S SCIENCE HOUR"
		title.TextColor3 = Color3.fromRGB(244, 220, 134)
		title.TextScaled = true
		title.TextWrapped = true
		title.Parent = safeArea

		local character = Instance.new("Frame")
		character.Name = "ProfessorNeutron"
		character.Position = UDim2.fromScale(0.09, 0.34)
		character.Size = UDim2.fromScale(0.32, 0.44)
		character.BackgroundTransparency = 1
		character.Parent = safeArea

		local head = Instance.new("Frame")
		head.Name = "Head"
		head.Position = UDim2.fromScale(0.18, 0.05)
		head.Size = UDim2.fromScale(0.64, 0.72)
		head.BackgroundColor3 = Color3.fromRGB(232, 201, 156)
		head.BorderSizePixel = 0
		head.Parent = character
		local headCorner = Instance.new("UICorner")
		headCorner.CornerRadius = UDim.new(0.42, 0)
		headCorner.Parent = head

		local hair = Instance.new("Frame")
		hair.Name = "Hair"
		hair.Size = UDim2.fromScale(1, 0.28)
		hair.BackgroundColor3 = Color3.fromRGB(61, 42, 31)
		hair.BorderSizePixel = 0
		hair.Parent = head

		for _, x in ipairs({0.17, 0.58}) do
			local lens = Instance.new("Frame")
			lens.Name = "Glasses"
			lens.Position = UDim2.fromScale(x, 0.35)
			lens.Size = UDim2.fromScale(0.25, 0.20)
			lens.BackgroundTransparency = 0.45
			lens.BackgroundColor3 = Color3.fromRGB(175, 217, 207)
			lens.BorderSizePixel = 5
			lens.BorderColor3 = Color3.fromRGB(35, 35, 31)
			lens.Parent = head
		end

		local bow = Instance.new("TextLabel")
		bow.Name = "BowTie"
		bow.Position = UDim2.fromScale(0.16, 0.72)
		bow.Size = UDim2.fromScale(0.68, 0.24)
		bow.BackgroundTransparency = 1
		bow.Font = Enum.Font.GothamBlack
		bow.Text = "◀◆▶"
		bow.TextColor3 = Color3.fromRGB(172, 54, 47)
		bow.TextScaled = true
		bow.Parent = character

		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "ProgramSubtitle"
		subtitle.Position = UDim2.fromScale(0.43, 0.35)
		subtitle.Size = UDim2.fromScale(0.52, 0.40)
		subtitle.BackgroundColor3 = Color3.fromRGB(226, 214, 171)
		subtitle.BackgroundTransparency = 0.08
		subtitle.BorderSizePixel = 0
		subtitle.Font = Enum.Font.GothamBold
		subtitle.Text = "TONIGHT:\nCAN A TRAIN OUTRUN A TORNADO?"
		subtitle.TextColor3 = Color3.fromRGB(44, 67, 61)
		subtitle.TextScaled = true
		subtitle.TextWrapped = true
		subtitle.Parent = safeArea

		local ticker = Instance.new("TextLabel")
		ticker.Name = "Ticker"
		ticker.Position = UDim2.fromScale(0, 0.85)
		ticker.Size = UDim2.fromScale(1, 0.15)
		ticker.BackgroundColor3 = Color3.fromRGB(27, 36, 33)
		ticker.BorderSizePixel = 0
		ticker.Font = Enum.Font.Code
		ticker.Text = "CHANNEL 8 • SCIENCE • TRAINS • TEXAS WEATHER • BRISKET ALERTS"
		ticker.TextColor3 = Color3.fromRGB(120, 236, 156)
		ticker.TextScaled = true
		ticker.Parent = program

		local static = Instance.new("Frame")
		static.Name = "StaticOverlay"
		static.Size = UDim2.fromScale(1, 1)
		static.BackgroundTransparency = 1
		static.ZIndex = 20
		static.Parent = program
		for i = 0, 17 do
			local line = Instance.new("Frame")
			line.Name = "Scanline"
			line.Position = UDim2.fromScale(0, i / 18)
			line.Size = UDim2.fromScale(1, 0.008)
			line.BackgroundColor3 = Color3.fromRGB(8, 12, 10)
			line.BackgroundTransparency = 0.73
			line.BorderSizePixel = 0
			line.ZIndex = 20
			line.Parent = static
		end

		local glow = Instance.new("SurfaceLight")
		glow.Name = "CRTGlow"
		glow.Face = Enum.NormalId.Back
		glow.Color = Color3.fromRGB(119, 190, 151)
		glow.Brightness = 0.6
		glow.Range = 8
		glow.Angle = 90
		glow.Shadows = false
		glow.Parent = screen
	end
end

local oldAnimator = ServerScriptService:FindFirstChild("CooperHouseTVAnimator")
if oldAnimator then
	oldAnimator:Destroy()
end
local animator = Instance.new("Script")
animator.Name = "CooperHouseTVAnimator"
animator:SetAttribute("Purpose", "Original fictional vintage TV loop")
animator.Parent = ServerScriptService

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("Young Sheldon story details and TV")
	end)
end

print("Young Sheldon story details and original TV created", #details:GetDescendants())
return #details:GetDescendants()
