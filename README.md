Do a:

    bundle install

Then you should be able to start a server from the current directory by doing:

    ruby -I./ server.rb

and then you can start some clients with:

    ruby -I./ main.rb


I think this should work with the current renet gem, but if you get segfaults, install renet from here: https://github.com/jvranish/rENet

