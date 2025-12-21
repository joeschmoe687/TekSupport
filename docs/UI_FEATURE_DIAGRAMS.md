# UI Feature Diagrams

## Light Theme vs Dark Theme

### Dark Theme (Original - Indoor Use)
```
╔══════════════════════════════════════╗
║  Gauges         [☀]  [⚙]  [R-410A▼] ║
╠══════════════════════════════════════╣
║                                      ║
║  ┌───────────────┐  ┌──────────────┐║
║  │ Low Side  📡 🔋│  │High Side 📡 🔋│║
║  │               │  │              │║
║  │               │  │              │║
║  │      72.5     │  │    285.3     │║
║  │      PSI      │  │     PSI      │║
║  │               │  │              │║
║  │  Sat: 41.2°F  │  │ Sat: 105.3°F │║
║  └───────────────┘  └──────────────┘║
║                                      ║
║  Background: Dark gradient           ║
║  Text: Light gray/white              ║
║  Accents: Cyan & Purple              ║
╚══════════════════════════════════════╝
```

### Light Theme (New - Outdoor Use)
```
╔══════════════════════════════════════╗
║  Gauges         [🌙]  [⚙]  [R-410A▼] ║
╠══════════════════════════════════════╣
║                                      ║
║  ┌───────────────┐  ┌──────────────┐║
║  │ Low Side  📡 🔋│  │High Side 📡 🔋│║
║  │               │  │              │║
║  │               │  │              │║
║  │      72.5     │  │    285.3     │║
║  │      PSI      │  │     PSI      │║
║  │               │  │              │║
║  │  Sat: 41.2°F  │  │ Sat: 105.3°F │║
║  └───────────────┘  └──────────────┘║
║                                      ║
║  Background: Light gray gradient     ║
║  Text: Dark gray/black (HIGH CONTRAST)║
║  Borders: Visible light gray         ║
╚══════════════════════════════════════╝
```

## Digital vs Analog Gauge Modes

### Digital Mode (Default)
```
┌─────────────────────────────────────────────┐
│  [📊] ← Tap to switch to Analog             │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────┐      ┌──────────────┐   │
│  │ Low Side      │      │ High Side    │   │
│  │   📡 🔋85%    │      │   📡 🔋85%   │   │
│  │               │      │              │   │
│  │               │      │              │   │
│  │    72.5       │      │   285.3      │   │
│  │    PSI        │      │    PSI       │   │
│  │               │      │              │   │
│  │ Sat: 41.2°F   │      │Sat: 105.3°F  │   │
│  └───────────────┘      └──────────────┘   │
│                                             │
│  Clean box layout                           │
│  Precise digital readout                    │
│  Saturation temperature shown               │
└─────────────────────────────────────────────┘
```

### Analog Mode (Classic)
```
┌─────────────────────────────────────────────┐
│  [📈] ← Tap to switch to Digital            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────┐      ┌──────────────┐   │
│  │ Low Side 📡🔋 │      │High Side 📡🔋 │   │
│  │               │      │              │   │
│  │     ╭─────╮   │      │   ╭─────╮    │   │
│  │    ╱  72.5 ╲  │      │  ╱ 285.3 ╲   │   │
│  │   │   PSI   │ │      │ │   PSI   │  │   │
│  │   │    🔴   │ │      │ │   🔴    │  │   │
│  │    ╲   │   ╱  │      │  ╲  │    ╱   │   │
│  │     ╰───┼───╯ │      │   ╰──┼───╯   │   │
│  │         ▼     │      │      ▼       │   │
│  │  Testo 115i   │      │ Testo 549i   │   │
│  └───────────────┘      └──────────────┘   │
│                                             │
│  Round dial with needle                     │
│  Visual indicator of pressure               │
│  Familiar analog gauge feel                 │
└─────────────────────────────────────────────┘
```

## Scale Auto-Display Feature

### Gauge Screen Without Scale
```
╔═══════════════════════════════════════════╗
║  Gauges         [📊]  [⚙]  [R-410A▼]      ║
╠═══════════════════════════════════════════╣
║                                           ║
║  ┌───────────────┐    ┌──────────────┐   ║
║  │ Low Side      │    │ High Side    │   ║
║  │     72.5      │    │    285.3     │   ║
║  │     PSI       │    │     PSI      │   ║
║  └───────────────┘    └──────────────┘   ║
║                                           ║
║  ┌──────────────────────────────────┐    ║
║  │  Superheat: 12.3°F │ Subcool: 8.5°F│  ║
║  └──────────────────────────────────┘    ║
║                                           ║
║  [No scale connected]                     ║
║                                           ║
║                                           ║
╚═══════════════════════════════════════════╝
```

### Gauge Screen WITH Scale (Auto-Appears)
```
╔═══════════════════════════════════════════╗
║  Gauges         [📊]  [⚙]  [R-410A▼]      ║
╠═══════════════════════════════════════════╣
║                                           ║
║  ┌───────────────┐    ┌──────────────┐   ║
║  │ Low Side      │    │ High Side    │   ║
║  │     72.5      │    │    285.3     │   ║
║  │     PSI       │    │     PSI      │   ║
║  └───────────────┘    └──────────────┘   ║
║                                           ║
║  ┌──────────────────────────────────┐    ║
║  │  Superheat: 12.3°F │ Subcool: 8.5°F│  ║
║  └──────────────────────────────────┘    ║
║                                           ║
║ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    ║
║ ┃ 🔴 Wey-Tek HD        📶 🔋 92%   ┃ ← Auto-appears!
║ ┃                                  ┃    ║
║ ┃ 24.35 oz                         ┃    ║
║ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    ║
╚═══════════════════════════════════════════╝
     └─ Scale overlay (purple gradient)
```

### Scale Disconnected (Shows Last Weight)
```
╔═══════════════════════════════════════════╗
║  Gauges         [📊]  [⚙]  [R-410A▼]      ║
╠═══════════════════════════════════════════╣
║                                           ║
║  ┌───────────────┐    ┌──────────────┐   ║
║  │ Low Side      │    │ High Side    │   ║
║  │     72.5      │    │    285.3     │   ║
║  │     PSI       │    │     PSI      │   ║
║  └───────────────┘    └──────────────┘   ║
║                                           ║
║ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    ║
║ ┃ 🔴 Wey-Tek HD        📵 🔋 92%   ┃    ║
║ ┃                                  ┃    ║
║ ┃ 24.35 oz                         ┃    ║
║ ┃ Last known weight                ┃ ← Preserved!
║ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    ║
╚═══════════════════════════════════════════╝
     └─ Grayed out overlay (disconnected)
```

## Connection Flow Diagram

### Scale Connection Lifecycle
```
[Tech walks outside]
        │
        ▼
[Scale powers on]
        │
        ▼
[BLE Advertisement detected] ──────────┐
        │                              │
        ▼                              │
[Scale widget appears] ◄───────────────┘
        │                    Auto-detect
        ▼
[Real-time weight updates]
        │
        ▼
[Tech walks inside]
        │
        ▼
[Signal lost - Disconnected]
        │
        ▼
[Widget stays visible]
[Shows "Last known weight"]
[Weight: 24.35 oz (preserved)]
        │
        ▼
[Tech walks back outside]
        │
        ▼
[Signal regained - Reconnected] ───────┐
        │                              │
        ▼                              │
[Weight updates resume] ◄──────────────┘
[Calibration intact]         Seamless
```

## User Interaction Flow

### Switching Display Modes
```
┌─────────────────────────────────────┐
│ 1. On Gauge Screen                  │
│    Tap [📊] icon in app bar         │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 2. Display mode switches            │
│    Digital ↔ Analog                 │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 3. Preference saved automatically   │
│    Persists between app launches    │
└─────────────────────────────────────┘
```

### Theme Switching
```
┌─────────────────────────────────────┐
│ 1. Working indoors (Dark theme)     │
│    Tap theme toggle [☀]             │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 2. Going outside                    │
│    Switch to Light theme [🌙]       │
│    High contrast for sunlight       │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 3. Entire app updates               │
│    All screens use light theme      │
│    Preference saved                 │
└─────────────────────────────────────┘
```

## Feature Integration

All three features work together seamlessly:

```
        ┌──────────────────┐
        │   Gauge Screen   │
        └────────┬─────────┘
                 │
        ┌────────┴─────────┐
        │                  │
        ▼                  ▼
   ┌─────────┐      ┌──────────┐
   │ Theme   │      │ Display  │
   │ Toggle  │      │  Mode    │
   └────┬────┘      └────┬─────┘
        │                │
        ▼                ▼
   Light/Dark      Digital/Analog
        │                │
        └────────┬───────┘
                 │
                 ▼
        ┌─────────────────┐
        │  Scale Overlay  │
        │  (Auto-appear)  │
        └─────────────────┘
                 │
                 ▼
        Works in all modes!
```

Legend:
- 📊 = Digital mode icon
- 📈 = Analog mode icon
- ☀ = Light theme (sun icon)
- 🌙 = Dark theme (moon icon)
- 🔋 = Battery indicator
- 📡 = Sensor connected
- 📶 = Signal strength (connected)
- 📵 = No signal (disconnected)
- 🔴 = Scale icon
