with import <nixpkgs> {};

stdenv.mkDerivation rec {
    name = "env";

    #src = ./.;

    # Customizable development requirements
    nativeBuildInputs = [
        git
        gnused
        pkg-config
        autoconf automake libtool
        cmake gcc
        gnupg
        pgadmin
        nodejs_20
        vscodium
        jdk
        graphviz
        #thrift
        python312
        python312Packages.mypy
        python312Packages.thriftpy2
        python312Packages.psycopg2
        python312Packages.types-psycopg2
    ];

    buildInputs = [
        openssl
        zlib
    ];

    shellHook = ''
      echo 'nixified environment'
      export SED=sed
    '';

}

