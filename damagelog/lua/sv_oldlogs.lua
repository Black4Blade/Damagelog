
-- this code made me mad

util.AddNetworkString("DL_AskLogsList")
util.AddNetworkString("DL_AskOldLog")
util.AddNetworkString("DL_SendOldLog")
util.AddNetworkString("DL_SendLogsList")

hook.Add("TTTEndRound", "Damagelog_TTTEndRound", function()
	if Damagelog.DamageTable and (Damagelog.ShootTables and Damagelog.ShootTables[Damagelog.CurrentRound]) and Damagelog.RoundSaveDir then
		local logs = {
			DamageTable = Damagelog.DamageTable,
			ShootTable = Damagelog.ShootTables[Damagelog.CurrentRound],
			Infos = Damagelog.OldLogsInfos
		}
		local rounds = #file.Find(Damagelog.RoundSaveDir.."/round_*.txt", "DATA")
		if not rounds then
			rounds = 0
		end
		logs = von.serialize(logs)
		if logs then
			file.Write(Damagelog.RoundSaveDir.."/round_"..tostring(rounds+1)..".txt", util.Compress(logs))
		end
	end
end)

net.Receive("DL_AskLogsList", function(_,ply)
	net.Start("DL_SendLogsList")
	net.WriteTable(Damagelog.available_logs or {})
	net.Send(ply)
end)

net.Receive("DL_AskOldLog", function(_,ply)
	local infos = net.ReadTable()
	local round = net.ReadUInt(8)
	if not round or not infos then return end
	infos.month = #tostring(infos.month) > 1 and infos.month or "0"..tostring(infos.month)
	infos.day = #tostring(infos.day) > 1 and infos.day or "0"..tostring(infos.day)
	local filename = "damagelog/logs/"..infos.year.."/"..infos.month.."/"..infos.day.."/"..infos.map.."/round_"..round..".txt"
	local compressed = file.Read(filename, "DATA")
	net.Start("DL_SendOldLog")
	if compressed then
		net.WriteUInt(1,1)
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	else
		net.WriteUInt(0,1)
	end
	net.Send(ply)
end)

if not DAMAGELOG_LOADED_OLDLOGS then

	Damagelog.available_logs = {}
	local _1, years = file.Find("damagelog/logs/*", "DATA")
	for _2,year in pairs(years) do
		year = tonumber(year)
		local year_infos = {}
		local _3, months = file.Find("damagelog/logs/"..year.."/*", "DATA")
		for _4, month in pairs(months) do
			month = tonumber(month)
			local month_str = #tostring(month) > 1 and month or "0"..tostring(month)
			year_infos[month] = {}
			local _5, days = file.Find("damagelog/logs/"..year.."/"..month_str.."/*", "DATA")
			for _6, day in pairs(days) do
				day = tonumber(day)
				local day_str = #tostring(day) > 1 and day or "0"..tostring(day)
				year_infos[month][day] = {}
				local _7, maps = file.Find("damagelog/logs/"..year.."/"..month_str.."/"..day_str.."/*", "DATA")
				for _8, map in pairs(maps) do
					local rounds = #file.Find("damagelog/logs/"..year.."/"..month_str.."/"..day_str.."/"..map.."/round_*.txt", "DATA")
					local date = file.Read("damagelog/logs/"..year.."/"..month_str.."/"..day_str.."/"..map.."/date.txt", "DATA")
					if date and (rounds and rounds > 0) then
						year_infos[month][day][map] = {
							date = date,
							rounds = rounds
						}
					end
				end
			end
		end
		Damagelog.available_logs[year] = year_infos
	end
		
	local m,y,d = os.date("%m"), os.date("%y"), os.date("%d")
	local dir = "damagelog/logs/"..y
	local function CreateDir()
		if not file.IsDir(dir, "DATA") then
			file.CreateDir(dir)
		end
	end
	CreateDir()
	dir = dir.."/"..m
	CreateDir()
	dir = dir.."/"..d
	CreateDir()
	local map = game.GetMap()
	local _,maplist = file.Find(dir.."/"..map.."*", "DATA")
	dir = dir.."/"..map.."_"..tostring(#maplist+1)
	CreateDir() 
	file.Write(dir.."/date.txt", os.date("%H:%M"))
	Damagelog.RoundSaveDir = dir
	
	DAMAGELOG_LOADED_OLDLOGS = true

end

