--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals onValueChanged

function onValueChanged()
    if super and super.onValueChanged then super.onValueChanged(); end
    local rActor = ActorManager.resolveActor(window.getDatabaseNode())
    PCLiveHP.setHpTotal(rActor)
end