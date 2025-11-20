# Aging Chamber Control System - Architecture Diagrams

## Table of Contents
1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Control Flow Diagram](#control-flow-diagram)
4. [Event Processing Flow](#event-processing-flow)
5. [State Machine Diagram](#state-machine-diagram)
6. [Data Flow Diagram](#data-flow-diagram)
7. [Function Call Hierarchy](#function-call-hierarchy)
8. [Cross-Component Interactions](#cross-component-interactions)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     AGING CHAMBER CONTROL SYSTEM                         │
│                    (Tech Sinum Device Platform)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌────────────────┐         ┌────────────────┐
│  DEVICE CODE  │         │  VARIABLES     │         │   HARDWARE     │
│ (Lua Scripts) │◄────────┤  (Storage)     │─────────►│  (Relays/IO)  │
└───────────────┘         └────────────────┘         └────────────────┘
        │                           │                           │
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌────────────────┐         ┌────────────────┐
│ aging_chamber │         │ Variables 1-42 │         │ Modbus Sensors │
│ _Apar2_0_     │         │ - Temp/Humidity│         │ - XY-MD1.1     │
│ REFACTORED    │         │ - Setpoints    │         │ - Supply Air   │
│ .lua          │         │ - Control Flags│         │                │
└───────────────┘         └────────────────┘         └────────────────┘
        │                           │                           │
┌───────────────┐         ┌────────────────┐         ┌────────────────┐
│erlelo_1119_   │         │ Relays (sbus)  │         │ UI Widgets     │
│REFACTORED.json│         │ - 52: cooling  │         │ - Sliders      │
│(embedded Lua) │         │ - 60: heating  │         │ - Text displays│
└───────────────┘         │ - 61-65: fans  │         └────────────────┘
                          └────────────────┘
```

---

## Component Architecture

### UML Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          CustomDevice (Main Controller)                  │
│                    File: aging_chamber_Apar2_0_REFACTORED.lua           │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    │                               │                               │
    ▼                               ▼                               ▼
┌─────────────┐              ┌─────────────┐              ┌──────────────┐
│  LIFECYCLE  │              │   CONTROL   │              │    EVENT     │
│  FUNCTIONS  │              │   LOGIC     │              │  HANDLERS    │
└─────────────┘              └─────────────┘              └──────────────┘
    │                               │                               │
    ├─ onInit()                     ├─ controlling()                ├─ onEvent()
    ├─ online()                     ├─ setrelay()                   ├─ onRegisterAsyncRead()
    ├─ offline()                    └─ intelligent                  ├─ onAsyncRequestFailure()
    ├─ poll()                          propagation                  └─ lua_variable_state_changed
    └─ c()                                                               handler

    ┌───────────────────────────────┼───────────────────────────────┐
    │                               │                               │
    ▼                               ▼                               ▼
┌─────────────┐              ┌─────────────┐              ┌──────────────┐
│   UI/UX     │              │ PSYCHRO-    │              │   SENSOR     │
│  HANDLERS   │              │ METRICS     │              │  FILTERING   │
└─────────────┘              └─────────────┘              └──────────────┘
    │                               │                               │
    ├─ on_Target_                   ├─ calculate_absolute_          ├─ mozgoatlag()
    │  TemperatureChange()           │  humidity()                   │  (moving average)
    ├─ on_Target_                   ├─ calculate_rh()               │
    │  HumidityChange()             ├─ calc_dew_point()             │
    ├─ updateText()                 ├─ saturation_vapor_            │
    ├─ onBaudrate()                 │  pressure()                   │
    ├─ onParity()                   ├─ ah_dp_set()                  │
    ├─ onStopbits()                 ├─ ah_dp_cel_szamol()           │
    ├─ onSlaveId()                  └─ ah_dp_befujt_szamol()        │
    └─ onXceiver()                                                   │

┌─────────────────────────────────────────────────────────────────────────┐
│                          VARIABLE STORAGE                                │
│                   (Tech Sinum Platform - variable[])                    │
└─────────────────────────────────────────────────────────────────────────┘
    │
    ├─ Chamber (kamra) - Variables 1-2, 19-20
    │  ├─ kamra_homerseklet_v1 [1]        (actual temp)
    │  ├─ kamra_para_v1 [2]               (actual humidity)
    │  ├─ kamra_cel_homerseklet_v1 [3]    (target temp) ◄── USER INPUT
    │  ├─ kamra_cel_para_v1 [4]           (target humidity) ◄── USER INPUT
    │  └─ kamra_hibaszam1 [30]            (error count)
    │
    ├─ Supply Air (befujt) - Variables 5-6, 17-18, 23-24, 25, 29
    │  ├─ befujt_cel_homerseklet_v1 [5]   (calculated target temp)
    │  ├─ befujt_cel_para_v1 [6]          (calculated target humidity)
    │  ├─ befujt_homerseklet_akt1 [23]    (filtered actual temp)
    │  ├─ befujt_para_akt1 [24]           (filtered actual humidity)
    │  ├─ befujt_szimulalt1 [25]          (simulation flag)
    │  └─ befujt_hibaszam1 [29]           (error count)
    │
    ├─ Outdoor (kulso) - Variables 7-8, 21-22, 31
    │  ├─ kulso_homerseklet_v1 [7]        (outdoor temp)
    │  ├─ kulso_para_v1 [8]               (outdoor humidity)
    │  ├─ kulso_szimulalt_ertekek_v1 [9]  (simulation flag)
    │  └─ kulso_hibaszam1 [31]            (error count)
    │
    ├─ Control Parameters
    │  ├─ constansok1 [33]                (delta thresholds, hysteresis)
    │  ├─ signals1 [34]                   (control signals)
    │  └─ cycle_variable1 [38]            (cycle state)
    │
    └─ Calculated Values
       ├─ ah_dp_table1 [42]               (dew point, absolute humidity)
       ├─ biztonsagi_hom_akt1 [26]        (safety temperature)
       └─ last_sent_table1 [28]           (propagation history)

┌─────────────────────────────────────────────────────────────────────────┐
│                          HARDWARE INTERFACES                             │
│                      (Tech Sinum Platform - sbus[])                     │
└─────────────────────────────────────────────────────────────────────────┘
    │
    ├─ Cooling/Heating
    │  ├─ relay_cool [52]          (cooling relay)
    │  ├─ relay_warm [60]          (heating relay)
    │  └─ relay_sleep [53]         (rest period relay)
    │
    ├─ Ventilation
    │  ├─ relay_main_fan [65]      (main fan 1-2 speed)
    │  ├─ relay_add_air_max [61]   (max fresh air / summer-winter)
    │  ├─ relay_add_air_save [63]  (fresh air saving mode)
    │  ├─ relay_reventon [62]      (reverse fan)
    │  └─ relay_bypass_open [64]   (humidity bypass)
    │
    └─ Modbus Communication
       └─ com (component)          (Modbus RTU client)
          ├─ baud_rate: 9600
          ├─ parity: none
          ├─ stop_bits: one
          └─ slave_address: 5

---

## Control Flow Diagram

### Main Control Loop (Every 5 seconds)

```
                          ┌──────────────────────┐
                          │  SYSTEM STARTUP      │
                          │  File: aging_chamber │
                          │  _Apar2_0_REFACTORED │
                          │  .lua:58-81          │
                          └──────────┬───────────┘
                                     │
                                     ▼
                    ┌────────────────────────────┐
                    │   CustomDevice:onInit()    │
                    │   - Initialize UI elements │
                    │   - Initialize sliders ✓   │ ◄── BUG FIX #1
                    │   - Set error counters     │
                    └────────────┬───────────────┘
                                 │
                                 ▼
                    ┌────────────────────────────┐
                    │   CustomDevice:online()    │
                    │   - Set status = 'online'  │
                    │   - Start polling          │
                    └────────────┬───────────────┘
                                 │
                                 ▼
       ┌─────────────────────────────────────────────────┐
       │            MAIN EVENT LOOP (Line 505-619)       │
       │            onEvent(event)                       │
       └─────────────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
       ┌────────────────────┐    ┌──────────────────────┐
       │  Timer Event       │    │  Modbus Response     │
       │  (every 5 sec)     │    │  Event               │
       └────────┬───────────┘    └──────┬───────────────┘
                │                       │
                │                       │
    ┌───────────┴──────────┐           │
    │                      │           │
    ▼                      ▼           ▼
┌─────────┐      ┌──────────────┐   ┌────────────────┐
│ poll()  │      │ controlling()│   │ onRegisterAsync│
│ Line    │      │ Line 215-453 │   │ Read()         │
│ 651-654 │      │              │   │ Line 524-549   │
└────┬────┘      └──────┬───────┘   └────┬───────────┘
     │                  │                │
     │                  │                │
     └──────────────────┴────────────────┘
                        │
            ┌───────────┴───────────┐
            │                       │
            ▼                       ▼
  ┌──────────────────┐   ┌──────────────────────┐
  │ Read Modbus      │   │ Update Variables     │
  │ Registers 1-2    │   │ (with moving avg)    │
  │ (temp, humidity) │   │ mozgoatlag()         │
  │                  │   │ Line 460-501         │
  └──────────────────┘   └──────┬───────────────┘
                                │
                                ▼
                   ┌────────────────────────┐
                   │ Variable State Changed │
                   │ Event Triggered        │
                   └────────┬───────────────┘
                            │
            ┌───────────────┴────────────────┐
            │                                │
            ▼                                ▼
  ┌──────────────────┐           ┌───────────────────┐
  │ Update UI        │           │ Propagate to      │
  │ Displays         │           │ Other Devices     │
  │ Line 555-591     │           │ (if threshold met)│
  └──────────────────┘           └───────────────────┘
```

### Controlling() Function - Decision Tree

```
┌────────────────────────────────────────────────────────────────────┐
│                    controlling() - Line 215-453                    │
│                  Called every 5 seconds by timer                   │
└────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 1: Read Current Values                                         │
│ - kamra_homerseklet (chamber actual temp)                          │
│ - kamra_para (chamber actual humidity)                             │
│ - kamra_cel_homerseklet (chamber target temp)                      │
│ - kamra_cel_para (chamber target humidity)                         │
│ - befujt_mert_homerseklet (supply air actual temp)                 │
│ - befujt_mert_para (supply air actual humidity)                    │
│ - constansok1 (delta thresholds: ±2°C, ±3%)                        │
│ - signals1 (control flags: sleep, summer/winter, etc.)             │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 2: Calculate Supply Air Targets (Line 280-309)                │
│                                                                      │
│ IF kamra_hibaflag (chamber sensor error):                          │
│   befujt_cel_temp = kamra_cel_temp  (use target directly)          │
│   befujt_cel_humi = kamra_cel_humi  (use target directly)          │
│ ELSE:                                                               │
│   befujt_cel_temp = kamra_cel_temp +                               │
│                     (kamra_cel_temp - kamra_actual_temp)/2          │
│   befujt_cel_humi = kamra_cel_humi +                               │
│                     (kamra_cel_humi - kamra_actual_humi)/2          │
│                                                                      │
│ Intelligent Propagation:                                            │
│   IF |new - old| >= 0.2°C: PROPAGATE temp change                   │
│   IF |new - old| >= 0.3%:  PROPAGATE humidity change               │
│   ELSE: setValue(..., true)  [block propagation]                   │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 3: Chamber Temperature Control Logic (Line 312-349)           │
│                                                                      │
│ IF NOT kamra_hibaflag:                                             │
│                                                                      │
│   Temperature Control Flags:                                        │
│   ┌────────────────────────────────────────────────────────┐       │
│   │ IF kamra_temp > (target + 2×delta_hi):                │       │
│   │   kamra_hutes = TRUE  (start cooling)                 │       │
│   │                                                         │       │
│   │ IF kamra_temp < (target + delta_hi):                  │       │
│   │   kamra_hutes = FALSE (stop cooling)                  │       │
│   │                                                         │       │
│   │ IF kamra_temp > (target - delta_lo):                  │       │
│   │   kamra_hutes_tiltas = FALSE (allow cooling)          │       │
│   │   kamra_futes = FALSE (stop heating)                  │       │
│   │                                                         │       │
│   │ IF kamra_temp < (target - 2×delta_lo):                │       │
│   │   kamra_futes = TRUE  (start heating)                 │       │
│   │                                                         │       │
│   │ IF kamra_temp < (target - 3×delta_lo):                │       │
│   │   kamra_hutes_tiltas = TRUE (prevent cooling)         │       │
│   └────────────────────────────────────────────────────────┘       │
│                                                                      │
│   Humidity Control Flags:                                           │
│   ┌────────────────────────────────────────────────────────┐       │
│   │ IF kamra_humi > (target + 2×delta_hi):                │       │
│   │   kamra_para_hutes = TRUE  (dehumidify)               │       │
│   │                                                         │       │
│   │ IF kamra_humi < (target + delta_hi):                  │       │
│   │   kamra_para_hutes = FALSE (stop dehumidify)          │       │
│   │                                                         │       │
│   │ IF kamra_humi < (target - 2×delta_lo):                │       │
│   │   kamra_para_futes_tiltas = TRUE (prevent humidify)   │       │
│   │                                                         │       │
│   │ IF kamra_humi > (target - delta_lo):                  │       │
│   │   kamra_para_futes_tiltas = FALSE (allow humidify)    │       │
│   └────────────────────────────────────────────────────────┘       │
│                                                                      │
│ ELSE (sensor error):                                               │
│   All flags = FALSE (safety mode)                                  │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 4: Supply Air Temperature Control (Line 351-389)              │
│                                                                      │
│ Supply Air Heating/Cooling Logic:                                   │
│ ┌──────────────────────────────────────────────────────────┐       │
│ │ IF befujt_temp > (befujt_target + delta_hi):            │       │
│ │   befujt_hutes = TRUE, befujt_futes = FALSE             │       │
│ │                                                           │       │
│ │ IF befujt_temp > befujt_target:                         │       │
│ │   befujt_futes = FALSE                                  │       │
│ │                                                           │       │
│ │ IF befujt_temp < befujt_target:                         │       │
│ │   befujt_hutes = FALSE                                  │       │
│ │                                                           │       │
│ │ IF befujt_temp < (befujt_target - delta_lo):            │       │
│ │   befujt_futes = TRUE, befujt_hutes = FALSE             │       │
│ │                                                           │       │
│ │ IF befujt_temp < (befujt_target - 2×delta_lo):          │       │
│ │   hutes_tiltas = TRUE  (prevent cooling)                │       │
│ │                                                           │       │
│ │ IF befujt_temp < MIN_SUPPLY_AIR_TEMP (6.0°C):           │       │
│ │   hutes_tiltas = TRUE  (safety limit)                   │       │
│ └──────────────────────────────────────────────────────────┘       │
│                                                                      │
│ Supply Air Humidity Logic:                                          │
│ ┌──────────────────────────────────────────────────────────┐       │
│ │ IF befujt_humi > (befujt_target + delta_hi):            │       │
│ │   befujt_para_hutes = TRUE (dehumidify supply air)      │       │
│ │   futes_tiltas = FALSE                                  │       │
│ │                                                           │       │
│ │ IF befujt_humi < befujt_target - delta_lo:              │       │
│ │   futes_tiltas = TRUE (prevent humidification)          │       │
│ └──────────────────────────────────────────────────────────┘       │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 5: Combine Signals & Apply Logic (Line 392-414)               │
│                                                                      │
│ Final Control Signals:                                              │
│ ┌──────────────────────────────────────────────────────────┐       │
│ │ warm = (kamra_futes OR befujt_futes)                    │       │
│ │        AND NOT (kamra_para_futes_tiltas OR futes_tiltas)│       │
│ │        AND NOT sleep                                     │       │
│ │                                                           │       │
│ │ cool = (kamra_hutes OR befujt_hutes OR kamra_para_hutes)│       │
│ │        AND NOT kamra_hutes_tiltas                        │       │
│ │                                                           │       │
│ │ cool_rel = cool AND (NOT sleep) AND sum_wint_jel        │       │
│ │                                                           │       │
│ │ dehumi = kamra_para_hutes OR befujt_para_hutes          │       │
│ │                                                           │       │
│ │ add_air_max = cool AND (NOT sum_wint_jel)               │       │
│ │               AND (NOT humi_save)                        │       │
│ │                                                           │       │
│ │ bypass_open = humi_save OR (cool AND NOT dehumi)        │       │
│ │                                                           │       │
│ │ main_fan = sum_wint_jel                                 │       │
│ └──────────────────────────────────────────────────────────┘       │
│                                                                      │
│ Apply to Relays:                                                    │
│   setrelay(warm, relay_warm [60])                                  │
│   setrelay(cool_rel, relay_cool [52])                              │
│   setrelay(add_air_max, relay_add_air_max [61])                    │
│   setrelay(reventon, relay_reventon [62])                          │
│   setrelay(add_air_save, relay_add_air_save [63])                  │
│   setrelay(bypass_open, relay_bypass_open [64])                    │
│   setrelay(main_fan, relay_main_fan [65])                          │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 6: Update UI Widgets (Line 416-427)                           │
│                                                                      │
│ IF warm: "Fűtés Aktív!" (Heating Active)                           │
│ IF cool: "Hűtés Aktív!" (Cooling Active)                           │
│ IF warm_dis: "Fűtés Tiltva!" (Heating Disabled)                    │
│ IF dehumi: "Páramentesítés!" (Dehumidification)                    │
│ IF cool_dis: "Hűtés Tiltva!" (Cooling Disabled)                    │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 7: Intelligent Signal Propagation (Line 428-451)              │
│                                                                      │
│ Store old signal state                                              │
│ Update signal values (warm, cool, dehumi, etc.)                    │
│                                                                      │
│ IF ANY signal changed:                                             │
│   signals1:setValue(signal, FALSE)  → PROPAGATE                    │
│ ELSE:                                                               │
│   signals1:setValue(signal, TRUE)   → BLOCK                        │
│                                                                      │
│ This prevents unnecessary event flooding across multi-device setup  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Event Processing Flow

### Event-Driven Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EVENT SOURCES (Multiple Origins)                  │
└─────────────────────────────────────────────────────────────────────┘
           │                    │                    │
           │                    │                    │
           ▼                    ▼                    ▼
    ┌──────────┐       ┌────────────┐       ┌──────────────┐
    │  TIMER   │       │  MODBUS    │       │  VARIABLE    │
    │  5 sec   │       │  RESPONSE  │       │  CHANGED     │
    │  tick    │       │  async     │       │  propagation │
    └────┬─────┘       └─────┬──────┘       └──────┬───────┘
         │                   │                     │
         └───────────────────┴─────────────────────┘
                             │
                             ▼
             ┌───────────────────────────────┐
             │   CustomDevice:onEvent(event) │
             │   File: aging_chamber_        │
             │   Apar2_0_REFACTORED.lua      │
             │   Line: 505-619               │
             └───────────────┬───────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌────────────────┐   ┌─────────────────┐
│ Timer Elapsed │   │ Modbus Read    │   │ Variable State  │
│ or Off        │   │ Response       │   │ Changed         │
└───────┬───────┘   └────────┬───────┘   └────────┬────────┘
        │                    │                     │
        │                    │                     │
        ▼                    ▼                     │
  ┌──────────┐      ┌─────────────────┐           │
  │ Start    │      │ onRegisterAsync │           │
  │ timer    │      │ Read()          │           │
  │ (5000ms) │      │ - Parse Modbus  │           │
  └────┬─────┘      │   registers     │           │
       │            │ - Extract temp  │           │
       │            │   & humidity    │           │
       │            │ - Call          │           │
       │            │   mozgoatlag()  │           │
       │            └────────┬────────┘           │
       │                     │                    │
       ▼                     ▼                    │
  ┌──────────┐      ┌─────────────────┐          │
  │ poll()   │      │ mozgoatlag()    │          │
  │ Request  │      │ Moving average  │          │
  │ Modbus   │      │ filtering       │          │
  │ read     │      │ - Line 460-501  │          │
  └────┬─────┘      └────────┬────────┘          │
       │                     │                    │
       │                     ▼                    │
       │            ┌─────────────────┐          │
       │            │ IF buffer full  │          │
       │            │ AND value       │          │
       │            │ changed >= 0.1: │          │
       │            │   setValue(..., │          │
       │            │     FALSE)      │          │
       │            │   → PROPAGATE   │──────────┤
       │            └─────────────────┘          │
       │                                         │
       ▼                                         ▼
  ┌──────────────┐          ┌───────────────────────────────────┐
  │ controlling()│          │ lua_variable_state_changed Handler│
  │ Main control │          │ Line 552-596                      │
  │ algorithm    │          └───────────────┬───────────────────┘
  └──────────────┘                          │
                          ┌─────────────────┼─────────────────┐
                          │                 │                 │
                          ▼                 ▼                 ▼
                 ┌────────────┐   ┌─────────────┐   ┌─────────────┐
                 │ Source 23  │   │ Source 1-2  │   │ Source 3-4  │
                 │ or 24      │   │ or 19-20    │   │ TARGET      │
                 │ Supply Air │   │ Chamber     │   │ CHANGED     │
                 │ (befujt)   │   │ (kamra)     │   │             │
                 └─────┬──────┘   └──────┬──────┘   └──────┬──────┘
                       │                 │                 │
                       ▼                 ▼                 ▼
           ┌────────────────┐  ┌─────────────┐  ┌──────────────────┐
           │ Update befujt  │  │ Update kamra│  │ Update sliders ✓ │
           │ displays:      │  │ displays:   │  │ - slider_1       │
           │ - temp text    │  │ - temp text │  │ - slider_0       │
           │ - humi text    │  │ - humi text │  │ - dew point      │
           │ - dew point    │  │ - dew point │  │ - abs humidity   │
           │ - abs humidity │  │ - abs humi  │  │   BUG FIX #2 ✓   │
           └────────────────┘  └─────────────┘  └──────────────────┘
                                                   Line 580-591

┌─────────────────────────────────────────────────────────────────────┐
│                   USER INTERACTION EVENTS                            │
└─────────────────────────────────────────────────────────────────────┘
           │                                    │
           ▼                                    ▼
┌──────────────────────┐           ┌──────────────────────────┐
│ on_Target_           │           │ on_Target_               │
│ TemperatureChange()  │           │ HumidityChange()         │
│ Line 623-633         │           │ Line 636-648             │
└──────────┬───────────┘           └────────┬─────────────────┘
           │                                │
           ▼                                ▼
┌──────────────────────────────────────────────────────────────┐
│ Validation:                                                   │
│   IF |new - old| < 19 (1.9°C or 1.9%):                      │
│     kamra_cel_X_v1:setValue(newValue*10, FALSE) → PROPAGATE │
│     kamra_cel_X_v1:save(FALSE) → PROPAGATE                  │
│     ah_dp_cel_szamol() → Update displays                    │
│   ELSE:                                                      │
│     Reject change, reset slider to old value                │
│                                                               │
│ This propagates user changes to other devices immediately    │
└───────────────────────────────────────────────────────────────┘
```


---

## State Machine Diagram

### Device Lifecycle States

```
                    ┌──────────────┐
                    │  INITIALIZED │
                    │  (unknown)   │
                    └──────┬───────┘
                           │
                           │ Modbus connection
                           │ established
                           ▼
                    ┌──────────────┐
              ┌────►│   ONLINE     │◄────┐
              │     │  (polling)   │     │
              │     └──────┬───────┘     │
              │            │             │
              │            │ Modbus      │ Connection
              │            │ timeout     │ restored
              │            ▼             │
              │     ┌──────────────┐     │
              └─────│   OFFLINE    │─────┘
                    │ (not polling)│
                    └──────────────┘

    State Transitions:
    - onInit() → Set status = 'unknown'
    - online() → Set status = 'online', start polling
    - offline() → Set status = 'offline', stop polling
    - Modbus async request failure → Decrement error counter
```

### Control State Machine (per Sensor Zone)

```
TEMPERATURE CONTROL STATE MACHINE (Chamber & Supply Air)

                    ┌────────────────────────┐
                    │     IDLE STATE         │
                    │  (within deadband)     │
                    └───────┬────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        │ Temp >            │                   │ Temp <
        │ Target+2×ΔHI      │                   │ Target-2×ΔLO
        │                   │                   │
        ▼                   │                   ▼
┌───────────────┐           │           ┌────────────────┐
│   COOLING     │           │           │    HEATING     │
│   ACTIVE      │           │           │    ACTIVE      │
│ kamra_hutes   │           │           │  kamra_futes   │
│ = TRUE        │           │           │  = TRUE        │
└───────┬───────┘           │           └────────┬───────┘
        │                   │                    │
        │ Temp <            │                    │ Temp >
        │ Target+ΔHI        │                    │ Target-ΔLO
        │                   │                    │
        └───────────────────┼────────────────────┘
                            │
                            ▼
                    ┌────────────────┐
                    │ Return to IDLE │
                    └────────────────┘

SAFETY INTERLOCKS:

┌────────────────────────────────────────────────────────────┐
│ COOLING DISABLED STATE (kamra_hutes_tiltas = TRUE)        │
│ Triggered when: Temp < Target - 3×ΔLO                     │
│ Effect: Cooling relay blocked regardless of temp          │
│ Exit when: Temp > Target - ΔLO                            │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ HEATING DISABLED STATE (kamra_para_futes_tiltas = TRUE)   │
│ Triggered when: Humidity < Target - 2×ΔLO                 │
│ Effect: Heating relay blocked (prevents over-drying)      │
│ Exit when: Humidity > Target - ΔLO                        │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ SLEEP MODE STATE (signal.sleep = TRUE)                    │
│ Effect: Both heating and cooling disabled                 │
│ Purpose: Rest period for system                           │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ SENSOR ERROR STATE (kamra_hibaflag = TRUE)                │
│ Triggered when: kamra_hibaszam1 <= 0                      │
│ Effect: All control flags = FALSE (safe shutdown)         │
│        Supply air targets = chamber targets (bypass)      │
└────────────────────────────────────────────────────────────┘


HUMIDITY CONTROL STATE MACHINE

                    ┌────────────────────────┐
                    │     IDLE STATE         │
                    │  (within deadband)     │
                    └───────┬────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        │ Humidity >        │                   │ Humidity <
        │ Target+2×ΔHI      │                   │ Target-2×ΔLO
        │                   │                   │
        ▼                   │                   ▼
┌───────────────┐           │           ┌────────────────┐
│ DEHUMIDIFY    │           │           │  HUMIDIFY      │
│ ACTIVE        │           │           │  DISABLED      │
│ para_hutes    │           │           │  para_futes_   │
│ = TRUE        │           │           │  tiltas = TRUE │
└───────┬───────┘           │           └────────┬───────┘
        │                   │                    │
        │ Humidity <        │                    │ Humidity >
        │ Target+ΔHI        │                    │ Target-ΔLO
        │                   │                    │
        └───────────────────┼────────────────────┘
                            │
                            ▼
                    ┌────────────────┐
                    │ Return to IDLE │
                    └────────────────┘
```

---

## Data Flow Diagram

### Sensor Data Processing Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SENSOR INPUT (Raw Modbus Data)                    │
│                   XY-MD1.1 Temp/Humidity Sensor                      │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Modbus RTU
                                  │ Registers 1-2
                                  │ (int16 values)
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│              poll() - Modbus Async Read Request                      │
│              com:readInputRegistersAsync(1, 2)                       │
│              Line 651-654                                            │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Async response
                                  │ event triggered
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│           onRegisterAsyncRead() - Response Handler                   │
│           Line 524-549                                               │
│                                                                       │
│  function (kind, addrBase, values)                                  │
│    IF kind == 'INPUT_REGISTERS' AND addrBase == 1:                 │
│      var1 = value(1)  -- Temperature (raw)                          │
│      var2 = value(2)  -- Humidity (raw)                             │
│    END                                                               │
│  end                                                                 │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Raw values
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│            mozgoatlag() - Moving Average Filter                      │
│            Line 460-501                                              │
│                                                                       │
│  INPUTS:                                                             │
│    - tablazat: circular buffer (last N measurements)                │
│    - akt_meres: current raw measurement                             │
│    - atlag_ertek: output variable for average                       │
│    - mertdb: buffer size (3 for supply air)                         │
│                                                                       │
│  ALGORITHM:                                                          │
│    1. Add current measurement to buffer                             │
│    2. IF buffer.size > mertdb: remove oldest                        │
│    3. Calculate average = sum(buffer) / buffer.size                 │
│    4. Round to nearest integer                                      │
│                                                                       │
│  INTELLIGENT PROPAGATION:                                            │
│    IF buffer_ready (size >= mertdb)                                 │
│       AND value_changed (|new - old| >= 1):                         │
│         atlag_ertek:setValue(new_avg, FALSE) → PROPAGATE            │
│    ELSE:                                                             │
│         atlag_ertek:setValue(new_avg, TRUE) → BLOCK                 │
│                                                                       │
│  OUTPUTS:                                                            │
│    - befujt_homerseklet_akt1 [23] (filtered temp)                   │
│    - befujt_para_akt1 [24] (filtered humidity)                      │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Filtered values
                                  │ (if propagated)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│         lua_variable_state_changed Event Triggered                   │
│         Line 552 (event type check)                                  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
┌─────────────────────────────┐   ┌──────────────────────────┐
│ Update UI Displays          │   │ Psychrometric            │
│ Line 555-559                │   │ Calculations             │
│                             │   │                          │
│ - _1_tx_befujt_homerseklet_ │   │ ah_dp_befujt_szamol()    │
│   = format("%3.1f°C",       │   │ Line 207-212             │
│     val/10)                 │   │                          │
│                             │   │ Calculate:               │
│ - _tx_2_tx_befujt_para      │   │ - Absolute humidity      │
│   = format("%3.1f%%",       │   │   (g/m³)                 │
│     val/10)                 │   │ - Dew point (°C)         │
│                             │   │                          │
│ - dp_befujt_tx              │   │ Store in:                │
│   = dew point               │   │ ah_dp_table1[42]         │
│                             │   │   .ah_befujt             │
│ - ah_befujt_tx              │   │   .dp_befujt             │
│   = absolute humidity       │   │                          │
└─────────────────────────────┘   └──────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                  CONTROL CALCULATION DATA FLOW                       │
└─────────────────────────────────────────────────────────────────────┘

    User Input (Sliders)                 Sensor Data
           │                                   │
           │ on_Target_X_Change()              │ lua_variable_state_changed
           ▼                                   ▼
    kamra_cel_homerseklet_v1 [3]        kamra_homerseklet_v1 [1]
    kamra_cel_para_v1 [4]               kamra_para_v1 [2]
           │                                   │
           └──────────────┬────────────────────┘
                          │
                          │ controlling()
                          ▼
           ┌──────────────────────────┐
           │ Supply Air Target Calc   │
           │ Line 280-309             │
           │                          │
           │ befujt_cel_temp =        │
           │   kamra_cel_temp +       │
           │   (kamra_cel_temp -      │
           │    kamra_actual_temp)/2  │
           └──────────┬───────────────┘
                      │
                      ▼
           befujt_cel_homerseklet_v1 [5]
           befujt_cel_para_v1 [6]
                      │
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌────────────────┐         ┌────────────────┐
│ Chamber        │         │ Supply Air     │
│ Control        │         │ Control        │
│ Line 312-349   │         │ Line 351-389   │
│                │         │                │
│ Calculate:     │         │ Calculate:     │
│ - kamra_hutes  │         │ - befujt_hutes │
│ - kamra_futes  │         │ - befujt_futes │
│ - para_hutes   │         │ - hutes_tiltas │
│ - etc.         │         │ - futes_tiltas │
└────────┬───────┘         └────────┬───────┘
         │                          │
         └──────────┬───────────────┘
                    │
                    ▼
         ┌────────────────────┐
         │ Combine Signals    │
         │ Line 392-414       │
         │                    │
         │ warm = ...         │
         │ cool = ...         │
         │ dehumi = ...       │
         └──────────┬─────────┘
                    │
        ┌───────────┴────────────┐
        │                        │
        ▼                        ▼
┌────────────────┐      ┌─────────────────┐
│ setrelay()     │      │ Update signals1 │
│ Line 98-107    │      │ Line 428-451    │
│                │      │                 │
│ IF signal:     │      │ Propagate if    │
│   relay.on()   │      │ changed         │
│ ELSE:          │      │                 │
│   relay.off()  │      │                 │
└────────┬───────┘      └─────────┬───────┘
         │                        │
         ▼                        ▼
  Hardware Relays          Other Devices
  (sbus[52], [60],        (Multi-device
   [61-65])               synchronization)
```

### Multi-Device Data Synchronization

```
┌─────────────┐          ┌─────────────┐          ┌─────────────┐
│  Device A   │          │  Device B   │          │  Device C   │
│ (Master UI) │          │ (Slave 1)   │          │ (Slave 2)   │
└──────┬──────┘          └──────┬──────┘          └──────┬──────┘
       │                        │                        │
       │ User changes           │                        │
       │ slider_1 to 25°C       │                        │
       │                        │                        │
       ▼                        │                        │
 on_Target_                     │                        │
 TemperatureChange()            │                        │
       │                        │                        │
       │ Validation OK          │                        │
       ▼                        │                        │
 kamra_cel_                     │                        │
 homerseklet_v1:                │                        │
 setValue(250, FALSE)           │                        │
       │                        │                        │
       │ PROPAGATE = TRUE       │                        │
       └────────────────────────┼────────────────────────┤
                                │                        │
                                ▼                        ▼
                    lua_variable_state_changed   lua_variable_state_changed
                    source.id == 3               source.id == 3
                                │                        │
                                ▼                        ▼
                    BUG FIX #2 (Line 580-591)   BUG FIX #2
                    Read kamra_cel_              Read kamra_cel_
                    homerseklet_v1               homerseklet_v1
                                │                        │
                                ▼                        ▼
                    Update slider_1 to 25.0°C   Update slider_1 to 25.0°C
                    Update displays              Update displays
                                │                        │
                                ▼                        ▼
                    ┌─────────────┐          ┌─────────────┐
                    │ Sliders in  │          │ Sliders in  │
                    │ SYNC ✓      │          │ SYNC ✓      │
                    └─────────────┘          └─────────────┘

WITHOUT BUG FIX #2 (Old Behavior):
                                │                        │
                                ▼                        ▼
                    Read slider_1 (old value 21.0°C)
                    OVERWRITE variable with 210
                                │                        │
                                ▼                        ▼
                    ┌─────────────┐          ┌─────────────┐
                    │ SYNC BROKEN │          │ SYNC BROKEN │
                    │ Rejects new │          │ Rejects new │
                    │ value ✗     │          │ value ✗     │
                    └─────────────┘          └─────────────┘
```


---

## Function Call Hierarchy

### Complete Call Graph

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ENTRY POINTS                                  │
│                  (Called by Tech Sinum Platform)                    │
└─────────────────────────────────────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
        ▼                         ▼                         ▼
┌───────────────┐       ┌──────────────────┐      ┌──────────────────┐
│ CustomDevice  │       │ CustomDevice     │      │ CustomDevice     │
│ :onInit()     │       │ :onEvent(event)  │      │ :on_Target_X     │
│ Line 58-81    │       │ Line 505-619     │      │ Change()         │
└───────┬───────┘       └────────┬─────────┘      │ Line 623-648     │
        │                        │                 └────────┬─────────┘
        │                        │                          │
        ▼                        │                          │
┌───────────────┐                │                          │
│ c()           │                │                          │
│ Line 53-55    │                │                          │
│ Returns       │                │                          │
│ component     │                │                          │
└───────┬───────┘                │                          │
        │                        │                          │
        ▼                        │                          │
┌───────────────┐                │                          │
│ getElement()  │◄───────────────┼──────────────────────────┤
│ Platform API  │                │                          │
│ Returns UI    │                │                          │
│ widget        │                │                          │
└───────┬───────┘                │                          │
        │                        │                          │
        ▼                        │                          │
┌───────────────┐                │                          │
│ setValue()    │◄───────────────┼──────────────────────────┤
│ Platform API  │                │                          │
│ Updates value │                │                          │
│ + propagation │                │                          │
└───────────────┘                │                          │
                                 │                          │
        ┌────────────────────────┼──────────────────────────┘
        │                        │
        │                        │
        ▼                        ▼
┌───────────────┐       ┌────────────────────┐
│ ah_dp_cel_    │       │ Timer elapsed?     │
│ szamol()      │       └─────────┬──────────┘
│ Line 198-205  │                 │
└───────┬───────┘                 ▼
        │              ┌──────────────────────┐
        │              │ getComponent("timer")│
        │              │ :start(5000)         │
        │              └──────────┬───────────┘
        │                         │
        │                         ▼
        │              ┌──────────────────────┐
        │              │ CustomDevice:poll()  │
        │              │ Line 651-654         │
        │              └──────────┬───────────┘
        │                         │
        │                         ▼
        │              ┌──────────────────────┐
        │              │ c():readInputRegisters│
        │              │ Async(1, 2)          │
        │              │ Platform API         │
        │              └──────────────────────┘
        │                         │
        │                         │
        ▼                         ▼
┌───────────────┐       ┌────────────────────┐
│ calculate_    │       │ CustomDevice:      │
│ absolute_     │       │ controlling()      │
│ humidity()    │       │ Line 215-453       │
│ Line 125-129  │       └──────────┬─────────┘
└───────┬───────┘                  │
        │                          │
        ▼                          ▼
┌───────────────┐       ┌────────────────────┐
│ saturation_   │       │ getValue() calls   │
│ vapor_        │       │ (multiple vars)    │
│ pressure()    │       └──────────┬─────────┘
│ Line 119-121  │                  │
└───────────────┘                  │
        ▲                          ▼
        │              ┌────────────────────┐
        │              │ Psychrometric      │
        │              │ calculations       │
        │              └──────────┬─────────┘
        │                         │
        ▼                         ▼
┌───────────────┐       ┌────────────────────┐
│ calc_dew_     │       │ setValue() calls   │
│ point()       │       │ (propagation logic)│
│ Line 161-178  │       └──────────┬─────────┘
└───────────────┘                  │
                                   ▼
                        ┌────────────────────┐
                        │ setrelay()         │
                        │ Line 98-107        │
                        └──────────┬─────────┘
                                   │
                                   ▼
                        ┌────────────────────┐
                        │ relay:call()       │
                        │ ("turn_on" or      │
                        │  "turn_off")       │
                        │ Platform API       │
                        └────────────────────┘
```

### Detailed Function Call Trees

#### 1. Initialization Sequence
```
CustomDevice:onInit()  [Line 58-81]
│
├─► self:c()  [Line 53-55]
│   └─► self:getComponent('com')  [Platform API]
│
├─► self:setValue('status', 'unknown')  [Platform API]
│
├─► com:getValue('baud_rate')  [Platform API]
├─► com:getValue('parity')  [Platform API]
├─► com:getValue('stop_bits')  [Platform API]
├─► com:getValue('slave_address')  [Platform API]
├─► com:getValue('associations.transceiver')  [Platform API]
│
├─► self:getElement('baudrate'):setValue(...)  [Platform API]
├─► self:getElement('parity'):setValue(...)  [Platform API]
├─► self:getElement('stopbits'):setValue(...)  [Platform API]
├─► self:getElement('slave_id'):setValue(...)  [Platform API]
├─► self:getElement('xceiver'):setValue(...)  [Platform API]
│
├─► befujt_hibaszam1:setValue(3, true)  [Platform API]
│
├─► kamra_cel_homerseklet_v1:getValue()  [Platform API] ◄── BUG FIX #1
├─► kamra_cel_para_v1:getValue()  [Platform API] ◄────────── BUG FIX #1
│
├─► self:getElement('slider_1'):setValue(...)  [Platform API] ◄── BUG FIX #1
├─► self:getElement('slider_0'):setValue(...)  [Platform API] ◄── BUG FIX #1
│
└─► ah_dp_cel_szamol(dp_tx, ah_tx)  [Line 198-205] ◄────────── BUG FIX #1
    │
    ├─► kamra_cel_homerseklet_v1:getValue()  [Platform API]
    ├─► kamra_cel_para_v1:getValue()  [Platform API]
    │
    ├─► calculate_absolute_humidity(temp, rh)  [Line 125-129]
    │   └─► saturation_vapor_pressure(temp)  [Line 119-121]
    │       └─► math.exp()  [Lua stdlib]
    │
    ├─► calc_dew_point(temp, rh)  [Line 161-178]
    │   └─► math.log()  [Lua stdlib]
    │
    ├─► ah_dp_table1:setValueByPath("ah_cel", ah, true)  [Platform API]
    ├─► ah_dp_table1:setValueByPath("dp_cel", dp, true)  [Platform API]
    │
    ├─► dp_tx:setValue("value", string.format(...), true)  [Platform API]
    │   └─► string.format()  [Lua stdlib]
    │
    └─► ah_tx:setValue("value", string.format(...), true)  [Platform API]
        └─► string.format()  [Lua stdlib]
```

#### 2. Main Control Loop Sequence
```
CustomDevice:onEvent(event)  [Line 505-619]
│
├─► self:getComponent("timer"):getState()  [Platform API]
│
├─► BRANCH: Timer elapsed/off
│   │
│   ├─► self:getComponent("timer"):start(5000)  [Platform API]
│   │
│   ├─► self:poll()  [Line 651-654]
│   │   └─► self:c():readInputRegistersAsync(1, 2)  [Platform API]
│   │
│   └─► self:controlling()  [Line 215-453]
│       │
│       ├─► kamra_homerseklet_v1:getValue()  [Platform API]
│       ├─► kamra_para_v1:getValue()  [Platform API]
│       ├─► kamra_cel_homerseklet_v1:getValue()  [Platform API]
│       ├─► kamra_cel_para_v1:getValue()  [Platform API]
│       ├─► befujt_cel_homerseklet_v1:getValue()  [Platform API]
│       ├─► befujt_cel_para_v1:getValue()  [Platform API]
│       ├─► kulso_homerseklet_v1:getValue()  [Platform API]
│       ├─► kulso_para_v1:getValue()  [Platform API]
│       ├─► befujt_para_akt1:getValue()  [Platform API]
│       ├─► befujt_homerseklet_akt1:getValue()  [Platform API]
│       ├─► variable[9]:getValue()  [Platform API]
│       ├─► variable[33]:getValue({})  [Platform API]
│       ├─► variable[34]:getValue({})  [Platform API]
│       ├─► variable[38]:getValue({})  [Platform API]
│       ├─► kamra_hibaszam1:getValue()  [Platform API]
│       │
│       ├─► befujt_cel_homerseklet_v1:getValue() [old value]  [Platform API]
│       ├─► befujt_cel_para_v1:getValue() [old value]  [Platform API]
│       │
│       ├─► math.abs()  [Lua stdlib]  (intelligent propagation check)
│       │
│       ├─► befujt_cel_homerseklet_v1:setValue(value, stop_prop)  [Platform API]
│       ├─► befujt_cel_para_v1:setValue(value, stop_prop)  [Platform API]
│       │
│       ├─► calculate_absolute_humidity(temp, rh)  [Line 125-129]
│       ├─► calc_dew_point(temp, rh)  [Line 161-178]
│       │
│       ├─► ah_dp_table1:setValueByPath(...)  [Platform API]
│       ├─► ah_dp_table1:save(true)  [Platform API]
│       │
│       ├─► setrelay(warm, relay_warm)  [Line 98-107]
│       │   └─► relay_warm:getValue("state")  [Platform API]
│       │       └─► relay_warm:call("turn_on" / "turn_off")  [Platform API]
│       │
│       ├─► setrelay(cool_rel, relay_cool)  [Line 98-107]
│       ├─► setrelay(add_air_max, relay_add_air_max)  [Line 98-107]
│       ├─► setrelay(reventon, relay_reventon)  [Line 98-107]
│       ├─► setrelay(add_air_save, relay_add_air_save)  [Line 98-107]
│       ├─► setrelay(bypass_open, relay_bypass_open)  [Line 98-107]
│       ├─► setrelay(main_fan, relay_main_fan)  [Line 98-107]
│       │
│       ├─► self:getElement('text_input_0_warm'):setValue(...)  [Platform API]
│       ├─► self:getElement('text_input_1_cool'):setValue(...)  [Platform API]
│       ├─► self:getElement('text_input_2_wdis'):setValue(...)  [Platform API]
│       ├─► self:getElement('text_input_3_cdis'):setValue(...)  [Platform API]
│       │
│       ├─► signals1:getValue({})  [old state]  [Platform API]
│       └─► signals1:setValue(signal, stop_prop)  [Platform API]
│
├─► BRANCH: modbus_client_async_read_response
│   │
│   ├─► utils:profiler()  [Platform API]
│   ├─► profiler:start()  [Platform API]
│   │
│   ├─► self:c():onRegisterAsyncRead(callback)  [Platform API]
│   │   └─► CALLBACK:
│   │       └─► self:online()  [Line 74-79]
│   │           ├─► self:getValue('status')  [Platform API]
│   │           ├─► self:setValue('status', 'online')  [Platform API]
│   │           ├─► self:poll()  [Line 651-654]
│   │           └─► befujt_hibaszam1:setValue(3, true)  [Platform API]
│   │
│   ├─► mozgoatlag(befujt_homerseklet_mert_table1, var1,
│   │              befujt_homerseklet_akt1, 3, true, simulate)  [Line 460-501]
│   │   │
│   │   ├─► tablazat:getValue({})  [Platform API]
│   │   ├─► table.insert()  [Lua stdlib]
│   │   ├─► table.remove()  [Lua stdlib]
│   │   ├─► math.floor()  [Lua stdlib]
│   │   ├─► tablazat:setValue(instab, kiir_call)  [Platform API]
│   │   ├─► atlag_ertek:getValue()  [Platform API]
│   │   ├─► math.abs()  [Lua stdlib]
│   │   ├─► atlag_ertek:setValue(new_avg, stop_prop)  [Platform API]
│   │   └─► print()  [Lua stdlib]
│   │
│   ├─► mozgoatlag(befujt_para_mert_table1, var2,
│   │              befujt_para_akt1, 3, simulate, simulate)  [Line 460-501]
│   │
│   ├─► ah_dp_befujt_szamol()  [Line 207-212]
│   │   ├─► befujt_homerseklet_akt1:getValue()  [Platform API]
│   │   ├─► befujt_para_akt1:getValue()  [Platform API]
│   │   ├─► calculate_absolute_humidity(temp, rh)  [Line 125-129]
│   │   ├─► calc_dew_point(temp, rh)  [Line 161-178]
│   │   ├─► ah_dp_table1:setValueByPath("ah_befujt", ah, true)  [Platform API]
│   │   └─► ah_dp_table1:setValueByPath("dp_befujt", dp, true)  [Platform API]
│   │
│   ├─► profiler:stop()  [Platform API]
│   └─► profiler:print()  [Platform API]
│
└─► BRANCH: lua_variable_state_changed
    │
    ├─► SUB-BRANCH: source.id == 23 or 24 (befujt values)
    │   ├─► self:getElement('_1_tx_befujt_homerseklet_'):setValue(...)  [Platform API]
    │   ├─► self:getElement('_tx_2_tx_befujt_para'):setValue(...)  [Platform API]
    │   ├─► self:getElement("dp_befujt_tx"):setValue(...)  [Platform API]
    │   ├─► self:getElement("ah_befujt_tx"):setValue(...)  [Platform API]
    │   ├─► ah_dp_table1:getValue()  [Platform API]
    │   ├─► string.format()  [Lua stdlib]
    │   └─► print()  [Lua stdlib]
    │
    ├─► SUB-BRANCH: source.id == 1, 2, 19, or 20 (kamra values)
    │   ├─► kamra_para_v1:getValue()  [Platform API]
    │   ├─► kamra_homerseklet_v1:getValue()  [Platform API]
    │   ├─► self:getElement("_3_tx_kamra_homerseklet_"):setValue(...)  [Platform API]
    │   ├─► self:getElement("_4_tx_kamra_para_"):setValue(...)  [Platform API]
    │   ├─► self:getElement("dp_kamra_tx"):setValue(...)  [Platform API]
    │   ├─► self:getElement("ah_kamra_tx"):setValue(...)  [Platform API]
    │   ├─► ah_dp_table1:getValue()  [Platform API]
    │   ├─► string.format()  [Lua stdlib]
    │   └─► print()  [Lua stdlib]
    │
    ├─► SUB-BRANCH: source.id == 3 or 4 (target values) ◄────── BUG FIX #2
    │   ├─► kamra_cel_homerseklet_v1:getValue()  [Platform API] ◄─── BUG FIX #2
    │   ├─► kamra_cel_para_v1:getValue()  [Platform API] ◄──────── BUG FIX #2
    │   ├─► self:getElement("slider_1"):setValue(...)  [Platform API] ◄─ BUG FIX #2
    │   ├─► self:getElement("slider_0"):setValue(...)  [Platform API] ◄─ BUG FIX #2
    │   ├─► ah_dp_cel_szamol(dp_tx, ah_tx)  [Line 198-205] ◄────── BUG FIX #2
    │   └─► print()  [Lua stdlib]
    │
    ├─► SUB-BRANCH: source.id == 7, 8, 21, or 22 (kulso values)
    │   ├─► kulso_homerseklet_v1:getValue()  [Platform API]
    │   ├─► kulso_para_v1:getValue()  [Platform API]
    │   ├─► self:getElement("_3_tx_kulso_homerseklet_"):setValue(...)  [Platform API]
    │   ├─► self:getElement("_4_tx_kulso_para_"):setValue(...)  [Platform API]
    │   ├─► calculate_absolute_humidity(temp, rh)  [Line 125-129]
    │   ├─► calc_dew_point(temp, rh)  [Line 161-178]
    │   ├─► ah_dp_table1:setValueByPath(...)  [Platform API]
    │   ├─► self:getElement("dp_kulso_tx"):setValue(...)  [Platform API]
    │   ├─► self:getElement("ah_kulso_tx"):setValue(...)  [Platform API]
    │   ├─► string.format()  [Lua stdlib]
    │   └─► print()  [Lua stdlib]
    │
    └─► SUB-BRANCH: source.id == 34 (signals changed)
        ├─► print()  [Lua stdlib]
        └─► self:controlling()  [Line 215-453]
```

#### 3. User Interaction Sequence
```
on_Target_TemperatureChange(newValue, element)  [Line 623-633]
│
├─► kamra_cel_homerseklet_v1:getValue()  [Platform API]
│
├─► IF validation passed (|new - old| < 19):
│   │
│   ├─► kamra_cel_homerseklet_v1:setValue(newValue*10, FALSE)  [Platform API]
│   │   └─► Propagates to other devices ✓
│   │
│   ├─► kamra_cel_homerseklet_v1:save(FALSE)  [Platform API]
│   │   └─► Saves to persistent storage
│   │
│   └─► ah_dp_cel_szamol(dp_tx, ah_tx)  [Line 198-205]
│       └─► [See ah_dp_cel_szamol tree above]
│
└─► ELSE (validation failed):
    └─► self:getElement('slider_1'):setValue('value', temp1/10, true)  [Platform API]
        └─► Reset slider to old value


on_Target_HumidityChange(newValue, element)  [Line 636-648]
│
├─► self:c()  [Line 53-55]
├─► print()  [Lua stdlib]
├─► kamra_cel_para_v1:getValue()  [Platform API]
│
├─► IF validation passed (|new - old| < 19):
│   │
│   ├─► kamra_cel_para_v1:setValue(newValue*10, FALSE)  [Platform API]
│   │   └─► Propagates to other devices ✓
│   │
│   ├─► kamra_cel_para_v1:save(FALSE)  [Platform API]
│   │   └─► Saves to persistent storage
│   │
│   └─► ah_dp_cel_szamol(dp_tx, ah_tx)  [Line 198-205]
│       └─► [See ah_dp_cel_szamol tree above]
│
└─► ELSE (validation failed):
    └─► self:getElement('slider_0'):setValue('value', humi1/10)  [Platform API]
        └─► Reset slider to old value
```

---

## Cross-Component Interactions

### File/Component Matrix

```
┌──────────────────────────────────────────────────────────────────────┐
│                      COMPONENT INTERACTION MATRIX                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  File: aging_chamber_Apar2_0_REFACTORED.lua (Primary)                │
│  File: erlelo_1119_REFACTORED.json (Same code, Base64 encoded)       │
│  File: erlelo_1119b/c/d_REFACTORED.json (Different device types)     │
│                                                                       │
│  ┌────────────────┬──────────────────────────────────────────────┐  │
│  │ COMPONENT      │ INTERACTS WITH                               │  │
│  ├────────────────┼──────────────────────────────────────────────┤  │
│  │ CustomDevice   │ - Tech Sinum Platform APIs                   │  │
│  │ (main class)   │ - All variables (variable[1-42])             │  │
│  │                │ - All relays (sbus[52-65])                   │  │
│  │                │ - Modbus RTU client (component 'com')        │  │
│  │                │ - Timer component                            │  │
│  │                │ - UI widgets (via getElement())              │  │
│  │                │ - Multi-device network (propagation)         │  │
│  ├────────────────┼──────────────────────────────────────────────┤  │
│  │ mozgoatlag()   │ - variables[17,18,19,20,21,22] (buffers)    │  │
│  │ (moving avg)   │ - variables[23,24] (filtered outputs)        │  │
│  │                │ - Lua math library                           │  │
│  │                │ - Lua table library                          │  │
│  ├────────────────┼──────────────────────────────────────────────┤  │
│  │ Psychrometric  │ - calculate_absolute_humidity()              │  │
│  │ functions      │ - calculate_rh()                             │  │
│  │                │ - calc_dew_point()                           │  │
│  │                │ - saturation_vapor_pressure()                │  │
│  │                │ - variable[42] (ah_dp_table1)                │  │
│  │                │ - Lua math library (exp, log)                │  │
│  ├────────────────┼──────────────────────────────────────────────┤  │
│  │ setrelay()     │ - sbus[52,53,60-65] (relay objects)          │  │
│  │ (relay ctrl)   │ - Platform relay API (call, getValue)        │  │
│  ├────────────────┼──────────────────────────────────────────────┤  │
│  │ UI Handlers    │ - on_Target_TemperatureChange()              │  │
│  │                │ - on_Target_HumidityChange()                 │  │
│  │                │ - Slider widgets (slider_0, slider_1)        │  │
│  │                │ - variables[3,4] (targets)                   │  │
│  │                │ - ah_dp_cel_szamol()                         │  │
│  ├────────────────┼──────────────────────────────────────────────┤  │
│  │ Event Handlers │ - onEvent() - master dispatcher              │  │
│  │                │ - Timer events → poll() + controlling()      │  │
│  │                │ - Modbus events → mozgoatlag()               │  │
│  │                │ - Variable events → UI updates               │  │
│  └────────────────┴──────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

### Tech Sinum Platform API Usage

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PLATFORM API CATEGORIES                           │
└─────────────────────────────────────────────────────────────────────┘

1. VARIABLE ACCESS (variable[], local variables)
   ├─► getValue() - Read variable value
   ├─► setValue(value, stop_propagation) - Write with propagation control
   ├─► setValueByPath(path, value, stop_prop) - Write to table field
   └─► save(stop_propagation) - Persist to storage

2. DEVICE/COMPONENT ACCESS (self, sbus[])
   ├─► self:getComponent(name) - Get device component by name
   ├─► self:getElement(id) - Get UI widget by ID
   ├─► self:setValue(property, value) - Set device property
   ├─► self:getValue(property) - Get device property
   └─► component:call(method) - Call component method

3. MODBUS COMMUNICATION (com component)
   ├─► com:readInputRegistersAsync(addr, count) - Async read
   ├─► com:onRegisterAsyncRead(callback) - Response handler
   ├─► com:onRegisterAsyncWrite(callback) - Write response handler
   ├─► com:onAsyncRequestFailure(callback) - Error handler
   ├─► com:getValue('baud_rate') - Get comm settings
   ├─► com:setValue('baud_rate', value) - Set comm settings
   └─► com:setValue('associations.transceiver', value) - Set transceiver

4. UI WIDGET API (getElement() result)
   ├─► widget:setValue('value', text/number, stop_prop) - Update widget
   ├─► widget:getValue('value') - Read widget value
   └─► widget:setValue('associations.selected', id, stop_prop) - Selections

5. TIMER API (timer component)
   ├─► timer:start(milliseconds) - Start timer
   ├─► timer:getState() - Get state ('elapsed', 'off', 'running')
   └─► [Triggers event when elapsed]

6. RELAY/SBUS API (sbus[N])
   ├─► relay:call('turn_on') - Energize relay
   ├─► relay:call('turn_off') - De-energize relay
   └─► relay:getValue('state') - Get relay state ('on', 'off')

7. UTILITY APIs
   ├─► utils:profiler() - Create performance profiler
   ├─► profiler:start() - Start timing
   ├─► profiler:stop() - Stop timing
   ├─► profiler:print() - Print timing results
   └─► JSON:decode(str) - Parse JSON string
```

### Multi-Device Communication Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│              MULTI-DEVICE NETWORK ARCHITECTURE                       │
│         (All devices run same aging_chamber_Apar2_0_REFACTORED.lua) │
└─────────────────────────────────────────────────────────────────────┘

                   Tech Sinum Event Bus
    ┌───────────────────────────────────────────────┐
    │  Shared Variable Network (Cloud Sync)         │
    └───────────────────────────────────────────────┘
           │              │              │
           ▼              ▼              ▼
    ┌───────────┐  ┌───────────┐  ┌───────────┐
    │ Device A  │  │ Device B  │  │ Device C  │
    │ Master UI │  │ Slave 1   │  │ Slave 2   │
    └───────────┘  └───────────┘  └───────────┘

SHARED VARIABLES (synchronized across all devices):
  ├─► variable[1]: kamra_homerseklet_v1        (chamber temp)
  ├─► variable[2]: kamra_para_v1               (chamber humidity)
  ├─► variable[3]: kamra_cel_homerseklet_v1    (target temp) ◄── USER INPUT
  ├─► variable[4]: kamra_cel_para_v1           (target humidity) ◄── USER INPUT
  ├─► variable[5]: befujt_cel_homerseklet_v1   (supply air target temp)
  ├─► variable[6]: befujt_cel_para_v1          (supply air target humidity)
  └─► variable[34]: signals1                   (control signals)

DEVICE-LOCAL VARIABLES (NOT synchronized):
  ├─► variable[23]: befujt_homerseklet_akt1    (local sensor reading)
  ├─► variable[24]: befujt_para_akt1           (local sensor reading)
  ├─► variable[29]: befujt_hibaszam1           (local error count)
  └─► sbus[52-65]: relay states                (local hardware)

PROPAGATION CONTROL:
  ├─► setValue(value, FALSE) → Propagate to all devices
  ├─► setValue(value, TRUE) → Block propagation (local only)
  └─► Intelligent propagation:
      - Only propagate if value changed meaningfully
      - Prevents event flooding
      - Maintains multi-device consistency

EVENT FLOW EXAMPLE:

Device A (User changes slider):
  on_Target_TemperatureChange()
    └─► kamra_cel_homerseklet_v1:setValue(250, FALSE)
         └─► PROPAGATE to network

Device B (Receives propagated value):
  onEvent(lua_variable_state_changed, source.id=3)
    └─► kamra_cel_homerseklet_v1 changed to 250
         └─► Update slider_1 to 25.0°C ✓ (BUG FIX #2)
              └─► ah_dp_cel_szamol() → Update displays

Device C (Receives propagated value):
  onEvent(lua_variable_state_changed, source.id=3)
    └─► kamra_cel_homerseklet_v1 changed to 250
         └─► Update slider_1 to 25.0°C ✓ (BUG FIX #2)
              └─► ah_dp_cel_szamol() → Update displays

Result: All devices show consistent 25.0°C target
```

---

## Summary: Critical Integration Points

### Bug Fixes Applied

**BUG FIX #1: Slider Initialization (Line 72-79)**
- Location: `CustomDevice:onInit()`
- Purpose: Initialize sliders with actual stored values at startup
- Cross-component impact:
  - Reads from: variable[3], variable[4]
  - Writes to: slider_1, slider_0 UI widgets
  - Calls: ah_dp_cel_szamol() → psychrometric calculations

**BUG FIX #2: Event Handler Correction (Line 580-591)**
- Location: `CustomDevice:onEvent()` → lua_variable_state_changed handler
- Purpose: Update sliders when variables change from remote devices
- Cross-component impact:
  - Reads from: variable[3], variable[4] (propagated from network)
  - Writes to: slider_1, slider_0 UI widgets
  - Calls: ah_dp_cel_szamol() → psychrometric calculations
  - Enables: Multi-device synchronization

### Key Integration Patterns

1. **Event-Driven Architecture**
   - Timer events trigger control loops
   - Modbus events trigger sensor processing
   - Variable change events trigger UI updates
   - All events routed through `onEvent()` dispatcher

2. **Intelligent Propagation**
   - Threshold-based change detection (0.2°C, 0.3%)
   - Prevents unnecessary network traffic
   - Maintains multi-device consistency
   - Implemented in: controlling(), mozgoatlag(), user handlers

3. **Psychrometric Chain**
   - Temperature + Humidity → Absolute Humidity → Dew Point
   - Used for: Display, control decisions, condensation prevention
   - Shared across all temperature/humidity processing

4. **Control Loop Hierarchy**
   - Chamber targets (user input) → Supply air targets (calculated)
   - Supply air targets → Relay control (heating/cooling)
   - Relay control → Physical hardware → Sensor feedback
   - Closed-loop control with deadband hysteresis

5. **Multi-File Architecture**
   - aging_chamber_Apar2_0_REFACTORED.lua: Standalone development
   - erlelo_1119_REFACTORED.json: Production deployment (Base64 encoded)
   - erlelo_1119b/c/d: Other device variants (different configurations)
   - All share Tech Sinum platform APIs

