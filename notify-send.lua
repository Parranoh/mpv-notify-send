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
        "run", "notify-send", "-r","10",unpack(option_args),
        summary, body,
    })
end

function escape_pango_markup(str)
    return string.gsub(str, "([\"'<>&])", function (char)
        return string.format("&#%d;", string.byte(char))
    end)
end

function notify_media(title, origin, thumbnail)
    return notify(escape_pango_markup(title), origin, {
        -- For some inscrutable reason, GNOME 3.24.2
        -- nondeterministically fails to pick up the notification icon
        -- if either of these two parameters are present.
        --
        -- urgency = "low",
        -- ["app-name"] = "mpv",

        -- ...and this one makes notifications nondeterministically
        -- fail to appear altogether.
        --
        -- hint = "string:desktop-entry:mpv",

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
    local path = mp.get_property_native("path")
    if string.match(path, "^http")=="http" then
        return nil
    end
    local cmd = string.format("ffprobe -i \"%s\" -show_streams -select_streams v -v quiet", path)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result ~= "" then
        local art_file = "/tmp/cover.png"
        local cmd = string.format("ffmpeg -i \"%s\" -v -8 -y -an -vcodec png '%s'", path, art_file)
        os.execute(cmd)
        return art_file
    end
    for _, file in ipairs(cover_filenames) do
        local path = utils.join_path(dir, file)
        if file_exists(path) then
            return path
        end
    end


    return nil
end

function get_screenshot_at_position(position)
    local path = mp.get_property_native("path")
    if string.match(path, "^http")=="http" then
        return nil
    end
    local screenshot_file = "/tmp/cover.png"
    os.execute("test -e /tmp/cover.png && rm /tmp/cover.png")
    local cmd = string.format("ffmpeg -y -v -8 -ss %f -i \"%s\" -vframes 1 %s", position, path, screenshot_file)
    --mp.msg.warn(cmd)
    local ret = os.execute(cmd)
    --mp.msg.warn(ret)
    if ret ~=0 then
        return nil
    else
        return screenshot_file
    end
end

function is_mp3_file()
    local path = mp.get_property_native("path")
    if string.match(path, "^http")=="http" then
        return false
    end
    local cmd = string.format("ffprobe -v quiet -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 \"%s\"",path)
    local handle = io.popen(cmd)
    local result = handle:read()
    handle:close()
    return result == "mp3"
end

function notify_current_media()
    local path = mp.get_property_native("path")

    local dir, file = utils.split_path(path)

    -- TODO: handle embedded covers and videos?
    -- potential options: mpv's take_screenshot, ffprobe/ffmpeg, ...
    -- hooking off existing desktop thumbnails would be good too
    local stream_filename = mp.get_property_native("stream-open-filename")
    if stream_filename and not is_mp3_file() then
        local duration = mp.get_property_number("duration")
        thumbnail = get_screenshot_at_position(duration / 5)
        if not thumbnail then
            thumbnail = find_cover(dir)
        end
    else
        thumbnail = find_cover(dir)
    end


    local title = file
    local origin = dir

    local metadata = mp.get_property_native("metadata")
    if metadata then
        function tag(name)
            return metadata[string.upper(name)] or metadata[name]
        end

        title = tag("title") or title
        origin = tag("artist_credit") or tag("artist") or ""

        --local album = tag("album")
        --if album then
        --    origin = string.format("%s — %s", origin, album)
        --end

        local year = tag("original_year") or tag("year")
        if year then
            origin = string.format("%s (%s)", origin, year)
        end
    end
    local counts=mp.get_property_number("playlist-count")-1
    local pos=mp.get_property_number("playlist-pos")
    origin=string.format("%s\n%d/%d",origin,pos,counts)
    return notify_media(title, origin, thumbnail)
end

mp.register_event("file-loaded", notify_current_media)
