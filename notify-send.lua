local utils = require "mp.utils"

local cover_filenames = {
    "cover.png", "cover.jpg", "cover.jpeg",
    "Cover.png", "Cover.jpg", "Cover.jpeg",
    "folder.jpg", "folder.png", "folder.jpeg",
    "Folder.jpg", "Folder.png", "Folder.jpeg",
    "AlbumArtwork.png", "AlbumArtwork.jpg", "AlbumArtwork.jpeg",
}

function notify(summary, body, options)
    local option_args = {}
    for key, value in pairs(options or {}) do
        table.insert(option_args, string.format("--%s=%s", key, value))
    end
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = { "notify-send", summary, body, unpack(option_args) },
    })
end

function notify_media(title, origin, thumbnail)
    notify(title, origin, {
        urgency = "low",
        ["app-name"] = "mpv",
        hint = "string:desktop-entry:mpv",
        icon = thumbnail or "mpv",
    })
end

function file_exists(path)
    local info, _ = utils.file_info(path)
    return info ~= nil
end

function find_cover(dir)
    -- make dir an absolute path
    if dir[1] ~= "/" then
        dir = utils.join_path(utils.getcwd(), dir)
    end

    for _, file in ipairs(cover_filenames) do
        local path = utils.join_path(dir, file)
        if file_exists(path) then
            return path
        end
    end

    return nil
end

function extract_cover(path)
    local tmp = os.tmpname()
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stderr = true,
        args = { "metaflac", "--export-picture-to=" .. tmp, path },
    })
    if r.status == 0 then
        return tmp, function () os.remove(tmp) end
    end
    return nil
end

function get_cover(path, dir)
    local cover = find_cover(dir)
    if cover then return cover end
    return extract_cover(path)
end

function first_upper(str)
    return (string.gsub(string.gsub(str, "^%l", string.upper), "_%l", string.upper))
end

function notify_current_media()
    if mp.get_property_native("focused") then return end

    local path = mp.get_property_native("path")

    local dir, file = utils.split_path(path)

    -- TODO: handle embedded covers and videos?
    -- potential options: mpv's take_screenshot, ffprobe/ffmpeg, ...
    -- hooking off existing desktop thumbnails would be good too
    local thumbnail, cleanup = get_cover(path, dir)

    local title = file
    local origin = dir

    local metadata = mp.get_property_native("metadata")
    if metadata then
        function tag(name)
            return metadata[string.upper(name)] or metadata[first_upper(name)] or metadata[name]
        end

        title = tag("title") or title
        origin = tag("artist_credit") or tag("artist") or ""

        local album = tag("album")
        if album then
            origin = string.format("%s — %s", origin, album)
        end

        local date = tag("date")
        local year = tag("original_year") or tag("year") or (date and date:sub(1, 4))
        if year then
            origin = string.format("%s (%s)", origin, year)
        end
    end

    notify_media(title, origin, thumbnail)
    if cleanup then cleanup() end
end

mp.register_event("file-loaded", notify_current_media)
