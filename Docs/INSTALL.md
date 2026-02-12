# Install MacPulse (Local)

1. Build and package the app:

```bash
Scripts/release_local.sh
```

2. Open the DMG:

```bash
open dist/MacPulse-1.0.0.dmg
```

3. Drag `MacPulse.app` into `/Applications`.

## If Gatekeeper blocks the app

Right-click the app → Open → Open. This is expected for unsigned builds.
