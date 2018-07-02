
-- gui config file

local cfg = {}

-- additional css loaded to customize the gui display (see gui/design.css to know the available css elements)
-- it is not recommended to modify the cRP core files outside the cfg/ directory, create a new resource instead
-- you can load external images/fonts/etc using the NUI absolute path: nui://my_resource/myfont.ttf
-- example, changing the gui font (suppose a cRP_mod resource containing a custom font)
cfg.css = [[
@font-face {
  font-family: "Custom Font";
  src: url(nui://cRP_mod/customfont.ttf) format("truetype");
}

body{
  font-family: "Custom Font";
}

]]

-- list of static menu types (map of name => {.title,.blipid,.blipcolor,.permissions (optional)})
-- static menus are menu with choices defined by menu builders (named "static:name" and with the player parameter)
cfg.static_menu_types = {
  ["missions"] = { -- example of a mission menu that can be filled by other resources
    title = "Missions",
    blipid = 205, 
    blipcolor = 5
  }
}

-- list of static menu points
cfg.static_menus = {
  {"missions", 1855.13940429688,3688.68579101563,34.2670478820801}
}

-- VoIP

-- configuration passed to RTCPeerConnection
cfg.voip_peer_configuration = {
  iceServers = {
    {urls = {"stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302", "stun:stun2.l.google.com:19302"}}
  }
}

return cfg