rem http://www.jayway.com/2014/09/03/creating-self-signed-certificates-with-makecert-exe-for-development/
"C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\x64\makecert.exe " -n "CN=Steamwinter Technologies" -r  -pe -a sha512 -len 4096 -cy authority -sv CARoot.pvk CARoot.cer

"C:\Program Files (x86)\Microsoft SDKs\Windows\v7.1A\Bin\pvk2pfx.exe" -pvk CARoot.pvk -spc CARoot.cer -pfx CARoot.pfx -f
