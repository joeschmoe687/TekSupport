# Web UI Setup Guide

## Prerequisites

- Flutter SDK installed and in PATH
- Firebase CLI installed (`npm install -g firebase-tools`)
- Access to the `tekneck-support` Firebase project
- Logged in to Firebase CLI (`firebase login`)

## Quick Start

### 1. Build the Web App

```bash
# From project root
./scripts/build-web.sh
```

This will:
- Clean previous builds
- Install dependencies
- Build optimized web bundle to `build/web/`

### 2. Test Locally

```bash
# Serve locally on http://localhost:5000
firebase serve --only hosting
```

Open http://localhost:5000 in your browser and sign in with your Firebase account.

### 3. Deploy to Production

```bash
# Build and deploy in one command
./scripts/build-web.sh deploy

# Or manually
flutter build web --release
firebase deploy --only hosting
```

## Configuration

### Firebase Hosting

The `firebase.json` file configures hosting:

```json
{
  "hosting": {
    "public": "build/web",  // Flutter web output
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"  // SPA routing
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|wasm|ttf|woff|woff2)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

### Web Manifest

The `web/manifest.json` defines the PWA configuration:
- App name: "TekTool - Live Device Monitor"
- Theme colors: Dark gradient (`#1A1A2E`, `#4EC7F3`)
- Icons: Uses same icons as mobile app

## User Flow

### First-Time User

1. Navigate to web URL (e.g., https://tekneck-support.web.app)
2. See Firebase Auth login screen
3. Sign in with email/password (same account as mobile app)
4. Web UI automatically loads
5. If devices are connected on mobile, they appear immediately

### Admin User

1. Sign in with admin account
2. See "ADMIN" badge in app bar
3. Use dropdown to select "My Devices" or other users
4. View any user's connected devices in real-time

### Regular User

1. Sign in with regular account
2. See only own devices
3. Admin features hidden

## Troubleshooting

### Build Fails

```bash
# Clear Flutter cache
flutter clean
rm -rf build/

# Reinstall dependencies
flutter pub get

# Try again
flutter build web --release
```

### Firebase Deploy Fails

```bash
# Check you're logged in
firebase login

# Check project is set
firebase use tekneck-support

# Verify firebase.json is valid
cat firebase.json | jq .

# Try deploying just hosting
firebase deploy --only hosting
```

### Web App Shows White Screen

1. Check browser console for errors (F12)
2. Verify Firebase config in `lib/firebase_options.dart`
3. Ensure Firestore rules allow web access
4. Check that `build/web/index.html` exists

### No Devices Showing

1. **Mobile app must be running** with devices connected
2. Verify same Firebase account on mobile and web
3. Check mobile app logs for sync errors
4. Verify Firestore rules (see below)

### Firestore Security Rules

Ensure these rules are deployed:

```javascript
// Users can read/write their own live data
match /live_device_data/{userId} {
  allow read, write: if request.auth.uid == userId;
  allow read: if isAdmin();
  
  match /readings/{deviceId} {
    allow read, write: if request.auth.uid == userId;
    allow read: if isAdmin();
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

## Advanced Configuration

### Custom Domain

1. Add domain in Firebase Console → Hosting
2. Add DNS records (provided by Firebase)
3. Wait for SSL provisioning (can take 24h)

### Multiple Environments

Create separate Firebase projects for dev/staging/prod:

```bash
# Add projects
firebase use --add  # Select tekneck-support-dev
firebase use --add  # Select tekneck-support-staging

# Switch between environments
firebase use default  # Production
firebase use dev      # Development

# Deploy to specific environment
firebase use dev && firebase deploy --only hosting
```

### Custom Build Variants

Build with different configurations:

```bash
# Development build (faster, unoptimized)
flutter build web --profile

# Production build (optimized, minified)
flutter build web --release

# With specific renderer
flutter build web --web-renderer canvaskit  # Better graphics
flutter build web --web-renderer html       # Faster load
```

## Performance Optimization

### Reduce Bundle Size

Add to `web/index.html`:
```html
<script>
  // Defer non-critical resources
  if ('loading' in HTMLIFrameElement.prototype) {
    // Native lazy loading supported
  } else {
    // Fallback for older browsers
  }
</script>
```

### Enable PWA Features

The app is already a Progressive Web App (PWA):
- ✅ Installable (Add to Home Screen)
- ✅ Offline-capable (service worker)
- ✅ App-like experience (standalone mode)

### Monitor Performance

Use Lighthouse in Chrome DevTools:
```bash
# Open DevTools
# Click Lighthouse tab
# Run audit for Performance, Best Practices, Accessibility, SEO
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy Web UI
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: tekneck-support
```

## Support

For issues or questions:
- Check [Web UI Guide](WEB_UI_GUIDE.md) for user documentation
- Review Flutter web docs: https://flutter.dev/web
- Firebase hosting docs: https://firebase.google.com/docs/hosting
- Open GitHub issue in repo
