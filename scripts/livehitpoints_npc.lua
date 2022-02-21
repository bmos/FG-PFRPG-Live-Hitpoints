--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--
--	NPC Specific Data Acquisition Functions
--

---	This function checks NPCs for feats, traits, and/or special abilities.
local function hasSpecialAbility(nodeActor, sSearchString, bFeat, bTrait, bSpecialAbility)
	if not nodeActor then
		return false;
	end

	local sLowerSpecAbil = string.lower(sSearchString);
	local sSpecialQualities = string.lower(DB.getValue(nodeActor, '.specialqualities', ''));
	local sSpecAtks = string.lower(DB.getValue(nodeActor, '.specialattacks', ''));
	local sFeats = string.lower(DB.getValue(nodeActor, '.feats', ''));

	if bFeat and sFeats:match(sLowerSpecAbil, 1) then
		local nRank = tonumber(sFeats:match(sLowerSpecAbil .. ' (%d+)', 1));
		return true, (nRank or 1);
	elseif bSpecialAbility and (sSpecAtks:match(sLowerSpecAbil, 1) or sSpecialQualities:match(sLowerSpecAbil, 1)) then
		local nRank = tonumber(sSpecAtks:match(sLowerSpecAbil .. ' (%d+)', 1) or sSpecialQualities:match(sLowerSpecAbil .. ' (%d+)', 1));
		return true, (nRank or 1);
	end

	return false
end

---	This function reports if the HD information is entered incorrectly.
--	It alerts the user and suggests that they report it on the bug report thread.
local function reportHdErrors(nodeNPC, sHd)
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
end

---	This function finds the total number of HD for the NPC.
function processHd(nodeNPC)
	local sHd = DB.getValue(nodeNPC, 'hd', '')

	-- remove potential hit dice 'total'
	-- Paizo uses format of "10 HD; 5d6+5d6+10" sometimes
	-- FG only understands this if trimmed to "5d6+5d6+10"
	sHd = string.gsub(sHd, "%d+%s-HD%;", "")

	reportHdErrors(nodeNPC, sHd)

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
		return nAbilHp, 0
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

local function getFeatBonusHp(nodeNPC, rActor, nLevel)
	local nFeatBonus = 0
	if DataCommon.isPFRPG() then
		if hasSpecialAbility(nodeNPC, "Toughness %(Mythic%)", true) then
			return nFeatBonus + ((math.max(nLevel, 3)) * 2)
		elseif hasSpecialAbility(nodeNPC, "Toughness", true) then
			return nFeatBonus + math.max(nLevel, 3)
		end
	else
		if hasSpecialAbility(nodeNPC, "Toughness", true) then
			nFeatBonus = nFeatBonus + 3
		end
		if hasSpecialAbility(nodeNPC, "Improved Toughness", true) then
			nFeatBonus = nFeatBonus + nLevel
		end
		return nFeatBonus
	end
	return 0
end

local function upgradeNpc(nodeNPC, rActor, nLevel, nCalculatedAbilHp, nHdAbilHp)
	local nHpTotal = DB.getValue(nodeNPC, 'hp', 0)
	
	-- house rule compatibility for rolling NPC hitpoints or using max
	local sOptHRNH = OptionsManager.getOption('HRNH');
	local sHD = StringManager.trim(DB.getValue(nodeNPC, 'hd', ''))
	if sOptHRNH == 'max' and sHD ~= '' then
		sHD = string.gsub(sHD, "%d+%s-HD%;", "")
		nHpTotal = DiceManager.evalDiceString(sHD, true, true)
	elseif sOptHRNH == 'random' and sHD ~= '' then
		sHD = string.gsub(sHD, "%d+%s-HD%;", "")
		nHpTotal = math.max(DiceManager.evalDiceString(sHD, true), 1)
	end
	
	local nRolledHp = nHpTotal - nHdAbilHp
	local nMiscMod = nHdAbilHp - nCalculatedAbilHp - getFeatBonusHp(nodeNPC, rActor, nLevel)

	DB.setValue(nodeNPC, 'livehp.rolled', 'number', nRolledHp)
	DB.setValue(nodeNPC, 'livehp.misc', 'number', nMiscMod)
end

local function getAbilityBonusUsed(nodeNPC, rActor, nLevel, nAbilHp)
	local sAbility = DB.getValue(nodeNPC, 'livehp.abilitycycler', '')
	if sAbility == '' then
		if string.find(string.lower(DB.getValue(nodeNPC, 'type', '')), 'undead', 1) and DataCommon.isPFRPG() then
			sAbility = 'charisma'
			DB.setValue(nodeNPC, 'livehp.abilitycycler', 'string', sAbility)
		elseif DB.getValue(nodeNPC, 'type', '') ~= '' then
			sAbility = 'constitution'
			DB.setValue(nodeNPC, 'livehp.abilitycycler', 'string', sAbility)
		end
	end
	
	local nAbilityMod = math.floor((DB.getValue(nodeNPC, sAbility, 0) - 10) / 2)
	local nEffectBonus = math.floor((EffectManager35EDS.getEffectsBonus(rActor, {DataCommon.ability_ltos[sAbility]}, true) or 0) / 2)

	if DB.getValue(nodeNPC, 'livehp.rolled', 0) == 0 then
		if not DB.getValue(nodeNPC, 'livehp.total') or nodeNPC.getParent().getNodeName() == "npc" then
			upgradeNpc(nodeNPC, rActor, nLevel, (nAbilityMod * nLevel) or 0, nAbilHp)
		end
	end

	return ((nAbilityMod + nEffectBonus) * nLevel) or 0
end

--
--	Set NPC HP
--

function setHpTotal(rActor)
	local nodeNPC = ActorManager.getCreatureNode(rActor)
	local nHdAbilHp, nLevel = processHd(nodeNPC)
	local nTotalHp = LiveHP.calculateHp(nodeNPC, rActor, getAbilityBonusUsed(nodeNPC, rActor, nLevel or 0, nHdAbilHp), getFeatBonusHp(nodeNPC, rActor, nLevel or 0))

	DB.setValue(nodeNPC, 'hp', 'number', nTotalHp)
end

--
--	Triggering Functions
--

---	This function is called when effect components are changed.
--	First, it makes sure the triggering actor is not a PC and that the effect is relevant to this extension.
--	Then, it calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('....'))
	if not ActorManager.isPC(rActor) and LiveHP.checkEffectRelevance(node.getChild('..')) then
		setHpTotal(rActor)
	end
end

---	This function is called when effects are removed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectRemoved(node)
	local rActor = ActorManager.resolveActor(node.getChild('..'))
	if not ActorManager.isPC(rActor) then
		setHpTotal(rActor)
	end
end

---	This function watches for changes in the database and triggers various functions.
--	It only runs on the host machine.
function onInit()
	if Session.IsHost then
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.label'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.isactive'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects'), 'onChildDeleted', onEffectRemoved)
	end
end
