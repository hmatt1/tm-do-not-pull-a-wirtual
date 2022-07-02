"C:\Program Files\7-Zip\7z.exe" a -tzip "DoNotPullAWirtual.op" "*"
del "%userprofile%\OpenplanetNext\Plugins\DoNotPullAWirtual.op"
move "DoNotPullAWirtual.op" "%userprofile%\OpenplanetNext\Plugins\DoNotPullAWirtual.op"

:: Get-Content -Path "%userprofile%\OpenplanetNext\Openplanet.log" -Wait
