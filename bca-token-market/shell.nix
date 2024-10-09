{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    bashInteractive

    corepack_21
    nodejs_21

    openssl
    postgresql_16

    nodePackages_latest.vercel
    nodePackages_latest.pnpm
    nodePackages_latest.prisma
  ];

  shellHook = ''
    export PATH="./node_modules/bin:$PATH"
    echo "npm install"
    echo "npm run build"
    echo "npm run start:prod"
  '';

   env = {
        PRISMA_QUERY_ENGINE_LIBRARY = "${pkgs.prisma-engines}/lib/libquery_engine.node";
        PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
        PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/schema-engine";
   };
}

