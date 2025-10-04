return {
  "nvim-mini/mini.indentscope",
  opts = {
    draw = {
      -- animation a bit faster than default
      animation = require("mini.indentscope").gen_animation.quadratic({
        duration = 150,
        unit = "total",
      }),
    },
  },
}
