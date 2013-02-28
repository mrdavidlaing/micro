## How to create a AWS AMI

1.  Launch Windows_Server-2012-RTM-English-64Bit-SQL_2012_RTM_Express-2013.02.13 (ami-fcaa3b95)
1.  Disable IE Enhanced Security
1.  Install railsinstaller.org
1.  Download libcurl (yes, the 32 bit version!)- http://curl.haxx.se/gknw.net/7.29.0/dist-w32/curl-7.29.0-devel-mingw32.zip and extract to `C:\RailsInstaller\curl-7.29.0-devel-mingw32`
1.  Add `C:\RailsInstaller\curl-7.29.0-devel-mingw32\bin` to the Path
1.  Install curb gem - `gem install curb --platform=ruby --version 0.7.18 -- --with-curl-lib=C:/RailsInstaller/curl-7.29.0-devel-mingw32/bin --with-curl-include=C:/RailsInstaller/curl-7.29.0-devel-mingw32/include`
1. `gem install highline net-ssh net-scp --no-ri --no-rdoc`
1.  Clone https://github.com/IronFoundry/micro
1.  Put things where they want to be (using *Admin* Command Prompt with Ruby and Rails):
    * `mklink /D C:\IronFoundry C:\Users\Administrator\Documents\GitHub\micro\C\IronFoundry`
    * `mklink /D C:\Ruby193 C:\RailsInstaller\Ruby1.9.3`
1. `cd C:\IronFoundry\mssql && bundle install`
1. `cd C:\IronFoundry\Setup && RunSetup.cmd`
