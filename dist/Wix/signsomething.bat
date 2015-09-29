if defined CAROOT (
	signtool.exe sign /fd sha512 /f %CAROOT% /t "http://timestamp.verisign.com/scripts/timstamp.dll" %*
) else (
	echo No CAROOT certificate env variable set. Skipping signing. 
)
