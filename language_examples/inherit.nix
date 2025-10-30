{
  b  = import nixpkgs {inherit system;};
  inherit a;
  inherit a b c;
  inherit (callPackage) a;
  inherit (callPackage) a b c;
  inherit (callPackage ../tools/filesystems/garage {

    inherit (darwin.apple_sdk.frameworks) Security;
  })
    garage
      garage_0_7 garage_0_8
      garage_0_7_3 garage_0_8_0;
}