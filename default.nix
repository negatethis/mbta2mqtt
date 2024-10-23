{ python3
, fetchFromGitHub
}:

python3.pkgs.buildPythonApplication rec {
  pname = "mbta2mqtt";
  version = "latest";
  format = "other";

  src = fetchFromGitHub {
    owner = "ralphbean";
    repo = "mbta2mqtt";
    rev = "395ddb8a16df30a0d190abb0de3959aa99781c82";
    hash = "sha256-4aYvQr8Z+BnBW7UHz3VE/ZK1me+tcCOWRwx3xDcJpnk=";
  };

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
