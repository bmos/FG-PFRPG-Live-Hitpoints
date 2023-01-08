--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
--
--	Set PC HP
--
--	luacheck: globals setHpTotal
function setHpTotal(rActor)
	local nodePC = ActorManager.getCreatureNode(rActor)
	local nLevel = DB.getValue(nodePC, 'level', 0)

	---	This function finds the relevant ability and gets the total number of hitpoints it provides.
	--	It uses ability modifier and character level for this determination.
	--	It also contains a little compatibility code to handle people upgrading from old versions of this extension.
	local function getAbilityBonusUsed()
		-- update old data format to new unified format
		local function updateData()
			local oldValue = DB.getValue(nodePC, 'hp.statused')
			if oldValue then
				DB.deleteChild(nodePC, 'hp.statused')
				DB.setValue(nodePC, 'livehp.abilitycycler', 'string', oldValue)
			end
		end

		updateData()

		local function getAbility()
			local sAbility = DB.getValue(nodePC, 'livehp.abilitycycler', '')
			if sAbility == '' then
				sAbility = 'constitution'
				DB.setValue(nodePC, 'livehp.abilitycycler', 'string', sAbility)
			end
			return sAbility, DB.getValue(nodePC, 'abilities.' .. sAbility .. '.bonus', 0)
		end

		local sAbility, nAbilityMod = getAbility()

		local nEffectBonus = math.floor((EffectManager35EDS.getEffectsBonus(rActor, { DataCommon.ability_ltos[sAbility] }, true) or 0) / 2)

		local function upgradePc()
			local nRolledHp = DB.getValue(nodePC, 'hp.total', 0) - (nAbilityMod * nLevel)

			DB.setValue(nodePC, 'livehp.rolled', 'number', nRolledHp)
		end

		if DB.getValue(nodePC, 'livehp.rolled', 0) == 0 then
			if not DB.getValue(nodePC, 'livehp.total') then upgradePc() end
		end

		return ((nAbilityMod + nEffectBonus) * nLevel) or 0
	end

	local function getFeatBonusHp()
		local nFeatBonus = 0
		if DataCommon.isPFRPG() then
			local function getFeatBonusPFRPG()
				if CharManager.hasFeat(nodePC, 'Toughness (Mythic)', true) then
					nFeatBonus = math.max(nLevel, 3) * 2
				elseif CharManager.hasFeat(nodePC, 'Toughness', true) then
					nFeatBonus = math.max(nLevel, 3)
				end
			end

			getFeatBonusPFRPG()
		else
			local function getFeatBonus35E()
				if CharManager.hasFeat(nodePC, 'Toughness', true) then nFeatBonus = nFeatBonus + 3 end
				if CharManager.hasFeat(nodePC, 'Improved Toughness', true) then nFeatBonus = nFeatBonus + nLevel end
			end

			getFeatBonus35E()
		end

		return nFeatBonus
	end

	DB.setValue(nodePC, 'hp.total', 'number', LiveHP.calculateHp(nodePC, rActor, getAbilityBonusUsed(), getFeatBonusHp()))
end

--
--	Triggering Functions
--

---	This function is called when effect components are changed.
--	First, it checks if the triggering actor is a PC and whether the effect is relevant to this extension.
--	Then, it calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectChanged(node)
	local rActor = ActorManager.resolveActor(DB.getChild(node, '....'))
	if ActorManager.isPC(rActor) and LiveHP.checkEffectRelevance(DB.getChild(node, '..')) then setHpTotal(rActor) end
end

---	This function is called when effects are removed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectRemoved(node)
	local rActor = ActorManager.resolveActor(DB.getChild(node, '..'))
	if ActorManager.isPC(rActor) then setHpTotal(rActor) end
end

---	This function is called when ability score components are changed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onAbilityChanged(node)
	local rActor = ActorManager.resolveActor(DB.getChild(node, '....'))
	setHpTotal(rActor)
end

---	This function is called when feats are added or renamed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onFeatsChanged(node)
	local rActor = ActorManager.resolveActor(DB.getChild(node, '....'))
	setHpTotal(rActor)
end

function onInit()
	local applyClassStats_old
	local function applyClassStats_new(nodeChar, nodeClass, nodeSource, nLevel, nTotalLevel, ...)
		applyClassStats_old(nodeChar, nodeClass, nodeSource, nLevel, nTotalLevel, ...)

		local sClassLookup = StringManager.strip(DB.getValue(nodeClass, 'name', ''))

		local function getHD()
			local sHD = StringManager.trim(DB.getValue(nodeSource, 'hitdie', ''))
			if DataCommon.classdata[sClassLookup:lower()] and not sHD:match('^%d?d%d+') then sHD = DataCommon.classdata[sClassLookup:lower()].hd end
			return sHD
		end

		local sHD = getHD()

		-- Hit points
		local sHDMult, sHDSides = sHD:match('^(%d?)d(%d+)')
		if sHDSides then
			local nHDMult = tonumber(sHDMult) or 1
			local nHDSides = tonumber(sHDSides) or 8
			local rActor = ActorManager.resolveActor(nodeChar)

			local function calculateHpFromHd()
				local nHP = DB.getValue(nodeChar, 'livehp.rolled', 0)
				if nTotalLevel == 1 then
					local nAddHP = (nHDMult * nHDSides)
					nHP = nAddHP
				elseif OptionsManager.getOption('LURHP') == 'on' then
					-- preparing for rolling of hitpoints on level-up
					local sMsg = string.format(Interface.getString('char_message_classhppromptroll'), 'd' .. nHDSides, sClassLookup, rActor.sName)
					ChatManager.SystemMessage(sMsg)
				else
					local nAddHP = math.floor(((nHDMult * (nHDSides + 1)) / 2) + 0.5)
					nHP = nHP + nAddHP
				end
				return nHP
			end
			local nHP = calculateHpFromHd()

			DB.setValue(nodeChar, 'livehp.rolled', 'number', nHP)
			setHpTotal(rActor)
		end
	end

	applyClassStats_old = CharManager.applyClassStats
	CharManager.applyClassStats = applyClassStats_new

	local onFavoredClassBonusSelect_old
	local function onFavoredClassBonusSelect_new(aSelection, rFavoredClassBonusSelect, ...)
		if #aSelection == 0 then return end

		for k, v in ipairs(aSelection) do
			if v == Interface.getString('char_value_favoredclasshpbonus') then
				local nodeChar = rFavoredClassBonusSelect.nodeChar
				DB.setValue(nodeChar, 'livehp.misc', 'number', DB.getValue(nodeChar, 'livehp.misc', 0) + 1)
				setHpTotal(ActorManager.resolveActor(nodeChar))
				aSelection[k] = nil
			end
		end

		onFavoredClassBonusSelect_old(aSelection, rFavoredClassBonusSelect, ...)
	end

	onFavoredClassBonusSelect_old = CharManager.onFavoredClassBonusSelect
	CharManager.onFavoredClassBonusSelect = onFavoredClassBonusSelect_new

	local function setHandlers()
		if Session.IsHost then
			DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonus'), 'onUpdate', onAbilityChanged)
			DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonusmodifier'), 'onUpdate', onAbilityChanged)
			DB.addHandler(DB.getPath('charsheet.*.abilities.*.damage'), 'onUpdate', onAbilityChanged)

			DB.addHandler(DB.getPath('charsheet.*.featlist.*.name'), 'onUpdate', onFeatsChanged)

			DB.addHandler(DB.getPath(CombatManager.CT_COMBATANT_PATH .. '.effects.*.label'), 'onUpdate', onEffectChanged)
			DB.addHandler(DB.getPath(CombatManager.CT_COMBATANT_PATH .. '.effects.*.isactive'), 'onUpdate', onEffectChanged)
			DB.addHandler(DB.getPath(CombatManager.CT_COMBATANT_PATH .. '.effects'), 'onChildDeleted', onEffectRemoved)
		end
	end

	setHandlers()
end
