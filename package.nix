{ stdenv
, libnotify
}:

stdenv.mkDerivation {
  name = "mpv-notify-send";

  src = builtins.filterSource
    (path: type: builtins.baseNameOf path == "notify-send.lua")
    ./.;

  patchPhase = ''
    substituteInPlace notify-send.lua \
      --replace '"notify-send"' '"${libnotify}/bin/notify-send"'
  '';

  installPhase = ''
    mkdir -p $out/share/mpv/scripts
    cp notify-send.lua $out/share/mpv/scripts
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/emilazy/mpv-notify-send";
    description = "A Lua script for mpv to send notifications with notify-send(1)";
    license = licenses.wtfpl;
    platforms = platforms.all;
    maintainers = with maintainers; [ emily ];
  };
}
