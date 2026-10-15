with import <nixpkgs> {};

stdenv.mkDerivation rec {
    name = "env";

    buildInputs = [
        git git-lfs
        gnused
        pkg-config
        autoconf automake libtool
        cmake gcc
        docker docker-compose
        gnupg
        nodejs_22
        openssl openssl.dev
        zlib
        zstd
        #python312
        #python312Packages.mypy
        #python312Packages.thriftpy2
        #python312Packages.psycopg2
        #python312Packages.types-psycopg2
    ];

    shellHook = ''
      echo 'nixified environment'
      if [ "$(uname -s)" = "Darwin" ]; then
        export SED=gsed
      else
        export SED=sed
      fi

      export NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
      export CURL_CA_BUNDLE=${cacert}/etc/ssl/certs/ca-bundle.crt
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    '';

}
