
mcl_music={}


mcl_music.pause_between_songs=minetest.settings:get("mcl_music.pause_between_songs") or 30

--end config

mcl_music.modpath=minetest.get_modpath("mcl_music")
if not mcl_music.modpath then
	error("ambient music folder has to be named 'mcl_music'!")
end
--{name, length, gain~1}
mcl_music.songs = {}
local sfile, sfileerr=io.open(mcl_music.modpath..DIR_DELIM.."songs.txt")
if not sfile then error("Error opening songs.txt: "..sfileerr) end
for linent in sfile:lines() do
	-- trim leading and trailing spaces away
	local line = string.match(linent, "^%s*(.-)%s*$")
	if line~="" and string.sub(line,1,1)~="#" then
		local name, timeMinsStr, timeSecsStr, gainStr, title = string.match(line, "^(%S+)%s+(%d+):([%d%.]+)%s+([%d%.]+)%s*(.*)$")
		local timeMins, timeSecs, gain = tonumber(timeMinsStr), tonumber(timeSecsStr), tonumber(gainStr)
		if title=="" then title = name end
		if name and timeMins and timeSecs and gain then
			mcl_music.songs[#mcl_music.songs+1]={name=name, length=timeMins*60+timeSecs, lengthhr=timeMinsStr..":"..timeSecsStr, gain=gain, title=title}
		else
			minetest.log("warning", "[mcl_music] Misformatted song entry in songs.txt: "..line)
		end
	end
end
sfile:close()

if #mcl_music.songs==0 then
	print("[mcl_music]no songs registered, not doing anything")
	return
end

mcl_music.storage = minetest.get_mod_storage()

mcl_music.handles={}

mcl_music.playing=false
mcl_music.id_playing=nil
mcl_music.song_time_left=nil
mcl_music.time_next=10 --sekunden
mcl_music.id_last_played=nil

minetest.register_globalstep(function(dtime)
	if mcl_music.playing then
		if mcl_music.song_time_left<=0 then
			mcl_music.stop_song()
			mcl_music.time_next=mcl_music.pause_between_songs
		else
			mcl_music.song_time_left=mcl_music.song_time_left-dtime
		end
	elseif mcl_music.time_next then
		if mcl_music.time_next<=0 then
			mcl_music.next_song()
		else
			mcl_music.time_next=mcl_music.time_next-dtime
		end
	end
end)
mcl_music.play_song=function(id)
	if mcl_music.playing then
		mcl_music.stop_song()
	end
	local song=mcl_music.songs[id]
	if not song then return end
	for _,player in ipairs(minetest.get_connected_players()) do
		local pname=player:get_player_name()
		local pvolume=tonumber(mcl_music.storage:get_string("vol_"..pname))
		if not pvolume then pvolume=1 end
		if pvolume>0 then
			local handle = minetest.sound_play(song.name, {to_player=pname, gain=song.gain*pvolume})
			if handle then
				mcl_music.handles[pname]=handle
			end
		end
	end
	mcl_music.playing=id
	--adding 2 seconds as security
	mcl_music.song_time_left = song.length + 2
end
mcl_music.stop_song=function()
	for pname, handle in pairs(mcl_music.handles) do
		minetest.sound_stop(handle)
	end
	mcl_music.id_last_played=mcl_music.playing
	mcl_music.playing=nil
	mcl_music.handles={}
	mcl_music.time_next=nil
end

mcl_music.next_song=function()
	local next
	repeat
		next=math.random(1,#mcl_music.songs)
	until #mcl_music.songs==1 or next~=mcl_music.id_last_played
	mcl_music.play_song(next)
end

mcl_music.song_human_readable=function(id)
	if not tonumber(id) then return "<error>" end
	local song=mcl_music.songs[id]
	if not song then return "<error>" end
	return id..": "..song.title.." ["..song.lengthhr.."]"
end

minetest.register_chatcommand("volume", {
	params = "[volume level (0-1)]",
	description = "Set your background music volume. Use /volume 0 to turn off background music for you. Without parameters, show your current setting.",
	privs = {},
	func = function(pname, param)
		if not param or param=="" then
			local pvolume=tonumber(mcl_music.storage:get_string("vol_"..pname))
			if not pvolume then pvolume=0.5 end
			if pvolume>0 then
				return true, "Your music volume is set to "..pvolume.."."
			else
				if mcl_music.handles[pname] then
					minetest.sound_stop(mcl_music.handles[pname])
				end
				return true, "Background music is disabled for you. Use '/volume 1' to enable it again."
			end
		end
		local pvolume=tonumber(param)
		if not pvolume then
			return false, "Invalid usage: /volume [volume level (0-1)]"
		end
		pvolume = math.min(pvolume, 1)
		pvolume = math.max(pvolume, 0)
		mcl_music.storage:set_string("vol_"..pname, pvolume)
		if pvolume>0 then
			return true, "Music volume set to "..pvolume..". Change will take effect when the next song starts."
		else
			if mcl_music.handles[pname] then
				minetest.sound_stop(mcl_music.handles[pname])
			end
			return true, "Disabled background music for you. Use /volume to enable it again."
		end
	end,		
})
