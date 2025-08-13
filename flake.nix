{
  description = "Flake for c2rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, utils, fenix}:
    utils.lib.eachDefaultSystem (system:
    let
        # fenixToolchain = fenix.packages.${system}.fromToolchainFile {
        #   file = ./rust-toolchain.toml;
        #   sha256 = "sha256-r/8YBFuFa4hpwgE3FnME7nQA2Uc1uqj0eCE1NWmI1u0";
      # };

          # fenixPkgs = fenix.packages.${system};

          # mkToolchain = fenixPkgs: fenixPkgs.toolchainOf {
          #   channel = "nightly";
          #   date = "2022-08-08";
          #   sha256 = "sha256-r/8YBFuFa4hpwgE3FnME7nQA2Uc1uqj0eCE1NWmI1u0";
          # };

          # fenixToolchain = fenixPkgs.combine [
          #   (mkToolchain fenixPkgs).rustc
          #   (mkToolchain fenixPkgs).cargo
          #   ((mkToolchain fenixPkgs).withComponents  ["rustfmt" "rustc-dev" "rust-src" "miri" "rust-analyzer"])
          #   (mkToolchain fenixPkgs.targets."x86_64-unknown-linux-musl").rust-std
          # ];

# fenixToolchain =
#   let
#     toml = with builtins; (fromTOML (readFile ./rust-toolchain.toml)).toolchain;
#     channel = toml.channel or "stable";
#     profile = toml.profile or "default";
#     targets = toml.targets or [ "x86_64-unknown-linux-gnu" ];
#     components = toml.components or [ ];
#   in
#   with pkgs;
#   pkgs.buildEnv {
#     name = "toolchain";
#     paths = [
#       cargo-nextest
#       cargo-ndk
#       cargo-audit
#       (fenix.packages.${system}.combine (
#         [
#           fenix.packages.${system}."${channel}"."${profile}Toolchain"
#           (fenix.packages.${system}."${channel}".withComponents components)
#         ] ++ map (target: fenix.targets.${target}.${channel}.rust-std) targets
#       ))
#     ];
#   };
        fenixToolchain =
          let
            toml = with builtins; (fromTOML (readFile ./rust-toolchain.toml)).toolchain;
          in
            (fenix.packages.${system}.fromToolchainName {
              name = toml.channel;
              sha256 = "sha256-r/8YBFuFa4hpwgE3FnME7nQA2Uc1uqj0eCE1NWmI1u0";
            })."completeToolchain";
      # fenixToolchain = fenix.packages.${system}.default.toolchain;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ ];
          config = {
            allowUnfree = true;
          };
        };
        myLLVM = pkgs.llvmPackages_18;
        # rustToolchain = pkgs.rust-bin.stable."1.65.0".default; # fromRustupToolchainFile ./rust-toolchain.toml;
        # pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default); # 
  #       # 2. Wrap it so LD_LIBRARY_PATH includes the LLVM libs
  #       fenixWrapped = pkgs.symlinkJoin {
  #         name = "fenix-wrapped";
  #         paths = [ fenixToolchain ];
  #         buildInputs = [ pkgs.makeWrapper ];
  #         postBuild = ''
  #     llvmLibDir="${fenixToolchain}/lib"
  #     for bin in $out/bin/*; do
  #       wrapProgram "$bin" \
  #         --prefix LD_LIBRARY_PATH : "$llvmLibDir" \
  #         --prefix LD_LIBRARY_PATH : ${pkgs.glibc}/lib \
  #         --prefix LD_LIBRARY_PATH : ${pkgs.gcc.lib}/lib
  #     done
  #   '';

  #   meta = fenixToolchain.meta // {
  #     # Ensure `targetPlatforms` is set
  #     targetPlatforms = fenixToolchain.meta.platforms or fenixToolchain.meta.targetPlatforms;
  #   };
  #       };
  # fenixFixed = fenixToolchain.overrideAttrs (old: {
  #   nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
  #   postInstall = (old.postInstall or "") + ''
  #     for bin in $out/bin/*; do
  #       wrapProgram "$bin" \
  #         --prefix LD_LIBRARY_PATH : "${fenixToolchain}/lib" \
  #         --prefix LD_LIBRARY_PATH : ${pkgs.glibc}/lib \
  #         --prefix LD_LIBRARY_PATH : ${pkgs.gcc.cc.lib}/lib
  #     done
  #   '';
  # });
        rustPlatform = pkgs.makeRustPlatform {
          cargo = fenixToolchain; # rustToolchain;
          rustc = fenixToolchain; # rustToolchain;
        };
        env = with pkgs; {
          LIBCLANG_PATH = "${myLLVM.libclang.lib}/lib";
          CMAKE_LLVM_DIR = "${myLLVM.libllvm.dev}/lib/cmake/llvm";
          CMAKE_CLANG_DIR = "${myLLVM.libclang.dev}/lib/cmake/clang";
          LLVM_CONFIG_PATH = "${myLLVM.libllvm.dev}/bin/llvm-config";
          CLANG_PATH = "${myLLVM.clang}/bin/clang";
          NIX_ENFORCE_NO_NATIVE = 0; # Enable SSE instructions.
          #RUSTC_BOOTSTRAP="1";
          RUST_SRC_PATH = "${fenixToolchain}/lib/rustlib/src/rust/library";
        };
        in rec {
          packages = {
            default = rustPlatform.buildRustPackage (with pkgs; env // {
                pname = "c2rust";
                version = "0.20.0";
                src = ./.;

shellHook = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${stdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${stdenv.cc}/nix-support/libc-cflags) \
      $(< ${stdenv.cc}/nix-support/cc-cflags) \
      $(< ${stdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
      ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config} -idirafter ${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include"} \
    "
  '';

  preBuild = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${stdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${stdenv.cc}/nix-support/libc-cflags) \
      $(< ${stdenv.cc}/nix-support/cc-cflags) \
      $(< ${stdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
      ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config} -idirafter ${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include"} \
    "
  '';

                
            #     shellHook = ''
            #   export CARGO_TARGET_DIR="$(git rev-parse --show-toplevel)/target_dirs/nix_rustc";
            # '';

                # nativeBuildInputs =
                #   with pkgs; [
                #     pkg-config
                #     cmake
                #     clang18Stdenv.cc
                #     clang18Stdenv.cc.libc
                #     myLLVM.libclang
                #     myLLVM.clang
                #     myLLVM.llvm
                #     myLLVM.libllvm
                #     zlib
                #     glibc
                #     tinycbor
                #     openssl
                #     (python3.withPackages
                #       (python-pkgs:
                #         with python-pkgs;
                #         [ "bencode-python3"
                #           cbor
                #           colorlog
                #           mako
                #           pip
                #           plumbum
                #           psutil
                #           pygments
                #           typing
                #           "scan-build"
                #           pyyaml
                #           toml
                #         ]
                #       )
                #     )
                #     zlib
                #   ];

                # nativeBuildInputs =
                #   with pkgs; [
                #     pkg-config
                #     cmake
                #   ];

                nativeBuildInputs =
                  with pkgs; [
                    clang18Stdenv.cc
                    myLLVM.libclang
                    pkg-config
#                    fenix.packages.${system}.rust-analyzer
                    myLLVM.clang
                    cmake
                    myLLVM.llvm
                    myLLVM.libllvm
                    tinycbor
                    openssl
                    (python3.withPackages
                      (python-pkgs:
                        with python-pkgs;
                        [ "bencode-python3"
                          cbor
                          colorlog
                          mako
                          pip
                          plumbum
                          psutil
                          pygments
                          typing
                          "scan-build"
                          pyyaml
                          toml
                        ]
                      )
                    )
                    zlib
                    fenixToolchain
                    # (rust-bin.fromRustupToolchainFile ./rust-toolchain.toml)
                  ];

                buildInputs =
                  with pkgs; [
                    clang18Stdenv.cc
                    myLLVM.libclang
                    pkg-config
#                    fenix.packages.${system}.rust-analyzer
                    myLLVM.clang
                    cmake
                    myLLVM.llvm
                    myLLVM.libllvm
                    tinycbor
                    openssl
                    (python3.withPackages
                      (python-pkgs:
                        with python-pkgs;
                        [ "bencode-python3"
                          cbor
                          colorlog
                          mako
                          pip
                          plumbum
                          psutil
                          pygments
                          typing
                          "scan-build"
                          pyyaml
                          toml
                        ]
                      )
                    )
                    zlib
                    fenixToolchain
                    # (rust-bin.fromRustupToolchainFile ./rust-toolchain.toml)
                  ];
                # buildInputs =
                #   with pkgs; [
                #     pkg-config
                #     cmake
                #     clang18Stdenv.cc
                #     clang18Stdenv.cc.libc
                #     myLLVM.libclang
                #     myLLVM.clang
                #     myLLVM.llvm
                #     myLLVM.libllvm
                #     zlib
                #     glibc
                #     glibc.dev
                #     libxml2
                #     libffi
                #     libxml2.dev
                #     libffi.dev
                #     tinycbor
                #     openssl
                #     (python3.withPackages
                #       (python-pkgs:
                #         with python-pkgs;
                #         [ "bencode-python3"
                #           cbor
                #           colorlog
                #           mako
                #           pip
                #           plumbum
                #           psutil
                #           pygments
                #           typing
                #           "scan-build"
                #           pyyaml
                #           toml
                #         ]
                #       )
                #     )
                #     zlib
                #   ];

                cargoLock = {
                  lockFile = ./Cargo.lock;
                };
            });
          };
          defaultPackage = packages.default;

          devShells = {
            # Include a fixed version of clang in the development environment for testing.
            default = pkgs.mkShell (with pkgs; env // {
shellHook = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${stdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${stdenv.cc}/nix-support/libc-cflags) \
      $(< ${stdenv.cc}/nix-support/cc-cflags) \
      $(< ${stdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
      ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config} -idirafter ${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include"} \
    "
  '';
            #     shellHook = ''
            #   export CARGO_TARGET_DIR="$(git rev-parse --show-toplevel)/target_dirs/nix_rustc";
            # '';

              inputsFrom = [ packages.default ];
              buildInputs = [ ];
            });
          };

          devShell = devShells.default;
        });
}
