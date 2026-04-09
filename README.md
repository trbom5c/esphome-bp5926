# ESPHome BP5926 Light Component

Custom ESPHome external component for LED fixtures using the **BP5926A** (Bright Power / 晶丰明源) dual-channel CW/WW PWM color-mixing driver IC.

## The Problem

The BP5926A uses a single PWM input to control the cold/warm white ratio, with a separate MOSFET controlling white LED power. Standard ESPHome light platforms (`rgbww`, `cwww`) can't drive this hardware correctly because they:

1. **Couple brightness to both channels** — dimming changes the color temperature
2. **Zero the power pin at warm color temps** — the light turns off instead of going warm
3. **Invert the color mapping** — the slider shows the opposite of what the fixture produces

## The Solution

This component properly decouples brightness from color temperature:

- **White power pin** always tracks brightness (never zeroed by color temp changes)
- **Color temp ratio pin** independently controls the BP5926's CW/WW ratio (never scaled by brightness)
- **RGB channels** provide supplemental cool-toned light, scaling with both color temp and brightness
- Exposes native `color_temp` + `rgb` modes to Home Assistant

## Known Compatible Hardware

| Device | Module | Board | Notes |
|--------|--------|-------|-------|
| Feit Electric LEDR6/RGBW/AG | CBU (BK7231N) | ED-05-B2002-V09 | Cloud-cut via [CloudCutter](https://github.com/tuya-cloudcutter/tuya-cloudcutter) |

### Feit LEDR6 CBU Pin Map

| Pin | Function |
|-----|----------|
| P26 | Red LED (MOSFET) |
| P24 | Green LED (MOSFET) |
| P6  | Blue LED (MOSFET) |
| P8  | White LED power — must always track brightness |
| P7  | BP5926 Pin 6 — CW/WW ratio (100% = cold, 0% = warm) |

## Installation

Add to your ESPHome YAML:

```yaml
external_components:
  - source:
      type: git
      url: https://github.com/trbom5c/esphome-bp5926
    components: [bp5926]
```

## Usage

```yaml
output:
  - platform: libretiny_pwm
    id: output_red
    pin: P26
    frequency: 3000 Hz

  - platform: libretiny_pwm
    id: output_green
    pin: P24
    frequency: 3000 Hz

  - platform: libretiny_pwm
    id: output_blue
    pin: P6
    frequency: 3000 Hz

  - platform: libretiny_pwm
    id: output_white_power
    pin: P8
    frequency: 3000 Hz

  - platform: libretiny_pwm
    id: output_color_temp_ratio
    pin: P7
    frequency: 3000 Hz

light:
  - platform: bp5926
    name: "Light"
    red: output_red
    green: output_green
    blue: output_blue
    white_power: output_white_power
    color_temp_ratio: output_color_temp_ratio
    restore_mode: RESTORE_DEFAULT_ON
```

## Configuration Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `red` | Yes | Red LED PWM output |
| `green` | Yes | Green LED PWM output |
| `blue` | Yes | Blue LED PWM output |
| `white_power` | Yes | White LED power output (brightness control) |
| `color_temp_ratio` | Yes | BP5926 PWM input (color temperature ratio) |
| `name` | Yes | Light entity name |
| `restore_mode` | No | Default: `ALWAYS_OFF`. Use `RESTORE_DEFAULT_ON` for lights that should restore state on power loss |

## How It Works

### Color Temperature Mode
- **P8** (white_power) = overall brightness
- **P7** (color_temp_ratio) = color temperature mapped to 0.0–1.0 (warm–cold)
- **RGB** = supplemental cool-toned tint, scales linearly with color temp ratio and brightness

### RGB Mode
- **RGB** = direct color control
- **P8, P7** = off (white LEDs disabled)

## BP5926A IC Details

- **Package:** SOP-8
- **Function:** Dual-channel constant-current LED driver with built-in MOSFETs
- **Input:** Single PWM signal (3.3V/5V, up to 10kHz)
- **Output:** Two LED channels with ratio controlled by PWM duty cycle
- **Built-in MOSFETs:** 100V, 0.6Ω RDS(ON), ~700mA max per channel

## License

MIT License — see [LICENSE](LICENSE).
