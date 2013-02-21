require 'highline/import'
require 'net/http'
require 'net/ssh'
require 'net/scp'
require 'socket'
require 'yaml'

$stdout.sync = true
$stderr.sync = true

A_ROOT_SERVER = '198.41.0.4'

def self.local_ip(route = A_ROOT_SERVER)
  route ||= A_ROOT_SERVER
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
  UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
ensure
  Socket.do_not_reverse_lookup = orig
end

def try_ping(host)
  unless system("ping -n 2 #{host} > nul 2>&1")
    abort("Can't ping server using #{host}")
  end
end

def wait_for_cloudcontroller(host, httpPort=80)

  print 'Waiting for cloud controller to restart...'

  count = 0
  restarted = false
  while (count < 60)
    begin
      r = Net::HTTP.get_response(host, '/', httpPort)
      code_i = r.code.to_i
      if code_i == 200 || code_i == 304
        restarted = true
        break
      end
    rescue => e
      puts "ERROR: #{e.to_s}"
      count += 1
      sleep(5)
    end
  end

  if restarted
    puts 'Done.'
  else
    abort("Cloud controller did not restart!")
  end

end

def write_yaml(file, yml)
  File.open(file, 'w') do |f|
    YAML.dump(yml, f)
  end
end

def setup_local(natsHost, natsPort, natsUser=nil, natsPass=nil, apiPort=nil)

  print "Uninstalling Iron Foundry DEA..."
  system('start /wait msiexec /q /x IronFoundry.DEA.Service.x64.msi /l*v uninstall.log')
  puts 'Done.'

  print "Installing Iron Foundry DEA..."
  system("start /wait msiexec /q /i IronFoundry.DEA.Service.x64.msi NATSHOST=#{natsHost} NATSUSER=\"#{natsUser}\" NATSPASSWORD=\"#{natsPass}\" /l*v install.log")
  puts 'Done.'

  mbus_url = "nats://#{natsUser}:#{natsPass}@#{natsHost}:#{natsPort}"
  if natsUser.nil? || natsPass.nil?
    mbus_url = "nats://#{natsHost}:#{natsPort}"
  end
  print 'Setting up MS-SQL node and provisioning services...'

  system('netsh advfirewall firewall delete rule name="Allow Incoming To rubyw.exe" > nul')
  system('netsh advfirewall firewall add rule name="Allow Incoming To rubyw.exe" dir=in action=allow enable=yes program="C:\Ruby193\bin\rubyw.exe" > nul')

  local_ip_addr = local_ip()

  node_cfg = 'C:/IronFoundry/mssql/config/mssql_node.yml'
  cfg = YAML.load_file(node_cfg)
  cfg['mbus'] = mbus_url
  write_yaml(node_cfg, cfg)

  gateway_cfg = 'C:/IronFoundry/mssql/config/mssql_gateway.yml'
  cfg = YAML.load_file(gateway_cfg)
  
  if apiPort.nil?
    cfg['cloud_controller_uri'] = "http://#{natsHost}"
  else
    cfg['cloud_controller_uri'] = "http://#{natsHost}:#{apiPort}"
  end

  cfg['mbus'] = mbus_url
  cfg['token'] = '0xdeadbeef' # must match token in cloud_controller.yml

  write_yaml(gateway_cfg, cfg)

  [ 'mssql_gateway_svc', 'mssql_node_svc' ].each do |svc|
    # puts "sc config #{svc} start= delayed-auto > nul"
    system("sc config #{svc} start= delayed-auto > nul")
    # puts "sc start #{svc} > nul"
    system("sc start #{svc} > nul")
    started = false
    cnt = 0
    until started
      sleep(30)
      # puts "sc query #{svc} 2>&1"
      query_out = %x/sc query #{svc} 2>&1/
      # puts "sc query OUT:\n#{query_out}"
      started = query_out =~ /RUNNING/
      if started || cnt > 5
        break
      else
        cnt += 1
      end
      if query_out =~ /STOPPED/
        system("sc start #{svc} > nul")
      end
    end
  end

  print '

Done.


Thank you for your interest in Iron Foundry.
Please use http://help.ironfoundry.org to report any issues found.

'

end

def micro_cloud_foundry

  puts '

Find your Micro Cloud Foundry Identity name, which can be found on the
Micro CF "Current Configuration" screen.

'

  micro_dns = ask("Enter Micro CF Identity: ") { |x| x.echo = true }
  password = ask("Enter Micro CF Password: ") { |x| x.echo = "*" }

  micro_dns.chomp!
  password.chomp!

  try_ping(micro_dns)

  puts "\nUsing Micro Cloud Foundry '#{micro_dns}'"

  print "Running patch script on #{micro_dns}..."
  output = nil
  Net::SSH.start(micro_dns, 'root', :password => password) do |ssh|
    scp = Net::SCP.new(ssh)
    scp.upload!('aspdotnet.yml', '/root/aspdotnet.yml')
    scp.upload!('plugin.rb', '/root/plugin.rb')
    scp.upload!('stage', '/root/stage')
    scp.upload!('microcf.runtimes-yml.patch', '/root/microcf.runtimes-yml.patch')
    scp.upload!('microcf_patch.rb', '/root/microcf_patch.rb')
    output = ssh.exec!('/var/vcap/bosh/bin/ruby /root/microcf_patch.rb 2>&1')
  end
  puts 'Done.'

  settings_line = nil
  output.each_line do |l| 
    if l.start_with?('SETTINGS')
      settings_line = l.chomp
      break
    end
  end

  settings = settings_line.split('|')
  natsHost = settings[1]
  natsUser = settings[2]
  natsPass = settings[3]
  natsPort = settings[4]

  puts "natsHost: #{natsHost}, natsPort: #{natsPort}, natsUser: #{natsUser}, natsPass: #{natsPass}"

  wait_for_cloudcontroller(natsHost)

  setup_local(natsHost, natsPort, natsUser, natsPass)

end

def stackato

  puts '

Find your Stackato host name (ends in .local) and IP Address, which can
be found on the ActiveState Stackato console screen.

'

  micro_dns = ask("Enter host name (without https://): ") { |x| x.echo = true }
  micro_ip = ask("Enter IP address: ") { |x| x.echo = true }
  password = ask("Enter administrator password: ") { |x| x.echo = "*" }

  micro_dns.chomp!
  micro_ip.chomp!
  password.chomp!

  try_ping(micro_ip)

  puts "\nUsing Stackato with host name '#{micro_dns}'"

  print "Adding #{micro_ip} to hosts file..."
  File.open('C:/Windows/System32/drivers/etc/hosts', 'a') do |f1|
    f1.puts("#{micro_ip}\t\t#{micro_dns} api.#{micro_dns} testapp.#{micro_dns}")
  end
  puts 'Done.'

  wait_for_cloudcontroller(micro_dns, 9022)

  setup_local(micro_dns, 4222, nil, nil, 9022)

end

puts '

Welcome to the Micro Iron Foundry setup process.

Before running setup, please ensure that you have a working Micro Cloud
Foundry VM or Stackato VM running on your workstation.

Instructions can be found here:

Micro CF: https://my.cloudfoundry.com/micro

Stackato: http://docs.stackato.com/quick-start/index.html#stackato-micro-cloud

'

vm_type = 0
while vm_type < 1 || vm_type > 3
  begin
    vm_type = ask('
Please choose VM type:

  1) Micro Cloud Foundry
  2) Stackato
  3) Quit').to_i

    if vm_type == 3
      exit
    end
  rescue
    puts 'Please enter 1, 2 or 3.'
    vm_type = 0
  end
end

if vm_type == 1
  micro_cloud_foundry
else
  stackato
end
