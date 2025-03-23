{
  description = "Development environment with Wayland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      nixosModule = { config, lib, pkgs, ... }:
        let
          cfg = config.services.idle-inhibitor;
        in {
          options.services.idle-inhibitor = {
            enable = lib.mkEnableOption "Enables the idle inhibitor service";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.idle-inhibitor;
              description = "Package to use for the service";
            };
          };
          config = lib.mkIf cfg.enable {
            enable = true;
            systemd.user.services.idle-inhibitor = {
              description = "Idle Inhibitor Service";

              after = [ "graphical-session.target" ];
              partOf = [ "graphical-session.target" ];
              wantedBy = [ "graphical-session.target" ];

              serviceConfig = {
                ExecStart = "${cfg.package}/bin/idle-inhibitor";
                Restart = "on-failure";
                RestartSec = 1;

                # Environment setup is handled by PAM and the systemd user session
                # The XDG_RUNTIME_DIR is automatically set for user services
              };
            };
          };
        };
    in 
      flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
          {
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              wayland
              zig
            ];

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.wayland
            ];
          };

          packages.idle-inhibitor = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "idle-inhibitor";
            version = "0.0.1";

            src = ./.; # Assumes source code is in the same directory as flake.nix

            deps = pkgs.callPackage ./build.zig.zon.nix {};

            nativeBuildInputs = with pkgs; [
              zig
            ];

            buildInputs = with pkgs; [
              wayland
              zig.hook
            ];

            zigBuildFlags = [
              "--system"
              "${finalAttrs.deps}"
            ];
          });

          packages.default = self.packages.${system}.idle-inhibitor;
        }
      ) // {
      nixosModules.default = nixosModule;
    };
}

