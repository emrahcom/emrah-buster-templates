-- ----------------------------------------------------------------------------
-- Token Owner Party
--
-- https://github.com/emrahcom/
-- ----------------------------------------------------------------------------
-- This plugin prevents the unauthorized users to create a room and terminates
-- the conference when the owner leaves. It's designed to run with
-- token_verification and token_affiliation plugins.
--
-- 1) Copy this script to the Prosody plugins folder. It's the following folder
--    on Debian
--
--    /usr/share/jitsi-meet/prosody-plugins/
--
-- 2) Enable module in your prosody config.
--    /etc/prosody/conf.d/meet.mydomain.com.cfg.lua
--
--    Component "conference.meet.mydomain.com" "muc"
--       modules_enabled = {
--         "token_verification";
--         "token_affiliation";
--         "token_owner_party";
--
-- 3) For most scenarios you may want to disable auto-ownership on Jicofo.
--    Add the following line to /etc/jitsi/jicofo/sip-communicator.properties
--
--    org.jitsi.jicofo.DISABLE_AUTO_OWNER=true
--
-- 4) Restart the services
--
--    systemctl restart prosody.service
--    systemctl restart jicofo.service
-- ----------------------------------------------------------------------------
local TIMEOUT = 60
local LOGLEVEL = "debug"

local is_admin = require "core.usermanager".is_admin
local is_healthcheck_room = module:require "util".is_healthcheck_room
local it = require "util.iterators"
local st = require "util.stanza"
local timer = require "util.timer"
module:log(LOGLEVEL, "loaded")

local function _is_admin(jid)
    return is_admin(jid, module.host)
end

module:hook("muc-occupant-pre-join", function (event)
    local room, stanza = event.room, event.stanza
    local user_jid = stanza.attr.from
    
    if is_healthcheck_room(room.jid) or _is_admin(user_jid) then
        module:log(LOGLEVEL, "location check, %s", user_jid)
        return
    end

    local context_user = event.origin.jitsi_meet_context_user
    if context_user then
        if context_user["affiliation"] == "owner" then
            module:log(LOGLEVEL, "let the party begin")
            return
        end
    end

    local occupant_count = it.count(room:each_occupant())
    if occupant_count < 2 then
        module:log(LOGLEVEL, "the party has not started yet")
        event.origin.send(st.error_reply(stanza, 'cancel', 'not-allowed'))
        return true
    end
end)

module:hook("muc-occupant-left", function (event)
    local room, occupant = event.room, event.occupant

    if is_healthcheck_room(room.jid) or _is_admin(occupant.jid) then
        return
    end

    if room:get_affiliation(occupant.jid) ~= "owner" then
        module:log(LOGLEVEL, "a participant leaved, %s", occupant.jid)
        return
    end
    module:log(LOGLEVEL, "an owner leaved, %s", occupant.jid)

    for _, occ in room:each_occupant() do
        if not _is_admin(occ.jid) then
            if room:get_affiliation(occ.jid) == "owner" then
                module:log(LOGLEVEL, "an owner is here, %s", occ.jid)
                return
            end
        end
    end

    timer.add_task(TIMEOUT, function()
        for _, occ in room:each_occupant() do
            if not _is_admin(occ.jid) then
                if room:get_affiliation(occ.jid) == "owner" then
                    module:log(LOGLEVEL, "timer, an owner is here, %s", occ.jid)
                    return
                end
            end
        end

        module:log(LOGLEVEL, "the party finished")
	room:destroy(nil, "The owner is gone")
    end)
end)
