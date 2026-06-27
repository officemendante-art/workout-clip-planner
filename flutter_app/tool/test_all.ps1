$ErrorActionPreference = "Stop"
$Flutter = "C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat"
$Dart = "C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\cache\dart-sdk\bin\dart.exe"

& $Flutter pub get
& $Dart format .
& $Flutter analyze
& $Flutter test
