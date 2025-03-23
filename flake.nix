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

            user = lib.mkOption {
              type = lib.types.str;
              default = "idle-inhibitor";
              description = "User account under which the service runs";
            };

            group = lib.mkOption {
              type = lib.types.str;
              default = "idle-inhibitor";
              description = "Group under which the service runs";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.services.idle-inhibitor = {
              description = "Idle Inhibitor Service";

              after = [ "graphical-session.target" ];
              wants = [ "graphical-session.target" ];
              wantedBy = [ "graphical-session.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                ExecStart = "${cfg.package}/bin/idle-inhibitor";
                Restart = "on-failure";
                RestartSec = "5s";

                Environment = [
                  "XDG_RUNTIME_DIR=/run/user/\${UID}"
                ];

                # Hardening options
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                NoNewPrivileges = true;
              };
            };

            # Create user and group for the service
            users.users.${cfg.user} = lib.mkIf (cfg.user == "idle-inhibitor") {
              isSystemUser = true;
              group = cfg.group;
              description = "Idle Inhibitor Service User";
            };

            users.groups.${cfg.group} = lib.mkIf (cfg.group == "idle-inhibitor") {};
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

