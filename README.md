# CHIKI BONA — Flutter APK + Live VPS API

This project keeps the CHIKI BONA 3D UI and connects it to the live Flask API.

## Current VPS API

Default server:

`http://157.20.104.34:8000`

The app uses:

- `GET /api/v1/health`
- `GET /api/v1/folders`
- `GET /api/v1/videos`
- `GET /api/v1/videos/<id>`
- `POST /upload` with `X-Upload-PIN`
- video streaming from `stream_url`
- thumbnails from `thumbnail_url`

The app silently refreshes the library every 5 seconds.

## GitHub → APK

1. Create a GitHub repository.
2. Upload this whole project to the repository's `main` branch.
3. Open **Actions**.
4. Open **Build CHIKI BONA APK**.
5. The workflow builds a release APK automatically.
6. Open the completed workflow run and download the **CHIKI_BONA_APK** artifact.

The GitHub workflow creates the Android platform files during the build, so the repository does not need a large local Android Studio installation.

## App settings

The Settings screen lets you change the VPS API URL and enter the upload PIN. The default VPS URL is the one above.

## Important

The Flask VPS must remain online for the APK to list and stream videos. The APK is the client; videos stay on the VPS.


## GitHub APK build
Push to the `main` branch or run the `Build CHIKI BONA APK` workflow manually from GitHub Actions. The APK is uploaded as the `CHIKI_BONA_APK` artifact.
