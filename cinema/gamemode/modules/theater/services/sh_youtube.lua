local SERVICE = {}

SERVICE.Name 	= "YouTube"
SERVICE.IsTimed = true
SERVICE.VideoUrl = "http://youtube.com/watch?v=%s"

local API_KEY = "AIzaSyASLPKvpCG2PVzo9mpvd_hFhNfvZ0dML14"

local METADATA_URL = "https://www.googleapis.com/youtube/v3/videos?id=%s" ..
		"&key=" .. API_KEY ..
		"&part=snippet,contentDetails,status" ..
		"&videoEmbeddable=true&videoSyndicated=true"

local PLAYLIST_URL = "https://www.googleapis.com/youtube/v3/playlistItems?&playlistId=%s" ..
		"&part=snippet" ..
		"&maxResults=%s" ..
		"&key=" .. API_KEY

local PLAYLIST_URL_PAGE = "https://www.googleapis.com/youtube/v3/playlistItems?&playlistId=%s" ..
		"&part=snippet" ..
		"&maxResults=%s" ..
		"&pageToken=%s" ..
		"&key=" .. API_KEY

function SERVICE:Match( url )
	return string.match( url.host, "youtu.?be[.com]?" )
end

---
-- Helper function for converting ISO 8601 time strings; this is the formatting
-- used for duration specified in the YouTube v3 API.
--
-- http://stackoverflow.com/a/22149575/1490006
--
local function convertISO8601Time( duration )
	local a = {}

	for part in string.gmatch(duration, "%d+") do
	   table.insert(a, part)
	end

	if duration:find('M') and not (duration:find('H') or duration:find('S')) then
		a = {0, a[1], 0}
	end

	if duration:find('H') and not duration:find('M') then
		a = {a[1], 0, a[2]}
	end

	if duration:find('H') and not (duration:find('M') or duration:find('S')) then
		a = {a[1], 0, 0}
	end

	duration = 0

	if #a == 3 then
		duration = duration + tonumber(a[1]) * 3600
		duration = duration + tonumber(a[2]) * 60
		duration = duration + tonumber(a[3])
	end

	if #a == 2 then
		duration = duration + tonumber(a[1]) * 60
		duration = duration + tonumber(a[2])
	end

	if #a == 1 then
		duration = duration + tonumber(a[1])
	end

	return duration
end

function SERVICE:GetPlaylistVideos( body, length, headers, code, videos, nextPage, size, data, onSuccess, onFailure )
	local resp = util.JSONToTable( body )
	if not resp then
		return onFailure( 'Theater_RequestFailed' )
	end

	if resp.error then
		return onFailure( 'Theater_RequestFailed' )
	end

	if not table.Lookup( resp, 'items') then
		return onFailure( 'Theater_RequestFailed' )
	end

	if resp['nextPageToken'] then
		nextPage = resp['nextPageToken']
	end

	local items = resp['items']
	if #items <= 0 then
		return onFailure( 'Theater_RequestFailed' )
	end

	for _, item in ipairs(items) do
		table.insert(videos, item['snippet']['resourceId']['videoId'])
	end

	local url = nil
	if nextPage then
		url = PLAYLIST_URL_PAGE:format( data, 50, nextPage )
	end

	if not nextPage or not url then
		onFailure( 'Theater_RequestFailed' )
	end

	if #videos == size then
		if onSuccess then
			pcall(onSuccess, videos)
		end
	else
		self:Fetch( url, function(body, length, headers, code)
			self:GetPlaylistVideos(body, length, headers, code, videos, nextPage, size, data, onSuccess, onFailure)
		end, onFailure)
	end
end

function SERVICE:GetPlaylistInfo( data, onSuccess, onFailure )
	local getSize = function( body, length, headers, code )
		local resp = util.JSONToTable( body )
		if not resp then
			return onFailure( 'Theater_RequestFailed' )
		end

		if resp.error then
			return onFailure( 'Theater_RequestFailed' )
		end

		if not table.Lookup( resp, 'pageInfo.totalResults') then
			return onFailure( 'Theater_RequestFailed' )
		end

		local size = resp['pageInfo']['totalResults']
		print("Got playlist size of" .. size .. ".")
		local videos = {}
		local nextPage = nil

		local url = PLAYLIST_URL:format( data, 50 )
		self:Fetch( url, function(body, length, headers, code)
			self:GetPlaylistVideos(body, length, headers, code, videos, nextPage, size, data, onSuccess, onFailure)
		end, onFailure)
	end
	local url = PLAYLIST_URL:format( data, 0 )
	self:Fetch( url, getSize, onFailure)
end

function SERVICE:GetURLInfo( url )
	local info = {}

	-- http://www.youtube.com/watch?v=(videoId)
	if url.query and url.query.v and string.len(url.query.v) > 0 then
		-- http://www.youtube.com/watch?v=(videoId)&list=(list)
		if url.query.list then
			info.Playlist = true
			info.Data = url.query.list
		else
			info.Data = url.query.v
		end

	-- http://www.youtube.com/playlist?list=(list)
	elseif url.query and url.query.list and string.len(url.query.list) > 0 then
		info.Playlist = true
		info.Data = url.query.list

	-- http://www.youtube.com/v/(videoId)
	elseif url.path and string.match(url.path, "^/v/([%a%d-_]+)") then
		info.Data = string.match(url.path, "^/v/([%a%d-_]+)")

	-- http://youtu.be/(videoId)
	elseif string.match(url.host, "youtu.be") and 
		url.path and string.match(url.path, "^/([%a%d-_]+)$") and
		( !info.query or #info.query == 0 ) then -- short url
		info.Data = string.match(url.path, "^/([%a%d-_]+)$")
	end

	-- Start time, #t=123s or ?t=123s
	if (url.fragment and url.fragment.t) or (url.query and url.query.t) then
		local time = (url.fragment and url.fragment.t) and url.fragment.t or url.query.t

		local seconds = tonumber(string.match(time, "(%d+)s"))
		local minutes = tonumber(string.match(time, "(%d+)m"))
		local hours = tonumber(string.match(time, "(%d+)h"))

		if seconds then
			time = seconds
		end

		if minutes then
			time = tonumber(time) and time or 0
			time = time + (minutes * 60)
		end

		if hours then
			time = tonumber(time) and time or 0
			time = time + (hours * 60 * 60)
		end

		if time then
			info.StartTime = time
		end
	end

	if info.Data then
		return info
	else
		return false
	end
end

function SERVICE:GetVideoInfo( data, onSuccess, onFailure )
	local onReceive = function( body, length, headers, code )
		local resp = util.JSONToTable( body )
		if not resp then
			return onFailure( 'Theater_RequestFailed' )
		end

		if resp.error then
			return onFailure( 'Theater_RequestFailed' )
		end

		if table.Lookup( resp, 'pageInfo.totalResults', 0 ) <= 0 then
			return onFailure( 'Theater_RequestFailed' )
		end

		local item = resp.items[1]
		if not table.Lookup( item, 'status.embeddable' ) then
			return onFailure( 'Service_EmbedDisabled' )
		end

		local info = {}
		info.title = table.Lookup( item, 'snippet.title' )

		-- Medium Size doesn't have a letterbox
		info.thumbnail = table.Lookup( item, 'snippet.thumbnails.medium.url' )

		local isLive = ( table.Lookup( item, 'snippet.liveBroadcastContent' ) ~= 'none' )
		if isLive then
			info.type = 'youtubelive'
			info.duration = 0
		else
			local durStr = table.Lookup( item, 'contentDetails.duration', '' )
			info.duration = convertISO8601Time( durStr )
		end

		if onSuccess then
			pcall(onSuccess, info)
		end
	end

	local url = METADATA_URL:format( data )
	self:Fetch( url, onReceive, onFailure )
end

theater.RegisterService( 'youtube', SERVICE )


local SERVICE = {}

SERVICE.Name 		= "YouTube Live"
SERVICE.IsTimed 	= false
SERVICE.TheaterType = THEATER_PRIVATE

-- Implementation is found in 'youtube' service.
-- GetVideoInfo switches to 'youtubelive'

theater.RegisterService( 'youtubelive', SERVICE )
