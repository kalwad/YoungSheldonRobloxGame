--!strict
-- Source of truth for the restored, original four-character Cooper NPC system.
-- This module is an install/audit manifest; the original dialogue scripts read
-- the published image and audio StringValues directly.

local Config = {}

Config.SchemaVersion = 3
Config.ControllerVersion = "2026-07-13.simple-four.1"
Config.WorldName = "CooperFamilyNPCs"
Config.NPCServerName = "CooperFamilyNPCs"
Config.DialogueServerName = "CooperFamilyDialogue"
Config.DialogueClientName = "CooperFamilyDialogue"
Config.ImageFolderName = "CooperFamilyLocalImages"
Config.AudioFolderName = "CooperFamilyLocalAudio"

-- This deliberately stays false. Panic/chase/brisket state does not belong in
-- the onboarding version of the game.
Config.PanicEnabled = false

Config.Proximity = {
	EnterDistance = 10,
	ExitDistance = 14,
	CooldownSeconds = 18,
}

export type CharacterDefinition = {
	id: string,
	imageId: number,
	width: number,
	height: number,
	walkSpeed: number,
	home: string,
	route: { string },
	proximityScript: string,
	catchphraseName: string,
	catchphraseId: number,
	dialogueAudio: { [string]: number },
}

-- Each catchphrase is reserved exclusively for that character's one-per-
-- approach proximity reaction. Every other clip is used only after the player
-- selects a dialogue option (or ends that character's conversation).
Config.Characters = {
	{
		id = "George",
		imageId = 114737318979057,
		width = 4.0,
		height = 6.0,
		walkSpeed = 4.5,
		home = "GeorgeChair",
		route = { "GeorgeChair", "Den", "Kitchen", "Dining", "Hall" },
		proximityScript = "CooperGeorgeProximityVoice",
		catchphraseName = "HotDamn",
		catchphraseId = 123587414049600,
		dialogueAudio = {
			AGoodBrisket = 83799592017776,
			WhoLeftRefrigerator = 77786599263011,
			PutRemoteBack = 79289776680372,
			IfSomethingMakingNoise = 110699898244221,
			FinishYourChores = 86681083705753,
			NowYouSee = 92827583667865,
			GeorgeYouDog = 137266157082120,
		},
	},
	{
		id = "Mary",
		imageId = 109845379583984,
		width = 3.6,
		height = 5.8,
		walkSpeed = 4.8,
		home = "Kitchen",
		route = { "Kitchen", "Dining", "FormalLiving", "Hall", "Bathroom" },
		proximityScript = "CooperMaryProximityVoice",
		catchphraseName = "LordHaveMercy",
		catchphraseId = 85333334351253,
		dialogueAudio = {
			LordGiveMe = 96261582298800,
			NobodyLeaves = 74277047579153,
			SheldonBeingSmartest = 105238678332525,
			DinnerAtSix = 72778934811250,
			LoveAllMyChildren = 83916155499190,
			ALittleFaith = 92621439030547,
			MaryYouDawg = 87205834602411,
		},
	},
	{
		id = "Missy",
		imageId = 105870837764920,
		width = 3.3,
		height = 5.2,
		walkSpeed = 5.6,
		home = "TwinsRoom",
		route = { "TwinsRoom", "Hall", "FormalLiving", "Den" },
		proximityScript = "CooperMissyProximityVoice",
		catchphraseName = "IncrediblySmart",
		catchphraseId = 133768516435257,
		dialogueAudio = {
			Didntbreakit = 132524119731260,
			maybegenius = 134693608661947,
			DoingHomework = 95241176659394,
			BeingGrounded = 106400282660497,
			BlameGeorgie = 113609143900900,
			OffSwitch = 80869016081796,
			MissyYouDog = 89936197729584,
		},
	},
	{
		id = "Georgie",
		imageId = 137011952735257,
		width = 3.7,
		height = 5.9,
		walkSpeed = 5.1,
		home = "GeorgieRoom",
		route = { "GeorgieRoom", "Hall", "FrontPorch", "Driveway", "Garage" },
		proximityScript = "CooperGeorgieProximityVoice",
		catchphraseName = "AnotherDay",
		catchphraseId = 122044176484695,
		dialogueAudio = {
			IfTheresMoney = 113602911214128,
			SchooAintEverything = 135695367961036,
			FixATire = 92431553856417,
			IfDadAsks = 82235614960589,
			ALittleConfidence = 115120211151919,
			DontWorryMama = 131193040290388,
			GeorgieYouDog = 132776099262271,
		},
	},
} :: { CharacterDefinition }

return table.freeze(Config)
