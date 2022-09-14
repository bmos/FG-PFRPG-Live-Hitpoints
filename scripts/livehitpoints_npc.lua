--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
--
--	NPC Specific Data Acquisition Functions
--
---	This function checks NPCs for feats, traits, and/or special abilities.
--	luacheck: no unused args
local function hasSpecialAbility(nodeActor, sSearchString, bFeat, bTrait, bSpecialAbility)
	if not nodeActor then return false; end

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
	local sNpcName = DB.getValue(nodeNPC, 'name', '');
	local sHdErrorEnd = sHd:find('%)', 1) or sHd:find('%;', 1) or sHd:find('planar', 1) or sHd:find('profane', 1) or sHd:find('sacred', 1);
	if sHdErrorEnd and DB.getValue(nodeNPC, 'erroralerted') ~= 1 and sNpcName ~= '' then
		if DataCommon.isPFRPG() then
			ChatManager.SystemMessage(string.format(Interface.getString('npc_hd_error_pf1e'), sNpcName));
		else
			ChatManager.SystemMessage(string.format(Interface.getString('npc_hd_error_generic'), sNpcName));
		end
		DB.setValue(nodeNPC, 'erroralerted', 'number', 1);
	end
end

---	This function finds the total number of HD for the NPC.
--	luacheck: globals processHd
function processHd(nodeNPC)
	local sHd = DB.getValue(nodeNPC, 'hd', ''):gsub('%d+%s-HD;', ''):gsub(';.+', '')
	reportHdErrors(nodeNPC, sHd)

	sHd = sHd .. '+' -- ending plus
	local tHd = {} -- table to collect fields
	local fieldstart = 1
	repeat
		local nexti = string.find(sHd, '+', fieldstart)
		table.insert(tHd, string.sub(sHd, fieldstart, nexti - 1))
		fieldstart = nexti + 1
	until fieldstart > string.len(sHd)

	local nAbilHp, nHdCount = 0, 0
	if not tHd[1] or (tHd[1] == '') then return nAbilHp, nHdCount end

	for _, v in ipairs(tHd) do
		if string.find(v, 'd', 1) then
			local nHdEndPos = string.find(v, 'd', 1)
			local nHd = tonumber(string.sub(v, 1, nHdEndPos - 1))
			if nHd then nHdCount = nHdCount + nHd end
		elseif string.match(v, '%d', 1) then
			nAbilHp = nAbilHp + v
		end
	end

	return nAbilHp, nHdCount
end

local function getFeatBonusHp(nodeNPC, nLevel)
	local nFeatBonus = 0
	if DataCommon.isPFRPG() then
		if hasSpecialAbility(nodeNPC, 'Toughness %(Mythic%)', true) then
			nFeatBonus = nFeatBonus + (math.max(nLevel, 3)) * 2
		elseif hasSpecialAbility(nodeNPC, 'Toughness', true) then
			nFeatBonus = nFeatBonus + math.max(nLevel, 3)
		end
	else
		if hasSpecialAbility(nodeNPC, 'Toughness', true) then nFeatBonus = nFeatBonus + 3 end
		if hasSpecialAbility(nodeNPC, 'Improved Toughness', true) then nFeatBonus = nFeatBonus + nLevel end
	end
	return nFeatBonus
end

local function getRolled(nodeNPC)
	local nRolled = DB.getValue(nodeNPC, 'livehp.rolled');

	local sHD = DB.getValue(nodeNPC, 'hd', ''):gsub('%d+%s-HD%;', ''):gsub(';.+', '')
	sHD = StringManager.trim(sHD:gsub('[+-]%s*%d+', ''))
	if sHD ~= '' then
		local sOptHRNH = OptionsManager.getOption('HRNH');
		if sOptHRNH == 'max' then
			nRolled = DiceManager.evalDiceString(sHD, true, true)
		elseif sOptHRNH == 'random' then
			nRolled = math.max(DiceManager.evalDiceString(sHD, true), 1)
		end
	end

	return nRolled
end

local function guessAbility(nodeNPC)
	local nAbilModOverride
	local sAbility = DB.getValue(nodeNPC, 'livehp.abilitycycler', '')
	if sAbility == '' then
		local sType = string.lower(DB.getValue(nodeNPC, 'type', ''))
		if sType:match('undead') and DataCommon.isPFRPG() then
			sAbility = 'charisma'
			DB.setValue(nodeNPC, 'livehp.abilitycycler', 'string', sAbility)
		elseif sType:match('construct') and DataCommon.isPFRPG() then
			nAbilModOverride = 0
		elseif sType ~= '' then
			sAbility = 'constitution'
			DB.setValue(nodeNPC, 'livehp.abilitycycler', 'string', sAbility)
		else
			sAbility = 'constitution'
		end
	end
	return sAbility, nAbilModOverride
end

local function getAbilityBonusUsed(rActor, nLevel)
	local nodeNPC = ActorManager.getCreatureNode(rActor)

	local sAbility, nAbilModOverride = guessAbility(nodeNPC)
	local nAbilityMod = ActorManager35E.getAbilityBonus(rActor, sAbility)
	local nEffectBonus = ActorManager35E.getAbilityEffectsBonus(rActor, sAbility)
	if nAbilModOverride then nAbilityMod = nAbilModOverride; end

	return ((nAbilityMod + nEffectBonus) * nLevel) or 0
end

local function upgradeNpc(rActor, nAbil, nCalcAbil, nLevel)
	local nodeNPC = ActorManager.getCreatureNode(rActor)

	local nRolledHp = DB.getValue(nodeNPC, 'hp', 0) - nAbil
	DB.setValue(nodeNPC, 'livehp.rolled', 'number', nRolledHp)

	local nMiscMod = nAbil - nCalcAbil - getFeatBonusHp(nodeNPC, nLevel)
	DB.setValue(nodeNPC, 'livehp.misc', 'number', nMiscMod)
end

--
--	Set NPC HP
--

--	luacheck: globals setHpTotal
function setHpTotal(rActor, bOnAdd)
	local nodeNPC = ActorManager.getCreatureNode(rActor)
	local nAbil, nLevel = processHd(nodeNPC)
	local nCalcAbil = getAbilityBonusUsed(rActor, nLevel)

	if DB.getValue(nodeNPC, 'livehp.total', 0) == 0 then
		upgradeNpc(rActor, nAbil, nCalcAbil, nLevel)
	end

	-- reroll rolled hp if adding npc to combat
	if bOnAdd then DB.setValue(nodeNPC, 'livehp.rolled', 'number', getRolled(nodeNPC)); end

	local nTotalHp = LiveHP.calculateHp(nodeNPC, rActor, nCalcAbil, getFeatBonusHp(nodeNPC, nLevel))
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
	if not ActorManager.isPC(rActor) and LiveHP.checkEffectRelevance(node.getChild('..')) then setHpTotal(rActor) end
end

---	This function is called when effects are removed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectRemoved(node)
	local rActor = ActorManager.resolveActor(node.getChild('..'))
	if not ActorManager.isPC(rActor) then setHpTotal(rActor) end
end

---	This function watches for changes in the database and triggers various functions.
--	It only runs on the host machine.
function onInit()

	---	This function is called when NPCs are added to the combat tracker.
	--	First, it calls the original addNPC function.
	--	Then, it recalculates the hitpoints after the NPC has been added.
	local addNPC_old -- placeholder for original addNPC function
	local function addNPC_new(tCustom, ...)
		addNPC_old(tCustom, ...) -- call original function

		setHpTotal(ActorManager.resolveActor(tCustom['nodeCT']), true)
	end

	addNPC_old = CombatRecordManager.addNPC
	CombatRecordManager.addNPC = addNPC_new

	if Session.IsHost then
		DB.addHandler(DB.getPath(CombatManager.CT_COMBATANT_PATH .. '.effects.*.label'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_COMBATANT_PATH .. '.effects.*.isactive'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_COMBATANT_PATH .. '.effects'), 'onChildDeleted', onEffectRemoved)
	end
end
