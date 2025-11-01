## Deploying Kyotee as a Web App

This project is written in Flutter, so you can ship a single codebase to the web alongside your Android bundle. Follow the steps below to produce a web build and host it on GitHub Pages (`https://kyoteee.github.io/Kyotee/app/` is used as an example target).

### 1. Enable Flutter web (one time per machine)
```bash
flutter config --enable-web
flutter devices   # Should list Chrome and Web Server
```

### 2. Build the web bundle with the correct base href
```bash
flutter build web --release --base-href /Kyotee/app/
```
This writes the compiled assets to `build/web`. The `--base-href` flag makes asset links work when GitHub Pages serves the app from the `/Kyotee/app/` subdirectory.

### 3. Publish the assets to GitHub Pages
Copy the build output into your `docs/` folder (or whichever directory your Pages site uses). Keep the contents of `build/web` in a dedicated sub-folder to avoid clutter.
```bash
rm -rf docs/app
mkdir -p docs/app
cp -r build/web/* docs/app/
```

Commit the changes and push. After GitHub Pages finishes publishing, the Flutter app will be available at `https://kyoteee.github.io/Kyotee/app/`.

### 4. Optional conveniences
- Link to the web app from your other docs (e.g., add a “Try the Kyotee web app” button).
- Automate the copy step with a simple script, for example:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  flutter build web --release --base-href /Kyotee/app/
  rm -rf docs/app
  mkdir -p docs/app
  cp -r build/web/* docs/app/
  ```

### Notes
- Some native-only features (contacts access, alternate app icons) are guarded in code with `kIsWeb`, so the app will degrade gracefully in the browser.
- Building the web bundle requires a local Flutter SDK and network access to fetch any missing packages; it cannot be produced directly inside this scratch environment.
