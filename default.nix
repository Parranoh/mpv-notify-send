{ pkgs ? <nixpkgs> }:

(import pkgs {
  overlays = [ (import ./overlay.nix) ];
}).mpv-notify-send
