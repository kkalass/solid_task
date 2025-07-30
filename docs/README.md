# Solid Task - Public Client Identifier

This directory contains the files needed for Solid-OIDC authentication using a Public Client Identifier Document approach.

## Files

- `client-identifier.jsonld` - The Public Client Identifier Document as per Solid-OIDC specification
- `redirect.html` - OAuth redirect handler for web authentication flows

## Hosting

These files need to be publicly accessible via HTTPS. For this project, they should be hosted on GitHub Pages at:

- https://kkalass.github.io/solid_task/client-identifier.jsonld
- https://kkalass.github.io/solid_task/redirect.html

## Setup GitHub Pages

1. Go to your repository settings
2. Navigate to "Pages" section
3. Set source to "Deploy from a branch"
4. Select "main" branch and "/docs" folder
5. The files will be available at the URLs above

## Solid-OIDC Compliance

This implementation follows the Solid-OIDC specification for public clients:

1. **WebID-based client identification** - We use a static client ID that points to our Public Client Identifier Document
2. **Public client** - No client secret is used (appropriate for mobile/desktop apps)
3. **Redirect URIs** - Supports both web (GitHub Pages) and native app redirects

## Why This Approach?

Unlike dynamic registration, which is intended for server-side applications that can securely store client credentials per issuer, the Public Client Identifier Document approach is designed for:

- Native mobile applications
- Single-page web applications  
- Apps distributed through app stores
- Cases where you can't have per-installation secrets

This approach is much simpler, more secure for client-side apps, and fully compliant with the Solid-OIDC specification.
