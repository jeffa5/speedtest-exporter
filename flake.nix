{
  description = "Speedtest exporter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      python = pkgs.python3.withPackages (ps: with ps; [prometheus-client flask waitress]);
    in {
      packages.speedtest-exporter = pkgs.writeShellScriptBin "speedtest-exporter" ''
        export PATH=${pkgs.ookla-speedtest}/bin:$PATH
        ${python}/bin/python ${./src/exporter.py}
      '';

      devShells.default = pkgs.mkShellNoCC {
        packages = [python];
      };
    })
    // {
      nixosModules.speedtest-exporter = {
        lib,
        pkgs,
        config,
        ...
      }:
        with lib; let
          cfg = config.services.prometheus.exporters.speedtest;
        in {
          options = {
            services.prometheus.exporters.speedtest = {
              enable = mkEnableOption "speedest-exporter";
              port = mkOption {
                type = lib.types.int;
                default = 9798;
              };
            };
          };
          config = mkIf cfg.enable {
            systemd.services.prometheus-speedtest-exporter = {
              wantedBy = ["multi-user.target"];
              after = ["network.target"];
              serviceConfig = {
                ExecStart = "${self.packages.${pkgs.system}.speedtest-exporter}/bin/speedtest-exporter";
                Environment = "SPEEDTEST_PORT=${toString cfg.port}";
              };
            };
          };
        };
    };
}
