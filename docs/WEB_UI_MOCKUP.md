# Web UI Visual Guide

## Desktop View (1920x1080)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TekTool                                          [Refresh] [Theme] [Logout] │
│ Live Device Monitor                                                         │
│ Updated 3s ago                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐ │
│  │ 🟢 Testo 549i        │  │ 🟢 Wey-Tek HD Scale │  │ 🟡 ABM-200       │ │
│  │ Temperature Probe    │  │ Refrigerant Scale   │  │ Airflow Meter    │ │
│  │                      │  │                     │  │                  │ │
│  │     72.5°F           │  │     18.4 oz         │  │    450 FPM       │ │
│  │                      │  │                     │  │                  │ │
│  │ 🔋 85%      2s ago   │  │ 🔋 92%     2s ago   │  │ 🔋 67%  15s ago  │ │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘ │
│                                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐ │
│  │ 🟢 Fieldpiece SRL8   │  │ 🔴 Testo T115i      │  │ 🟢 Parker Gauge  │ │
│  │ Refrigerant Gauge    │  │ Temperature Probe   │  │ Refrigerant Gauge│ │
│  │                      │  │                     │  │                  │ │
│  │     125.3 PSI        │  │     68.2°F          │  │    95.7 PSI      │ │
│  │                      │  │                     │  │                  │ │
│  │         3s ago       │  │        2m ago       │  │        4s ago    │ │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Admin View with User Selector

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TekTool   [ADMIN]                    [My Devices ▼] [Refresh] [Theme]      │
│ Live Device Monitor                                                         │
│ Updated 1s ago                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Dropdown menu when clicked:                                                │
│  ┌─────────────────────┐                                                   │
│  │ 👤 My Devices       │ ← Current user                                    │
│  │ ─────────────────── │                                                   │
│  │ John Smith          │ ← Other technicians                               │
│  │ Sarah Johnson       │                                                   │
│  │ Mike Williams       │                                                   │
│  └─────────────────────┘                                                   │
│                                                                             │
│  [Same device grid as above, showing selected user's devices]              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Tablet View (1024x768) - 2 Columns

```
┌─────────────────────────────────────────────┐
│ TekTool                    [⟳] [☽] [Exit]  │
│ Live Device Monitor                         │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐  │
│  │ 🟢 Testo 549i   │  │ 🟢 Wey-Tek HD  │  │
│  │ Temp Probe      │  │ Scale          │  │
│  │                 │  │                │  │
│  │    72.5°F       │  │    18.4 oz     │  │
│  │                 │  │                │  │
│  │ 🔋85%    2s ago │  │ 🔋92%   2s ago │  │
│  └─────────────────┘  └─────────────────┘  │
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐  │
│  │ 🟢 ABM-200      │  │ 🟢 Fieldpiece  │  │
│  │ Airflow Meter   │  │ Gauge          │  │
│  │                 │  │                │  │
│  │    450 FPM      │  │   125.3 PSI    │  │
│  │                 │  │                │  │
│  │ 🔋67%   15s ago │  │       3s ago   │  │
│  └─────────────────┘  └─────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

## Mobile View (375x667) - Single Column

```
┌───────────────────────┐
│ TekTool         [≡]   │
│ Live Device Monitor   │
│ Updated 3s ago        │
├───────────────────────┤
│                       │
│ ┌───────────────────┐ │
│ │ 🟢 Testo 549i     │ │
│ │ Temperature Probe │ │
│ │                   │ │
│ │     72.5°F        │ │
│ │                   │ │
│ │ 🔋 85%     2s ago │ │
│ └───────────────────┘ │
│                       │
│ ┌───────────────────┐ │
│ │ 🟢 Wey-Tek HD     │ │
│ │ Refrigerant Scale │ │
│ │                   │ │
│ │     18.4 oz       │ │
│ │                   │ │
│ │ 🔋 92%     2s ago │ │
│ └───────────────────┘ │
│                       │
│ ┌───────────────────┐ │
│ │ 🟡 ABM-200        │ │
│ │ Airflow Meter     │ │
│ │                   │ │
│ │    450 FPM        │ │
│ │                   │ │
│ │ 🔋 67%    15s ago │ │
│ └───────────────────┘ │
│                       │
└───────────────────────┘
```

## No Devices View

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TekTool                                          [Refresh] [Theme] [Logout] │
│ Live Device Monitor                                                         │
│ No updates yet                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                                                                             │
│                            🔍                                               │
│                       Bluetooth Searching                                   │
│                                                                             │
│                       No active devices                                     │
│                                                                             │
│            Connect devices in the mobile app                                │
│            to see live data here                                            │
│                                                                             │
│                                                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Device Card States

### Active (Green) - Data < 5 seconds old
```
┌──────────────────────┐
│ 🟢 Testo 549i        │  ← Green dot
│ Temperature Probe    │
│                      │
│     72.5°F           │  ← Large, bold cyan text
│                      │
│ 🔋 85%      2s ago   │  ← Battery + timestamp
└──────────────────────┘
```

### Recent (Yellow) - Data 5-30 seconds old
```
┌──────────────────────┐
│ 🟡 ABM-200           │  ← Yellow dot
│ Airflow Meter        │
│                      │
│    450 FPM           │
│                      │
│ 🔋 67%     15s ago   │
└──────────────────────┘
```

### Stale (Red) - Data > 30 seconds old
```
┌──────────────────────┐
│ 🔴 Testo T115i       │  ← Red dot
│ Temperature Probe    │
│                      │
│     68.2°F           │
│                      │
│ 🔋 45%      2m ago   │  ← Red battery icon
└──────────────────────┘
```

## Color Palette

### Background Gradient
```
Top:    #1A1A2E (dark blue-gray)
Middle: #16213E (midnight blue)
Bottom: #0F3460 (deep blue)
```

### Text Colors
```
Primary:   #E0E0E0 (light gray)
Secondary: #888888 (medium gray)
Muted:     #6B7280 (dark gray)
```

### Accent Colors
```
Cyan:    #4EC7F3 (bright cyan - readings)
Purple:  #764BA2 (purple - admin badge)
Green:   #10B981 (success - active)
Yellow:  #F59E0B (warning - recent)
Red:     #EF4444 (error - stale)
```

### UI Elements
```
Card background: rgba(30, 30, 46, 0.95)
Border:          rgba(255, 255, 255, 0.1)
Button gradient: #764BA2 → #667EEA
```

## Interactions

### Refresh Button
- Click → Brief loading indicator → Data refreshes → Success toast

### Theme Toggle
- Click → Smooth transition between dark/light mode
- Persists to localStorage

### Admin User Dropdown
- Click → Dropdown opens with user list
- Select user → Cards fade out → New data loads → Cards fade in

### Device Card Hover (Desktop)
- Subtle lift animation
- Border color brightens
- Shows full device ID if admin

## Loading States

### Initial Load
```
┌─────────────────────────────────────┐
│                                     │
│            ⟳ Loading...             │
│                                     │
│     Connecting to Firebase...       │
│                                     │
└─────────────────────────────────────┘
```

### Refreshing Data
```
Top-right corner shows:
  [⟳ Refreshing...] (spinner animation)
```

### User Switch (Admin)
```
Cards show skeleton loaders during transition:
┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓             │
│ ▓▓▓▓▓▓▓▓▓▓▓          │
│                      │
│     ▓▓▓▓▓▓           │
│                      │
│ ▓▓▓▓        ▓▓▓▓▓▓   │
└──────────────────────┘
```

## Animations

- **Card entrance**: Fade in + slide up (200ms, ease-out)
- **Card update**: Pulse highlight (300ms)
- **Status dot**: Fade between colors (500ms)
- **Battery icon**: Smooth color transition (300ms)
- **Hover**: Scale 1.02, lift shadow (200ms, ease-out)

## Accessibility

- ✅ Keyboard navigation support (Tab, Enter, Esc)
- ✅ ARIA labels on all interactive elements
- ✅ High contrast color ratios (WCAG AA)
- ✅ Focus indicators on all buttons
- ✅ Screen reader announcements for data updates

## Browser Support

- ✅ Chrome 90+ (primary target)
- ✅ Safari 14+ (Mac default)
- ✅ Firefox 88+
- ✅ Edge 90+
- ⚠️ IE 11 not supported (uses modern web APIs)
