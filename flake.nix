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

            user = mkOption {
              type = types.str;
              default = "mbta2mqtt";
              example = "mbta2mqtt";
              description = "User running mbta2mqtt service";
            };

            group = mkOption {
              type = types.str;
              default = "mbta2mqtt";
              example = "mbta2mqtt";
              description = "Group running mbta2mqtt service";
            };

            environmentFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              example = "/run/keys/secrets.env";
              description = ''
                An environment file as defined in {manpage}`systemd.exec(5)`.

                This should be used to store secrets, such as your API key or MQTT broker password, and then pass the environment variables to mbta2mqtt by setting a configuration value to !ENV <MY_SECRET>.
              '';
            };

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
                      description = "A list of stop IDs to monitor";
                    };
                    include = mkOption {
                      type = types.listOf types.str;
                      default = [ "schedule"
                                  "stop"
                                  "stop.connecting_stops"
                                  "stop.child_stops"
                                  "stop.parent_station"
                                  "route"
                                  "route.alerts"
                                  "route.line"
                                  "route.route_patterns.representative_trip.shape"
                                  "trip"
                                  "trip.shape"
                                  "trip.service"
                                  "trip.stops"
                                  "trip.alerts"
                                  "trip.occupancies"
                                  "trip.route_pattern.representative_trip.shape"
                                  "vehicle"
                                  "vehicle.route"
                                  "vehicle.trip"
                                  "vehicle.stop"
                                  "alerts"
                                  "alerts.facilities" ];
                      example = ''
                        [ "schedule"
                          "stop"
                          "stop.connecting_stops"
                          "stop.child_stops"
                          "stop.parent_station"
                          "route"
                          "route.alerts"
                          "route.line"
                          "route.route_patterns.representative_trip.shape"
                          "trip"
                          "trip.shape"
                          "trip.service"
                          "trip.stops"
                          "trip.alerts"
                          "trip.occupancies"
                          "trip.route_pattern.representative_trip.shape"
                          "vehicle"
                          "vehicle.route"
                          "vehicle.trip"
                          "vehicle.stop"
                          "alerts"
                          "alerts.facilities" ]
                      '';
                      description = ''
                        Relationships to include in MBTA predictions.
                      '';
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
              description = ''
                Settings to write to /etc/mbta2mqtt/mbta2mqtt.conf.

                All available options are listed on the project's [defaults.conf](https://github.com/negatethis/mbta2mqtt/raw/refs/heads/main/defaults.conf) file.
              '';
            };
          };

          config = mkIf cfg.enable {
            users = {
              users = {
                mbta2mqtt = mkIf (cfg.user == "mbta2mqtt") {
                  isSystemUser = true;
                  group = cfg.group;
                };
              };
              groups = {
                ${cfg.group} = { };
              };
            };
            
            environment.etc = lib.mkMerge [
              (lib.mkIf (cfg.settings != null) {
                "mbta2mqtt/mbta2mqtt.conf".source = configFile;
              })
            ];

            systemd.services.mbta2mqtt = {
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                User = cfg.user;
                Group = cfg.group;
                ExecStart = "${pkg}/bin/mbta2mqtt";
                LogsDirectory = "mbta2mqtt";
                LogsDirectoryMode = "0755";
                Restart = "on-failure";
                EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
              };
            };
          };
        };
  };
}
