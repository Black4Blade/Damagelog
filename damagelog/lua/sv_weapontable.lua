
util.AddNetworkString("DL_AskWeaponTable")
util.AddNetworkString("DL_SendWeaponTable")
util.AddNetworkString("DL_AddWeapon")
util.AddNetworkString("DL_RemoveWeapon")
util.AddNetworkString("DL_WeaponTableDefault")
	
function Damagelog:SaveWeaponTable()
	local encoded = util.TableToJSON(Damagelog.weapon_table)
	file.Write("damagelog/weapon_table.txt", encoded)
end

if not file.Exists("damagelog/weapon_table.txt", "DATA") then
	Damagelog.weapon_table = Damagelog.weapon_table_default
	local encoded = util.TableToJSON(Damagelog.weapon_table_default)
	file.Write("damagelog/weapon_table.txt", encoded)
else
	local encoded = file.Read("damagelog/weapon_table.txt", "DATA")
	Damagelog.weapon_table = util.JSONToTable(encoded)
end

if not Damagelog.weapon_table then
	Damagelog.weapon_table = Damagelog.weapon_table_default
	Damagelog:SaveWeaponTable()
end

hook.Add("PlayerInitialSpawn", "Damagelog_PlayerInitialSpawn", function(ply)
	net.Start("DL_SendWeaponTable")
	net.WriteUInt(1,1)
	net.WriteTable(Damagelog.weapon_table)
	net.Send(ply)
end)

net.Receive("DL_AddWeapon", function(_, ply)
	if not ply:IsSuperAdmin() then return end
	local class = net.ReadString()
	local name = net.ReadString()
	if class and name then
		Damagelog.weapon_table[class] = name
		net.Start("DL_SendWeaponTable")
		net.WriteUInt(0,1)
		net.WriteString(class)
		net.WriteString(name)
		net.Broadcast()
		Damagelog:SaveWeaponTable()
	end
end)

net.Receive("DL_RemoveWeapon", function(_,ply)
	if not ply:IsSuperAdmin() then return end
	local classes = net.ReadTable()
	for k,v in pairs(classes) do
		Damagelog.weapon_table[v] = nil
	end
	Damagelog:SaveWeaponTable()
	net.Start("DL_SendWeaponTable")
	net.WriteUInt(1,1)
	net.WriteTable(Damagelog.weapon_table)
	net.Broadcast()
end)

net.Receive("DL_WeaponTableDefault", function(_,ply)
	if not ply:IsSuperAdmin() then return end
	Damagelog.weapon_table = Damagelog.weapon_table_default
	Damagelog:SaveWeaponTable()
	net.Start("DL_SendWeaponTable")
	net.WriteUInt(1,1)
	net.WriteTable(Damagelog.weapon_table)
	net.Broadcast()
end)