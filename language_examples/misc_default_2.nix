{ config, lib, stdenv, fetchurl, fetchFromGitHub, pkgs, buildPackages
, callPackage
, enableThreading ? true, coreutils, makeWrapper
, enableCrypt ? true, libxcrypt ? null
, zlib
}:

assert (enableCrypt -> (libxcrypt != null));

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

let

  libc = if stdenv.cc.libc or null != null then stdenv.cc.libc else "/usr";
  libcInc = lib.getDev libc;
  libcLib = lib.getLib libc;
  crossCompiling = stdenv.buildPlatform != stdenv.hostPlatform;

  common = { perl, buildPerl, version, sha256 }: stdenv.mkDerivation (rec {
    inherit version;
    pname = "perl";

    src = fetchurl {__id_static="0.1512204687687564";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

      url = "mirror://cpan/src/5.0/perl-${version}.tar.gz";
      inherit sha256;
    };

    strictDeps = true;
    # TODO: Add a "dev" output containing the header files.
    outputs = [ "out" "man" "devdoc" ] ++
      lib.optional crossCompiling "mini";
    setOutputFlags = false;

    # On FreeBSD, if Perl is built with threads support, having
    # libxcrypt available will result in a build failure, because
    # perl.h will get conflicting definitions of struct crypt_data
    # from libc's unistd.h and libxcrypt's crypt.h.
    #
    # FreeBSD Ports has the same issue building the perl port if
    # the libxcrypt port has been installed.
    #
    # Without libxcrypt, Perl will still find FreeBSD's crypt functions.
    propagatedBuildInputs = lib.optional (enableCrypt && !stdenv.isFreeBSD) libxcrypt;

    disallowedReferences = [ stdenv.cc ];

    patches =
      [
        # Do not look in /usr etc. for dependencies.
        ./no-sys-dirs-5.31.patch

        # Enable TLS/SSL verification in HTTP::Tiny by default
        ./http-tiny-verify-ssl-by-default.patch
      ]
      ++ lib.optional stdenv.isSunOS ./ld-shared.patch
      ++ lib.optionals stdenv.isDarwin [ ./cpp-precomp.patch ./sw_vers.patch ]
      ++ lib.optional crossCompiling ./MakeMaker-cross.patch;

    # This is not done for native builds because pwd may need to come from
    # bootstrap tools when building bootstrap perl.
    postPatch = (if crossCompiling then ''
      substituteInPlace dist/PathTools/Cwd.pm \
        --replace "/bin/pwd" '${coreutils}/bin/pwd'
      substituteInPlace cnf/configure_tool.sh --replace "cc -E -P" "cc -E"
    '' else ''
      substituteInPlace dist/PathTools/Cwd.pm \
        --replace "/bin/pwd" "$(type -P pwd)"
    '') +
    # Perl's build system uses the src variable, and its value may end up in
    # the output in some cases (when cross-compiling)
    ''
      unset src
    '';

    # Build a thread-safe Perl with a dynamic libperl.so.  We need the
    # "installstyle" option to ensure that modules are put under
    # $out/lib/perl5 - this is the general default, but because $out
    # contains the string "perl", Configure would select $out/lib.
    # Miniperl needs -lm. perl needs -lrt.
    configureFlags =
      (if crossCompiling
       then [ "-Dlibpth=\"\"" "-Dglibpth=\"\"" "-Ddefault_inc_excludes_dot" ]
       else [ "-de" "-Dcc=cc" ])
      ++ [
        "-Uinstallusrbinperl"
        "-Dinstallstyle=lib/perl5"
      ] ++ lib.optional (!crossCompiling) "-Duseshrplib" ++ [
        "-Dlocincpth=${libcInc}/include"
        "-Dloclibpth=${libcLib}/lib"
      ]
      ++ lib.optionals ((builtins.match ''5\.[0-9]*[13579]\..+'' version) != null) [ "-Dusedevel" "-Uversiononly" ]
      ++ lib.optional stdenv.isSunOS "-Dcc=gcc"
      ++ lib.optional enableThreading "-Dusethreads"
      ++ lib.optional (!enableCrypt) "-A clear:d_crypt_r"
      ++ lib.optional stdenv.hostPlatform.isStatic "--all-static"
      ++ lib.optionals (!crossCompiling) [
        "-Dprefix=${placeholder "out"}"
        "-Dman1dir=${placeholder "out"}/share/man/man1"
        "-Dman3dir=${placeholder "out"}/share/man/man3"
      ];

    configureScript = lib.optionalString (!crossCompiling) "${stdenv.shell} ./Configure";

    dontAddStaticConfigureFlags = true;

    dontAddPrefix = !crossCompiling;

    enableParallelBuilding = !crossCompiling;

    # perl includes the build date, the uname of the build system and the
    # username of the build user in some files.
    # We override these to make it build deterministically.
    # other distro solutions
    # https://github.com/bmwiedemann/openSUSE/blob/master/packages/p/perl/perl-reproducible.patch
    # https://github.com/archlinux/svntogit-packages/blob/packages/perl/trunk/config.over
    # https://salsa.debian.org/perl-team/interpreter/perl/blob/debian-5.26/debian/config.over
    # A ticket has been opened upstream to possibly clean some of this up: https://rt.perl.org/Public/Bug/Display.html?id=133452
    preConfigure = ''
        cat > config.over <<EOF
        ${lib.optionalString (stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isGnu) ''osvers="gnulinux"''}
        myuname="nixpkgs"
        myhostname="nixpkgs"
        cf_by="nixpkgs"
        cf_time="$(date -d "@$SOURCE_DATE_EPOCH")"
        EOF

        # Compress::Raw::Zlib should use our zlib package instead of the one
        # included with the distribution
        cat > ./cpan/Compress-Raw-Zlib/config.in <<EOF
        BUILD_ZLIB   = False
        INCLUDE      = ${zlib.dev}/include
        LIB          = ${zlib.out}/lib
        OLD_ZLIB     = False
        GZIP_OS_CODE = AUTO_DETECT
        EOF
      '' + lib.optionalString stdenv.isDarwin ''
        substituteInPlace hints/darwin.sh --replace "env MACOSX_DEPLOYMENT_TARGET=10.3" ""
      '' + lib.optionalString (!enableThreading) ''
        # We need to do this because the bootstrap doesn't have a static libpthread
        sed -i 's,\(libswanted.*\)pthread,\1,g' Configure
      '';

    # Default perl does not support --host= & co.
    configurePlatforms = [];

    setupHook = ./setup-hook.sh;

    passthru = rec {
      interpreter = "${perl}/bin/perl";
      libPrefix = "lib/perl5/site_perl";
      pkgs = callPackage ../../../top-level/perl-packages.nix {__id_static="0.9041562874641536";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

        inherit perl buildPerl;
        overrides = config.perlPackageOverrides or (p: {}); # TODO: (self: super: {}) like in python
      };
      buildEnv = callPackage ./wrapper.nix {__id_static="0.7240999306638332";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

        inherit perl;
        inherit (pkgs) requiredPerlModules;
      };
      withPackages = f: buildEnv.override {__id_static="0.8886847187107909";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;
 extraLibs = f pkgs; };
    };

    doCheck = false; # some tests fail, expensive

    # TODO: it seems like absolute paths to some coreutils is required.
    postInstall =
      ''
        # Remove dependency between "out" and "man" outputs.
        rm "$out"/lib/perl5/*/*/.packlist

        # Remove dependencies on glibc and gcc
        sed "/ *libpth =>/c    libpth => ' '," \
          -i "$out"/lib/perl5/*/*/Config.pm
        # TODO: removing those paths would be cleaner than overwriting with nonsense.
        substituteInPlace "$out"/lib/perl5/*/*/Config_heavy.pl \
          --replace "${libcInc}" /no-such-path \
          --replace "${
              if stdenv.hasCC then stdenv.cc.cc else "/no-such-path"
            }" /no-such-path \
          --replace "${stdenv.cc}" /no-such-path \
          --replace "$man" /no-such-path
      '' + lib.optionalString crossCompiling
      ''
        mkdir -p $mini/lib/perl5/cross_perl/${version}
        for dir in cnf/{stub,cpan}; do
          cp -r $dir/* $mini/lib/perl5/cross_perl/${version}
        done

        mkdir -p $mini/bin
        install -m755 miniperl $mini/bin/perl

        export runtimeArch="$(ls $out/lib/perl5/site_perl/${version})"
        # wrapProgram should use a runtime-native SHELL by default, but
        # it actually uses a buildtime-native one. If we ever fix that,
        # we'll need to fix this to use a buildtime-native one.
        #
        # Adding the arch-specific directory is morally incorrect, as
        # miniperl can't load the native modules there. However, it can
        # (and sometimes needs to) load and run some of the pure perl
        # code there, so we add it anyway. When needed, stubs can be put
        # into $mini/lib/perl5/cross_perl/${version}.
        wrapProgram $mini/bin/perl --prefix PERL5LIB : \
          "$mini/lib/perl5/cross_perl/${version}:$out/lib/perl5/${version}:$out/lib/perl5/${version}/$runtimeArch"
      ''; # */

    meta = with lib; {__id_static="0.5148383197703723";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

      homepage = "https://www.perl.org/";
      description = "The standard implementation of the Perl 5 programmming language";
      license = licenses.artistic1;
      maintainers = [ maintainers.eelco ];
      platforms = platforms.all;
      priority = 6; # in `buildEnv' (including the one inside `perl.withPackages') the library files will have priority over files in `perl`
    };
  } // lib.optionalAttrs (stdenv.buildPlatform != stdenv.hostPlatform) rec {
    crossVersion = "c876045741f5159318085d2737b0090f35a842ca"; # June 5, 2022

    perl-cross-src = fetchFromGitHub {__id_static="0.6268244684816244";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

      name = "perl-cross-unstable-${crossVersion}";
      owner = "arsv";
      repo = "perl-cross";
      rev = crossVersion;
      sha256 = "sha256-m9UCoTQgXBxSgk9Q1Zv6wl3Qnd0aZm/jEPXkcMKti8U=";
    };

    depsBuildBuild = [ buildPackages.stdenv.cc makeWrapper ];

    postUnpack = ''
      unpackFile ${perl-cross-src}
      chmod -R u+w ${perl-cross-src.name}
      cp -R ${perl-cross-src.name}/* perl-${version}/
    '';

    configurePlatforms = [ "build" "host" "target" ];

    # TODO merge setup hooks
    setupHook = ./setup-hook-cross.sh;
  });
in {__id_static="0.2444325821285529";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

  # Maint version
  perl534 = common {__id_static="0.46951280852409405";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

    perl = pkgs.perl534;
    buildPerl = buildPackages.perl534;
    version = "5.34.1";
    sha256 = "sha256-NXlRpJGwuhzjYRJjki/ux4zNWB3dwkpEawM+JazyQqE=";
  };

  # Maint version
  perl536 = common {__id_static="0.6751212973436183";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

    perl = pkgs.perl536;
    buildPerl = buildPackages.perl536;
    version = "5.36.0";
    sha256 = "sha256-4mCFr4rDlvYq3YpTPDoOqMhJfYNvBok0esWr17ek4Ao=";
  };

  # the latest Devel version
  perldevel = common {__id_static="0.14917647225460673";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

    perl = pkgs.perldevel;
    buildPerl = buildPackages.perldevel;
    version = "5.37.0";
    sha256 = "sha256-8RQO6gtH+WmghqzRafbqAH1MhKv/vJCcvysi7/+T9XI=";
  };
}