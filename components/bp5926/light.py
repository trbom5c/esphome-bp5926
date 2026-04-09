import esphome.codegen as cg
import esphome.config_validation as cv
from esphome.components import light, output
from esphome.const import CONF_OUTPUT_ID

from . import bp5926_ns

BP5926Light = bp5926_ns.class_("BP5926Light", cg.Component, light.LightOutput)

CONF_WHITE_POWER = "white_power"
CONF_COLOR_TEMP_RATIO = "color_temp_ratio"

CONFIG_SCHEMA = light.LIGHT_SCHEMA.extend(
    {
        cv.GenerateID(CONF_OUTPUT_ID): cv.declare_id(BP5926Light),
        cv.Required("red"): cv.use_id(output.FloatOutput),
        cv.Required("green"): cv.use_id(output.FloatOutput),
        cv.Required("blue"): cv.use_id(output.FloatOutput),
        cv.Required(CONF_WHITE_POWER): cv.use_id(output.FloatOutput),
        cv.Required(CONF_COLOR_TEMP_RATIO): cv.use_id(output.FloatOutput),
    }
)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_OUTPUT_ID])
    await cg.register_component(var, config)
    await light.register_light(var, config)

    red = await cg.get_variable(config["red"])
    cg.add(var.set_red(red))

    green = await cg.get_variable(config["green"])
    cg.add(var.set_green(green))

    blue = await cg.get_variable(config["blue"])
    cg.add(var.set_blue(blue))

    wp = await cg.get_variable(config[CONF_WHITE_POWER])
    cg.add(var.set_white_power(wp))

    ctr = await cg.get_variable(config[CONF_COLOR_TEMP_RATIO])
    cg.add(var.set_color_temp_ratio(ctr))
