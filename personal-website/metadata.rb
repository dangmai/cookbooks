name             "personal-website"
maintainer       "Dang Mai"
maintainer_email "contact@dangmai.net"
license          "All rights reserved"
description      "Installs/Configures my personal website"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

depends "apache2"
depends "npm"
depends "git"