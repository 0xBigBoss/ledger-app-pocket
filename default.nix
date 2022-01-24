rec {
  ledger-platform = import ./dep/ledger-platform {};

  inherit (ledger-platform)
    lib
    pkgs ledgerPkgs
    crate2nix
    buildRustCrateForPkgsLedger;

  app = import ./Cargo.nix {
    pkgs = ledgerPkgs;
    buildRustCrateForPkgs = pkgs: let
      fun = (buildRustCrateForPkgsLedger pkgs).override {
        defaultCrateOverrides = pkgs.defaultCrateOverrides // {
          rust-app = attrs: let
            sdk = lib.findFirst (p: lib.hasPrefix "rust_nanos_sdk" p.name) (builtins.throw "no sdk!") attrs.dependencies;
          in {
            preHook = ledger-platform.gccLibsPreHook;
            extraRustcOpts = attrs.extraRustcOpts or [] ++ [
              "-C" "link-arg=-T${sdk.lib}/lib/nanos_sdk.out/script.ld"
              "-C" "linker=${pkgs.stdenv.cc.targetPrefix}lld"
            ];
          };
        };
      };
    in
      args: fun (args // lib.optionalAttrs pkgs.stdenv.hostPlatform.isAarch32 {
        RUSTC_BOOTSTRAP = true;
        extraRustcOpts = [
          "-C" "relocation-model=ropi"
          "-C" "passes=ledger-ropi"
        ] ++ args.extraRustcOpts or [];
        dependencies = map (d: d // { stdlib = true; }) [
          ledger-platform.ledgerCore
          ledger-platform.ledgerCompilerBuiltins
        ] ++ args.dependencies;
      });
  };

  # For CI
  rootCrate = app.rootCrate.build;

  tarSrc = ledgerPkgs.runCommandCC "tarSrc" {
    nativeBuildInputs = [
      ledger-platform.cargo-ledger
      ledger-platform.ledgerRustPlatform.rust.cargo
    ];
  } (ledger-platform.cargoLedgerPreHook + ''

    cp ${./rust-app/Cargo.toml} ./Cargo.toml
    # So cargo knows it's a binary
    mkdir src
    touch src/main.rs

    cargo-ledger --use-prebuilt ${rootCrate}/bin/rust-app --hex-next-to-json

    mkdir -p $out/rust-app
    cp app.json app.hex $out/rust-app
    cp ${./tarball-default.nix} $out/rust-app/default.nix
    cp ${./rust-app/crab.gif} $out/rust-app/crab.gif
  '');

  tarball = pkgs.runCommandNoCC "app-tarball.tar.gz" { } ''
    tar -czvhf $out -C ${tarSrc} rust-app
  '';

  pocket-core = pkgs.buildGoModule {
    name = "pocket-core";
    src = pkgs.fetchFromGitHub {
      owner = "pokt-network";
      repo = "pocket-core";
      rev = "27edab249a2a370c2b084b96daeda084261fcd0d";
      sha256 = "1gqpp16bxjcm2v27yxgsz7wa4l1mqagici76npg30z8fr7l66xa4";
    };
    vendorSha256 = "175absl4bz3ps7pr9g1s7spznw33lgqw0w0lvpyy4i99pq242idz";
    doCheck = false;
  };
}
