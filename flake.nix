{
  description = "Flake for mbta2mqtt package and module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib; 
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in rec {
          default = mbta2mqtt;
          mbta2mqtt = pkgs.callPackage ./default.nix { };
        });

      nixosModule = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.mbta2mqtt;
          pkg = self.packages.${pkgs.system}.default;
          format = pkgs.formats.yaml {};
          configFile = format.generate "mbta2mqtt.conf" cfg.settings;
        in {
          options.services.mbta2mqtt = {
            enable = mkEnableOption "Enables the mbta2mqtt service";

            settings = mkOption {
              type = types.nullOr (types.submodule {
                freeformType = format.type;
                options = {
                  mbta = {
                    api_key = mkOption {
                      type = types.nullOr types.str;
                      default = "!ENV MBTA_API_KEY";
                      example = "!ENV MBTA_API_KEY";
                      description = "API key for MBTA real-time API. If prefixed with !ENV, will read the API key from an environment variable";
                    };
                    stops = mkOption {
                      type = types.listOf types.str;
                      default = [];
                      example = ''
                        [ "110" "2168" "22549" ]
                      '';
                      description = "A list of stops to monitor";
                    };
                  };
                  mqtt = {
                    host = mkOption {
                      type = types.nullOr types.str;
                      default = "127.0.0.1";
                      example = "mqtt.example.com";
                      description = "Hostname for mqtt server";
                    };
                    port = mkOption {
                      type = types.nullOr types.port;
                      default = 1883;
                      example = 1883;
                      description = "Port for mqtt server";
                    };
                  };
                };
              });
              example = literalExpression ''
                {
                  mbta = {
                    api_key = "ENV! MBTA_API_KEY";
                    stops = [ "110" "2168" "22549"];
                  };
                  mqtt = {
                    host = "127.0.0.1";
                    port = 1883;
                  }
                }
              '';
              description = "Settings to write to defaults.conf";
            };
          };

          config = mkIf cfg.enable {
            environment.etc = lib.mkMerge [
              (lib.mkIf (cfg.settings != null) {
                "mbta2mqtt/mbta2mqtt.conf".source = configFile;
              })

              (lib.mkIf (cfg.settings != null) {
                "logrotate.d/mbta2mqtt".text = ''
                  /var/log/mbta2mqtt/mbta2mqtt.log {
                    daily
                    rotate 7
                    compress
                    missingok
                    notifempty
                    create 0640 root adm
                  }
                '';
              })
            ];

            systemd.services.mbta2mqtt = {
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Restart = "on-failure";
                ExecStart = "${pkg}/bin/mbta2mqtt /etc/mbta2mqtt/mbta2mqtt.conf";
                StandardOutput = "append:/var/log/mbta2mqtt/mbta2mqtt.log";
                StandardError = "append:/var/log/mbta2mqtt/mbta2mqtt.log";
                DynamicUser = "yes";
              };
            };

            systemd.tmpfiles.rules = [
              "d /var/log/mbta2mqtt 0755 root root -"
            ];
          };
        };
  };
}
