
Damagelog = Damagelog or {}

if not file.IsDir("damagelog", "DATA") then
	file.CreateDir("damagelog")
end

Damagelog.User_rights = Damagelog.User_rights or {}

function Damagelog:AddUser(user, rights)
	self.User_rights[user] = rights
end

if SERVER then
	AddCSLuaFile()
	include("sv_damagelog.lua")
else
	include("cl_damagelog.lua")
end