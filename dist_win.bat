@echo off

for /F "skip=1 tokens=1,2 delims==" %%i in (pluginst.inf) do ^
if "%%i" == "version" (
    set VERSION=%%j
)

zip wdx_fontinfo_%VERSION%_win.zip fontinfo.wdx fontinfo.wdx64 pluginst.inf README.md CHANGES.txt LICENSE.txt
