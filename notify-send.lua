local utils = require "mp.utils"

local cover_filenames = { "cover.png", "cover.jpg", "cover.jpeg",
                          "folder.jpg", "folder.png", "folder.jpeg",
                          "AlbumArtwork.png", "AlbumArtwork.jpg", "AlbumArtwork.jpeg" }

function notify(summary, body, options)
    local option_args = {}
    for key, value in pairs(options or {}) do
        table.insert(option_args, string.format("--%s=%s", key, value))
    end
    return mp.command_native({
        "run", "notify-send",
        summary, body,
        unpack(option_args)
    })
end

function notify_media(title, origin, thumbnail)
    -- escape Pango markup only in body
    -- cf. https://specifications.freedesktop.org/notification-spec/latest/ar01s04.html
    local body = origin:gsub("&", "&amp;"):gsub("<", "&lt;")
    notify(title, body, {
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

function first_upper(str)
    return (string.gsub(string.gsub(str, "^%l", string.upper), "_%l", string.upper))
end

function notify_current_media()
    local path = mp.get_property_native("path")

    local dir, file = utils.split_path(path)

    -- TODO: handle embedded covers and videos?
    -- potential options: mpv's take_screenshot, ffprobe/ffmpeg, ...
    -- hooking off existing desktop thumbnails would be good too
    local thumbnail = find_cover(dir)

    local title = file
    local origin = dir

    local metadata = mp.get_property_native("metadata")
    if metadata then
        function tag(name)
            return metadata[string.upper(name)] or metadata[first_upper(name)] or metadata[name]
        end

        title = tag("title")
        title = title and #title > 0 and title or file
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

    return notify_media(title, origin, thumbnail)
end

mp.register_event("file-loaded", notify_current_media)
