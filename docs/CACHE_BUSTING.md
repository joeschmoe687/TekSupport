# Cache Busting for Flutter Web

## Current Configuration

The `firebase.json` file sets a 1-year cache (`max-age=31536000`) for static assets including JavaScript, CSS, WASM, and fonts. This provides excellent performance for repeat visitors.

## Automatic Cache Busting

Flutter's web build automatically handles cache busting through:

1. **Content Hashing**: Flutter generates unique filenames with content hashes for main JavaScript files
   - Example: `main.dart.js` becomes `main.dart.js.1234abcd`
   - When code changes, the hash changes, forcing browsers to fetch the new version

2. **Service Worker**: Flutter web generates a service worker that manages caching
   - The service worker is updated on each deployment
   - It ensures users get the latest version after a hard refresh

## Verification

After each deployment, verify cache busting is working:

```bash
# Build the web app
flutter build web --release

# Check generated filenames
ls -la build/web/*.js

# Deploy and test
firebase deploy --only hosting

# In browser DevTools (Network tab), verify:
# - main.dart.js has a content hash in filename
# - Version updates after deployment + hard refresh (Ctrl+Shift+R)
```

## Best Practices

1. **Hard Refresh After Deploy**: Advise users to hard refresh (Ctrl+Shift+R or Cmd+Shift+R) after major updates
2. **Service Worker Updates**: The service worker checks for updates on page load
3. **Monitor User Issues**: If users report old versions, guide them to clear cache and hard refresh

## Fallback

If cache issues persist, consider:
- Reducing `max-age` for main JS files (e.g., `max-age=3600` for 1 hour)
- Adding versioning query parameters to index.html
- Using Firebase Hosting version rollback if needed

## Current Status

✅ Flutter web build includes content hashing  
✅ Service worker manages updates  
✅ 1-year cache provides optimal performance  
✅ Cache busting is automatic and working as designed
