GM.Name 		= "Cinema"
GM.Author		= "pixelTail Games"
GM.Email 		= "contact@pixeltailgames.com"
GM.Website 		= "www.pixeltailgames.com"
GM.Version 		= "1.1"
GM.TeamBased 	= false

include( 'sh_load.lua' )

include( 'player_shd.lua' )
include( 'player_class/player_lobby.lua' )
include( 'translations.lua' )

Loader.Load( "extensions" )
Loader.Load( "modules" )

-- Load Map configuration file
local strMap = GM.FolderName .. "/gamemode/maps/" .. game.GetMap() .. ".lua"
if file.Exists( strMap, "LUA" ) then
	if SERVER then
		AddCSLuaFile( strMap )
	end
	include( strMap )
end

--[[
-----------------------------------------------------------
	Name: gamemode:PlayerShouldTakeDamage
	Desc: Return true if this player should take damage from this attacker
-----------------------------------------------------------
]]--
function GM:PlayerShouldTakeDamage( ply, attacker )
	if GetConVar("cinema_deathmatch"):GetBool() then return true end

	if GetConVar("cinema_deathmatch_admin"):GetBool() then
		local ply = nil
		if IsValid(attacker) and attacker:IsPlayer() then
			ply = attacker
		elseif IsValid(attacker:GetOwner()) and attacker:GetOwner():IsPlayer() then
			ply = attacker:GetOwner()
		end

		if ply and ply:IsAdmin() then
			return true
		end
	end

	return false
end

--[[
-----------------------------------------------------------
	Name: Text to show in the server browser
-----------------------------------------------------------
]]--
function GM:GetGameDescription()
	return self.Name
end

--[[
-----------------------------------------------------------
	Name: gamemode:ShouldCollide( Ent1, Ent2 )
	Desc: This should always return true unless you have
		a good reason for it not to.
-----------------------------------------------------------
]]--
function GM:ShouldCollide( Ent1, Ent2 )
	return false
end


--[[
-----------------------------------------------------------
	Name: gamemode:Move
	Desc: This basically overrides the NOCLIP, PLAYERMOVE movement stuff.
		It's what actually performs the move.
		Return true to not perform any default movement actions. (completely override)
-----------------------------------------------------------
]]--
function GM:Move( ply, mv )
	if ( player_manager.RunClass( ply, "Move", mv ) ) then return true end
end


--[[
-----------------------------------------------------------
	Name: SetupMove
	Desc: This is called pre player movement and copies all the data necessary
		from the player for movement. Copy from the usercmd to move.
-----------------------------------------------------------
]]--
function GM:SetupMove( ply, mv, cmd )
	if ( player_manager.RunClass( ply, "StartMove", mv, cmd ) ) then return true end
end

--[[
-----------------------------------------------------------
	Name: gamemode:FinishMove( player, movedata )
-----------------------------------------------------------
]]--
function GM:FinishMove( ply, mv )
	if ( player_manager.RunClass( ply, "FinishMove", mv ) ) then return true end
end