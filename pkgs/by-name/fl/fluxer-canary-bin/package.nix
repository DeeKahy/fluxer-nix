{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  imagemagick,
}:

let
  pname = "fluxer-canary-bin";
  version = "2026.1018.223341";

  # Upstream ships exactly one desktop channel, and it is served from the canary
  # path. The `stable` route on the download API 302s to `canary` and has no
  # per-version path at all (.../stable/linux/x64/<version>/appimage is a 404),
  # and fluxer.app/download hands every visitor a canary URL. So this is both
  # what everyone runs and the only artifact a fixed-output derivation can pin.
  #
  # Upstream's roadmap is to promote canary to stable, after which the canary
  # route is expected to be deliberately broken for automated downloaders. When
  # a per-version stable path appears, move `src.url` and update.sh onto it.
  #
  # The version and matching sha256 for each architecture are served as JSON from
  #   https://pkgs.fluxer.com/desktop/canary/linux/<arch>/latest.json
  # which is what passthru.updateScript reads. Both architectures are published
  # from the same build and share a version.
  sources = {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-pdp+SZhgXSSFxoN7lnrQLZEuPpSYEm/rPrTlJJECdMY=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-1bMvQaupSHPLSI5v5tnzUH6XhPrJvElx0r4Nu4cV/Bc=";
    };
  };

  # Deliberately falls back rather than throwing: a throw here would also break
  # evaluation on unsupported platforms. See nixpkgs#542642.
  source = sources.${stdenv.hostPlatform.system} or sources.x86_64-linux;

  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    # api.canary.fluxer.app now 302s here; point at the final location directly.
    url = "https://pkgs.fluxer.com/desktop/canary/linux/${source.arch}/${version}/appimage";
    inherit (source) hash;
  };

  # The AppImage is still built under upstream's canary branding, so everything
  # inside it - the binary, the icon, the desktop entry's basename and its
  # Icon= key - is named this regardless of what the package is called.
  upstreamName = "fluxer-canary";
  desktopName = "app.fluxer.FluxerDesktopCanary";

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
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

  # Three Exec= lines need rewriting, not one: the main entry uses AppRun, and
  # the open-settings and new-dm desktop actions both hardcode an /opt path
  # that does not exist here. --replace-fail rewrites every occurrence, so the
  # single /opt rule covers both actions.
  #
  # Icon= and StartupWMClass= keep upstream's names on purpose: the former has
  # to match the icon files installed below, and the latter has to match the WM
  # class the binary inside the AppImage actually sets, or windows stop
  # associating with the launcher entry.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/${desktopName}.desktop -t $out/share/applications

    substituteInPlace $out/share/applications/${desktopName}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}' \
      --replace-fail '"/opt/${upstreamName}/${upstreamName}"' '${pname}'

    # Upstream ships a single 1024x1024 icon, which is not a size hicolor's
    # index lists, so some launchers fail to find it. Keep the original and
    # scale it down into the standard sizes.
    install -Dm444 \
      ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/${upstreamName}.png \
      $out/share/icons/hicolor/1024x1024/apps/${upstreamName}.png

    for size in 16 24 32 48 64 128 256 512; do
      dir=$out/share/icons/hicolor/''${size}x''${size}/apps
      mkdir -p "$dir"
      ${lib.getExe imagemagick} \
        ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/${upstreamName}.png \
        -resize ''${size}x''${size} "$dir/${upstreamName}.png"
    done
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
    platforms = lib.attrNames sources;
    mainProgram = pname;
  };
}
