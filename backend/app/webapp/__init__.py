"""Serves the built Flutter Web bundle at /app/*.

This blueprint is the last mile of the 'Path 2' architecture:
    wasit.app/            → Jinja marketing web (SEO)
    wasit.app/app/…       → Flutter Web (the actual product, in a browser)

Same Flask process, same JWT, same backend API. The bundle is a static
build of the mobile app; ship changes via `scripts/build-web-app.ps1`."""
