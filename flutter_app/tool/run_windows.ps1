$ErrorActionPreference = "Stop"
$Flutter = "C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat"

& $Flutter pub get
& $Flutter run -d windows
