-- a basic market implementation

local lang = cRP.lang
local cfg = module("cfg/markets")
local market_types = cfg.market_types
local markets = cfg.markets

local market_menus = {}


-- build market menus
local function build_market_menus()
  for gtype,mitems in pairs(market_types) do
    local market_menu = {
      name=lang.market.title({gtype}),
      css={top = "75px", header_color="rgba(0,255,125,0.75)"}
    }

    -- build market items
    local kitems = {}

    -- item choice
    local market_choice = function(player,choice)
      local idname = kitems[choice][1]
      local item_name, item_desc, item_weight = cRP.getItemDefinition(idname)
      local price = kitems[choice][2]

      if item_name then
        -- prompt amount
        local user_id = cRP.getUserId(player)
        if user_id then
          local amount = cRP.prompt(player,lang.market.prompt({item_name}),"")
          local amount = parseInt(amount)
          if amount > 0 then
            -- weight check
            local new_weight = cRP.getInventoryWeight(user_id)+item_weight*amount
            if new_weight <= cRP.getInventoryMaxWeight(user_id) then
              -- payment
              if cRP.tryPayment(user_id,amount*price) then
                cRP.giveInventoryItem(user_id,idname,amount,true)
                cRPclient._notify(player,lang.money.paid({amount*price}))
              else
                cRPclient._notify(player,lang.money.not_enough())
              end
            else
              cRPclient._notify(player,lang.inventory.full())
            end
          else
            cRPclient._notify(player,lang.common.invalid_value())
          end
        end
      end
    end

    -- add item options
    for k,v in pairs(mitems) do
      local item_name, item_desc, item_weight = cRP.getItemDefinition(k)
      if item_name then
        kitems[item_name] = {k,math.max(v,0)} -- idname/price
        market_menu[item_name] = {market_choice,lang.market.info({v,item_desc})}
      end
    end

    market_menus[gtype] = market_menu
  end
end

local first_build = true

local function build_client_markets(source)
  -- prebuild the market menu once (all items should be defined now)
  if first_build then
    build_market_menus()
    first_build = false
  end

  local user_id = cRP.getUserId(source)
  if user_id ~= nil then
    for k,v in pairs(markets) do
      local gtype,x,y,z = table.unpack(v)
      local group = market_types[gtype]
      local menu = market_menus[gtype]

      if group and menu then -- check market type
        local gcfg = group._config

        local function market_enter(source)
          local user_id = cRP.getUserId(source)
          if user_id ~= nil and cRP.hasPermissions(user_id,gcfg.permissions or {}) then
            cRP.openMenu(source,menu) 
          end
        end

        local function market_leave(source)
          cRP.closeMenu(source)
        end

        cRPclient._addBlip(source,x,y,z,gcfg.blipid,gcfg.blipcolor,lang.market.title({gtype}))
        cRPclient._addMarker(source,x,y,z-1,0.7,0.7,0.5,0,255,125,125,150)

        cRP.setArea(source,"cRP:market"..k,x,y,z,1,1.5,market_enter,market_leave)
      end
    end
  end
end

AddEventHandler("cRP:playerSpawn",function(user_id, source, first_spawn)
  if first_spawn then
    build_client_markets(source)
  end
end)
