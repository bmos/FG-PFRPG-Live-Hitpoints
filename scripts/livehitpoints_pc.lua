--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--
--	PC Specific Data Acquisition Functions
--

---	This function checks PCs for feats, traits, and/or special abilities.
local function hasSpecialAbility(nodeActor, sSearchString, bFeat, bTrait, bSpecialAbility)
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

local function upgradePc(nodePC, rActor, nLevel, nAbilityMod)
	local nHpTotal = DB.getValue(nodePC, 'hp.total', 0)
	local nRolledHp = nHpTotal - (nAbilityMod * nLevel)

	DB.setValue(nodePC, 'livehp.rolled', 'number', nRolledHp)
end

local function getFeatBonusHp(nodePC, rActor, nLevel)
	local nFeatBonus = 0
	if DataCommon.isPFRPG() then
		if hasSpecialAbility(nodePC, "Toughness %(Mythic%)", true) then
			return nFeatBonus + (math.max(nLevel, 3) * 2)
		elseif hasSpecialAbility(nodePC, "Toughness", true) then
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

---	This function finds the relevant ability and gets the total number of hitpoints it provides.
--	It uses ability modifier and character level for this determination.
--	It also contains a little compatibility code to handle people upgrading from old versions of this extension.
local function getAbilityBonusUsed(nodePC, rActor, nLevel)
	-- update old data format to new unified format
	local oldValue = DB.getValue(nodePC, 'hp.statused')
	if oldValue then DB.deleteNode(nodePC.getChild('hp.statused')); DB.setValue(nodePC, 'livehp.abilitycycler', 'string', oldValue) end
	-- end compatibility block
	
	local sAbility = DB.getValue(nodePC, 'livehp.abilitycycler', '')	
	if sAbility == '' then
		sAbility = 'constitution'
		DB.setValue(nodePC, 'livehp.abilitycycler', 'string', sAbility)
	end
	
	local nAbilityMod = DB.getValue(nodePC, 'abilities.' .. sAbility .. '.bonus', 0)
	local nEffectBonus = math.floor((EffectManager35EDS.getEffectsBonus(rActor, {DataCommon.ability_ltos[sAbility]}, true) or 0) / 2)

	if DB.getValue(nodePC, 'livehp.rolled', 0) == 0 then
		local nHdHp = DB.getValue(nodePC, 'hp.hdhp', 0)
		if nHdHp ~= 0 then
			DB.setValue(nodePC, 'livehp.rolled', 'number', nHdHp - getFeatBonusHp(nodePC, rActor, nLevel))
			if nodePC.getChild('hp.hdhp') then DB.deleteNode(nodePC.getChild('hp.hdhp')) end
			if nodePC.getChild('hp.bonushp') then DB.deleteNode(nodePC.getChild('hp.bonushp')) end
			if nodePC.getChild('hp.livehpused') then DB.deleteNode(nodePC.getChild('hp.livehpused')) end
		else
			upgradePc(nodePC, rActor, nLevel, nAbilityMod)
		end
	end

	return ((nAbilityMod + nEffectBonus) * nLevel) or 0
end

--
--	Set PC HP
--

function setHpTotal(rActor)
	local nodePC = ActorManager.getCreatureNode(rActor)
	local nLevel = DB.getValue(nodePC, 'level', 0)
	local nTotalHp = LiveHP.calculateHp(nodePC, rActor, getAbilityBonusUsed(nodePC, rActor, nLevel), getFeatBonusHp(nodePC, rActor, nLevel))
	DB.setValue(nodePC, 'hp.total', 'number', nTotalHp)
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
		setHpTotal(rActor)
	end
end

---	This function is called when character level is changed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onLevelChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('..'))
	setHpTotal(rActor)
	local sPcName = DB.getValue(node.getChild('..'), 'name', '')
	ChatManager.SystemMessage(string.format(Interface.getString('livehp_pc_levelup'), sPcName))	
end

---	This function is called when effects are removed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectRemoved(node)
	local rActor = ActorManager.resolveActor(node.getChild('..'))
	if ActorManager.isPC(rActor) then
		setHpTotal(rActor)
	end
end

---	This function is called when ability score components are changed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onAbilityChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('....'))
	setHpTotal(rActor)
end

---	This function is called when feats are added or renamed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onFeatsChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('....'))
	setHpTotal(rActor)
end

local applyClassStats_old = nil
function applyClassStats_new(nodeChar, nodeClass, nodeSource, nLevel, nTotalLevel)
	applyClassStats_old(nodeChar, nodeClass, nodeSource, nLevel, nTotalLevel)

	local sHD = StringManager.trim(DB.getValue(nodeSource, "hitdie", ""));
	if DataCommon.classdata[sClassLookup] and not sHD:match("^%d?d%d+") then
		sHD = DataCommon.classdata[sClassLookup].hd;
	end
	
	-- Hit points
	local sHDMult, sHDSides = sHD:match("^(%d?)d(%d+)");
	if sHDSides then
		local nHDMult = tonumber(sHDMult) or 1;
		local nHDSides = tonumber(sHDSides) or 8;

		local nHP = DB.getValue(nodeChar, "livehp.rolled", 0);
		if nTotalLevel == 1 then
			local nAddHP = (nHDMult * nHDSides);
			nHP = nHP + nAddHP;
		elseif OptionsManager.getOption('LURHP') == 'on' then
			-- preparing for rolling of hitpoints on level-up
		else
			local nAddHP = math.floor(((nHDMult * (nHDSides + 1)) / 2) + 0.5);
			nHP = nHP + nAddHP;
		end
		DB.setValue(nodeChar, "livehp.rolled", "number", nHP);
		local rActor = ActorManager.resolveActor(nodeChar)
		setHpTotal(rActor)
	end

end

---	This function watches for changes in the database and triggers various functions.
--	It only runs on the host machine.
function onInit()
	if Session.IsHost then
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonus'), 'onUpdate', onAbilityChanged)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonusmodifier'), 'onUpdate', onAbilityChanged)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.damage'), 'onUpdate', onAbilityChanged)
		
		DB.addHandler(DB.getPath('charsheet.*.featlist.*.name'), 'onUpdate', onFeatsChanged)
		DB.addHandler(DB.getPath('charsheet.*.level'), 'onUpdate', onLevelChanged)

		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.label'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.isactive'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects'), 'onChildDeleted', onEffectRemoved)
	end
	applyClassStats_old = CharManager.applyClassStats
	CharManager.applyClassStats = applyClassStats_new
end

function onClose()
	CharManager.applyClassStats = applyClassStats_old
end