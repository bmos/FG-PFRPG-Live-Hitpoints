-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function finds the total number of HD for the NPC.
--	If the HD information is entered incorrectly, it alerts the user and suggests that they report it on the bug report thread.
function processHd(nodeNPC)
	local sHd = DB.getValue(nodeNPC, 'hd', '')
	
	local sError = ''
	local sHdErrorEnd = string.find(sHd, '%)', 1)
	if not sHdErrorEnd then sHdErrorEnd = string.find(sHd, '%;', 1) end
	if not sHdErrorEnd then sHdErrorEnd = string.find(sHd, 'planar', 1) end
	if not sHdErrorEnd then sHdErrorEnd = string.find(sHd, 'profane', 1) end
	if not sHdErrorEnd then sHdErrorEnd = string.find(sHd, 'sacred', 1) end
	
	if string.find(sHd, 'regeneration', 1) then sError = 'regeneration' end
	if string.find(sHd, 'fast-healing', 1) then sError = 'fast healing' end
	if string.find(sHd, 'fast healing', 1) then sError = 'fast healing' end
	
	local bErrorAlerted = (DB.getValue(nodeNPC, 'erroralerted') == 1)
	
	local sNpcName = DB.getValue(nodeNPC, 'name', '')

	if (sNpcName ~= '') and sHdErrorEnd and DataCommon.isPFRPG() and not bErrorAlerted then
		sHd = string.sub(sHd, 1, sHdErrorEnd - 1)
		ChatManager.SystemMessage(string.format(Interface.getString('npc_hd_error_pf1e'), sNpcName))
		if (sError ~= '') then ChatManager.SystemMessage(string.format(Interface.getString('npc_hd_error_type'), sError, sError)) end
		DB.setValue(nodeNPC, 'erroralerted', 'number', 1)
	elseif (sNpcName ~= '') and sHdErrorEnd and not bErrorAlerted then
		ChatManager.SystemMessage(string.format(Interface.getString('npc_hd_error_generic'), sNpcName))
		if (sError ~= '') then ChatManager.SystemMessage(string.format(Interface.getString('npc_hd_error_type'), sError, sError)) end
		DB.setValue(nodeNPC, 'erroralerted', 'number', 1)
	end

	sHd = sHd .. '+'		-- ending plus
	local tHd = {}			-- table to collect fields
	local fieldstart = 1
	repeat
		local nexti = string.find(sHd, '+', fieldstart)
		table.insert(tHd, string.sub(sHd, fieldstart, nexti-1))
		fieldstart = nexti + 1
	until fieldstart > string.len(sHd)

	local nAbilHp = 0

	if (tHd == {}) or (tHd[1] == '') then
		return nAbilHp
	end
	
	local nHdCount = 0
	for _,v in ipairs(tHd) do
		if string.find(v, 'd', 1) then
			local nHdEndPos = string.find(v, 'd', 1)
			local nHd = tonumber(string.sub(v, 1, nHdEndPos-1))
			if nHd then nHdCount = nHdCount + nHd end
		elseif not string.match(v, '%D', 1) then
			nAbilHp = nAbilHp + v
		end
	end
	
	return nAbilHp, nHdCount
end

---	Get the bonus to the npc's ability mod from effects in combat tracker
local function getAbilEffects(nodeNPC)
	local rActor = ActorManager.getActor('npc', nodeNPC)

	local sAbilNameUsed = DB.getValue(nodeNPC, 'hpabilused', '')
	local sAbilUsed = 'CON'

	if sAbilNameUsed == 'strength' then sAbilUsed = 'STR' end
	if sAbilNameUsed == 'dexterity' then sAbilUsed = 'DEX' end
	if sAbilNameUsed == '' then sAbilNameUsed = 'constitution' end
	if sAbilNameUsed == 'intelligence' then sAbilUsed = 'INT' end
	if sAbilNameUsed == 'wisdom' then sAbilUsed = 'WIS' end
	if sAbilNameUsed == 'charisma' then sAbilUsed = 'CHA' end
	
	local nAbilFromEffects = EffectManagerLHFC.getEffectsBonus(rActor, sAbilUsed, true)

	return sAbilUsed, sAbilNameUsed, nAbilFromEffects
end

---	This function checks for Toughness and could easilly be expanded to check for other feats.
local function getFeats(nodeNPC)
	local sFeats = string.lower(DB.getValue(nodeNPC, 'feats', ''))
	
	local bToughness = false
	if string.find(sFeats, 'toughness') then bToughness = true end
	
	return bToughness
end

---	This function calculates the total Hp from the selected ability.
--	To do this, it gets the NPC's total HD from processHd(), the relevant ability mod, any effects (served by getAbilEffects()), and whether the NPC has the Toughness feat.
function calculateAbilHp(nodeNPC)
	local nAbilHp, nHdCount = processHd(nodeNPC)
	if not nHdCount then nHdCount = 0 end

	local sAbilUsed, sAbilNameUsed, nAbilFromEffects = getAbilEffects(nodeNPC)
	local nAbilBase = DB.getValue(nodeNPC, sAbilNameUsed, 0)
	local nAbilScore = nAbilBase + nAbilFromEffects
	local nAbilScoreBonus = (nAbilScore - 10) / 2

	local nFeatBonus = 0
	
	local bToughness = getFeats(nodeNPC)
	if bToughness then nFeatBonus = (math.max(nHdCount, 3)) end

	local nMiscBonus = DB.getValue(nodeNPC, 'hpfromabilbak', 0)

	local rActor = ActorManager.getActor('npc', nodeNPC)
	local nMaxHPBonus = HpFromCon.getHPEffects(rActor)

	return math.floor((nAbilScoreBonus * nHdCount) + nFeatBonus + nMiscBonus + nMaxHPBonus)
end

---	This function combines the rolled HP with the ability-calculated HP and writes it to the field.
local function calculateTotalHp(nodeNPC)
	local nAbilHp = DB.getValue(nodeNPC, 'hpfromabil', 0)
	local nHdHp = DB.getValue(nodeNPC, 'hpfromhd', 0)
	
	DB.setValue(nodeNPC, 'hp', 'number', nHdHp + nAbilHp)
end

---	This function gets the total HP from the selected ability from calculateAbilHp() and writes it to the field.
--	Then, it triggers calculateTotalHp()
function setAbilHp(nodeNPC)
	local nHdHp = DB.getValue(nodeNPC, 'hpfromhd', 0)
	if nHdHp == 0 then
		local sType = DB.getValue(nodeNPC, 'type', '')
		if string.find(sType, 'undead', 1) and DataCommon.isPFRPG() then
			DB.setValue(nodeNPC, 'hpabilused', 'string', 'charisma')
		end

		local nHpTotal = DB.getValue(nodeNPC, 'hp', 0)
		
		-- house rule compatibility for rolling NPC hitpoints or using max
		local sHD = StringManager.trim(DB.getValue(nodeNPC, 'hd', ''))
		local sOptHRNH = OptionsManager.getOption('HRNH')
		if sOptHRNH == 'max' and sHD ~= '' then
			nHpTotal = StringManager.evalDiceString(sHD, true, true)
		elseif sOptHRNH == 'random' and sHD ~= '' then
			nHpTotal = math.max(StringManager.evalDiceString(sHD, true), 1)
		end
		
		local nAbilHp = processHd(nodeNPC)
		local nCalcAbilHp = calculateAbilHp(nodeNPC)
		local nMiscMod = nAbilHp - nCalcAbilHp

		DB.setValue(nodeNPC, 'hpfromabilbak', 'number', nMiscMod)
		DB.setValue(nodeNPC, 'hpfromhd', 'number', nHpTotal - nAbilHp)
		DB.setValue(nodeNPC, 'hpfromabil', 'number', nAbilHp)
	else
		local nAbilHp = calculateAbilHp(nodeNPC)

		DB.setValue(nodeNPC, 'hpfromabil', 'number', nAbilHp)
		
		calculateTotalHp(nodeNPC)
	end
end