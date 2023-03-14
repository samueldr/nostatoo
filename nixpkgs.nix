let
  rev = "01413746884cde1173edda10f0745793ca7c998d";
  sha256 = "sha256:1c70p2r8r5bfhx90c830ap59zql3ds50bh6wj866wvb9jj43axcc";
  owner = "samueldr";
  repo = "nixpkgs";
in
fetchTarball {
  url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
  inherit sha256;
}
