--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--
--	PC Specific Data Acquisition Functions
--

---	This function checks PCs for feats, traits, and special abilities.
function hasSpecialAbility(nodeActor, sSearchString, bFeat, bTrait, bSpecialAbility)
	if not nodeActor then
		return false;
	end

	local sLowerSpecAbil = string.lower(sSearchString);
	if bFeat then
		for _,vNode in pairs(DB.getChildren(nodeActor, '.featlist')) do
			local vLowerSpecAbilName = StringManager.trim(DB.getValue(vNode, 'name', ''):lower());
			local nRank = tonumber(vLowerSpecAbilName:match(sLowerSpecAbil .. ' (%d+)', 1));
			if vLowerSpecAbilName and (nRank or vLowerSpecAbilName:match(sLowerSpecAbil, 1)) then
				return true, (nRank or 1);
			end
		end
	end
	if bTrait then
		for _,vNode in pairs(DB.getChildren(nodeActor, '.traitlist')) do
			local vLowerSpecAbilName = StringManager.trim(DB.getValue(vNode, 'name', ''):lower());
			local nRank = tonumber(vLowerSpecAbilName:match(sLowerSpecAbil .. ' (%d+)', 1));
			if vLowerSpecAbilName and (nRank or vLowerSpecAbilName:match(sLowerSpecAbil, 1)) then
				return true, (nRank or 1);
			end
		end
	end
	if bSpecialAbility then
		for _,vNode in pairs(DB.getChildren(nodeActor, '.specialabilitylist')) do
			local vLowerSpecAbilName = StringManager.trim(DB.getValue(vNode, 'name', ''):lower());
			local nRank = tonumber(vLowerSpecAbilName:match(sLowerSpecAbil .. ' (%d+)', 1));
			if vLowerSpecAbilName and (nRank or vLowerSpecAbilName:match(sLowerSpecAbil, 1)) then
				return true, (nRank or 1);
			end
		end
	end

	return false
end

function getAbilityBonusUsed(nodePC, rActor, nLevel)
	--update old data format to new unified format
	local oldValue = DB.getValue(nodePC, 'hp.statused')
	if oldValue then DB.deleteNode(nodePC.getChild('hp.statused')); DB.setValue(nodePC, 'hp.abilitycycler', 'string', oldValue) end
	
	local sAbility = DB.getValue(nodePC, 'hp.abilitycycler', '')
	if sAbility == '' then sAbility = 'constitution' end
	local nAbilityMod = DB.getValue(nodePC, 'abilities.' .. sAbility .. '.bonus', 0)
	local nAbilityDamage = math.floor(DB.getValue(nodePC, 'abilities.' .. sAbility .. '.damage', 0) / 2)
	local nEffectBonus = math.floor((EffectManager35EDS.getEffectsBonus(rActor, {'CON'}, true) or 0) / 2)

	return ((nAbilityMod - nAbilityDamage + nEffectBonus) * nLevel) or 0
end

function getFeatBonusHp(nodePC, rActor, nLevel)
	local nFeatBonus = 0
	if DataCommon.isPFRPG() then
		if hasSpecialAbility(nodePC, "Toughness", true) then
			return nFeatBonus + math.max(nLevel, 3)
		end
	else
		if hasSpecialAbility(nodePC, "Toughness", true) then
			nFeatBonus = nFeatBonus + 3
		end
		if hasSpecialAbility(nodePC, "Improved Toughness", true) then
			nFeatBonus = nFeatBonus + nLevel
		end
		return nFeatBonus
	end
	return 0
end

--
--	Triggering Functions
--

---	This function is called when effect components are changed.
--	First, it checks if the triggering actor is a PC and whether the effect is relevant to this extension.
--	Then, it calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('....'))
	if ActorManager.isPC(rActor) and LiveHP.checkEffectRelevance(node.getChild('..')) then
		local nodePC = ActorManager.getCreatureNode(rActor)
		local nLevel = DB.getValue(nodePC, 'level', 0)
		LiveHP.calculateHp(nodePC, rActor, getAbilityBonusUsed(nodePC, rActor, nLevel), getFeatBonusHp(nodePC, rActor, nLevel))
	end
end

---	This function is called when effects are removed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectRemoved(node)
	local rActor = ActorManager.resolveActor(node.getChild('..'))
	if ActorManager.isPC(rActor) then
		local nodePC = ActorManager.getCreatureNode(rActor)
		local nLevel = DB.getValue(nodePC, 'level', 0)
		LiveHP.calculateHp(nodePC, rActor, getAbilityBonusUsed(nodePC, rActor, nLevel), getFeatBonusHp(nodePC, rActor, nLevel))
	end
end

---	This function is called when ability score components are changed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onAbilityChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('....'))
	local nodePC = ActorManager.getCreatureNode(rActor)
	local nLevel = DB.getValue(nodePC, 'level', 0)
	LiveHP.calculateHp(nodePC, rActor, getAbilityBonusUsed(nodePC, rActor, nLevel), getFeatBonusHp(nodePC, rActor, nLevel))
end

---	This function is called when feats are added or renamed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onFeatsChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('....'))
	local nodePC = ActorManager.getCreatureNode(rActor)
	local nLevel = DB.getValue(nodePC, 'level', 0)
	LiveHP.calculateHp(nodePC, rActor, getAbilityBonusUsed(nodePC, rActor, nLevel), getFeatBonusHp(nodePC, rActor, nLevel))
end

---	This function watches for changes in the database and triggers various functions.
--	It only runs on the host machine.
function onInit()
	if Session.IsHost then
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonus'), 'onUpdate', onAbilityChanged)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonusmodifier'), 'onUpdate', onAbilityChanged)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.damage'), 'onUpdate', onAbilityChanged)
		
		DB.addHandler(DB.getPath('charsheet.*.featlist.*.name'), 'onUpdate', onFeatsChanged)

		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.label'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.isactive'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects'), 'onChildDeleted', onEffectRemoved)
	end
end
