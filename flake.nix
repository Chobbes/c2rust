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
        fenixToolchain =
          let
            toml = with builtins; (fromTOML (readFile ./rust-toolchain.toml)).toolchain;
          in
            (fenix.packages.${system}.fromToolchainName {
              name = toml.channel;
              sha256 = "sha256-r/8YBFuFa4hpwgE3FnME7nQA2Uc1uqj0eCE1NWmI1u0";
            })."completeToolchain";

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ ];
          config = {
            allowUnfree = true;
          };
        };

        myLLVM = pkgs.llvmPackages_14;
        myStdenv = pkgs.clang14Stdenv;

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
            doCheck = false; # Can use checkFlags to disable specific tests
            shellHook = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${myStdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${myStdenv.cc}/nix-support/libc-cflags) \
      $(< ${myStdenv.cc}/nix-support/cc-cflags) \
      $(< ${myStdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString myStdenv.cc.isClang "-idirafter ${myStdenv.cc.cc}/lib/clang/${lib.getVersion myStdenv.cc.cc}/include"} \
      ${lib.optionalString myStdenv.cc.isGNU "-isystem ${myStdenv.cc.cc}/include/c++/${lib.getVersion myStdenv.cc.cc} -isystem ${myStdenv.cc.cc}/include/c++/${lib.getVersion myStdenv.cc.cc}/${myStdenv.hostPlatform.config} -idirafter ${myStdenv.cc.cc}/lib/gcc/${myStdenv.hostPlatform.config}/${lib.getVersion myStdenv.cc.cc}/include"} \
    "
  '';

            preBuild = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${myStdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${myStdenv.cc}/nix-support/libc-cflags) \
      $(< ${myStdenv.cc}/nix-support/cc-cflags) \
      $(< ${myStdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString myStdenv.cc.isClang "-idirafter ${myStdenv.cc.cc}/lib/clang/${lib.getVersion myStdenv.cc.cc}/include"} \
      ${lib.optionalString myStdenv.cc.isGNU "-isystem ${myStdenv.cc.cc}/include/c++/${lib.getVersion myStdenv.cc.cc} -isystem ${myStdenv.cc.cc}/include/c++/${lib.getVersion myStdenv.cc.cc}/${myStdenv.hostPlatform.config} -idirafter ${myStdenv.cc.cc}/lib/gcc/${myStdenv.hostPlatform.config}/${lib.getVersion myStdenv.cc.cc}/include"} \
    "
  '';

            nativeBuildInputs =
              with pkgs; [
                rustPlatform.bindgenHook
                myStdenv.cc
                myLLVM.libclang
                pkg-config
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
              ];

            buildInputs =
              with pkgs; [
                rustPlatform.bindgenHook
                myStdenv.cc
                myLLVM.libclang
                pkg-config
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
              ];

            cargoLock = {
              lockFile = ./Cargo.lock;
            };
          });
        };
        defaultPackage = packages.default;

        devShells = {
          # Include a fixed version of clang in the development environment for testing.
          default = pkgs.mkShell (with pkgs; env // {
            strictDeps = true;
            shellHook = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${myStdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${myStdenv.cc}/nix-support/libc-cflags) \
      $(< ${myStdenv.cc}/nix-support/cc-cflags) \
      $(< ${myStdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString myStdenv.cc.isClang "-idirafter ${myStdenv.cc.cc}/lib/clang/${lib.getVersion myStdenv.cc.cc}/include"} \
      ${lib.optionalString myStdenv.cc.isGNU "-isystem ${myStdenv.cc.cc}/include/c++/${lib.getVersion myStdenv.cc.cc} -isystem ${myStdenv.cc.cc}/include/c++/${lib.getVersion myStdenv.cc.cc}/${myStdenv.hostPlatform.config} -idirafter ${myStdenv.cc.cc}/lib/gcc/${myStdenv.hostPlatform.config}/${lib.getVersion myStdenv.cc.cc}/include"} \
    "
  '';

            inputsFrom = [ packages.default ];
            buildInputs = [ ];
          });
        };

        devShell = devShells.default;
      });
}
