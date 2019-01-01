# Ubic::Watchdog::Notice
===============================
* Fork of Ubic::Watchdog::Notice

Todo
======
- Call REST API from [Towncrier](https://github.com/fastmail/towncrier/tree/master/lib/TownCrier)







Ubic::Watchdog::Notice - Notice service for ubic. Currently module can notice by email and to [HIPCHAT](https://www.hipchat.com) or [SLACK](https://slack.com) service.

## Installation

    cpan -i Ubic::Watchdog::Notice

Put this code in file `/etc/ubic/service/ubic/notice`:

    use Ubic::Service::SimpleDaemon;
    
    Ubic::Service::SimpleDaemon->new(
        bin => ['ubic-notice'],
    );

Put this configuration in file `/etc/ubic/notice.cfg`:


    {
	    From => 'likhatskiy@gmail.com',
	    To   => 'name@mail.com',
    };

Start it:

    $ ubic start ubic.notice
    
## Options
* From
    
    Sets the email address to send from.
* To
    
    Sets the addresses in `MIME::Lite` style to send to.
* log
    
    Path to `ubic-watchdog` file for scan. Default is `/var/log/ubic/watchdog.log`.
* hipchat
    
    Notice to [HIPCHAT](https://www.hipchat.com) service.


	hipchat => {
		token => 'YOUR_TOKEN',
		room  => 'ROOM_NAME'
	},
* slack
    
    Notice to [SLACK](https://slack.com) service.


	slack => {
		token    => 'YOUR_TOKEN',
		channel  => '#CHANNEL_NAME'
		username => 'Ubic Server Bot'
	},

	

	
## Towncrier
==================



* Service ADD

        curl -XPOST --data 'name=up&description=dasisttest&icon=ok' 'http://admin:secret@btc-mining.at:3000/admin/api/v1/statuses' 
        {
            "url" : "/statuses/up",
            "id" : "up",
            "icon" : "ok-sign",
            "name" : "up",
            "description" : "dasisttest"
        }
  
        curl -XPOST --data 'name=ping&description=blabla' 'http://admin:secret@btc-mining.at:3000/admin/api/v1/services'
        {
            "status" : null,
            "description" : "blabla",
            "id" : "ping",
            "group" : null,
            "name" : "ping",
            "order" : 0,
            "event" : null,
            "url" : "/services/ping"
        }



* CREATE

         curl -XPOST --data 'name=online&description=dasisttest&icon=ok&path=/test' 'http://bob:hacks@btc-mining.at:3000/admin/api/v1/statuses


* DELTE 

        curl -XPOST --data 'name=online&description=dasisttest&icon=ok&path=/test' 'http://bob:hacks@btc-mining.at:3000/admin/api/v1/statuses' 

        

## Source repository
<https://github.com/likhatskiy/Ubic-Watchdog-Notice> 

## Author
Alexey Likhatskiy, <likhatskiy@gmail.com>

## Copyright and licence
Copyright (C) 2014 "Alexey Likhatskiy"

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
