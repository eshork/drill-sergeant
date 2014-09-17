drill-sergeant
==============
A centralized browser director for web-based dashboards.

### Is it any good? ###
[Yes.](https://news.ycombinator.com/item?id=3067434)

### Why does this exist? ###
After adopting [dashing](http://dashing.io) for generic dashboards at the day job, I found there were several features lacking that would have made it a more complete product, but they didn't quite fit into the loose and fast spirit of the project, so they wouldn't be good addons - this is one of those features.

This software will allow you to point an army of web browsers at a single url, and then assign them individual rotation schedules to flip through other various urls - effectively giving you remote scheduling over the URLs that each browser display. We find this great for cycling the TVs on our campus through multiple dashboards - both dashing driven, and otherwise.

I'm sure someone wrote a Firefox plugin that already does this, but a) this is centrally coordinated, so all your dashboards could update simultaneously (and let's face it, that's way sexier); and b) I had a free weekend.

### What am I looking at? ###
* Ruby 2.1.2
* Padrino/Sinatra/Rack
* faye-websockets - wrapped by padrino-websockets
* Hours of my time, wasted


### How do I get set up? ###

* First you need to [Get Vagrant](http://www.vagrantup.com/) (we use VirtualBox as the provider)
* Check out all the code to some directory and chdir to project_path/vagrant
* Run: *vagrant up*
* Go drink a beverage you find refreshing for 10-15 minutes
* Run: *vagrant ssh* to enter the VM and look in /vagrant_src for all the relevant bits
* chdir to /vagrant_src/trade2win and Run: *bundle*
* Go drink more a beverage you find refreshing for 10-15 minutes

You now have a working Ubuntu 14.04 LTS development environment.
You can start the app with: *'padrino -h 0.0.0.0 -p 18080'*
  or some other appropriate variant that suits your needs


