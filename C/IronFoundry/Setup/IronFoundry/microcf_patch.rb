#!/usr/bin/env ruby -w

require 'yaml'
require 'etc'
require 'fileutils'

ENV['PATH'] = '/var/vcap/bosh/bin:' + ENV['PATH']
Dir.chdir('/root')

vcap_uid = Etc.getpwnam('vcap').uid
vcap_gid = Etc.getgrnam('vcap').gid

natsUser = nil
natsPass = nil

# NATS
nats_config = '/var/vcap/jobs/nats/config/nats.yml'
cfg = YAML.load_file(nats_config)

cfg['net'] = '0.0.0.0'
cfg['authorization']['timeout'] = 60
natsUser = cfg['authorization']['user']
natsPass = cfg['authorization']['password']
natsPort = cfg['port']

File.open(nats_config, 'w') do |f|
  YAML.dump(cfg, f)
end

# CLOUD CONTROLLER
cc_configs = [ '/var/vcap/jobs/cloud_controller/config/cloud_controller.yml',
               '/var/vcap/jobs/micro/cloud_controller/config/cloud_controller.yml' ]

cc_external_uri = nil
cc_configs.each do |config|
  cfg = YAML.load_file(config)
  if cc_external_uri.nil?
    cc_external_uri = cfg['external_uri']
  end
  cfg['local_route'] = cfg['external_uri']
  # cfg['runtimes']['aspdotnet40'] = { 'version' => '4.0.30319.1' }
  cfg['builtin_services']['mssql'] = { 'token' => '0xdeadbeef' }
  File.open(config, 'w') do |f|
    YAML.dump(cfg, f)
  end
end

unless system('patch -f -p0 < microcf.runtimes-yml.patch')
  $stderr.puts("patch failed: #{$?}")
end

cc_staging_dir = '/var/vcap/jobs/micro/cloud_controller/config/staging'
FileUtils.cp('aspdotnet.yml', cc_staging_dir)

vcap_staging_dir = '/var/vcap/packages/stager/vendor/bundle/ruby/1.9.1/gems/vcap_staging-0.1.63/lib/vcap/staging/plugin'
aspdotnet_dir = File.join(vcap_staging_dir, 'aspdotnet')
unless Dir.exists?(aspdotnet_dir)
  Dir.mkdir(aspdotnet_dir, 0755)
end
FileUtils.cp('stage', aspdotnet_dir)
FileUtils.cp('plugin.rb', aspdotnet_dir)
FileUtils.chown_R('vcap', 'vcap', aspdotnet_dir)

# Restart services
pid_files = [
  '/var/vcap/sys/run/nats/nats.pid',
  '/var/vcap/sys/run/router/router.pid',
  '/var/vcap/sys/run/cloud_controller/cloud_controller.pid'
]
pid_files.each do |pid_file|
  pid = nil
  File.open(pid_file) {|f| pid = f.readline.chomp.to_i}
  File.unlink(pid_file)
  Process.kill('TERM', pid)
  while false == File.exists?(pid_file)
    sleep(1)
  end
end

puts "SETTINGS|#{cc_external_uri}|#{natsUser}|#{natsPass}|#{natsPort}"
exit 0
