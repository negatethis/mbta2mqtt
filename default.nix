{ python3 }:

python3.pkgs.buildPythonApplication rec {
  pname = "mbta2mqtt";
  version = "latest";
  format = "other";

  src = ./.;

  installPhase = ''
    mkdir -p $out/bin
    cp ${pname}.py $out/bin/${pname}
    cp defaults.conf $out/bin
    chmod +x $out/bin/${pname}
  '';
  
  propagatedBuildInputs = with python3.pkgs; [
    paho-mqtt
    pyyaml-env-tag
    requests
    mergedeep
  ];
}
