name             "common"
maintainer       "Dang Mai"
maintainer_email "contact@dangmai.net"
license          "MIT"
description      "Installs/Configures common stuff across my systems"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

depends "apt"
depends "chocolatey"
depends "git"
depends "nodejs"
depends "npm"
depends "homebrew"
depends "pacman"
depends "python"
depends "rvm"