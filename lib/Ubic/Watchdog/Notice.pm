package Ubic::Watchdog::Notice;
#  
# use strict;
# use warnings;
use Data::Dumper;

use Sys::Hostname;
use Getopt::Long;
use File::Tail;
use MIME::Lite;
use URI;
use LWP::UserAgent;
use Ubic;
use JSON;

our $VERSION = 0.31;

my $host = hostname;

my $ua = LWP::UserAgent->new;
$ua->timeout(2);

$SIG{TERM} = sub { exit 0 };

my $conf;
my $conf_file = '/etc/ubic/notice.cfg';

my $default = {
	log       => '/var/log/ubic/watchdog.log',
	hipchat   => {
		host  => 'https://api.hipchat.com',
	},
	slack     => {
		host  => 'https://slack.com',
	},
};
use Data::Dumper;

sub service_status {
    my ($know_services,$search) = @_;
    $search =~ s/\./-/g;
    foreach my $service (@{$know_services}) {
            next if not ( $service->{"name"} eq $search);
            return $service->{"status"}->{"name"};

    }
}

sub know_service {
    my ($know_services,$search) = @_;
    foreach my $service (@{$know_services}) {
            next if not ($service->{"name"} eq $search);
            return true;
            
    }
    return false;
}

sub get_services {
    my ($know_services,$search) = @_;
    my @names = ();
    foreach my $service (@{$know_services}) {
            next if not ($service->{"name"});
#             print Dumper($service->{"name"})."\n";
              push(@names,$service->{name});    

    }
    return \@names;
}

sub run {
	GetOptions(
		'config=s' => \$conf_file,
	);

	die "Configuration file <$conf_file> not exists" unless -e $conf_file;

	$conf = do $conf_file;

	for (qw/From To/) {
		die "Configuration value <$_> is required" unless $conf->{$_};
	}
# 	   my @services = Ubic->root_service;

    my $url = URI->new("http://".$conf->{towncrier}->{url}."/admin/api/v1/services");
    my $response = $ua->get($url);
    my $know_services = {};
    if ($response->is_success) {
        $know_services = decode_json($response->content());
    }else    {
        warn "Getting Towncrier services faild";
        warn $response->status_line;
    };

    my $kservices = $know_services->{services};

    my $val = Ubic->root_service;

    foreach my $service ($val->services()) {
            my $counter = 0;
            foreach my $subservices ($service->services()) { $counter++;
                my $name = $service->name.".".$subservices->name;
                print $name."\tKnown: ".service_status($kservices,$name)."\n";      
#                 print Dumper($kservices)."\n";
                
                next if ( (service_status($kservices,$name) eq "Up") && (Ubic->cached_status($name)->status eq 'running') );
                next if ( (service_status($kservices,$name) eq "Down") && (Ubic->cached_status($name)->status eq 'broken') );
                my $init;
                $init->{name} = $service->name."-".$subservices->name;
                $init->{description} ||= "Multiservice";
  
        #         $bla->{description} ||= "Temp";
                #curl -u $AUTH -i http://localhost:3000/admin/api/v1/groups -F name=Primary -F description='Primary services'

                my $url = URI->new("http://".$conf->{towncrier}->{creds}.'@'.$conf->{towncrier}->{url}."/admin/api/v1/services");
                $url->query_form(%$init);
                $ua->post($url);
                my $bla; $bla->{service} = $service->name."-".$subservices->name;;
#                 print Ubic->cached_status($name)->status."\n";
                if(Ubic->cached_status($name)->status eq 'running') { # should read status from static file on disk
#                     print Dumper($status)."\n";                   
                    $bla->{status} ||= "up";	                    
                    $bla->{message} ||= "[NOTICE] $name is up and running"; 
                }else {
                    $bla->{status} ||= "down";	                    
                    $bla->{message} ||= "[NOTICE] $name is DOWN ";                 
                }
#                     $bla->{host} ||= "test";
                    my $nurl = URI->new("http://".$conf->{towncrier}->{creds}.'@'.$conf->{towncrier}->{url}."/admin/event");
                    $nurl->query_form(%$bla);
                    $response = $ua->post($nurl);

            }
            next if not ( $service->name );
            next if ($counter != 0);
#             next if (know_service($kservices,$service->name) eq true);
#             print "Known: ".know_service($kservices, $service->name)."\n";         
                my $name = $service->name;
                next if ( (service_status($kservices,$name) eq "Up") && (Ubic->cached_status($name)->status eq 'running') );
                next if ( (service_status($kservices,$name) eq "Down") && (Ubic->cached_status($name)->status eq 'broken') );
                print $name."\n";     
                my $init;
        
               if(Ubic->cached_status($name)->status eq 'running') { # should read status from static file on disk
#                     print Dumper($status)."\n";                   
                    $init->{status} ||= "up";	                    
                    $init->{message} ||= "[NOTICE] $name is up and running"; 
                }else {
                    $init->{status} ||= "down";	                    
                    $init->{message} ||= "[NOTICE] $name is DOWN ";                 
                }

                $init->{service} = $name;
#                 $init->{description} ||= "SingleService";

                my $url = URI->new("http://".$conf->{towncrier}->{creds}.'@'.$conf->{towncrier}->{url}."/admin/event");
                $url->query_form(%$init);
                my $response = $ua->post($url);
                unless ($response->is_success) {
                    warn "towncrier Init2 failed!";
                    warn $response->status_line;
                    warn $response->content;
                }      

    };
#     exit;
    $conf->{log} ||= $default->{log};
	#try to wipe logs
    system("echo >".$conf->{log}.' 2>/dev/null');
	while (1) {
		# Maybe file not exists
		eval {
			my $F = File::Tail->new(name => $conf->{log}, maxinterval => 10);
			my $line;
			while (defined( $line = $F->read )) {
				if (my ($service) = $line =~ /\]\s*(\S+)\s+status.*restarting/) {
					notice($service, $line);
				}
			}
		};

		sleep 1;
	}
}



sub notice {
	my ($service, $txt) = @_;

	return unless $service;
    my $nservice = $service;
    
    $nservice =~ s/\./-/g;
	my $msg = MIME::Lite->new(
		From    => $conf->{From},
		To      => $conf->{To  },
		Subject => "[UBIC] $service down on $host",
		Data    => $txt,
	);
	$msg->attr("content-type.charset" => "utf-8");
	$msg->send("sendmail", "/usr/sbin/sendmail -t -oi -oem");

	if ($conf->{hipchat}) {
		my $h = $host;
		$h = substr $h, 0, 15 if length($h) > 15;

		my $response = $ua->post("$default->{hipchat}->{host}/v1/rooms/message", {
			auth_token     => $conf->{hipchat}->{token},
			room_id        => $conf->{hipchat}->{room },
			from           => $h,
			message        => $txt,
			message_format => 'text',
			notify         => 1,
			color          => 'yellow',
			format         => 'json',
		});

		unless ($response->is_success) {
			warn "Hipchat notification failed!";
			warn $response->status_line;
			warn $response->content;
		}
	}

	if($conf->{towncrier}) {
 		my $t = $conf->{slack};
	#	$t->{text    }   = "[$service] down on $host";
	#	$t->{username} ||= 'Ubic Server Bot';
# 		my $url1 = URI->new("http://".$default->{towncrier}->{url}.'@'.$default->{towncrier}->{url}"/admin/api/v1/groups");
# 		$url->query_form(%$t);
# 		my $response1 = $ua->get($url);	
        my $bla; my $init;
        $init->{name} = $service;
        $init->{description} ||= "Temp";
        $bla->{service} = $service;

#         $test->{service} = $service;
        $bla->{status} ||= "warn";	
        $bla->{message} ||= "restarting $service"; 
        $bla->{host} ||= "test";
                print "$nservice\n".Dumper(%$bla)."\n";
        my $nurl = URI->new("http://".$conf->{towncrier}->{creds}.'@'.$conf->{towncrier}->{url}."/admin/event");
		$nurl->query_form(%$bla);
		$response = $ua->post($nurl);

    }
	
	
	
	if($conf->{slack}) {
		my $t = $conf->{slack};
		$t->{text    }   = "[$service] down on $host";
		$t->{username} ||= 'Ubic Server Bot';

		my $url = URI->new("$default->{slack}->{host}/api/chat.postMessage");
		$url->query_form(%$t);
		my $response = $ua->get($url);

		unless ($response->is_success) {
			warn "Slack notification failed!";
			warn $response->status_line;
			warn $response->content;
		}
	}
}

1;

=pod
 
=head1 NAME

Ubic::Watchdog::Notice - Notice service for ubic.

=head1 VERSION

version 0.31

=head1 SYNOPSIS

    Start notice service:
    $ ubic start ubic.notice

=head1 DESCRIPTION

Currently module can notice by email and to L<HIPCHAT|https://www.hipchat.com> or L<SLACK|https://slack.com> service.

=head1 INSTALLATION

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

=head1 OPTIONS

=over

=item B< From >
    
Sets the email address to send from.

=item B< To >
    
Sets the addresses in `MIME::Lite` style to send to.

=item B< log >
    
Path to `ubic-watchdog` file for scan. Default is `/var/log/ubic/watchdog.log`.

=item B< hipchat >
    
Notice to L<HIPCHAT|https://www.hipchat.com> service.

	hipchat => {
		token => 'YOUR_TOKEN',
		room  => 'ROOM_NAME'
	},

=item B< slack >
    
Notice to L<SLACK|https://slack.com> service.

	slack => {
		token    => 'YOUR_TOKEN',
		channel  => '#CHANNEL_NAME'
		username => 'Ubic Server Bot'
	},

=back

=head1 SOURCE REPOSITORY

L<https://github.com/likhatskiy/Ubic-Watchdog-Notice>

=head1 AUTHOR

Alexey Likhatskiy, <likhatskiy@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 "Alexey Likhatskiy"

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
