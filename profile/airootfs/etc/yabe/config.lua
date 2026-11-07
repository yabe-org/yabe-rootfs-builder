yabe.config({
  pixels_per_meter = 2500.0,
  input = {
    pointer = {
      scroll_multiplier = 20,
    },
  },
  surface_grouping = {
    enabled = true,
    line_width = 6.0,
  },
})

yabe.keybind({ "Ctrl", "Alt", "Return" }, yabe.dispatchers.exec("wezterm"))
yabe.keybind({ "Ctrl", "Alt", "E" }, yabe.dispatchers.exec("thunar"))
yabe.keybind({ "Ctrl", "Alt", "D" }, yabe.dispatchers.exec("wofi --show drun"))
yabe.keybind({ "Ctrl", "Alt", "C" }, yabe.dispatchers.recenter())

for i = 0, 9 do
  yabe.keybind({ "Ctrl", "Alt", tostring(i) }, yabe.dispatchers.set_workspace(i))
end
