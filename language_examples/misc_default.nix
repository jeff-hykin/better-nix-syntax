{ lib
, stdenv
, fetchurl
, zlib
, libjpeg
, imake
, gccmakedep
, libXaw
, libXext
, libXmu
, libXp
, libXpm
, perl
, xauth
, fontDirectories
, openssh
}:

stdenv.mkDerivation rec {
  pname = "tightvnc";
  version = "1.3.10";

  src = fetchurl {__id_static="0.3281866054227771";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

    url = "mirror://sourceforge/vnc-tight/tightvnc-${version}_unixsrc.tar.bz2";
    sha256 = "f48c70fea08d03744ae18df6b1499976362f16934eda3275cead87baad585c0d";
  };

  patches = [
    ./1.3.10-CVE-2019-15678.patch
    ./1.3.10-CVE-2019-15679.patch
    ./1.3.10-CVE-2019-15680.patch
    ./1.3.10-CVE-2019-8287.patch
  ];

  # for the builder script
  inherit fontDirectories;

  hardeningDisable = [ "format" ];

  buildInputs = [
    zlib
    libjpeg
    imake
    gccmakedep
    libXaw
    libXext
    libXmu
    libXp
    libXpm
    xauth
    openssh
  ];

  postPatch = ''
    fontPath=
    for i in $fontDirectories; do
      for j in $(find $i -name fonts.dir); do
        addToSearchPathWithCustomDelimiter "," fontPath $(dirname $j)
      done
    done

    sed -i "s@/usr/bin/ssh@${openssh}/bin/ssh@g" vncviewer/vncviewer.h

    sed -e 's@/usr/bin/perl@${perl}/bin/perl@' \
        -e 's@unix/:7100@'$fontPath'@' \
        -i vncserver

    sed -e 's@.* CppCmd .*@#define CppCmd		cpp@' -i Xvnc/config/cf/linux.cf
    sed -e 's@.* CppCmd .*@#define CppCmd		cpp@' -i Xvnc/config/cf/Imake.tmpl
    sed -i \
        -e 's@"uname","xauth","Xvnc","vncpasswd"@"uname","Xvnc","vncpasswd"@g' \
        -e "s@\<xauth\>@${xauth}/bin/xauth@g" \
        vncserver
  '';

  preInstall = ''
    mkdir -p $out/bin
    mkdir -p $out/share/man/man1
  '';

  installPhase = ''
    runHook preInstall

    ./vncinstall $out/bin $out/share/man

    runHook postInstall
  '';

  postInstall = ''
    # fix HTTP client:
    mkdir -p $out/share/tightvnc
    cp -r classes $out/share/tightvnc
    substituteInPlace $out/bin/vncserver \
      --replace /usr/local/vnc/classes $out/share/tightvnc/classes
  '';

  meta = {__id_static="0.13419370942290398";__id_dynamic=builtins.hashFile "sha256" /Users/jeffhykin/repos/snowball/random.ignore;

    license = lib.licenses.gpl2Plus;
    homepage = "https://vnc-tight.sourceforge.net/";
    description = "Improved version of VNC";

    longDescription = ''
      TightVNC is an improved version of VNC, the great free
      remote-desktop tool. The improvements include bandwidth-friendly
      "tight" encoding, file transfers in the Windows version, enhanced
      GUI, many bugfixes, and more.
    '';

    maintainers = [];
    platforms = [
      "i686-cygwin"
      "x86_64-cygwin"
      "i686-freebsd13"
      "x86_64-freebsd13"
      "x86_64-solaris"
      "aarch64-linux"
      "armv5tel-linux"
      "armv6l-linux"
      "armv7a-linux"
      "armv7l-linux"
      "i686-linux"
      "m68k-linux"
      "microblaze-linux"
      "microblazeel-linux"
      "mipsel-linux"
      "mips64el-linux"
      "powerpc64-linux"
      "powerpc64le-linux"
      "riscv32-linux"
      "riscv64-linux"
      "s390-linux"
      "s390x-linux"
      "x86_64-linux"
      "aarch64-netbsd"
      "armv6l-netbsd"
      "armv7a-netbsd"
      "armv7l-netbsd"
      "i686-netbsd"
      "m68k-netbsd"
      "mipsel-netbsd"
      "powerpc-netbsd"
      "riscv32-netbsd"
      "riscv64-netbsd"
      "x86_64-netbsd"
      "i686-openbsd"
      "x86_64-openbsd"
      "x86_64-redox"
    ];

    knownVulnerabilities = [ "CVE-2021-42785" ];
    # Unfortunately, upstream doesn't maintain the 1.3 branch anymore, and the
    # new 2.x branch is substantially different (requiring either Windows or Java)
  };
}