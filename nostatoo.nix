{ stdenv
, ruby
, writeScript
}:

let
  stub = writeScript "nostatoo" ''
    #!${ruby}/bin/ruby

    require_relative "../share/nostatoo/nostatoo"
  '';
in
stdenv.mkDerivation {
  pname = "nostatoo";
  version = "WIP";
  src = ./.;

  checkPhase = ''
    runHook preCheck

    ${ruby}/bin/ruby -c *.rb lib/*.rb

    runHook postCheck
  '';
  doCheck = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/nostatoo
    cp -r -t $out/share/nostatoo lib nostatoo.rb COPYING

    mkdir -p $out/bin
    cp ${stub} $out/bin/nostatoo

    runHook postInstall
  '';
}
