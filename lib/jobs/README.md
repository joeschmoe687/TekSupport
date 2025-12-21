# Jobs Module

Guided workflow system for HVAC commissioning and service calls.

## Structure

```
lib/jobs/
├── models/              # Data models
│   ├── job.dart        # Job (commissioning/service call)
│   ├── equipment.dart  # HVAC equipment (AC, Heat Pump, etc.)
│   └── job_step.dart   # Workflow step
├── services/           # Business logic
│   ├── job_service.dart      # Job CRUD and workflow management
│   └── location_service.dart # GPS and geocoding
└── screens/            # UI components
    ├── job_launch_screen.dart    # Job type selection
    ├── job_workflow_screen.dart  # Step orchestration
    └── steps/                    # Individual step screens
        ├── location_capture_step.dart
        ├── customer_info_step.dart
        ├── system_type_step.dart
        ├── nameplate_scan_step.dart
        ├── mode_selection_step.dart
        ├── gauge_connection_step.dart
        ├── stabilization_step.dart
        ├── amp_draw_step.dart
        ├── diagnostics_step.dart
        └── completion_step.dart
```

## Quick Start

### Launch a Job
Tap the "Start Job" floating action button in the main navigation (techs/admins only).

### Workflow Types

**Commissioning** (full workflow):
1. Location Capture
2. Customer Info
3. System Type Selection
4. Nameplate Scan
5. Mode Selection
6. Gauge Connection
7. Stabilization (20 min)
8. Amp Draw Measurement
9. Diagnostics
10. Completion

**Service Call** (simplified):
1. Location Capture
2. Customer Info
3. Diagnostics
4. Completion

## Firebase Collections

- `jobs` - Job documents
- `jobSteps` - Step documents (linked by jobId)
- `equipment` - Equipment documents (linked by jobId)

## Adding a New Step

1. Add enum to `StepType` in `job_step.dart`
2. Create step widget in `screens/steps/`
3. Add case to `_buildStepWidget()` in `job_workflow_screen.dart`
4. Update `_initializeWorkflowSteps()` in `job_service.dart`

## Integration

- **TekTool** - Diagnostics step links to Tools Hub
- **Devices** - Gauge connection links to device manager
- **Location** - Uses geolocator and geocoding packages
- **Camera** - Uses image_picker (OCR placeholder)

See [docs/features/GUIDED_JOB_WORKFLOW.md](../../docs/features/GUIDED_JOB_WORKFLOW.md) for full documentation.
