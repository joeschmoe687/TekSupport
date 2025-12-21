# Guided Job Workflow Documentation

## Overview

The Guided Job Workflow feature provides step-by-step guidance for HVAC technicians performing commissioning and service calls. It walks users through proper procedures, automates data collection, and integrates with the TekTool Bluetooth hub for live measurements.

## Architecture

### Data Models

#### Job (`lib/jobs/models/job.dart`)
- Represents a single job (commissioning or service call)
- Stores job metadata, location, customer info, timestamps
- Syncs to Firestore `jobs` collection

**Fields:**
- `id`, `userId`, `type` (commissioning/serviceCall)
- `status` (pending/inProgress/completed/cancelled)
- `customerName`, `locationAddress`, `latitude`, `longitude`
- `createdAt`, `updatedAt`, `completedAt`
- `metadata` (flexible JSON for step-specific data)

#### Equipment (`lib/jobs/models/equipment.dart`)
- Represents HVAC equipment scanned during job
- Stores nameplate data (brand, model, serial, specs)
- Supports multiple equipment types per job
- Syncs to Firestore `equipment` collection

**Fields:**
- `type` (condenser/evaporatorCoil/airHandler/furnace)
- `systemType` (ac/heatPump/furnace)
- `brand`, `model`, `serialNumber`, `refrigerantType`
- `voltage`, `mca`, `mop`, `rla`, `fla` (electrical specs)
- `nameplateImageUrl`, `ocrData`

#### JobStep (`lib/jobs/models/job_step.dart`)
- Represents individual workflow steps
- Auto-generated when job is created based on type
- Tracks completion status and stores step-specific data
- Syncs to Firestore `jobSteps` collection

**Step Types:**
- `locationCapture` - GPS location detection
- `customerInfo` - Customer name entry
- `systemTypeSelection` - AC vs Heat Pump
- `nameplateOcr` - Equipment scanning
- `modeSelection` - AC vs Heat mode
- `gaugeConnection` - Bluetooth device connection
- `stabilization` - 20-minute wait timer
- `ampDrawMeasurement` - Electrical readings
- `diagnostics` - Live gauge readings
- `completion` - Final notes and completion

### Services

#### JobService (`lib/jobs/services/job_service.dart`)
Central service for job management:
- `createJob(type)` - Creates job and initializes workflow steps
- `updateJob(job)` - Updates job data
- `completeJob(jobId)` - Marks job as completed
- `getJob(jobId)` - Fetches single job
- `getUserJobs()` - Stream of user's jobs
- `getJobSteps(jobId)` - Stream of job's workflow steps
- `updateJobStep(step)` - Updates step data
- `completeJobStep(stepId)` - Marks step as completed
- `addEquipment(equipment)` - Adds equipment to job
- `getJobEquipment(jobId)` - Stream of job's equipment

#### LocationService (`lib/jobs/services/location_service.dart`)
Handles GPS and geocoding:
- `getCurrentLocation()` - Gets current GPS coordinates
- `getAddressFromCoordinates()` - Reverse geocoding
- `getCoordinatesFromAddress()` - Forward geocoding
- `requestPermission()` - Requests location permission

### Screens

#### JobLaunchScreen (`lib/jobs/screens/job_launch_screen.dart`)
Entry point for starting a job:
- Two options: Commissioning or Service Call
- Creates job and initializes workflow steps
- Navigates to JobWorkflowScreen

#### JobWorkflowScreen (`lib/jobs/screens/job_workflow_screen.dart`)
Main orchestration screen:
- Displays progress indicator (X of Y steps, % complete)
- Renders current step widget
- Handles step completion and navigation
- Streams job steps from Firestore for real-time updates

#### Step Screens (`lib/jobs/screens/steps/`)
Individual step implementations:

**LocationCaptureStep** - Auto-detects GPS location, allows manual edit
**CustomerInfoStep** - Simple text input for customer name
**SystemTypeStep** - Card selection for AC vs Heat Pump
**NameplateScanStep** - Camera integration + manual entry fallback
**ModeSelectionStep** - AC vs Heat mode selection
**GaugeConnectionStep** - Instructions + link to Devices screen
**StabilizationStep** - 20-minute countdown with skip option
**AmpDrawStep** - Three number inputs for motor amps
**DiagnosticsStep** - Links to TekTool, shows tips
**CompletionStep** - Final notes input + completion

## User Flow

### Commissioning Flow
1. Tech taps "Start Job" FAB in main navigation
2. Selects "Commissioning"
3. **Location Capture** - GPS detects address, tech verifies
4. **Customer Info** - Enters customer name
5. **System Type** - Selects AC or Heat Pump
6. **Nameplate Scan** - Photos equipment nameplate (or manual entry)
7. **Mode Selection** - Starts system in AC or Heat mode
8. **Gauge Connection** - Connects Bluetooth gauges and probes
9. **Stabilization** - 20-minute wait for system to stabilize
10. **Amp Draw** - Measures motor amp draws
11. **Diagnostics** - Opens TekTool for live readings
12. **Completion** - Adds notes, marks job complete

### Service Call Flow
1. Tech taps "Start Job" FAB
2. Selects "Service Call"
3. **Location Capture** - GPS detects address
4. **Customer Info** - Enters customer name
5. **Diagnostics** - Opens TekTool for troubleshooting
6. **Completion** - Marks job complete

## Integration Points

### Firebase Collections
- `jobs` - Job documents
- `jobSteps` - Step documents (linked by `jobId`)
- `equipment` - Equipment documents (linked by `jobId`)

### TekTool Integration
- **GaugeConnectionStep** - Links to Devices screen for BLE pairing
- **DiagnosticsStep** - Links to Tools Hub for live gauge readings
- Gauge data can reference active job context for automatic documentation

### Location Services
- Requires `ACCESS_FINE_LOCATION` permission (Android)
- Uses `geolocator` package for GPS
- Uses `geocoding` package for address lookup

### Camera/OCR
- Requires `CAMERA` permission
- Uses `image_picker` package for photo capture
- Placeholder for `google_mlkit_text_recognition` OCR implementation

## Future Enhancements

### Phase 4: Interactive Gauge Guidance
- Target pressure calculations based on equipment specs
- Real-time superheat/subcool comparison with targets
- Visual indicators (green/yellow/red) for in-spec readings
- Refrigerant adjustment prompts ("Add 2oz" / "Remove 4oz")
- AI-powered troubleshooting suggestions

### Phase 5: Beginner Mode
- Enhanced help text and explanations
- Photo verification (AI checks gauge hookup, probe placement)
- Error prevention warnings
- Educational tips throughout workflow

### Phase 6: Admin Customization
- Web dashboard for workflow configuration
- Custom step templates
- Per-brand/model workflow overrides
- Company-specific procedures

### AHRI Integration
- Auto-lookup system ratings from equipment models
- Display SEER2, EER2, HSPF2 ratings
- Show rated capacity and efficiency

### Install Manual Parsing
- Fetch manufacturer install docs
- Extract charging charts, wiring diagrams
- Context-sensitive guidance from manual data

## Development Notes

### Adding New Step Types
1. Add enum value to `StepType` in `job_step.dart`
2. Create step widget in `lib/jobs/screens/steps/`
3. Add case to `_buildStepWidget()` in `job_workflow_screen.dart`
4. Update `_initializeWorkflowSteps()` in `job_service.dart`

### Modifying Workflow Order
Edit `_initializeWorkflowSteps()` in `job_service.dart` to change step order or conditionally include steps based on job type or equipment.

### Step Data Storage
Use the `onComplete` callback to pass step-specific data:
```dart
widget.onComplete({
  'myField': myValue,
  'anotherField': anotherValue,
});
```
Data is stored in `job.metadata` and persists across app restarts.

## Testing Checklist
- [ ] Create commissioning job, complete all steps
- [ ] Create service call job, verify simplified flow
- [ ] Test GPS location detection and manual edit
- [ ] Test camera integration for nameplate scanning
- [ ] Test stabilization timer (skip and full countdown)
- [ ] Verify job data syncs to Firestore
- [ ] Test job completion and history view
- [ ] Verify TekTool integration in diagnostics step
- [ ] Test device connection from gauge step

## Known Limitations
- OCR implementation is placeholder (manual entry only)
- No AHRI database integration yet
- No target pressure calculations
- No AI troubleshooting suggestions
- No admin customization panel
- No job history view in app (exists in Firestore)
