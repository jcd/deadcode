echo "Creating deadcode MSI"
"C:\Program Files (x86)\WiX Toolset v3.9\bin\candle" -wx deadcode.wxs
"C:\Program Files (x86)\WiX Toolset v3.9\bin\light" -ext WixUtilExtension -ext WixUIExtension -cultures:en-us -sice:ICE60 -wx deadcode.wixobj 
signsomething.bat deadcode.msi
