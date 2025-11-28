# ERLELO v2.5 Initialization Design Document

## Document Information
| Field | Value |
|-------|-------|
| Version | 1.0 |
| Date | November 28, 2024 |
| Status | Draft for Review |

---

## 1. Problem Statement

### 1.1 Current Issue

When the SINUM controller reboots, all variables reset to their default values (typically 0). This causes:

| Issue | Description | Risk Level |
|-------|-------------|------------|
| False Emergency | Sensors show 0°C, 0% RH | High |
| Unsafe Responses | Controller triggers heating/humidification | High |
| Empty Buffers | Moving average has no data | Medium |
| No History | Previous control state lost | Low |

### 1.2 Current Behavior (Undesired)

```
REBOOT
  │
  ▼
Variables reset to 0
  │
  ▼
Controller reads: T=0°C, RH=0%
  │
  ▼
Control logic: "Emergency! Too cold and dry!"
  │
  ▼
Heating ON, Humidifier ON  ← DANGEROUS
```

---

## 2. Proposed Solution

### 2.1 User Story

> As a facility operator, when I reboot the SINUM controller, I want the ERLELO system to safely initialize for 32 seconds before starting normal control operations, so that no dangerous relay switching occurs based on invalid sensor data.

### 2.2 Desired Behavior

```
REBOOT
  │
  ▼
INITIALIZATION MODE (32 seconds)
  │
  ├── System operates in NORMAL mode
  ├── All control logic runs normally
  ├── Sensors collect real data
  ├── Buffers fill with valid readings
  ├── All relays held in SAFE OFF state
  │
  ▼
INITIALIZATION COMPLETE
  │
  ▼
Normal operation begins (including sleep cycle)
```

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-01 | System shall have a 32-second initialization phase after startup | Must |
| FR-02 | During initialization, system shall operate in NORMAL control mode | Must |
| FR-03 | During initialization, all relays shall remain in OFF state | Must |
| FR-04 | Sensor data collection shall continue during initialization | Must |
| FR-05 | Moving average buffers shall fill during initialization | Must |
| FR-06 | After 32 seconds, system shall transition to normal operation | Must |
| FR-07 | Sleep cycle shall only apply after initialization completes | Must |

### 3.2 Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-01 | Initialization shall not require manual intervention | Must |
| NFR-02 | Initialization state shall be visible in signals output | Should |
| NFR-03 | Initialization duration shall be configurable via constansok | Could |

---

## 4. Technical Design

### 4.1 New Variables/Parameters

| Parameter | Location | Default | Description |
|-----------|----------|---------|-------------|
| `init_duration` | constansok | 32 | Initialization period in seconds |
| `init_complete` | signals | false | Initialization status flag |
| `init_countdown` | signals | 32 | Remaining seconds in init |

### 4.2 Relay States During Initialization

| Relay | State | Reason |
|-------|-------|--------|
| relay_cool | OFF | Prevent cooling on false data |
| relay_warm | OFF | Prevent heating on false data |
| relay_humidifier | OFF | Prevent humidification on false data |
| relay_add_air_max | OFF | No outdoor air during init |
| relay_bypass_open | OFF | Standard safe position |

### 4.3 Control Flow Modification

```lua
-- Pseudo-code for initialization logic

local init_start_time = nil
local init_complete = false

function onPoll()
  -- Track initialization
  if init_start_time == nil then
    init_start_time = os.time()
  end
  
  local elapsed = os.time() - init_start_time
  local init_duration = C('init_duration') or 32
  
  if elapsed < init_duration then
    init_complete = false
  else
    init_complete = true
  end
  
  -- Normal sensor reading and processing
  readSensors()
  updateBuffers()
  calculatePsychrometrics()
  
  -- Normal control logic (humidity mode, temperature control)
  runControlLogic()
  
  -- Apply relay outputs
  if init_complete then
    -- Normal relay control (respects sleep cycle)
    applyRelayOutputs()
  else
    -- Initialization: all relays OFF
    setAllRelaysOff()
    signals.init_countdown = init_duration - elapsed
  end
  
  signals.init_complete = init_complete
  writeSignals()
end
```

### 4.4 State Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        SYSTEM STARTUP                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INITIALIZATION MODE                          │
│                                                                 │
│  Duration: 32 seconds                                           │
│  Control Mode: NORMAL (FINE/HUMID/DRY logic runs)              │
│  Relay State: ALL OFF                                           │
│                                                                 │
│  Activities:                                                    │
│  ✓ Sensor data collection                                       │
│  ✓ Moving average buffer filling                                │
│  ✓ Psychrometric calculations                                   │
│  ✓ Control logic execution (outputs ignored)                    │
│  ✓ Humidity mode determination                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 32 seconds elapsed
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NORMAL OPERATION                             │
│                                                                 │
│  Control Mode: NORMAL (FINE/HUMID/DRY)                         │
│  Relay State: Controlled by logic                               │
│  Sleep Cycle: Active if enabled                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Implementation Plan

### 5.1 Changes Required

| File | Change | Complexity |
|------|--------|------------|
| erlelo_kamra1.lua | Add initialization tracking and relay override | Medium |
| erlelo_config_Xch.json | Add init_duration parameter | Low |
| signals output | Add init_complete, init_countdown fields | Low |

### 5.2 Code Changes Summary

1. **Add initialization timer**: Track startup time and elapsed seconds
2. **Add relay override**: During init, force all relays OFF regardless of control logic
3. **Add status reporting**: Include init state in signals JSON
4. **Add configurable duration**: init_duration in constansok (default 32)

### 5.3 Backward Compatibility

- Existing installations will use default 32-second init
- No changes required to UI or monitoring
- Control logic unchanged, only relay output timing affected

---

## 6. Testing Plan

### 6.1 Test Cases

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| TC-01 | Reboot controller | Relays stay OFF for 32 seconds |
| TC-02 | Monitor sensors during init | Readings increase from 0 to actual |
| TC-03 | Check buffers after init | Buffers contain valid data |
| TC-04 | Verify init_complete flag | False during init, true after |
| TC-05 | Verify normal operation after init | Relays respond to control logic |
| TC-06 | Test sleep cycle after init | Sleep cycle operates normally |

### 6.2 Acceptance Criteria

- [ ] No relay activation during 32-second initialization
- [ ] Sensor data collected throughout initialization
- [ ] Smooth transition to normal operation
- [ ] Sleep cycle unaffected after initialization
- [ ] Status visible in signals output

---

## 7. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Chamber conditions drift during init | Medium | 32 seconds is short; product safe |
| Sensor failure not detected | Low | Existing error counting still active |
| Init too short for buffer fill | Low | 32s > 5 samples at 1s interval |

---

## 8. Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| System Owner | | | |
| Developer | | | |
| Reviewer | | | |

---

## 9. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024-11-28 | System Design | Initial draft |
