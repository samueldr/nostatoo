let
  rev = "5a1dc8acd977ff3dccd1328b7c4a6995429a656b";
  sha256 = "sha256:1irryhsaz946vjijknnjl2j29l6hnmfaqxg1a7jbnqv973fz0mv9";
  owner = "NixOS";
  repo = "nixpkgs";
in
fetchTarball {
  url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
  inherit sha256;
}
