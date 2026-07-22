-- Idempotent edit-mode installer for the secret-bunker construction setpiece.
--
-- The runtime controller clones these deliberately script-free, anchored
-- templates.  Every visible part is noncolliding, nontouching, and nonquerying;
-- the runtime creates a separate, static safety perimeter while the machinery
-- is moving.  All coordinates in this file are template-local around origin.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

assert(not RunService:IsRunning(), "Run this construction asset installer in Studio edit mode")

local INSTALL_VERSION = "1.0.0"
local ROOT_NAME = "CooperBunkerConstructionAssets"

local COLORS = {
	yellow = Color3.fromRGB(210, 151, 38),
	yellowLight = Color3.fromRGB(238, 186, 66),
	yellowDark = Color3.fromRGB(151, 100, 24),
	cream = Color3.fromRGB(222, 213, 177),
	red = Color3.fromRGB(178, 55, 43),
	orange = Color3.fromRGB(226, 104, 34),
	gunmetal = Color3.fromRGB(50, 57, 58),
	steel = Color3.fromRGB(103, 111, 108),
	steelLight = Color3.fromRGB(171, 177, 168),
	rubber = Color3.fromRGB(28, 29, 27),
	glass = Color3.fromRGB(122, 166, 177),
	white = Color3.fromRGB(239, 229, 193),
	black = Color3.fromRGB(15, 17, 17),
	amber = Color3.fromRGB(255, 173, 58),
}

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"CooperBunkerConstructionAssetsInstall",
		"Install Cooper bunker construction assets"
	)
end)

local success, failure = pcall(function()
	local oldRoot = ServerStorage:FindFirstChild(ROOT_NAME)
	if oldRoot then
		oldRoot:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root:SetAttribute("InstallVersion", INSTALL_VERSION)
	root:SetAttribute("TemplateCount", 4)
	root:SetAttribute("UsesMarketplaceModels", false)
	root:SetAttribute("AllMovingVisualsNoncolliding", true)
	root.Parent = ServerStorage

	local function makePart(parent, name, size, cframe, options)
		options = options or {}
		local object = Instance.new(options.className or "Part")
		object.Name = name
		object.Size = size
		object.CFrame = cframe
		object.Color = options.color or COLORS.yellow
		object.Material = options.material or Enum.Material.Metal
		object.Transparency = options.transparency or 0
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.CastShadow = options.castShadow ~= false
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		if options.shape then
			object.Shape = options.shape
		end
		object:SetAttribute("ConstructionVisual", true)
		object.Parent = parent
		return object
	end

	local function makePivotModel(parent, name, pivot)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = parent
		local pivotRoot = makePart(
			model,
			name .. "Pivot",
			Vector3.new(0.08, 0.08, 0.08),
			pivot,
			{
				color = COLORS.black,
				material = Enum.Material.SmoothPlastic,
				transparency = 1,
				castShadow = false,
			}
		)
		pivotRoot:SetAttribute("ConstructionPivot", true)
		model.PrimaryPart = pivotRoot
		return model
	end

	local function makeAsset(name)
		local model = makePivotModel(root, name, CFrame.identity)
		model:SetAttribute("ConstructionAssetVersion", INSTALL_VERSION)
		model:SetAttribute("ConstructionVehicle", true)
		pcall(function()
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		return model
	end

	local function beamBetween(parent, name, pointA, pointB, width, color, material)
		local delta = pointB - pointA
		return makePart(
			parent,
			name,
			Vector3.new(width, width, delta.Magnitude),
			CFrame.lookAt((pointA + pointB) * 0.5, pointB),
			{
				color = color,
				material = material or Enum.Material.Metal,
			}
		)
	end

	local function wheel(parent, name, position, diameter, width)
		local tire = makePart(
			parent,
			name,
			Vector3.new(width, diameter, diameter),
			CFrame.new(position),
			{
				color = COLORS.rubber,
				material = Enum.Material.Rubber,
				shape = Enum.PartType.Cylinder,
			}
		)
		local side = if position.X < 0 then -1 else 1
		makePart(
			parent,
			name .. "Hubcap",
			Vector3.new(0.10, diameter * 0.46, diameter * 0.46),
			CFrame.new(position + Vector3.new(side * (width * 0.5 + 0.055), 0, 0)),
			{
				color = COLORS.steelLight,
				material = Enum.Material.Metal,
				shape = Enum.PartType.Cylinder,
			}
		)
		return tire
	end

	local function warningStripe(parent, name, cframe, size, index)
		return makePart(parent, name, size, cframe, {
			color = if index % 2 == 0 then COLORS.black else COLORS.amber,
			material = Enum.Material.SmoothPlastic,
		})
	end

	local function makeSurfaceLabel(part, face, text, textColor, backgroundColor)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "ConstructionMarking"
		gui.Face = face
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0.3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 36
		gui.Enabled = true
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = backgroundColor
		label.BackgroundTransparency = 0.08
		label.BorderSizePixel = 0
		label.Text = text
		label.TextColor3 = textColor
		label.TextScaled = true
		label.TextWrapped = false
		label.Font = Enum.Font.GothamBlack
		label.Parent = gui

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = 8
		constraint.MaxTextSize = 24
		constraint.Parent = label
	end

	local function addBeacon(parent, cframe)
		local beacon = makePart(parent, "AmberWarningBeacon", Vector3.new(0.46, 0.52, 0.46), cframe, {
			color = COLORS.amber,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Cylinder,
		})
		local light = Instance.new("PointLight")
		light.Name = "WarningGlow"
		light.Color = COLORS.amber
		light.Brightness = 1.15
		light.Range = 8
		light.Enabled = true
		light.Parent = beacon
		return beacon
	end

	local function addExhaustMount(parent, cframe)
		local tip = makePart(parent, "ExhaustTip", Vector3.new(0.34, 1.3, 0.34), cframe, {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
		tip.CFrame *= CFrame.Angles(0, 0, math.rad(90))
		tip:SetAttribute("ConstructionExhaustMount", true)
		return tip
	end

	local function stampArticulation(asset)
		for _, descendant in ipairs(asset:GetDescendants()) do
			if descendant:IsA("Model") and descendant ~= asset then
				local parentModel = descendant.Parent
				while parentModel and not parentModel:IsA("Model") do
					parentModel = parentModel.Parent
				end
				if parentModel and parentModel:IsA("Model") then
					descendant:SetAttribute(
						"ConstructionParentLocalPivot",
						parentModel:GetPivot():ToObjectSpace(descendant:GetPivot())
					)
					descendant:SetAttribute("ConstructionParentModel", parentModel.Name)
				end
				descendant:SetAttribute("ConstructionArticulated", true)
			end
		end
		for _, descendant in ipairs(asset:GetDescendants()) do
			if descendant:IsA("BasePart") then
				assert(descendant.Anchored, descendant:GetFullName() .. " is not anchored")
				assert(not descendant.CanCollide, descendant:GetFullName() .. " is collidable")
				assert(not descendant.CanTouch, descendant:GetFullName() .. " is touchable")
				assert(not descendant.CanQuery, descendant:GetFullName() .. " is queryable")
			end
		end
		local boundsCFrame, boundsSize = asset:GetBoundingBox()
		asset:SetAttribute("TemplateBoundsSize", boundsSize)
		asset:SetAttribute("TemplateBoundsCenter", asset:GetPivot():ToObjectSpace(boundsCFrame))
	end

	-- DUMP TRUCK -------------------------------------------------------------
	do
		local truck = makeAsset("DumpTruck")
		local body = makePivotModel(truck, "Body", CFrame.new(0, 1.55, 0))
		makePart(body, "Chassis", Vector3.new(6.3, 0.85, 14.2), CFrame.new(0, 1.55, 0), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
		})
		makePart(body, "FrontBumper", Vector3.new(6.5, 0.45, 0.45), CFrame.new(0, 1.4, -7.25), {
			color = COLORS.steelLight,
			material = Enum.Material.Metal,
		})
		makePart(body, "RearBumper", Vector3.new(6.5, 0.42, 0.42), CFrame.new(0, 1.35, 7.15), {
			color = COLORS.steel,
			material = Enum.Material.Metal,
		})
		local cab = makePivotModel(truck, "Cab", CFrame.new(0, 2.0, -4.35))
		makePart(cab, "CabBody", Vector3.new(5.75, 3.25, 4.75), CFrame.new(0, 3.25, -4.55), {
			color = COLORS.yellow,
			material = Enum.Material.Metal,
		})
		makePart(cab, "CabRoof", Vector3.new(5.95, 0.30, 4.95), CFrame.new(0, 4.98, -4.55), {
			color = COLORS.yellowDark,
			material = Enum.Material.Metal,
		})
		makePart(cab, "Windshield", Vector3.new(4.75, 1.35, 0.12), CFrame.new(0, 3.90, -6.97), {
			color = COLORS.glass,
			material = Enum.Material.Glass,
			transparency = 0.22,
		})
		for _, side in ipairs({ -1, 1 }) do
			makePart(cab, "SideWindow" .. tostring(side), Vector3.new(0.11, 1.25, 2.45), CFrame.new(
				side * 2.88,
				3.88,
				-4.55
			), {
				color = COLORS.glass,
				material = Enum.Material.Glass,
				transparency = 0.25,
			})
			makePart(cab, "Mirror" .. tostring(side), Vector3.new(0.18, 0.65, 0.78), CFrame.new(
				side * 3.25,
				4.12,
				-5.35
			), {
				color = COLORS.steel,
				material = Enum.Material.Metal,
			})
			makePart(cab, "Headlight" .. tostring(side), Vector3.new(1.0, 0.52, 0.15), CFrame.new(
				side * 1.72,
				2.35,
				-7.02
			), {
				color = COLORS.white,
				material = Enum.Material.Neon,
			})
		end
		local grille = makePart(cab, "FrontGrille", Vector3.new(3.1, 1.0, 0.16), CFrame.new(0, 2.32, -7.04), {
			color = COLORS.gunmetal,
			material = Enum.Material.DiamondPlate,
		})
		makeSurfaceLabel(grille, Enum.NormalId.Front, "MEDFORD HEAVY WORKS", COLORS.white, COLORS.gunmetal)
		addBeacon(cab, CFrame.new(0, 5.30, -4.4))
		addExhaustMount(truck, CFrame.new(-2.35, 3.6, -1.0))

		local bed = makePivotModel(truck, "Bed", CFrame.new(0, 2.75, 6.0))
		makePart(bed, "BedFloor", Vector3.new(5.95, 0.42, 8.7), CFrame.new(0, 3.05, 2.7), {
			color = COLORS.yellowDark,
			material = Enum.Material.Metal,
		})
		for _, side in ipairs({ -1, 1 }) do
			makePart(bed, "BedSide" .. tostring(side), Vector3.new(0.35, 2.75, 8.7), CFrame.new(
				side * 2.83,
				4.20,
				2.7
			), {
				color = COLORS.yellow,
				material = Enum.Material.DiamondPlate,
			})
			for rib = -3, 3 do
				makePart(bed, "SideRib" .. tostring(side) .. "_" .. tostring(rib), Vector3.new(
					0.16,
					2.45,
					0.18
				), CFrame.new(side * 3.02, 4.18, 2.7 + rib * 1.12), {
					color = COLORS.yellowLight,
					material = Enum.Material.Metal,
				})
			end
		end
		makePart(bed, "BedHeadboard", Vector3.new(5.95, 2.9, 0.38), CFrame.new(0, 4.25, -1.65), {
			color = COLORS.yellow,
			material = Enum.Material.DiamondPlate,
		})
		local tailgate = makePart(bed, "Tailgate", Vector3.new(5.95, 2.35, 0.38), CFrame.new(0, 4.0, 7.05), {
			color = COLORS.yellow,
			material = Enum.Material.DiamondPlate,
		})
		makeSurfaceLabel(tailgate, Enum.NormalId.Back, "CAUTION • KEEP CLEAR", COLORS.black, COLORS.amber)

		local wheels = makePivotModel(truck, "Wheels", CFrame.new(0, 1.25, 0))
		for _, z in ipairs({ -4.75, 4.65 }) do
			for _, x in ipairs({ -3.18, 3.18 }) do
				wheel(wheels, string.format("Wheel_%s_%s", x < 0 and "Left" or "Right", z < 0 and "Front" or "Rear"), Vector3.new(
					x,
					1.20,
					z
				), 2.45, 0.85)
			end
		end
		stampArticulation(truck)
	end

	-- EXCAVATOR --------------------------------------------------------------
	do
		local excavator = makeAsset("Excavator")
		local undercarriage = makePivotModel(excavator, "Undercarriage", CFrame.new(0, 1.1, 0))
		makePart(undercarriage, "TrackFrame", Vector3.new(4.4, 0.75, 7.3), CFrame.new(0, 1.2, 0.25), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
		})
		for _, side in ipairs({ -1, 1 }) do
			local trackName = if side < 0 then "TrackLeft" else "TrackRight"
			local track = makePivotModel(undercarriage, trackName, CFrame.new(side * 2.25, 1.0, 0.25))
			makePart(track, trackName .. "Belt", Vector3.new(1.05, 1.5, 7.65), CFrame.new(
				side * 2.25,
				1.0,
				0.25
			), {
				color = COLORS.rubber,
				material = Enum.Material.Rubber,
			})
			for index = -4, 4 do
				makePart(track, trackName .. "Tread" .. tostring(index), Vector3.new(
					1.24,
					0.18,
					0.56
				), CFrame.new(side * 2.25, 0.22, 0.25 + index * 0.82), {
					color = COLORS.gunmetal,
					material = Enum.Material.DiamondPlate,
				})
			end
			for index, z in ipairs({ -2.55, 0.25, 3.05 }) do
				makePart(track, trackName .. "Roller" .. tostring(index), Vector3.new(
					1.15,
					1.15,
					1.15
				), CFrame.new(side * 2.25, 1.05, z), {
					color = COLORS.steel,
					material = Enum.Material.Metal,
					shape = Enum.PartType.Cylinder,
				})
			end
		end
		local upper = makePivotModel(excavator, "UpperBody", CFrame.new(0, 2.0, 0.8))
		makePart(upper, "Turntable", Vector3.new(0.72, 4.2, 4.2), CFrame.new(0, 2.0, 0.6)
			* CFrame.Angles(0, 0, math.rad(90)), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
		makePart(upper, "Counterweight", Vector3.new(4.7, 2.7, 3.1), CFrame.new(0, 3.35, 2.35), {
			color = COLORS.yellow,
			material = Enum.Material.Metal,
		})
		local cab = makePivotModel(upper, "Cab", CFrame.new(1.35, 3.0, 0))
		makePart(cab, "CabShell", Vector3.new(2.45, 3.65, 3.15), CFrame.new(1.25, 4.08, -0.05), {
			color = COLORS.yellow,
			material = Enum.Material.Metal,
		})
		makePart(cab, "CabFrontGlass", Vector3.new(2.08, 2.2, 0.11), CFrame.new(1.25, 4.48, -1.64), {
			color = COLORS.glass,
			material = Enum.Material.Glass,
			transparency = 0.2,
		})
		makePart(cab, "CabSideGlass", Vector3.new(0.11, 2.15, 2.25), CFrame.new(2.50, 4.48, -0.1), {
			color = COLORS.glass,
			material = Enum.Material.Glass,
			transparency = 0.23,
		})
		makePart(cab, "CabRoof", Vector3.new(2.70, 0.28, 3.35), CFrame.new(1.25, 5.94, -0.05), {
			color = COLORS.yellowDark,
			material = Enum.Material.Metal,
		})
		addBeacon(cab, CFrame.new(1.25, 6.25, 0.25))
		addExhaustMount(excavator, CFrame.new(-1.72, 4.25, 2.0))

		local boomStart = Vector3.new(-0.45, 3.65, -0.85)
		local boomEnd = Vector3.new(-0.45, 7.55, -5.35)
		local boom = makePivotModel(upper, "Boom", CFrame.new(boomStart))
		beamBetween(boom, "BoomBeam", boomStart, boomEnd, 0.85, COLORS.yellow, Enum.Material.Metal)
		beamBetween(
			boom,
			"BoomHydraulicCylinder",
			boomStart + Vector3.new(0.62, 0.2, 0.15),
			boomEnd + Vector3.new(0.62, -0.55, 0.5),
			0.25,
			COLORS.steelLight,
			Enum.Material.Metal
		)
		makePart(boom, "BoomPivotPin", Vector3.new(1.45, 0.56, 0.56), CFrame.new(boomStart), {
			color = COLORS.steel,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
		local stickEnd = Vector3.new(-0.45, 2.85, -8.35)
		local stick = makePivotModel(boom, "Stick", CFrame.new(boomEnd))
		beamBetween(stick, "StickBeam", boomEnd, stickEnd, 0.68, COLORS.yellowDark, Enum.Material.Metal)
		beamBetween(
			stick,
			"StickHydraulicCylinder",
			boomEnd + Vector3.new(-0.52, -0.25, 0.2),
			stickEnd + Vector3.new(-0.52, 0.75, 0.45),
			0.21,
			COLORS.steelLight,
			Enum.Material.Metal
		)
		local bucket = makePivotModel(stick, "Bucket", CFrame.new(stickEnd))
		makePart(bucket, "BucketShell", Vector3.new(3.0, 1.4, 2.2), CFrame.new(stickEnd + Vector3.new(
			0,
			-0.35,
			-0.65
		)) * CFrame.Angles(math.rad(-18), 0, 0), {
			color = COLORS.yellowDark,
			material = Enum.Material.DiamondPlate,
			shape = Enum.PartType.Wedge,
		})
		for _, x in ipairs({ -1.1, -0.55, 0, 0.55, 1.1 }) do
			makePart(bucket, "BucketTooth" .. tostring(x), Vector3.new(0.24, 0.28, 0.85), CFrame.new(
				stickEnd + Vector3.new(x, -0.95, -1.85)
			) * CFrame.Angles(math.rad(-18), 0, 0), {
				color = COLORS.steelLight,
				material = Enum.Material.Metal,
			})
		end
		stampArticulation(excavator)
	end

	-- SKID STEER -------------------------------------------------------------
	do
		local skid = makeAsset("SkidSteer")
		local body = makePivotModel(skid, "Body", CFrame.new(0, 1.35, 0))
		makePart(body, "LowerBody", Vector3.new(4.4, 1.8, 5.5), CFrame.new(0, 1.65, 0.2), {
			color = COLORS.yellow,
			material = Enum.Material.Metal,
		})
		makePart(body, "RearCounterweight", Vector3.new(4.25, 1.5, 1.1), CFrame.new(0, 2.0, 2.85), {
			color = COLORS.yellowDark,
			material = Enum.Material.Metal,
		})
		local cab = makePivotModel(skid, "Cab", CFrame.new(0, 2.1, 0.35))
		makePart(cab, "CabCage", Vector3.new(3.5, 3.3, 3.45), CFrame.new(0, 3.55, 0.55), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
		})
		makePart(cab, "FrontGlass", Vector3.new(2.75, 2.2, 0.10), CFrame.new(0, 3.75, -1.2), {
			color = COLORS.glass,
			material = Enum.Material.Glass,
			transparency = 0.24,
		})
		for _, side in ipairs({ -1, 1 }) do
			makePart(cab, "CabSideGlass" .. tostring(side), Vector3.new(0.10, 2.15, 2.5), CFrame.new(
				side * 1.76,
				3.75,
				0.55
			), {
				color = COLORS.glass,
				material = Enum.Material.Glass,
				transparency = 0.28,
			})
		end
		makePart(cab, "CabRoof", Vector3.new(3.8, 0.28, 3.7), CFrame.new(0, 5.25, 0.55), {
			color = COLORS.yellowDark,
			material = Enum.Material.Metal,
		})
		addBeacon(cab, CFrame.new(0, 5.57, 1.1))
		addExhaustMount(skid, CFrame.new(-1.65, 3.1, 2.65))

		local wheels = makePivotModel(skid, "Wheels", CFrame.new(0, 1.1, 0))
		for _, z in ipairs({ -1.75, 1.75 }) do
			for _, x in ipairs({ -2.25, 2.25 }) do
				wheel(wheels, string.format("Wheel_%s_%s", x < 0 and "Left" or "Right", z < 0 and "Front" or "Rear"), Vector3.new(
					x,
					1.12,
					z
				), 2.05, 0.72)
			end
		end

		local arms = makePivotModel(skid, "LiftArms", CFrame.new(0, 2.85, 1.45))
		for _, side in ipairs({ -1, 1 }) do
			beamBetween(
				arms,
				if side < 0 then "ArmLeft" else "ArmRight",
				Vector3.new(side * 2.0, 3.65, 1.75),
				Vector3.new(side * 2.0, 1.5, -3.25),
				0.38,
				COLORS.yellowDark,
				Enum.Material.Metal
			)
			beamBetween(
				arms,
				"ArmHydraulic" .. tostring(side),
				Vector3.new(side * 1.75, 2.5, 1.35),
				Vector3.new(side * 1.75, 1.45, -2.5),
				0.19,
				COLORS.steelLight,
				Enum.Material.Metal
			)
		end
		local bucket = makePivotModel(arms, "Bucket", CFrame.new(0, 1.05, -3.55))
		makePart(bucket, "BucketPan", Vector3.new(5.2, 1.35, 2.05), CFrame.new(0, 0.9, -3.9)
			* CFrame.Angles(math.rad(-12), 0, 0), {
			color = COLORS.yellowDark,
			material = Enum.Material.DiamondPlate,
			shape = Enum.PartType.Wedge,
		})
		makePart(bucket, "BucketCuttingEdge", Vector3.new(5.25, 0.22, 0.62), CFrame.new(
			0,
			0.28,
			-4.85
		), {
			color = COLORS.steelLight,
			material = Enum.Material.Metal,
		})
		stampArticulation(skid)
	end

	-- MOBILE CRANE -----------------------------------------------------------
	do
		local crane = makeAsset("MobileCrane")
		local carrier = makePivotModel(crane, "Carrier", CFrame.new(0, 1.55, 0))
		makePart(carrier, "CarrierChassis", Vector3.new(6.45, 0.85, 16.0), CFrame.new(0, 1.55, 0), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
		})
		makePart(carrier, "FrontBumper", Vector3.new(6.6, 0.42, 0.45), CFrame.new(0, 1.4, -8.15), {
			color = COLORS.steelLight,
			material = Enum.Material.Metal,
		})
		local cab = makePivotModel(carrier, "Cab", CFrame.new(0, 2.0, -5.45))
		makePart(cab, "CarrierCabBody", Vector3.new(5.75, 3.2, 4.5), CFrame.new(0, 3.2, -5.6), {
			color = COLORS.cream,
			material = Enum.Material.Metal,
		})
		makePart(cab, "CarrierWindshield", Vector3.new(4.75, 1.3, 0.11), CFrame.new(0, 3.85, -7.88), {
			color = COLORS.glass,
			material = Enum.Material.Glass,
			transparency = 0.22,
		})
		makePart(cab, "CarrierRoof", Vector3.new(5.95, 0.28, 4.7), CFrame.new(0, 4.92, -5.6), {
			color = COLORS.red,
			material = Enum.Material.Metal,
		})
		for _, side in ipairs({ -1, 1 }) do
			makePart(cab, "CarrierHeadlight" .. tostring(side), Vector3.new(1.0, 0.5, 0.14), CFrame.new(
				side * 1.75,
				2.35,
				-7.91
			), {
				color = COLORS.white,
				material = Enum.Material.Neon,
			})
		end
		addBeacon(cab, CFrame.new(0, 5.23, -5.45))
		addExhaustMount(crane, CFrame.new(-2.45, 3.65, -1.8))

		local wheels = makePivotModel(crane, "Wheels", CFrame.new(0, 1.15, 0))
		for _, z in ipairs({ -5.15, 0, 5.15 }) do
			for _, x in ipairs({ -3.28, 3.28 }) do
				wheel(wheels, string.format("Wheel_%s_%s", x < 0 and "Left" or "Right", tostring(z)), Vector3.new(
					x,
					1.18,
					z
				), 2.35, 0.82)
			end
		end

		local outriggers = makePivotModel(crane, "Outriggers", CFrame.new(0, 1.4, 1.4))
		for _, definition in ipairs({
			{ name = "OutriggerFrontLeft", x = -4.7, z = -2.1 },
			{ name = "OutriggerFrontRight", x = 4.7, z = -2.1 },
			{ name = "OutriggerRearLeft", x = -4.7, z = 4.8 },
			{ name = "OutriggerRearRight", x = 4.7, z = 4.8 },
		}) do
			local side = if definition.x < 0 then -1 else 1
			makePart(outriggers, definition.name .. "Beam", Vector3.new(3.4, 0.35, 0.55), CFrame.new(
				definition.x * 0.67,
				1.55,
				definition.z
			), {
				color = COLORS.red,
				material = Enum.Material.Metal,
			})
			makePart(outriggers, definition.name .. "Leg", Vector3.new(0.45, 1.5, 0.45), CFrame.new(
				definition.x,
				0.95,
				definition.z
			), {
				color = COLORS.steel,
				material = Enum.Material.Metal,
			})
			makePart(outriggers, definition.name .. "Pad", Vector3.new(1.25, 0.22, 1.25), CFrame.new(
				definition.x,
				0.16,
				definition.z
			), {
				color = COLORS.gunmetal,
				material = Enum.Material.DiamondPlate,
			})
			warningStripe(
				outriggers,
				definition.name .. "Stripe",
				CFrame.new(side * 3.15, 1.78, definition.z),
				Vector3.new(0.58, 0.08, 0.58),
				if side < 0 then 1 else 2
			)
		end

		local turret = makePivotModel(crane, "Turret", CFrame.new(0, 2.15, 2.1))
		makePart(turret, "SlewRing", Vector3.new(0.78, 4.8, 4.8), CFrame.new(0, 2.15, 2.1)
			* CFrame.Angles(0, 0, math.rad(90)), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
		makePart(turret, "TurretDeck", Vector3.new(5.6, 0.6, 5.5), CFrame.new(0, 2.7, 2.1), {
			color = COLORS.red,
			material = Enum.Material.DiamondPlate,
		})
		local operatorCab = makePivotModel(turret, "OperatorCab", CFrame.new(1.55, 3.2, 1.5))
		makePart(operatorCab, "OperatorCabShell", Vector3.new(2.45, 3.0, 3.0), CFrame.new(1.55, 4.25, 1.15), {
			color = COLORS.cream,
			material = Enum.Material.Metal,
		})
		makePart(operatorCab, "OperatorCabGlass", Vector3.new(2.05, 1.75, 0.10), CFrame.new(
			1.55,
			4.55,
			-0.37
		), {
			color = COLORS.glass,
			material = Enum.Material.Glass,
			transparency = 0.2,
		})
		local boomStart = Vector3.new(-0.3, 4.05, 1.25)
		local boom = makePivotModel(turret, "Boom", CFrame.new(boomStart))
		local boomMid = Vector3.new(-0.3, 8.0, -8.7)
		local boomTip = Vector3.new(-0.3, 11.15, -18.0)
		beamBetween(boom, "BoomBaseSection", boomStart, boomMid, 1.05, COLORS.red, Enum.Material.Metal)
		beamBetween(boom, "BoomMiddleSection", boomMid, boomTip, 0.78, COLORS.cream, Enum.Material.Metal)
		beamBetween(
			boom,
			"BoomLiftCylinder",
			boomStart + Vector3.new(0.72, -0.2, 0.7),
			boomMid + Vector3.new(0.72, -1.8, 2.4),
			0.28,
			COLORS.steelLight,
			Enum.Material.Metal
		)
		makePart(boom, "BoomTipSheave", Vector3.new(0.32, 1.15, 1.15), CFrame.new(boomTip), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		})
		local hook = makePivotModel(boom, "Hook", CFrame.new(boomTip + Vector3.new(0, -5.0, 0)))
		makePart(hook, "HookCable", Vector3.new(0.12, 5.0, 0.12), CFrame.new(
			boomTip + Vector3.new(0, -2.5, 0)
		), {
			color = COLORS.black,
			material = Enum.Material.Metal,
		})
		makePart(hook, "HookBlock", Vector3.new(0.65, 0.85, 0.48), CFrame.new(
			boomTip + Vector3.new(0, -5.0, 0)
		), {
			color = COLORS.yellow,
			material = Enum.Material.Metal,
		})
		makePart(hook, "CraneHook", Vector3.new(0.55, 1.0, 0.25), CFrame.new(
			boomTip + Vector3.new(0, -5.85, 0)
		) * CFrame.Angles(0, 0, math.rad(28)), {
			color = COLORS.gunmetal,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Wedge,
		})
		stampArticulation(crane)
	end

	-- BUILT-IN PARTICLE TEMPLATES -------------------------------------------
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = root

	local dustCarrier = makePart(
		effects,
		"DustEmitterTemplate",
		Vector3.new(0.25, 0.25, 0.25),
		CFrame.identity,
		{
			color = Color3.fromRGB(181, 151, 105),
			material = Enum.Material.SmoothPlastic,
			transparency = 1,
			castShadow = false,
		}
	)
	dustCarrier:SetAttribute("ConstructionEffectTemplate", true)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "DustCloud"
	dust.Enabled = false
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(192, 165, 120)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(156, 130, 93)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(116, 102, 82)),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.68, 0.50),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.6),
		NumberSequenceKeypoint.new(0.45, 6.8),
		NumberSequenceKeypoint.new(1, 10.5),
	})
	dust.Lifetime = NumberRange.new(2.1, 4.1)
	dust.Rate = 0
	dust.Speed = NumberRange.new(2.5, 6.5)
	dust.SpreadAngle = Vector2.new(170, 170)
	dust.Acceleration = Vector3.new(0, 1.6, 0)
	dust.Drag = 1.5
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-24, 24)
	dust.LightInfluence = 0.65
	dust.LockedToPart = false
	dust.Parent = dustCarrier
	dust:SetAttribute("ConstructionBaseRate", 30)
	dust:SetAttribute("ConstructionBurstCount", 34)

	local groundDustCarrier = dustCarrier:Clone()
	groundDustCarrier.Name = "GroundDustEmitterTemplate"
	local groundDust = groundDustCarrier:FindFirstChild("DustCloud")
	if groundDust and groundDust:IsA("ParticleEmitter") then
		groundDust.Name = "GroundDust"
		groundDust.Lifetime = NumberRange.new(1.2, 2.4)
		groundDust.Speed = NumberRange.new(4.0, 8.5)
		groundDust.Acceleration = Vector3.new(0, -1.2, 0)
		groundDust.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.8),
			NumberSequenceKeypoint.new(0.55, 4.8),
			NumberSequenceKeypoint.new(1, 7.2),
		})
		groundDust:SetAttribute("ConstructionBaseRate", 22)
		groundDust:SetAttribute("ConstructionBurstCount", 26)
	end
	groundDustCarrier.Parent = effects

	local exhaustCarrier = makePart(
		effects,
		"ExhaustSmokeEmitterTemplate",
		Vector3.new(0.12, 0.12, 0.12),
		CFrame.identity,
		{
			color = COLORS.gunmetal,
			material = Enum.Material.SmoothPlastic,
			transparency = 1,
			castShadow = false,
		}
	)
	exhaustCarrier:SetAttribute("ConstructionEffectTemplate", true)
	local exhaust = Instance.new("ParticleEmitter")
	exhaust.Name = "ExhaustSmoke"
	exhaust.Enabled = false
	exhaust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	exhaust.Color = ColorSequence.new(
		Color3.fromRGB(93, 96, 94),
		Color3.fromRGB(158, 157, 148)
	)
	exhaust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(0.45, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	exhaust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.55, 1.2),
		NumberSequenceKeypoint.new(1, 2.3),
	})
	exhaust.Lifetime = NumberRange.new(1.0, 2.2)
	exhaust.Rate = 0
	exhaust.Speed = NumberRange.new(1.2, 2.8)
	exhaust.SpreadAngle = Vector2.new(20, 20)
	exhaust.Acceleration = Vector3.new(0, 1.6, 0)
	exhaust.Drag = 0.45
	exhaust.Rotation = NumberRange.new(0, 360)
	exhaust.RotSpeed = NumberRange.new(-18, 18)
	exhaust.LightInfluence = 0.75
	exhaust.Parent = exhaustCarrier
	exhaust:SetAttribute("ConstructionBaseRate", 7)

	-- PERSISTENT LOCKED-WORLD BASELINE --------------------------------------
	--
	-- Author the locked state in edit mode as well as at runtime. This avoids
	-- a one-frame flash of the completed entrance while server scripts start,
	-- and leaves a real grass support over the physical cut in every saved
	-- place. The lifecycle controller uses these exact original-value
	-- attributes to restore the entrance without guessing authored values.
	local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
	assert(environment and environment:IsA("Model"), "CooperHouseEnvironment was not found")
	local site = environment:FindFirstChild("SiteAndStreet")
	assert(site and site:IsA("Model"), "CooperHouseEnvironment.SiteAndStreet was not found")
	local lot = site:FindFirstChild("CooperLot")
	assert(lot and lot:IsA("BasePart"), "SiteAndStreet.CooperLot was not found")
	local bunker = environment:FindFirstChild("BackyardBunker")
	assert(bunker and bunker:IsA("Model"), "CooperHouseEnvironment.BackyardBunker was not found")
	local surface = bunker:FindFirstChild("SurfaceEntrance")
	assert(surface and surface:IsA("Model"), "BackyardBunker.SurfaceEntrance was not found")
	local shaftOpening = surface:FindFirstChild("ShaftOpening")
	assert(shaftOpening and shaftOpening:IsA("BasePart"), "SurfaceEntrance.ShaftOpening was not found")

	local ORIGINAL_TRANSPARENCY = "BunkerConstructionOriginalTransparency"
	local ORIGINAL_CAN_COLLIDE = "BunkerConstructionOriginalCanCollide"
	local ORIGINAL_CAN_TOUCH = "BunkerConstructionOriginalCanTouch"
	local ORIGINAL_CAN_QUERY = "BunkerConstructionOriginalCanQuery"
	local ORIGINAL_CAST_SHADOW = "BunkerConstructionOriginalCastShadow"
	local ORIGINAL_ENABLED = "BunkerConstructionOriginalEnabled"
	local ORIGINAL_RATE = "BunkerConstructionOriginalRate"
	local PROTECTED_SURFACE_CHILDREN = {
		PhysicalAccess = true,
		ShaftOpening = true,
		BunkerGrassCover = true,
		BunkerAccessGate = true,
	}

	local function isAccessGate(instance)
		local cursor = instance
		while cursor and cursor ~= surface do
			if cursor.Name == "BunkerAccessGate"
				or cursor:GetAttribute("BunkerAccessGate") == true
			then
				return true
			end
			cursor = cursor.Parent
		end
		return false
	end

	local function storeAttributeOnce(instance, attributeName, value)
		if instance:GetAttribute(attributeName) == nil then
			instance:SetAttribute(attributeName, value)
		end
	end

	local function concealInstance(instance)
		if isAccessGate(instance) then
			return
		end
		if instance:IsA("BasePart") then
			storeAttributeOnce(instance, ORIGINAL_TRANSPARENCY, instance.Transparency)
			storeAttributeOnce(instance, ORIGINAL_CAN_COLLIDE, instance.CanCollide)
			storeAttributeOnce(instance, ORIGINAL_CAN_TOUCH, instance.CanTouch)
			storeAttributeOnce(instance, ORIGINAL_CAN_QUERY, instance.CanQuery)
			storeAttributeOnce(instance, ORIGINAL_CAST_SHADOW, instance.CastShadow)
			instance.Transparency = 1
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.CastShadow = false
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			storeAttributeOnce(instance, ORIGINAL_TRANSPARENCY, instance.Transparency)
			instance.Transparency = 1
		elseif instance:IsA("Light")
			or instance:IsA("SurfaceGui")
			or instance:IsA("BillboardGui")
			or instance:IsA("ProximityPrompt")
		then
			storeAttributeOnce(instance, ORIGINAL_ENABLED, instance.Enabled)
			instance.Enabled = false
		elseif instance:IsA("ParticleEmitter") then
			storeAttributeOnce(instance, ORIGINAL_ENABLED, instance.Enabled)
			storeAttributeOnce(instance, ORIGINAL_RATE, instance.Rate)
			instance.Enabled = false
			instance.Rate = 0
		end
	end

	for _, surfaceChild in ipairs(surface:GetChildren()) do
		if not PROTECTED_SURFACE_CHILDREN[surfaceChild.Name]
			and surfaceChild:GetAttribute("BunkerAccessGate") ~= true
		then
			concealInstance(surfaceChild)
			for _, descendant in ipairs(surfaceChild:GetDescendants()) do
				concealInstance(descendant)
			end
		end
	end

	local oldCover = bunker:FindFirstChild("BunkerGrassCover")
	if oldCover and not oldCover:IsA("BasePart") then
		oldCover:Destroy()
		oldCover = nil
	end
	local cover = oldCover
	if not cover then
		cover = Instance.new("Part")
		cover.Name = "BunkerGrassCover"
		cover.Parent = bunker
	end
	local cutterSize = lot:GetAttribute("BunkerShaftSize")
	if typeof(cutterSize) ~= "Vector3" then
		cutterSize = Vector3.new(6.55, 8.0, 6.15)
	end
	local localShaft = lot.CFrame:PointToObjectSpace(shaftOpening.Position)
	cover.Size = Vector3.new(cutterSize.X, lot.Size.Y, cutterSize.Z)
	cover.CFrame = lot.CFrame * CFrame.new(localShaft.X, 0, localShaft.Z)
	cover.Anchored = true
	cover.CanCollide = true
	cover.CanTouch = false
	cover.CanQuery = true
	cover.CastShadow = true
	cover.Transparency = 0
	cover.Material = Enum.Material.Grass
	cover.Color = lot.Color
	cover.TopSurface = Enum.SurfaceType.Smooth
	cover.BottomSurface = Enum.SurfaceType.Smooth
	cover:SetAttribute("BunkerConstructionCover", true)
	cover:SetAttribute("ConstructionRole", "BunkerGrassCover")
	cover:SetAttribute("TrikeGroundSurface", true)
	cover:SetAttribute("ConstructionSafetySupport", true)
	cover:SetAttribute("ConstructionCoverVersion", INSTALL_VERSION)

	local oldViewingAnchor = environment:FindFirstChild("BunkerConstructionViewingAnchor")
	if oldViewingAnchor and not oldViewingAnchor:IsA("BasePart") then
		oldViewingAnchor:Destroy()
		oldViewingAnchor = nil
	end
	local viewingAnchor = oldViewingAnchor
	if not viewingAnchor then
		viewingAnchor = Instance.new("Part")
		viewingAnchor.Name = "BunkerConstructionViewingAnchor"
		viewingAnchor.Parent = environment
	end
	local viewPlan = shaftOpening.CFrame:PointToWorldSpace(Vector3.new(-18, 0, 0.15))
	local localView = lot.CFrame:PointToObjectSpace(viewPlan)
	viewingAnchor.Size = Vector3.new(0.3, 0.3, 0.3)
	viewingAnchor.CFrame = lot.CFrame
		* CFrame.new(localView.X, lot.Size.Y * 0.5 + viewingAnchor.Size.Y * 0.5, localView.Z)
	viewingAnchor.Anchored = true
	viewingAnchor.CanCollide = false
	viewingAnchor.CanTouch = false
	viewingAnchor.CanQuery = false
	viewingAnchor.CastShadow = false
	viewingAnchor.Transparency = 1
	viewingAnchor:SetAttribute("BunkerConstructionViewingAnchor", true)
	viewingAnchor:SetAttribute("ConstructionViewVersion", INSTALL_VERSION)

	bunker:SetAttribute("UnlockState", "Locked")
	bunker:SetAttribute("ConstructionStage", "Locked")
	bunker:SetAttribute("ConstructionProgress", 0)
	bunker:SetAttribute("ConstructionReadyAt", 0)
	bunker:SetAttribute("ConstructionRequestKey", "")
	bunker:SetAttribute("ConstructionControllerVersion", INSTALL_VERSION)
	bunker:SetAttribute("ConstructionLockedWorldInstalled", true)
	for _, descendant in ipairs(bunker:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		end
	end
	root:SetAttribute("WorkspaceLockedStateInstalled", true)
	root:SetAttribute("ParticleTemplateCount", 3)
	root:SetAttribute("Ready", true)
end)

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(
			recording,
			success and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
		)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("Installed Cooper bunker construction assets")
	end)
end

if not success then
	error(failure, 0)
end

print("[CooperBunkerConstructionAssets] Installed polished DumpTruck, Excavator, SkidSteer, and MobileCrane v" .. INSTALL_VERSION)
