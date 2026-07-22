-- Installs the six user-provided Young Sheldon wall photos throughout the house.
-- These are the underlying Image content IDs resolved from the uploaded Decals;
-- ImageLabel cannot reliably render the public Decal-page IDs.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

local PHOTO_ASSETS = {
	GeorgeBow = 131638879874432,
	SheldonBus = 131682058363938,
	SheldonPortrait = 110202364274761,
	GeorgeSmile = 139125267020451,
	GeorgeBackstage = 122723002483342,
	GeorgeDog = 107846670790796,
}
local PHOTO_SCALE = 1.35

for slot, assetId in pairs(PHOTO_ASSETS) do
	assert(assetId > 0, string.format("Roblox photo asset ID is still pending for %s", slot))
end

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment, "CooperHouseEnvironment was not found")
local house = environment:FindFirstChild("CooperHouse")
assert(house, "CooperHouse was not found")
local props = house:FindFirstChild("FurnitureAndProps")
assert(props, "FurnitureAndProps was not found")

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"UserWallPhotoGallery",
		"Install six user-provided Young Sheldon wall photos"
	)
end)

local oldGallery = props:FindFirstChild("UserWallPhotoGallery")
if oldGallery then
	oldGallery:Destroy()
end

-- The George-with-bow photo replaces the botanical print across from the
-- toilet; remove the old frame so the two frames do not intersect.
local oldBathroomPrint = props:FindFirstChild("BathroomBotanicalPrint")
if oldBathroomPrint then
	oldBathroomPrint:Destroy()
end

-- The foyer frames duplicated three of the six gallery images. Keep exactly
-- one copy of every supplied image.
for index = 1, 3 do
	local duplicate = props:FindFirstChild("FoyerFamilyPhoto" .. index)
	if duplicate then
		duplicate:Destroy()
	end
end

-- Remove the old text-only hallway cards and wedding card so the new photo
-- gallery is the only prominent framed art in these spaces.
local bedroomDetails = props:FindFirstChild("YoungSheldonBedroomDetails_V2")
if bedroomDetails then
	local textGallery = bedroomDetails:FindFirstChild("CooperHallGallery")
	if textGallery then
		textGallery:Destroy()
	end
	local parents = bedroomDetails:FindFirstChild("ParentsRoomStoryProps")
	local weddingCard = parents and parents:FindFirstChild("CooperWeddingPhoto")
	if weddingCard then
		weddingCard:Destroy()
	end
end

local gallery = Instance.new("Model")
gallery.Name = "UserWallPhotoGallery"
gallery:SetAttribute("Source", "Six images supplied directly by the user")
gallery:SetAttribute("Style", "Warm 1980s family-photo frames")
gallery.Parent = props

local function smooth(part)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function makePart(parent, name, size, cf, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	smooth(part)
	part.Parent = parent
	return part
end

local function installPhoto(entry)
	local model = Instance.new("Model")
	model.Name = entry.name
	model:SetAttribute("PhotoSlot", entry.slot)
	model:SetAttribute("PhotoAssetId", entry.assetId)
	model:SetAttribute("SourceFile", entry.sourceFile)
	model.Parent = gallery
	local width = entry.width * PHOTO_SCALE
	local height = entry.height * PHOTO_SCALE

	local frame = makePart(
		model,
		"WalnutFrame",
		Vector3.new(width + 0.38, height + 0.38, 0.18),
		entry.cframe,
		Color3.fromRGB(78, 45, 27),
		Enum.Material.Wood
	)

	local direction = entry.face == Enum.NormalId.Front and -1 or 1
	local matte = makePart(
		model,
		"CreamMatte",
		Vector3.new(width + 0.10, height + 0.10, 0.07),
		entry.cframe * CFrame.new(0, 0, direction * 0.115),
		Color3.fromRGB(224, 208, 178),
		Enum.Material.SmoothPlastic
	)

	local photoPlate = makePart(
		model,
		"PhotoPlate",
		Vector3.new(width, height, 0.035),
		entry.cframe * CFrame.new(0, 0, direction * 0.175),
		Color3.fromRGB(242, 235, 219),
		Enum.Material.SmoothPlastic
	)
	photoPlate:SetAttribute("PhotoAssetId", entry.assetId)
	photoPlate:SetAttribute("SourceFile", entry.sourceFile)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "WallPhoto"
	surface.Face = entry.face
	surface.CanvasSize = Vector2.new(
		math.floor(width * 320),
		math.floor(height * 320)
	)
	surface.LightInfluence = 0.12
	surface.Brightness = 1.1
	surface.Parent = photoPlate

	local image = Instance.new("ImageLabel")
	image.Name = "ActorPhoto"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundColor3 = Color3.fromRGB(239, 232, 216)
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = "rbxassetid://" .. tostring(entry.assetId)
	image.ScaleType = Enum.ScaleType.Crop
	image.Parent = surface

	model.PrimaryPart = frame
	return model
end

local function wallFrame(position, roomNormal)
	return CFrame.lookAt(position, position + roomNormal, Vector3.yAxis)
end

local entries = {
	{
		name = "EntryGeorgeBowPhoto",
		slot = "GeorgeBow",
		assetId = PHOTO_ASSETS.GeorgeBow,
		sourceFile = "george_bow.png",
		width = 2.55,
		height = 2.25,
		-- Main bathroom: directly across from the side-facing toilet.
		cframe = wallFrame(Vector3.new(26.76, 7.35, 47.30), Vector3.xAxis),
		face = Enum.NormalId.Front,
	},
	{
		name = "DiningSheldonBusPhoto",
		slot = "SheldonBus",
		assetId = PHOTO_ASSETS.SheldonBus,
		sourceFile = "sheldon_bus.png",
		width = 2.25,
		height = 3.35,
		-- Formal living room front wall; more prominent than the dining nook.
		cframe = wallFrame(Vector3.new(-10.00, 7.45, 2.27), Vector3.zAxis),
		face = Enum.NormalId.Front,
	},
	{
		name = "DenSheldonPortraitPhoto",
		slot = "SheldonPortrait",
		assetId = PHOTO_ASSETS.SheldonPortrait,
		sourceFile = "sheldon_portrait.png",
		width = 2.35,
		height = 3.05,
		cframe = wallFrame(Vector3.new(11.00, 8.35, 34.475), -Vector3.zAxis),
		face = Enum.NormalId.Front,
	},
	{
		name = "HallGeorgeSmilePhoto",
		slot = "GeorgeSmile",
		assetId = PHOTO_ASSETS.GeorgeSmile,
		sourceFile = "george_smile.png",
		width = 3.30,
		height = 2.25,
		-- Formal living room, centered above the floral sofa.
		cframe = wallFrame(Vector3.new(-20.43, 8.15, 10.50), Vector3.xAxis),
		face = Enum.NormalId.Front,
	},
	{
		name = "BedroomHallGeorgeBackstagePhoto",
		slot = "GeorgeBackstage",
		assetId = PHOTO_ASSETS.GeorgeBackstage,
		sourceFile = "george_backstage.png",
		width = 2.15,
		height = 2.85,
		-- Kitchen side of the formal/kitchen divider, clear of the refrigerator.
		cframe = wallFrame(Vector3.new(-10.80, 7.35, 20.19), Vector3.zAxis),
		face = Enum.NormalId.Front,
	},
	{
		name = "BedroomHallGeorgeDogPhoto",
		slot = "GeorgeDog",
		assetId = PHOTO_ASSETS.GeorgeDog,
		sourceFile = "george_dog.png",
		width = 2.15,
		height = 2.85,
		-- Living-room side of the formal/kitchen divider.
		cframe = wallFrame(Vector3.new(-7.50, 7.35, 19.45), -Vector3.zAxis),
		face = Enum.NormalId.Front,
	},
}

for _, entry in ipairs(entries) do
	installPhoto(entry)
end

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("User wall photo gallery")
	end)
end

print("Installed unique user wall photo gallery", #entries)
return { gallery = #entries, duplicates = 0 }
