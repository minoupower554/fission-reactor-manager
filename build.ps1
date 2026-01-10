Remove-Item -Recurse -Force -Path dist
New-Item -ItemType Directory -Path dist -Force
New-Item -ItemType Directory -Path components -Force
(Get-Content main.lua) -replace "require\('types'\)","-- require('types')" | Set-Content 'dist\main.lua'
Copy-Item -Recurse -Path components -Destination 'dist\components'
Copy-Item -Path config.lua -Destination dist
