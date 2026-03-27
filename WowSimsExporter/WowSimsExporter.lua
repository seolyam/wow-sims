-- Author      : generalwrex (Natop on Myzrael TBC)
-- Create Date : 1/28/2022 9:30:08 AM

WowSimsExporter = LibStub("AceAddon-3.0"):NewAddon("WowSimsExporter", "AceConsole-3.0", "AceEvent-3.0")


WowSimsExporter.Character = ""
WowSimsExporter.Link = "https://wowsims.github.io/wotlk/"

local AceGUI = LibStub("AceGUI-3.0")
local LibParse = LibStub("LibParse")
local orderedTalentCache = {}

local version = "2.3"

local defaults = {
	profile = {
		--updateGearChange = true,
	},
}

local options = { 
	name = "WowSimsExporter",
	handler = WowSimsExporter,
	type = "group",
	args = {
		--updateGearChange = {
			--type = "toggle",
			--name = "Update on Gear Change",
			--desc = "Update your data when you change gear pieces.",
			--get = "isGearChangeSet",
			--set = "setGearChange"
		--},
		openExporterButton = {
			type = "execute",
			name = "Open Exporter Window",
			desc = "Opens the exporter window",
			func = function() WowSimsExporter:CreateWindow() end
		},
	},
}


function WowSimsExporter:CreateCharacterStructure(unit)
    local name, realm = UnitName(unit)
    local locClass, engClass, locRace, engRace, gender, name, server = GetPlayerInfoByGUID(UnitGUID(unit))
    local level = UnitLevel(unit)

    self.Character = {
        name = name,
        realm = realm,
        race = engRace:gsub( "Scourge", "Undead"), -- hack? lol
        class = engClass:lower(),
		level = tonumber(level),
        talents = "",
		glyphs = { major = { }, minor = { } }, --wotlk
        professions = { }, --{ name = "", level = "" }, --wotlk
		spec  =  self:CheckCharacterSpec(engClass:lower()),
        gear = { items = { } } 
	}

    return self.Character
end

function WowSimsExporter:CreateGlyphEntry()
	local minor = {}
	local major = {}

    for t = 1, 6 do

		local enabled, glyphType, glyphTooltipIndex, glyphSpellID, icon = GetGlyphSocketInfo(t);
		local link = GetGlyphLink(t);

		if(enabled) then	
			local name = link and string.match(link, "Glyph of .+]")
			if(name) then
				local formattedName = name:gsub('%]', '')

				if(glyphType == 1 ) then-- major
					table.insert(major, formattedName)
				elseif(glyphType == 2 ) then -- minor
					table.insert(minor, formattedName)
				end
			end

		end
		self.Character.glyphs.major = major
		self.Character.glyphs.minor = minor
	
    end

end


function tInvert(tbl)
    local inverted = {};
    for k, v in pairs(tbl) do
	inverted[v] = k;
    end
    return inverted;
end

function WowSimsExporter:CreateProfessionEntry()
	local names = WowSimsExporter.professionNames
	local names_inv = tInvert(names)
	local professions = {}
 
	for i = 1, GetNumSkillLines() do
		local name, _, _, skillLevel = GetSkillLineInfo(i)
		if names_inv[name] then
			table.insert(professions, { name = name, level = skillLevel })		
		end
	end
	self.Character.professions = professions
end

function WowSimsExporter:CreateTalentEntry()
    local talents = {}

    local numTabs = GetNumTalentTabs()
    for t = 1, numTabs do
        local numTalents = GetNumTalents(t)
        for i = 1, numTalents do
	    local nameTalent, icon, tier, column, currRank, maxRank = GetTalentInfo(t, i)
            table.insert(talents, tostring(currRank))
        end
        if (t < 3) then
            table.insert(talents, "-")
        end
    end

    return table.concat(talents)
end

function WowSimsExporter:GetTalentTreePoints(tabIndex)
	local points = 0
	local numTalents = GetNumTalents(tabIndex) or 0

	for i = 1, numTalents do
		local _, _, _, _, currRank = GetTalentInfo(tabIndex, i)
		points = points + (tonumber(currRank) or 0)
	end

	return points
end

function WowSimsExporter:CheckCharacterSpec(class)

	local specs = self.specializations

	local T1 = self:GetTalentTreePoints(1)
	local T2 = self:GetTalentTreePoints(2)
	local T3 = self:GetTalentTreePoints(3)

	local spec = ""

	for i, character in ipairs(specs) do	
		if character then				
			if (character.class == class) then																			
				if character.comparator(T1,T2,T3) then
					spec = character.spec											
					break
				end		
			end																
		end
	end	
	return spec
end

function WowSimsExporter:OpenWindow(input)
    if not input or input:trim() == "" then
		self:CreateWindow()
	elseif (input == "open") then
		self:CreateWindow()
	elseif (input == "export") then        
        self:CreateWindow(true)
	elseif (input == "rawr") then
		self:CreateWindow(true, "rawr")
    elseif (input=="options") then           
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    end
end

function WowSimsExporter:GetGearEnchantGems(type)
    local gear = {}

	local slotNames = WowSimsExporter.slotNames

    for slotNum = 1, #slotNames do
		local slotName = slotNames[slotNum]

		-- WotLK sims importer does not currently map ammo as a regular gear item.
		if slotName ~= "AmmoSlot" then
			local slotId = GetInventorySlotInfo(slotName)
        local itemLink = GetInventoryItemLink("player", slotId)

        if itemLink then
			local Id, Enchant, Gem1, Gem2, Gem3, Gem4 = self:ParseItemLink(itemLink)
			local gems = {}

			for gemIndex = 1, 4 do
				local _, gemLink = GetItemGem(itemLink, gemIndex)
				if gemLink then
					local gemId = tonumber(string.match(gemLink, "item:(%d+)"))
					if gemId and gemId > 0 then
						table.insert(gems, gemId)
					end
				end
			end

			if #gems == 0 then
				for _, gemId in ipairs({Gem1, Gem2, Gem3, Gem4}) do
					local parsedGemId = tonumber(gemId)
					if parsedGemId and parsedGemId > 0 then
						table.insert(gems, parsedGemId)
					end
				end
			end

			local item = {}
			item.id = tonumber(Id)
			item.enchant = tonumber(Enchant)
			item.gems = gems
			gear[slotNum] = item
        end
		end
    end
	self.Character.spec = self:CheckCharacterSpec(self.Character.class)
	self.Character.talents = self:CreateTalentEntry()
	self:CreateGlyphEntry() -- wotlk
	self:CreateProfessionEntry() -- wotlk
	self.Character.gear.items = gear

    return self.Character
end


function WowSimsExporter:ParseItemLink(itemLink)
    local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, Name =
        string.find(
        itemLink,
        "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?"
    )
    return Id, Enchant, Gem1, Gem2, Gem3, Gem4
end

function WowSimsExporter:XmlEscape(value)
	if not value then return "" end
	return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
end

function WowSimsExporter:GetRawrRegionName()
	local portal = GetCVar("portal")
	if portal then
		portal = string.upper(portal)
		if portal == "US" or portal == "EU" or portal == "KR" or portal == "TW" or portal == "CN" then
			return portal
		end
	end
	return "US"
end

function WowSimsExporter:GetRawrClassName(class)
	local classMap = {
		warrior = "Warrior",
		paladin = "Paladin",
		hunter = "Hunter",
		rogue = "Rogue",
		priest = "Priest",
		deathknight = "DeathKnight",
		shaman = "Shaman",
		mage = "Mage",
		warlock = "Warlock",
		druid = "Druid",
	}

	return classMap[class] or "Warrior"
end

function WowSimsExporter:GetRawrRaceName(race)
	local raceMap = {
		human = "Human",
		orc = "Orc",
		dwarf = "Dwarf",
		nightelf = "NightElf",
		undead = "Undead",
		tauren = "Tauren",
		gnome = "Gnome",
		troll = "Troll",
		bloodelf = "BloodElf",
		draenei = "Draenei",
	}

	local normalized = string.lower((race or "")):gsub("[%s%-']", "")
	if normalized == "scourge" then normalized = "undead" end

	return raceMap[normalized] or "Human"
end

function WowSimsExporter:GetRawrProfessionName(name)
	local profMap = {
		Blacksmithing = "Blacksmithing",
		Leatherworking = "Leatherworking",
		Alchemy = "Alchemy",
		Herbalism = "Herbalism",
		Mining = "Mining",
		Tailoring = "Tailoring",
		Engineering = "Engineering",
		Enchanting = "Enchanting",
		Skinning = "Skinning",
		Jewelcrafting = "Jewelcrafting",
		Inscription = "Inscription",
	}

	return profMap[name] or "None"
end

function WowSimsExporter:GetRawrModelAndCalculation(class, spec)
	local model = "DPS"
	local calculation = "Overall Points"

	if class == "deathknight" then
		if spec == "blood" then
			model = "TankDK"
			calculation = "Survival"
		else
			model = "DPSDK"
			calculation = "DPS"
		end
	elseif class == "druid" then
		if spec == "balance" then
			model = "Moonkin"
			calculation = "DPS"
		elseif spec == "feral" then
			model = "Cat"
			calculation = "DPS"
		end
	elseif class == "hunter" then
		model = "Hunter"
		calculation = "DPS"
	elseif class == "mage" then
		model = "Mage"
		calculation = "DPS"
	elseif class == "paladin" then
		if spec == "protection" then
			model = "ProtPaladin"
			calculation = "Survival"
		elseif spec == "retribution" then
			model = "Retribution"
			calculation = "DPS"
		else
			model = "Healadin"
			calculation = "HPS"
		end
	elseif class == "priest" then
		if spec == "shadow" then
			model = "ShadowPriest"
			calculation = "DPS"
		else
			model = "HolyPriest"
			calculation = "HPS"
		end
	elseif class == "rogue" then
		model = "Rogue"
		calculation = "DPS"
	elseif class == "shaman" then
		if spec == "enhancement" then
			model = "Enhance"
			calculation = "DPS"
		elseif spec == "elemental" then
			model = "Elemental"
			calculation = "DPS"
		else
			model = "RestoSham"
			calculation = "HPS"
		end
	elseif class == "warlock" then
		model = "Warlock"
		calculation = "DPS"
	elseif class == "warrior" then
		if spec == "protection" then
			model = "ProtWarr"
			calculation = "Survival"
		else
			model = "DPSWarr"
			calculation = "DPS"
		end
	end

	return model, calculation
end

function WowSimsExporter:GetRawrPrimarySecondaryProfessions()
	local profs = {}
	for _, prof in ipairs(self.Character.professions or {}) do
		if prof and prof.name then
			table.insert(profs, { name = prof.name, level = tonumber(prof.level) or 0 })
		end
	end

	table.sort(profs, function(a, b)
		if a.level == b.level then
			return a.name < b.name
		end
		return a.level > b.level
	end)

	local p1 = self:GetRawrProfessionName(profs[1] and profs[1].name)
	local p2 = self:GetRawrProfessionName(profs[2] and profs[2].name)

	if p1 == "None" then p2 = "None" end
	if p1 == p2 then p2 = "None" end

	return p1, p2
end

function WowSimsExporter:GetCurrentOrderedTalentRanks()
	if not orderedTalentCache or not orderedTalentCache[1] then
		orderedTalentCache = {}
		for tab = 1, GetNumTalentTabs() do
			local temp = {}
			local products = {}
			for i = 1, GetNumTalents(tab) do
				local _, _, tier, column = GetTalentInfo(tab, i)
				local product = (tier - 1) * 4 + column
				temp[product] = i
				table.insert(products, product)
			end

			table.sort(products)
			orderedTalentCache[tab] = {}
			for idx, product in ipairs(products) do
				orderedTalentCache[tab][idx] = temp[product]
			end
		end
	end

	local ranks = {}

	for tab = 1, GetNumTalentTabs() do
		local numTalents = GetNumTalents(tab)
		for i = 1, numTalents do
			local currRank
			if orderedTalentCache and orderedTalentCache[tab] and orderedTalentCache[tab][i] then
				local _, _, _, _, rank = self:GetOrderedTalentInfo(tab, i)
				currRank = rank
			else
				local _, _, _, _, rank = GetTalentInfo(tab, i)
				currRank = rank
			end

			table.insert(ranks, tonumber(currRank) or 0)
		end
	end

	return ranks
end

function WowSimsExporter:GetActiveGlyphSpellIds()
	local glyphIds = {}

	for socketId = 1, 6 do
		local enabled, _, _, glyphSpellID = GetGlyphSocketInfo(socketId)
		local glyphSpellNumeric = tonumber(glyphSpellID)
		if enabled and glyphSpellNumeric and glyphSpellNumeric > 0 then
			glyphIds[socketId] = glyphSpellNumeric
		else
			glyphIds[socketId] = 0
		end
	end

	return glyphIds
end

function WowSimsExporter:BuildRawrGlyphDataString(targetLength)
	targetLength = tonumber(targetLength) or 0
	if targetLength <= 0 then
		return ""
	end

	local glyphIds = self:GetActiveGlyphSpellIds()
	local parts = {}

	for socketId = 1, 6 do
		parts[#parts + 1] = string.format("%05d", tonumber(glyphIds[socketId]) or 0)
	end

	local glyphData = table.concat(parts)

	if string.len(glyphData) < targetLength then
		glyphData = glyphData .. string.rep("0", targetLength - string.len(glyphData))
	elseif string.len(glyphData) > targetLength then
		glyphData = string.sub(glyphData, 1, targetLength)
	end

	return glyphData
end

function WowSimsExporter:BuildRawrTalentString(template, requiredDigitsBeforeSeparator)
	local ranks = self:GetCurrentOrderedTalentRanks()
	local prefixTemplate, suffixTemplate = string.match(template or "", "^(%d+)%.(%d+)$")

	if not prefixTemplate then
		prefixTemplate = tostring(template or "")
		suffixTemplate = ""
	end

	local targetPrefixLength = tonumber(requiredDigitsBeforeSeparator) or string.len(prefixTemplate)
	local prefixParts = {}

	for i = 1, targetPrefixLength do
		local rank = ranks[i]
		if rank ~= nil then
			prefixParts[i] = tostring(rank)
		else
			local templateDigit = string.sub(prefixTemplate, i, i)
			if templateDigit ~= "" and templateDigit >= "0" and templateDigit <= "9" then
				prefixParts[i] = templateDigit
			else
				prefixParts[i] = "0"
			end
		end
	end

	local prefix = table.concat(prefixParts)
	local suffix = self:BuildRawrGlyphDataString(string.len(suffixTemplate or ""))

	return prefix .. "." .. suffix
end

function WowSimsExporter:GetResolvedGemItemIds(itemLink, gem1, gem2, gem3, gem4)
	local gems = {}

	for gemIndex = 1, 4 do
		local _, gemLink = GetItemGem(itemLink, gemIndex)
		if gemLink then
			local gemId = tonumber(string.match(gemLink, "item:(%d+)"))
			if gemId and gemId > 0 then
				table.insert(gems, gemId)
			end
		end
	end

	if #gems == 0 then
		for _, parsedGem in ipairs({gem1, gem2, gem3, gem4}) do
			local gemId = tonumber(parsedGem)
			if gemId and gemId > 0 then
				table.insert(gems, gemId)
			end
		end
	end

	return gems
end

function WowSimsExporter:BuildRawrItemInstanceString(itemLink)
	local id, enchant, gem1, gem2, gem3, gem4 = self:ParseItemLink(itemLink)
	local gems = self:GetResolvedGemItemIds(itemLink, gem1, gem2, gem3, gem4)

	local g1 = gems[1] or 0
	local g2 = gems[2] or 0
	local g3 = gems[3] or 0

	local itemId = tonumber(id) or 0
	local enchantId = tonumber(enchant) or 0

	-- Rawr ItemInstance parser expects: itemId.gem1.gem2.gem3.enchantId
	return string.format("%d.%d.%d.%d.%d", itemId, g1, g2, g3, enchantId)
end

function WowSimsExporter:BuildRawrAvailableItemString(itemLink)
	local _, _, itemId, enchantId, gem1Id, gem2Id, gem3Id = string.find(itemLink, "item:(%-?%d+):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)")
	if not itemId then
		return nil
	end

	local gems = self:GetResolvedGemItemIds(itemLink, gem1Id, gem2Id, gem3Id, 0)

	local g1 = gems[1] or 0
	local g2 = gems[2] or 0
	local g3 = gems[3] or 0

	local id = tonumber(itemId) or 0
	local enchant = tonumber(enchantId) or 0

	return string.format("%d.%d.%d.%d.%d", id, g1, g2, g3, enchant)
end

function WowSimsExporter:BuildRawrAvailableBaseItemString(itemLink)
	local _, _, itemId = string.find(itemLink, "item:(%-?%d+):")
	if not itemId then
		return nil
	end

	return tostring(tonumber(itemId) or 0)
end

function WowSimsExporter:IsRawrEquippableItem(itemLink)
	if not itemLink then
		return false
	end

	local equipLocation = select(9, GetItemInfo(itemLink))
	if equipLocation and equipLocation ~= "" then
		return true
	end

	return false
end

function WowSimsExporter:GetAvailableItemsXML()
	local uniqueItems = {}
	local lines = {}

	local function addAvailableItem(itemLink)
		if not self:IsRawrEquippableItem(itemLink) then
			return
		end

		local fullItemString = self:BuildRawrAvailableItemString(itemLink)
		if fullItemString and not uniqueItems[fullItemString] then
			uniqueItems[fullItemString] = true
		end

		local baseItemString = self:BuildRawrAvailableBaseItemString(itemLink)
		if baseItemString and not uniqueItems[baseItemString] then
			uniqueItems[baseItemString] = true
		end
	end

	for slotId = 1, 19 do
		local itemLink = GetInventoryItemLink("player", slotId)
		if itemLink then
			addAvailableItem(itemLink)
		end
	end

	local orderedItems = {}
	for itemString in pairs(uniqueItems) do
		table.insert(orderedItems, itemString)
	end
	table.sort(orderedItems)

	for _, itemString in ipairs(orderedItems) do
		table.insert(lines, "  <AvailableItems>" .. itemString .. "</AvailableItems>")
	end

	return lines
end

function WowSimsExporter:GetRawrAvailableItemsXmlLines()
	return self:GetAvailableItemsXML()
end

function WowSimsExporter:GetRawrSlotItems()
	local slotMap = {
		HeadSlot = "Head",
		NeckSlot = "Neck",
		ShoulderSlot = "Shoulders",
		BackSlot = "Back",
		ChestSlot = "Chest",
		WristSlot = "Wrist",
		HandsSlot = "Hands",
		WaistSlot = "Waist",
		LegsSlot = "Legs",
		FeetSlot = "Feet",
		Finger0Slot = "Finger1",
		Finger1Slot = "Finger2",
		Trinket0Slot = "Trinket1",
		Trinket1Slot = "Trinket2",
		MainHandSlot = "MainHand",
		SecondaryHandSlot = "OffHand",
		RangedSlot = "Ranged",
		AmmoSlot = "Projectile",
	}

	local rawrSlots = {}

	for _, slotName in ipairs(self.slotNames) do
		local rawrSlotName = slotMap[slotName]
		if rawrSlotName then
			local slotId = GetInventorySlotInfo(slotName)
			local itemLink = GetInventoryItemLink("player", slotId)
			if itemLink then
				rawrSlots[rawrSlotName] = self:BuildRawrItemInstanceString(itemLink)
			end
		end
	end

	return rawrSlots
end

function WowSimsExporter:GetRawrDefaultTalentStrings()
	return {
		WarriorTalents = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000.0000000000000000000000000000000000",
		PaladinTalents = "0000000000000000000000000000000000000000000000000000000000000000000000000000.0000000000000000000000000000000000",
		HunterTalents = "000000000000000000000000000000000000000000000000000000000000000000000000000000.000000000000000000000000000000000",
		RogueTalents = "0000000000000000000000000000000000000000000000000000000000000000000000000000000.0000000000000000000000000000000000",
		PriestTalents = "0000000000000000000000000000000000000000000000000000000000000000000000000000000.000000000000000000000000000000000",
		ShamanTalents = "00000000000000000000000000000000000000000000000000000000000000000000000000000.00000000000000000000000000000",
		MageTalents = "000000000000000000000000000000000000000000000000000000000000000000000000000000000.0000000000000000000",
		WarlockTalents = "000000000000000000000000000000000000000000000000000000000000000000000000000000.00000000000000000",
		DruidTalents = "000000000000000000000000000000000000000000000000000000000000000000000000000000000.0000000000000000000000000",
		DeathKnightTalents = "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.000000000000000000000000000000000",
	}
end

function WowSimsExporter:BuildRawrCharacterXml()
	self.Character = self:GetGearEnchantGems("player")

	local char = self.Character
	local className = self:GetRawrClassName(char.class)
	local raceName = self:GetRawrRaceName(char.race)
	local regionName = self:GetRawrRegionName()
	local primaryProfession, secondaryProfession = self:GetRawrPrimarySecondaryProfessions()
	local rawrModel, rawrCalculation = self:GetRawrModelAndCalculation(char.class, char.spec)
	local slotItems = self:GetRawrSlotItems()
	local talentStrings = self:GetRawrDefaultTalentStrings()

	local classTalentTagMap = {
		warrior = "WarriorTalents",
		paladin = "PaladinTalents",
		hunter = "HunterTalents",
		rogue = "RogueTalents",
		priest = "PriestTalents",
		deathknight = "DeathKnightTalents",
		shaman = "ShamanTalents",
		mage = "MageTalents",
		warlock = "WarlockTalents",
		druid = "DruidTalents",
	}

	local talentTag = classTalentTagMap[char.class]
	if talentTag and talentStrings[talentTag] then
		if char.class == "deathknight" then
			talentStrings[talentTag] = self:BuildRawrTalentString(talentStrings[talentTag], 88)
		else
			talentStrings[talentTag] = self:BuildRawrTalentString(talentStrings[talentTag])
		end
	end

	local lines = {
		'<?xml version="1.0" encoding="utf-8"?>',
		'<Character xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
		'  <Name>' .. self:XmlEscape(char.name) .. '</Name>',
		'  <Realm>' .. self:XmlEscape(char.realm) .. '</Realm>',
		'  <Region>' .. regionName .. '</Region>',
		'  <Race>' .. raceName .. '</Race>',
		'  <Class>' .. className .. '</Class>',
		'  <CurrentModel>' .. self:XmlEscape(rawrModel) .. '</CurrentModel>',
		'  <Model>' .. self:XmlEscape(rawrModel) .. '</Model>',
		'  <CalculationToOptimize>' .. self:XmlEscape(rawrCalculation) .. '</CalculationToOptimize>',
		'  <EnforceMetagemRequirements>false</EnforceMetagemRequirements>',
	}

	for _, tagName in ipairs({
		"Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
		"Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand", "Ranged", "Projectile", "ProjectileBag"
	}) do
		local itemString = slotItems[tagName]
		if itemString then
			table.insert(lines, '  <' .. tagName .. '>' .. itemString .. '</' .. tagName .. '>')
		end
	end

	table.insert(lines, '  <CustomGemmingTemplates />')
	table.insert(lines, '  <GemmingTemplateOverrides />')

	local bossLines = {
		'  <Boss>',
		'    <Targets />',
		'    <Moves />',
		'    <Stuns />',
		'    <Fears />',
		'    <Roots />',
		'    <Disarms />',
		'    <Name>Generic</Name>',
		'    <Content>T7_0</Content>',
		'    <Instance>None</Instance>',
		'    <Version>V_10N</Version>',
		'    <Comment>No comments have been written for this Boss.</Comment>',
		'    <Level>83</Level>',
		'    <Armor>10643</Armor>',
		'    <BerserkTimer>480</BerserkTimer>',
		'    <SpeedKillTimer>180</SpeedKillTimer>',
		'    <Health>1000000</Health>',
		'    <InBackPerc_Melee>0</InBackPerc_Melee>',
		'    <InBackPerc_Ranged>0</InBackPerc_Ranged>',
		'    <Max_Players>10</Max_Players>',
		'    <Min_Healers>3</Min_Healers>',
		'    <Min_Tanks>2</Min_Tanks>',
		'    <DoTs />',
		'    <Attacks />',
		'    <Resist_Physical>0</Resist_Physical>',
		'    <Resist_Frost>0</Resist_Frost>',
		'    <Resist_Fire>0</Resist_Fire>',
		'    <Resist_Nature>0</Resist_Nature>',
		'    <Resist_Arcane>0</Resist_Arcane>',
		'    <Resist_Shadow>0</Resist_Shadow>',
		'    <Resist_Holy>0</Resist_Holy>',
		'    <TimeBossIsInvuln>0</TimeBossIsInvuln>',
		'    <InBack>false</InBack>',
		'    <MultiTargs>false</MultiTargs>',
		'    <StunningTargs>false</StunningTargs>',
		'    <MovingTargs>false</MovingTargs>',
		'    <FearingTargs>false</FearingTargs>',
		'    <RootingTargs>false</RootingTargs>',
		'    <DisarmingTargs>false</DisarmingTargs>',
		'    <DamagingTargs>false</DamagingTargs>',
		'    <Under35Perc>0.1</Under35Perc>',
		'    <Under20Perc>0.15</Under20Perc>',
		'    <FilterType>Content</FilterType>',
		'    <Filter />',
		'    <BossName />',
		'  </Boss>',
	}

	for _, line in ipairs(bossLines) do
		table.insert(lines, line)
	end

	for _, tagName in ipairs({
		"WarriorTalents", "PaladinTalents", "HunterTalents", "RogueTalents", "PriestTalents",
		"ShamanTalents", "MageTalents", "WarlockTalents", "DruidTalents", "DeathKnightTalents"
	}) do
		table.insert(lines, '  <' .. tagName .. '>' .. talentStrings[tagName] .. '</' .. tagName .. '>')
	end

	table.insert(lines, '  <CustomItemInstances />')
	table.insert(lines, '  <PrimaryProfession>' .. primaryProfession .. '</PrimaryProfession>')
	table.insert(lines, '  <SecondaryProfession>' .. secondaryProfession .. '</SecondaryProfession>')

	local availableItemsLines = self:GetRawrAvailableItemsXmlLines()
	for _, availableItemLine in ipairs(availableItemsLines) do
		table.insert(lines, availableItemLine)
	end

	table.insert(lines, '</Character>')

	return table.concat(lines, "\n")
end

function WowSimsExporter:OnInitialize()

	self.db = LibStub("AceDB-3.0"):New("WSEDB", defaults, true)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("WowSimsExporter", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WowSimsExporter", "WowSimsExporter")

	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("WowSimsExporter_Profiles", profiles)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WowSimsExporter_Profiles", "Profiles", "WowSimsExporter")

    self:RegisterChatCommand("wse", "OpenWindow")
    self:RegisterChatCommand("wowsimsexporter", "OpenWindow")
    self:RegisterChatCommand("wsexporter", "OpenWindow")

    self:Print("WowSimsExporter v" .. version .. " Initialized. use /wse For Window.")

end


-- UI
function WowSimsExporter:BuildLinks(frame, character)
	local specs = self.specializations
	local supportedsims =  self.supportedSims 
	local class = character.class
	local spec  = character.spec

	if table.contains(supportedsims, class) then

		for i, char in ipairs(specs) do
			if char and char.class == class and char.spec == spec then

				local link = WowSimsExporter.prelink..(char.url)..WowSimsExporter.postlink

				local l = AceGUI:Create("InteractiveLabel")
				l:SetText("Click to copy: "..link.."\r\n")
				l:SetFullWidth(true)
				l:SetCallback("OnClick", function()		
					WowSimsExporter:CreateCopyDialog(link)
				end)
				frame:AddChild(l)
			end
		end
	end
end


function WowSimsExporter:CreateCopyDialog(text)

	local frame = AceGUI:Create("Frame")
	frame:SetTitle("WSE Copy Dialog")
    frame:SetStatusText("Use CTRL+C to copy link")
    frame:SetLayout("Flow")
	frame:SetWidth(400)
	frame:SetHeight(100)
	frame:SetCallback(
        "OnClose",
        function(widget)
            AceGUI:Release(widget)
        end
    )

	local editbox = AceGUI:Create("EditBox")
    editbox:SetText(text)
    editbox:SetFullWidth(true)
    editbox:DisableButton(true)

	editbox:SetFocus()
	editbox:HighlightText()
	
	frame:AddChild(editbox)

end

function WowSimsExporter:CreateWindow(generate, exportType)

	local char = self:CreateCharacterStructure("player")
	
    local frame = AceGUI:Create("Frame")
    frame:SetCallback(
        "OnClose",
        function(widget)
            AceGUI:Release(widget)
        end
    )
    frame:SetTitle("WowSimsExporter V" .. version .. "")
	frame:SetStatusText("Choose an export format and generate data")
    frame:SetLayout("Flow")


    local jsonbox = AceGUI:Create("MultiLineEditBox")
    jsonbox:SetLabel("Copy the generated export data")
    jsonbox:SetFullWidth(true)
    jsonbox:SetFullHeight(true)
    jsonbox:DisableButton(true)
   
	local function l_GenerateWowSims()
		WowSimsExporter.Character = WowSimsExporter:GetGearEnchantGems("player")
		jsonbox:SetText(LibParse:JSONEncode(WowSimsExporter.Character)) 
		jsonbox:HighlightText()
		jsonbox:SetFocus()

		frame:SetStatusText("WowSims JSON generated")
	end

	local function l_GenerateRawr()
		jsonbox:SetText(WowSimsExporter:BuildRawrCharacterXml())
		jsonbox:HighlightText()
		jsonbox:SetFocus()

		frame:SetStatusText("Rawr XML generated")
	end

	if generate and exportType == "rawr" then
		l_GenerateRawr()
	elseif generate then
		l_GenerateWowSims()
	end

	local wowSimsButton = AceGUI:Create("Button")
	wowSimsButton:SetText("Generate WowSims JSON")
	wowSimsButton:SetWidth(200)
	wowSimsButton:SetCallback("OnClick", function()
		l_GenerateWowSims()
	end)

	local rawrButton = AceGUI:Create("Button")
	rawrButton:SetText("Generate Rawr XML")
	rawrButton:SetWidth(200)
	rawrButton:SetCallback("OnClick", function()
		l_GenerateRawr()
	end)
	
	
	local icon = AceGUI:Create("Icon")
	icon:SetImage("Interface\\AddOns\\wowsimsexporter\\Skins\\wowsims.tga") 
	icon:SetImageSize(32, 32)
	icon:SetFullWidth(true)


    local label = AceGUI:Create("Label")
	label:SetFullWidth(true)
    label:SetText([[

To upload your character to the simuator, click on the url below that leads to the simuator website.

You will find an Import button on the top right of the simulator named "Import". Click that and select the "Addon" tab, paste the data
into the provided box and click "Import"

]])

	frame:AddChild(icon)

	if table.contains(self.supportedSims, char.class) then
		frame:AddChild(label)
		WowSimsExporter:BuildLinks(frame, char)
	else
		local unsupportedLabel = AceGUI:Create("Label")
		unsupportedLabel:SetText("WowSims links are unavailable for this class, but Rawr XML export is still available.")
		unsupportedLabel:SetColor(255,0,0)
		unsupportedLabel:SetFullWidth(true)
		frame:AddChild(unsupportedLabel)
	end

	frame:AddChild(wowSimsButton)
	frame:AddChild(rawrButton)
	frame:AddChild(jsonbox)

end
-- Borrowed from rating buster!!
-- As of Classic Patch 3.4.0, GetTalentInfo indices no longer correlate
-- to their positions in the tree. Building a talent cache ordered by
-- tier then column allows us to replicate the previous behavior.
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("SPELLS_CHANGED")
	f:SetScript("OnEvent", function()
		local temp = {}
		for tab = 1, GetNumTalentTabs() do
			temp[tab] = {}
			local products = {}
			for i = 1,GetNumTalents(tab) do
				local name, _, tier, column = GetTalentInfo(tab,i)
				local product = (tier - 1) * 4 + column
				temp[tab][product] = i
				table.insert(products, product)
			end

			table.sort(products)

			orderedTalentCache[tab] = {}
			local j = 1
			for _, product in ipairs(products) do
				orderedTalentCache[tab][j] = temp[tab][product]
				j = j + 1
			end
		end
		f:UnregisterEvent("SPELLS_CHANGED")
	end)
end

function WowSimsExporter:GetOrderedTalentInfo(tab, num)
	return GetTalentInfo(tab, orderedTalentCache[tab][num])
end



function WowSimsExporter:OnEnable()
end

function WowSimsExporter:OnDisable()
end

function WowSimsExporter:isGearChangeSet(info)
	return self.db.profile.updateGearChange
end

function WowSimsExporter:setGearChange(info, value)
	self.db.profile.updateGearChange = value
end
