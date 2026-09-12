{
  lib,
  fetchurl,
  appimageTools,
  libappindicator,
  libnotify,
  libva,
  speechd-minimal,
}:

let
  pname = "fluxer-bin";
  version = "2026.911.113656";

  # Upstream ships exactly one desktop channel. The `stable` route on the
  # download API 302s to `canary` and has no per-version path at all
  # (.../stable/linux/x64/<version>/appimage is a 404), and fluxer.app/download
  # hands every visitor a .../dl/desktop/canary/... URL. So the canary path is
  # both what everyone runs and the only artifact that can be pinned; the
  # package is named for the client rather than for a channel that upstream
  # does not currently ship separately.
  #
  # Upstream's roadmap is to promote canary to stable, after which the canary
  # route is expected to be deliberately broken for automated downloaders. When
  # a per-version stable path appears, move `src.url` and update.sh onto it.
  #
  # The version and matching sha256 are served as JSON from
  #   https://api.fluxer.app/dl/desktop/canary/linux/x64/latest
  # which is what passthru.updateScript reads.
  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://api.fluxer.app/dl/desktop/canary/linux/x64/${version}/appimage";
    hash = "sha256-YKOA008Fm+r66JH5dSJNmdAIvCdUtmaqNdaj9rtEPBU=";
  };

  # The AppImage is still built under upstream's canary branding, so everything
  # inside it - the binary, the desktop entry, the icon - is called this
  # regardless of what the package is called.
  upstreamName = "fluxer-canary";

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

    # Chromium dlopens libva to probe for VA-API hardware video decode.
    # Note the explicit .out: libva's default output is `dev`, so a bare
    # `libva` here installs headers and no libva.so.2, and the probe fails
    # exactly as it would have with nothing listed at all.
    #
    # libva's compiled-in driver search path is /run/opengl-driver/lib/dri,
    # which the FHS environment already bind-mounts from the host, so the
    # VA-API backend itself (mesa, intel-media-driver, nvidia-vaapi-driver,
    # ...) comes from the host graphics stack and must not be pulled in here.
    libva.out
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

  # Icon= and StartupWMClass= keep upstream's name on purpose: the former has
  # to match the icon file installed from the AppImage, and the latter has to
  # match the WM class the binary inside the AppImage actually sets, or windows
  # stop associating with the launcher entry.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/${upstreamName}.desktop \
      $out/share/applications/${pname}.desktop

    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}' \
      --replace-fail '"/opt/Fluxer Canary/${upstreamName}"' '${pname}'

    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Free and open source instant messaging and VoIP chat app";
    longDescription = ''
      Fluxer is a self-hostable chat platform with messaging, voice, video and
      communities. This packages upstream's prebuilt Electron AppImage.
    '';
    homepage = "https://fluxer.app";
    downloadPage = "https://fluxer.app/download";
    changelog = "https://fluxer.app/blog";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ deekahy ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
