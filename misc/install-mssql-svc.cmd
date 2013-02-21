@echo on

setlocal

sc delete mssql_node_svc
sc delete mssql_gateway_svc

echo Creating 'mssql_node_svc' windows service ...
sc create mssql_node_svc start= disabled binPath= "C:\Ruby193\bin\rubyw.exe -C C:\IronFoundry\mssql\bin mssql_node_svc.rb"

echo Configuring 'mssql_node_svc' windows service ...
sc failure mssql_node_svc reset= 86400  actions= restart/600000/restart/600000/restart/600000 > nul

echo Creating 'mssql_gateway_svc' windows service ...
sc create mssql_gateway_svc start= disabled binPath= "C:\Ruby193\bin\rubyw.exe -C C:\IronFoundry\mssql\bin mssql_gateway_svc.rb"

echo Configuring 'mssql_gateway_svc' windows service ...
sc failure mssql_gateway_svc reset= 86400  actions= restart/600000/restart/600000/restart/600000 > nul
