{
  inputs = {
    system.url = "github:jeff-hykin/snowball/909217601e390f95f0773072c2fd8fd730ace838";
  };
  # case 1
  devShells.${system}.default = pkgs.mkShell {
  };
  outputs = { self, nixpkgs } : {
    perSystem = system: {
        a.a = 10;
      defaultPackage.${system} = nixpkgs.${system}.hello;
    };
  };
}