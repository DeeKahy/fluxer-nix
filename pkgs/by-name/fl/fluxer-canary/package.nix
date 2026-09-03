{
  lib,
  fetchurl,
  appimageTools,
  libappindicator,
  libnotify,
  speechd-minimal,
}:

let
  pname = "fluxer-canary";
  version = "2026.902.161542";

  # The version and matching sha256 are served as JSON from
  #   https://api.canary.fluxer.app/dl/desktop/canary/linux/x64/latest
  # which is what passthru.updateScript reads.
  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://api.canary.fluxer.app/dl/desktop/canary/linux/x64/${version}/appimage";
    hash = "sha256-WSLfVONn9yell5VPkRETmjrfAFxoM4FM2Mmj57CubJM=";
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

  # On launch the app writes its own desktop entry to
  # $XDG_DATA_HOME/applications, with Exec pointing at the raw extracted
  # binary. That path is not patchelf'd and has no FHS environment, so the
  # entry never launches, and it shadows the one installed below. Upstream
  # offers this opt-out for packagers; the fluxer:// protocol handler is
  # still registered when it is set.
  profile = ''
    export FLUXER_DISABLE_DESKTOP_FILE=1
  '';

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
    platforms = [ "x86_64-linux" ];
    mainProgram = "fluxer-canary";
  };
}
