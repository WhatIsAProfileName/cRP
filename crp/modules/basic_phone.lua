
-- basic phone module

local lang = cRP.lang
local cfg = module("cfg/phone")
local htmlEntities = module("lib/htmlEntities")
local services = cfg.services
local announces = cfg.announces

local sanitizes = module("cfg/sanitizes")

-- api

-- Send a service alert to all service listeners
--- sender: a player or nil (optional, if not nil, it is a call request alert)
--- service_name: service name
--- x,y,z: coordinates
--- msg: alert message
function cRP.sendServiceAlert(sender, service_name,x,y,z,msg)
  local service = services[service_name]
  local answered = false
  if service then
    local players = {}
    for k,v in pairs(cRP.rusers) do
      local player = cRP.getUserSource(tonumber(k))
      -- check user
      if cRP.hasPermission(k,service.alert_permission) and player then
        table.insert(players,player)
      end
    end

    -- send notify and alert to all listening players
    for k,v in pairs(players) do
      cRPclient._notify(v,service.alert_notify..msg)
      -- add position for service.time seconds
      local bid = cRPclient.addBlip(v,x,y,z,service.blipid,service.blipcolor,"("..service_name..") "..msg)
      SetTimeout(service.alert_time*1000,function()
        cRPclient._removeBlip(v,bid)
      end)

      -- call request
      if sender ~= nil then
        async(function()
          local ok = cRP.request(v,lang.phone.service.ask_call({service_name, htmlEntities.encode(msg)}), 30)
          if ok then -- take the call
            if not answered then
              -- answer the call
              cRPclient._notify(sender,service.answer_notify)
              cRPclient._setGPS(v,x,y)
              answered = true
            else
              cRPclient._notify(v,lang.phone.service.taken())
            end
          end
        end)
      end
    end
  end
end

-- send an sms from an user to a phone number
-- return true on success
function cRP.sendSMS(user_id, phone, msg)
  if string.len(msg) > cfg.sms_size then -- clamp sms
    sms = string.sub(msg,1,cfg.sms_size)
  end

  local identity = cRP.getUserIdentity(user_id)
  local dest_id = cRP.getUserByPhone(phone)
  if identity and dest_id then
    local dest_src = cRP.getUserSource(dest_id)
    if dest_src then
      local phone_sms = cRP.getPhoneSMS(dest_id)

      if #phone_sms >= cfg.sms_history then -- remove last sms of the table
        table.remove(phone_sms)
      end

      local from = cRP.getPhoneDirectoryName(dest_id, identity.phone).." ("..identity.phone..")"

      cRPclient._notify(dest_src,lang.phone.sms.notify({from, msg}))
      cRPclient._playAudioSource(dest_src, cfg.sms_sound, 0.5)
      table.insert(phone_sms,1,{identity.phone,msg}) -- insert new sms at first position {phone,message}
      return true
    end
  end
end

-- call from a user to a phone number
-- return true if the communication is established
function cRP.phoneCall(user_id, phone)
  local identity = cRP.getUserIdentity(user_id)
  local src = cRP.getUserSource(user_id)
  local dest_id = cRP.getUserByPhone(phone)
  if identity and dest_id then
    local dest_src = cRP.getUserSource(dest_id)
    if dest_src then
      local to = cRP.getPhoneDirectoryName(user_id, phone).." ("..phone..")"
      local from = cRP.getPhoneDirectoryName(dest_id, identity.phone).." ("..identity.phone..")"

      cRPclient._phoneHangUp(src) -- hangup phone of the caller
      cRPclient._phoneCallWaiting(src, dest_src, true) -- make caller to wait the answer

      -- notify
      cRPclient._notify(src,lang.phone.call.notify_to({to}))
      cRPclient._notify(dest_src,lang.phone.call.notify_from({from}))

      -- play dialing sound
      cRPclient._setAudioSource(src, "cRP:phone:dialing", cfg.dialing_sound, 0.5)
      cRPclient._setAudioSource(dest_src, "cRP:phone:dialing", cfg.ringing_sound, 0.5)

      local ok = false

      -- send request to called
      if cRP.request(dest_src, lang.phone.call.ask({from}), 15) then -- accepted
        cRPclient._phoneHangUp(dest_src) -- hangup phone of the receiver
        cRPclient._connectVoice(dest_src, "phone", src) -- connect voice
        ok = true
      else -- refused
        cRPclient._notify(src,lang.phone.call.notify_refused({to})) 
        cRPclient._phoneCallWaiting(src, dest_src, false) 
      end

      -- remove dialing sound
      cRPclient._removeAudioSource(src, "cRP:phone:dialing")
      cRPclient._removeAudioSource(dest_src, "cRP:phone:dialing")

      return ok
    end
  end
end

-- send an smspos from an user to a phone number
-- return true on success
function cRP.sendSMSPos(user_id, phone, x,y,z)
  local identity = cRP.getUserIdentity(user_id)
  local dest_id = cRP.getUserByPhone(phone)
  if identity and dest_id then
    local dest_src = cRP.getUserSource(dest_id)
    if dest_src then
      local from = cRP.getPhoneDirectoryName(dest_id, identity.phone).." ("..identity.phone..")"
      cRPclient._playAudioSource(dest_src, cfg.sms_sound, 0.5)
      cRPclient._notify(dest_src,lang.phone.smspos.notify({from})) -- notify
      -- add position for 5 minutes
      local bid = cRPclient.addBlip(dest_src,x,y,z,162,37,from)
      SetTimeout(cfg.smspos_duration*1000,function()
        cRPclient._removeBlip(dest_src,{bid})
      end)

      return true
    end
  end
end

-- get phone directory data table
function cRP.getPhoneDirectory(user_id)
  local data = cRP.getUserDataTable(user_id)
  if data then
    if data.phone_directory == nil then
      data.phone_directory = {}
    end

    return data.phone_directory
  else
    return {}
  end
end

-- get directory name by number for a specific user
function cRP.getPhoneDirectoryName(user_id, phone)
  local directory = cRP.getPhoneDirectory(user_id)
  for k,v in pairs(directory) do
    if v == phone then
      return k
    end
  end

  return "unknown"
end
-- get phone sms tmp table
function cRP.getPhoneSMS(user_id)
  local data = cRP.getUserTmpTable(user_id)
  if data then
    if data.phone_sms == nil then
      data.phone_sms = {}
    end

    return data.phone_sms
  else
    return {}
  end
end

-- build phone menu
local phone_menu = {name=lang.phone.title(),css={top="75px",header_color="rgba(0,125,255,0.75)"}}

local function ch_directory(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local phone_directory = cRP.getPhoneDirectory(user_id)
    -- build directory menu
    local menu = {name=choice,css={top="75px",header_color="rgba(0,125,255,0.75)"}}

    local ch_add = function(player, choice) -- add to directory
      local phone = cRP.prompt(player,lang.phone.directory.add.prompt_number(),"")
      local name = cRP.prompt(player,lang.phone.directory.add.prompt_name(),"")
      name = sanitizeString(tostring(name),sanitizes.text[1],sanitizes.text[2])
      phone = sanitizeString(tostring(phone),sanitizes.text[1],sanitizes.text[2])
      if #name > 0 and #phone > 0 then
        phone_directory[name] = phone -- set entry
        cRPclient._notify(player, lang.phone.directory.add.added())
      else
        cRPclient._notify(player, lang.common.invalid_value())
      end
    end

    local ch_entry = function(player, choice) -- directory entry menu
      -- build entry menu
      local emenu = {name=choice,css={top="75px",header_color="rgba(0,125,255,0.75)"}}

      local name = choice
      local phone = phone_directory[name] or ""

      local ch_remove = function(player, choice) -- remove directory entry
        phone_directory[name] = nil
        cRP.closeMenu(player) -- close entry menu (removed)
      end

      local ch_sendsms = function(player, choice) -- send sms to directory entry
        local msg = cRP.prompt(player,lang.phone.directory.sendsms.prompt({cfg.sms_size}),"")
        msg = sanitizeString(msg,sanitizes.text[1],sanitizes.text[2])
        if cRP.sendSMS(user_id, phone, msg) then
          cRPclient._notify(player,lang.phone.directory.sendsms.sent({phone}))
        else
          cRPclient._notify(player,lang.phone.directory.sendsms.not_sent({phone}))
        end
      end

      local ch_sendpos = function(player, choice) -- send current position to directory entry
        local x,y,z = cRPclient.getPosition(player)
        if cRP.sendSMSPos(user_id, phone, x,y,z) then
          cRPclient._notify(player,lang.phone.directory.sendsms.sent({phone}))
        else
          cRPclient._notify(player,lang.phone.directory.sendsms.not_sent({phone}))
        end
      end

      local ch_call = function(player, choice) -- call player
        if not cRP.phoneCall(user_id, phone) then
          cRPclient._notify(player,lang.phone.directory.call.not_reached({phone}))
        end
      end

      emenu[lang.phone.directory.call.title()] = {ch_call}
      emenu[lang.phone.directory.sendsms.title()] = {ch_sendsms}
      emenu[lang.phone.directory.sendpos.title()] = {ch_sendpos}
      emenu[lang.phone.directory.remove.title()] = {ch_remove}

      -- nest menu to directory
      emenu.onclose = function() ch_directory(player,lang.phone.directory.title()) end

      -- open mnu
      cRP.openMenu(player, emenu)
    end

    menu[lang.phone.directory.add.title()] = {ch_add}

    for k,v in pairs(phone_directory) do -- add directory entries (name -> number)
      menu[k] = {ch_entry,v}
    end

    -- nest directory menu to phone (can't for now)
    -- menu.onclose = function(player) cRP.openMenu(player, phone_menu) end

    -- open menu
    cRP.openMenu(player,menu)
  end
end

local function ch_sms(player, choice)
  local user_id = cRP.getUserId(player)
  if user_id then
    local phone_sms = cRP.getPhoneSMS(user_id)

    -- build sms list
    local menu = {name=choice,css={top="75px",header_color="rgba(0,125,255,0.75)"}}

    -- add sms
    for k,v in pairs(phone_sms) do
      local from = cRP.getPhoneDirectoryName(user_id, v[1]).." ("..v[1]..")"
      local phone = v[1]
      menu["#"..k.." "..from] = {function(player,choice)
        -- answer to sms
        local msg = cRP.prompt(player,lang.phone.directory.sendsms.prompt({cfg.sms_size}),"")
        msg = sanitizeString(msg,sanitizes.text[1],sanitizes.text[2])
        if cRP.sendSMS(user_id, phone, msg) then
          cRPclient._notify(player,lang.phone.directory.sendsms.sent({phone}))
        else
          cRPclient._notify(player,lang.phone.directory.sendsms.not_sent({phone}))
        end
      end, lang.phone.sms.info({from,htmlEntities.encode(v[2])})}
    end

    -- nest menu
    menu.onclose = function(player) cRP.openMenu(player, phone_menu) end

    -- open menu
    cRP.openMenu(player,menu)
  end
end

-- build service menu
local service_menu = {name=lang.phone.service.title(),css={top="75px",header_color="rgba(0,125,255,0.75)"}}

-- nest menu
service_menu.onclose = function(player) cRP.openMenu(player, phone_menu) end

local function ch_service_alert(player,choice) -- alert a service
  local service = services[choice]
  if service then
    local x,y,z = cRPclient.getPosition(player)
    local msg = cRP.prompt(player,lang.phone.service.prompt(),"")
    msg = sanitizeString(msg,sanitizes.text[1],sanitizes.text[2])
    cRPclient._notify(player,service.notify) -- notify player
    cRP.sendServiceAlert(player,choice,x,y,z,msg) -- send service alert (call request)
  end
end

for k,v in pairs(services) do
  service_menu[k] = {ch_service_alert}
end

local function ch_service(player, choice)
  cRP.openMenu(player,service_menu)
end

-- build announce menu
local announce_menu = {name=lang.phone.announce.title(),css={top="75px",header_color="rgba(0,125,255,0.75)"}}

-- nest menu
announce_menu.onclose = function(player) cRP.openMenu(player, phone_menu) end

local function ch_announce_alert(player,choice) -- alert a announce
  local announce = announces[choice]
  local user_id = cRP.getUserId(player)
  if announce and user_id then
    if not announce.permission or cRP.hasPermission(user_id,announce.permission) then
      local msg = cRP.prompt(player,lang.phone.announce.prompt(),"")
      msg = sanitizeString(msg,sanitizes.text[1],sanitizes.text[2])
      if string.len(msg) > 10 and string.len(msg) < 1000 then
        if announce.price <= 0 or cRP.tryPayment(user_id, announce.price) then -- try to pay the announce
          cRPclient._notify(player, lang.money.paid({announce.price}))

          msg = htmlEntities.encode(msg)
          msg = string.gsub(msg, "\n", "<br />") -- allow returns

          -- send announce to all
          local users = cRP.getUsers()
          for k,v in pairs(users) do
            cRPclient._announce(v,announce.image,msg)
          end
        else
          cRPclient._notify(player, lang.money.not_enough())
        end
      else
        cRPclient._notify(player, lang.common.invalid_value())
      end
    else
      cRPclient._notify(player, lang.common.not_allowed())
    end
  end
end

for k,v in pairs(announces) do
  announce_menu[k] = {ch_announce_alert,lang.phone.announce.item_desc({v.price,v.description or ""})}
end

local function ch_announce(player, choice)
  cRP.openMenu(player,announce_menu)
end

local function ch_hangup(player, choice)
  cRPclient._phoneHangUp(player)
end

phone_menu[lang.phone.directory.title()] = {ch_directory,lang.phone.directory.description()}
phone_menu[lang.phone.sms.title()] = {ch_sms,lang.phone.sms.description()}
phone_menu[lang.phone.service.title()] = {ch_service,lang.phone.service.description()}
phone_menu[lang.phone.announce.title()] = {ch_announce,lang.phone.announce.description()}
phone_menu[lang.phone.hangup.title()] = {ch_hangup,lang.phone.hangup.description()}

-- phone menu static builder after 10 seconds
SetTimeout(10000, function()
  local menu = cRP.buildMenu("phone", {})
  for k,v in pairs(menu) do
    phone_menu[k] = v
  end
end)

-- add phone menu to main menu

cRP.registerMenuBuilder("main", function(add, data)
  local player = data.player
  local choices = {}
  choices[lang.phone.title()] = {function() cRP.openMenu(player,phone_menu) end}

  local user_id = cRP.getUserId(player)
  if user_id and cRP.hasPermission(user_id, "player.phone") then
    add(choices)
  end
end)