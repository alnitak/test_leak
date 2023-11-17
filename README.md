## test_leak

Test `setImageSampler` memory leaks (Linux and Android simulator)

By running this app, memory leaks start to be noticed after 40~60 seconds on the *Operating System Monitor*. 
Memory tab of DevTools doesn't report leaks.

- This sample uses 2 shaders: `shader_a.frag` and `shader_b.frag`.
- The shaders are drawn using `PictureRecorder()` and the output is stored into 2 different `ui.Image`s.
- When pressing the button, the `Ticker` starts updating shader outputs.
- `shader_a` uses the lastest output of `shader_b` as sampler2D uniform and `shader_b` uses the latest output of itself.

Removing the sampler2D uniform from `shader_b.frag` (and of course 
the `setImageSampler` from `computeShader2()`), the leak doesn't occurs.

