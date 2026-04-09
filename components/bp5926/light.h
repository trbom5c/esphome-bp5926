#pragma once

#include "esphome/core/component.h"
#include "esphome/components/light/light_output.h"
#include "esphome/components/output/float_output.h"

namespace esphome {
namespace bp5926 {

// Custom light output for Feit LEDR6 downlights with BP5926 dual-channel driver.
//
// Hardware:
//   P26 -> MOSFET -> Red LED
//   P24 -> MOSFET -> Green LED
//   P6  -> MOSFET -> Blue LED
//   P8  -> MOSFET -> White LED power (must always track brightness)
//   P7  -> BP5926 Pin 6 -> CW/WW ratio (duty cycle sets color temperature)
//
// BP5926 behavior:
//   P7 duty 100% = full cold white (6500K)
//   P7 duty 0%   = full warm white (2700K)

class BP5926Light : public Component, public light::LightOutput {
 public:
  void set_red(output::FloatOutput *out) { red_ = out; }
  void set_green(output::FloatOutput *out) { green_ = out; }
  void set_blue(output::FloatOutput *out) { blue_ = out; }
  void set_white_power(output::FloatOutput *out) { white_power_ = out; }
  void set_color_temp_ratio(output::FloatOutput *out) { color_temp_ratio_ = out; }

  light::LightTraits get_traits() override {
    auto traits = light::LightTraits();
    traits.set_supported_color_modes({
      light::ColorMode::COLOR_TEMPERATURE,
      light::ColorMode::RGB
    });
    traits.set_min_mireds(154);   // 6500K
    traits.set_max_mireds(370);   // 2700K
    return traits;
  }

  void write_state(light::LightState *state) override {
    auto mode = state->current_values.get_color_mode();

    if (mode == light::ColorMode::RGB) {
      float r, g, b;
      state->current_values_as_rgb(&r, &g, &b);
      red_->set_level(r);
      green_->set_level(g);
      blue_->set_level(b);
      white_power_->set_level(0.0f);
      color_temp_ratio_->set_level(0.0f);
      ESP_LOGD("bp5926", "RGB: R=%.3f G=%.3f B=%.3f", r, g, b);
      return;
    }

    // Color temperature mode (default)
    float brightness;
    state->current_values_as_brightness(&brightness);

    float ct = state->current_values.get_color_temperature();
    // 154 mireds (6500K) -> 1.0 (cold), 370 mireds (2700K) -> 0.0 (warm)
    float ratio = clamp((370.0f - ct) / (370.0f - 154.0f), 0.0f, 1.0f);

    // P8: white LED power — always tracks brightness
    white_power_->set_level(brightness);

    // P7: BP5926 CW/WW ratio
    color_temp_ratio_->set_level(ratio);

    // RGB: supplemental cool-toned light
    float rgb_r = ratio * brightness;
    float rgb_g = ratio * brightness;
    float rgb_b = clamp(ratio * 1.2f, 0.0f, 1.0f) * brightness;
    red_->set_level(rgb_r);
    green_->set_level(rgb_g);
    blue_->set_level(rgb_b);

    ESP_LOGD("bp5926", "CT: br=%.3f ct=%.0f ratio=%.3f | P8=%.3f P7=%.3f R=%.3f G=%.3f B=%.3f",
             brightness, ct, ratio, brightness, ratio, rgb_r, rgb_g, rgb_b);
  }

  float get_setup_priority() const override { return setup_priority::HARDWARE; }

 protected:
  output::FloatOutput *red_{nullptr};
  output::FloatOutput *green_{nullptr};
  output::FloatOutput *blue_{nullptr};
  output::FloatOutput *white_power_{nullptr};
  output::FloatOutput *color_temp_ratio_{nullptr};
};

}  // namespace bp5926
}  // namespace esphome
