{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  libappindicator,
  libnotify,
  speechd-minimal,
}:

let
  pname = "fluxer-canary";
  version = "2026.811.124022";

  # Hashes are served as JSON from
  #   https://api.canary.fluxer.app/dl/desktop/canary/linux/<arch>/latest
  # which is what passthru.updateScript reads.
  sources = {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-q5DS0+FBCpVx4TURbmiFYdBu1vvGdinPh7J1aNrd44I=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-mP6mL8Z6rrY0uUw0ANqpdC+wVj/LMyJXqzGjfI+RwzM=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "${pname}-${version}: unsupported system ${stdenv.hostPlatform.system}");

  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://api.canary.fluxer.app/dl/desktop/canary/linux/${source.arch}/${version}/appimage";
    inherit (source) hash;
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: [
    # Electron dlopens these at runtime; they are not in appimageTools'
    # default environment.
    libnotify # desktop notifications
    libappindicator # tray icon
    speechd-minimal # Chromium text-to-speech
  ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/${pname}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'

    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Free and open source instant messaging and VoIP chat app (canary channel)";
    longDescription = ''
      Fluxer is a self-hostable chat platform with messaging, voice, video and
      communities. This packages the canary channel, which receives frequent
      pre-release builds.
    '';
    homepage = "https://fluxer.app";
    downloadPage = "https://canary.fluxer.app/download";
    changelog = "https://fluxer.app/blog";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ deekahy ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "fluxer-canary";
  };
}
