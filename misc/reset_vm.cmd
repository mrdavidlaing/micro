@echo on

net stop mssql_node_svc
net stop mssql_gateway_svc

sc config mssql_node_svc start= disabled
sc config mssql_gateway_svc start= disabled

cd C:\IronFoundry

rd /s /q apps
rd /s /q droplets

cd C:\IronFoundry\Setup

start /wait msiexec /q /x .\IronFoundry\IronFoundry.Dea.Service.x64.msi

cd C:\IronFoundry\Setup\IronFoundry

del /F *.log

cd C:\IronFoundry\mssql\log
del /F *.log

move /Y C:\Windows\System32\drivers\etc\hosts.bak C:\Windows\System32\drivers\etc\hosts
dir "C:\Program Files\"

pause
