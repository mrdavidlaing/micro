@echo on

net stop mssql_node_svc
net stop mssql_gateway_svc

sc config mssql_node_svc start= demand
sc config mssql_gateway_svc start= demand

cd C:\IronFoundry\Setup

start /wait msiexec /q /x .\IronFoundry\IronFoundry.Dea.Service.x64.msi

del /F .\IronFoundry\*.log

move /Y C:\Windows\System32\drivers\etc\hosts.bak C:\Windows\System32\drivers\etc\hosts

rd /s /q C:\IronFoundry\apps
rd /s /q C:\IronFoundry\droplets

dir "C:\Program Files\"

del /F C:\var\vcap\sys\log\*.log

pause
