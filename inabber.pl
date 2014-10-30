#!/usr/bin/perl

# inabber.pl -- a simple frontend for get_iplayer
# Author: Nathaniel Florin
# Email:  npflorin (then put in the at symbol) yahoo.com
# Github: https://github.com/nflorin/inabber/
#
#     The MIT License (MIT)
#
#     Copyright (c) 2014 Nathaniel Florin
#
#     Permission is hereby granted, free of charge, to any person obtaining a copy
#     of this software and associated documentation files (the "Software"), to deal
#     in the Software without restriction, including without limitation the rights
#     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#     copies of the Software, and to permit persons to whom the Software is
#     furnished to do so, subject to the following conditions:
#
#     The above copyright notice and this permission notice shall be included in
#     all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#     THE SOFTWARE.
#
# See https://github.com/nflorin/inabber/ for documentation, updates, etc.

use autodie;

use LWP::Simple;
use Time::Piece;
use Time::Seconds;

my @requests = ();
my %pidCache;

my $version = 0.1;
print "This is inabber.pl, version $version.\n";
print 'Updates may be available at https://github.com/nflorin/inabber/';
print "\n\n";

# Find username to get download_history file location
my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);

# Read in the download_cache file, so we won't see things get_iplayer won't fetch
# Comment out the next 12 lines if you want to see everything.
my $cacheFile = '/home/' . $username . '.get_iplayer/download_history';
if (-e $cacheFile)	{
	open $cache, "<", $cacheFile;

	while (<$cache>) {
		m/^(b.{7})/;
		if ($1) {
			$pidCache{ $1 } = 1;
		}
	}
	close $cache;
}

#   Main program
    &inabber;
#   Repeat?
    &another;
#   Send requests to get-iplayer
    &rungetiplayer( @requests );

sub another {
#   See if we should keep going.
    print "Another search? (Y or N)";
    my $another = <>;
    if ($another =~ /y/i)   {
        print "\n";
        &inabber;
    }
    if ($another =~ /n/i)   {
        return;
    }
#   Didn't get that.
    print "I didn't understand you -- ";
    &another;
}

sub inabber {
    my $xml = &SearchWanted;
    my @new_requests = &ParseRadioXML( $xml );
    foreach my $request (@new_requests) {
        push(@requests, $request);
        my $pid = $request;
        $pid =~ s/get-iplayer -g --type=radio --pid //;
        $pidCache{ $pid } = 1;
    }
}

sub SearchWanted    {
    my $xml = ' ';
    
	#   Find the station(s) we want.
	print qq{
	What station are you interested in?
        1. BBC Radio 3
        2. BBC Radio 4
        3. BBC Radio 4 Extra
        4. All three at once
        5. None -- quit
	};
	my $station_wanted = <>;
	chomp( $station_wanted );

	if ($station_wanted == 5)	{
		if (scalar @requests >= 1)	{
			&rungetiplayer( @requests );
		} else {
			print "No requests found. Quitting.\n";
			exit;
		}
	}
		
    if ($station_wanted !~ /\d/ || $station_wanted =~ /\D/ || $station_wanted > 5) {
        print "I didn't get that.";
        return( $xml );
    }
    else    {	
	#   Find the date, then find the dates we want
        my $datetime = Time::Piece->new;
        my $time_working = $datetime;
	
	print "\nWhat day are you interested in?\n";
		
		print "0\.\tToday\n";
		for (my $i=1; $i <= 10; $i++)    {
		    $time_working -= ONE_DAY;
		    my $time = $time_working;
		    $time =~ s/(.{11}).{9}/$1/;
		    print "$i\.\t$time\n";
		}
		my $day_wanted = <>;
		chomp( $day_wanted );
		
		#   Get the day and month of the wanted date
		for (my $i=1; $i <= $day_wanted; $i++)    {
		    $datetime -= ONE_DAY;
		}
		    $day_wanted = $datetime->ymd("/");
	
	    if ($station_wanted == 1)   {
	        my $url = 'http://www.bbc.co.uk/radio3/programmes/schedules/' . $day_wanted;
	        $xml = get( $url );
	    }
	    if ($station_wanted == 2)   {
	        my $url = 'http://www.bbc.co.uk/radio4/programmes/schedules/fm/' . $day_wanted;
	        $xml = get( $url );
	    }
	    if ($station_wanted == 3)   {
	        my $url = 'http://www.bbc.co.uk/radio4extra/programmes/schedules/' . $day_wanted;
	        $xml = get( $url );
	    }
	    if ($station_wanted == 4)   {
	        print "Fetching Radio 3 schedule...\n";
	        my $url = 'http://www.bbc.co.uk/radio3/programmes/schedules/' . $day_wanted;
	        $xml = get( $url );
	        print "Fetching Radio 4 schedule...\n";
	        $url = 'http://www.bbc.co.uk/radio4/programmes/schedules/fm/' . $day_wanted;
	        my $xml_plus = get( $url );
	        $xml = $xml . $xml_plus;
	        print "Fetching Radio 4 Extra schedule...\n";
	        $url = 'http://www.bbc.co.uk/radio4extra/programmes/schedules/' . $day_wanted;
	        $xml_plus = get( $url );
	        $xml = $xml . $xml_plus;
	    }
	    
#	    open XML, ">000-out.xml";
#	    print XML $xml;
	    
	    return( $xml );
    }
}

sub ParseRadioXML   {
    my $commandstart = 'get-iplayer -g --type=radio --pid ';

	my $break = '<div class="programme programme--radio programme--episode block-link"';
    my $xml = shift;
    $xml =~ s/$break/\n$break/g;
    my @schedule = split("\n", $xml);
    my @programs_wanted = ();
    my $localpids = '';
   
    foreach my $line (@schedule)    {
        my $program_title = '';
        my $program_subtitle = '';
        my $program_description = '';
        my $time = ' ';
        my $episode = ' ';
        if ($line =~ /$break/)  {
            $line =~ s/<span property="name">([^<]*)<\/span>//;
            $program_title = $1;
            $line =~ s/<span property="name">([^<]*)<\/span>//;
            $program_subtitle = $1;
            $line =~ /<span property="description">([^<]*)<\/span>/;
            $program_description = $1;
			$line =~ m/data-pid="([^"]+)"/;
            my $pid = $1;
            $line =~ m/<abbr title="([^"]*)"/;
            unless ($1 =~ /^b0/)    {
                $episode = $1;
            }
            $line =~ /"xsd:dateTime" content=".{11}(.{5})/;
            if ($1) {
                $time = $1;
            }
    #       See if the program is on the list of things we're going to skip
            my $skip = &SkipIt( $program_title, $program_description );            
    #       If we've seen this already, skip it. Otherwise show what we've found.
    
			# Check if we've done this one before
			unless ($pidCache{ $pid })	{
	            if ($program_title =~ /[A-Za-z]/ &&  $localpids !~ /$pid/ && $skip == 0)  {
	                print "\n\n";
	                print "PID:\t\t$pid\n";
	                print "Time:\t\t$time\n";
	                print "Title:\t\t$program_title\n";
	                $program_subtitle =~ s/(.{48}[\S]*)\s(.*)/$1\n\t\t$2/;
	                print "Subtitle:\t$program_subtitle\n";
	                if ($episode =~ /\d/)  {
	                    print "Episode:\t$episode\n";
	                }
	                $program_description =~ s/(.{48}[\S]*)\s(.*)/$1\n\t\t$2/;
	                print "Description:\t$program_description\n";
	                print "Interested? (Y or N)  ";
	                my $interest = <>;
	                if ($interest =~ /y/i)  {
	                    my $command = $commandstart . $pid;
	                    push (@programs_wanted, $command);
	                }
	                $localpids = $localpids . $pid;
	                $pid = $program_title = $program_subtitle = $program_description = undef;
				}
            }
        }
    }
    return ( @programs_wanted );
}

sub rungetiplayer	{
	
    my @requested = @_;
	my $allcommands = '';
	my $commandno;
    my $runcleanup = 0;
    
	foreach (@requested)	{
		$commandno++;
		if ($commandno >= 2)	{
			$allcommands = $allcommands .'&';	}
		$allcommands = $allcommands . $_;
    }
	
	if ($allcommands =~ /get-iplayer/)	{
#	print the run command to the output file, just in case 
        open FILE2, ">inabber_last_command.txt";
		print FILE2 "$allcommands";
        close FILE2;
		print "Invoking get-iplayer...\n\n";
		system($allcommands);
    }
	else {
		print "No programs to fetch.\nQuitting now.\n";	
    }
}

sub SkipIt  {
	# Is this a program that we know we don't want?

    my ( $program_title, $program_description ) = @_;
    
#	You can add keywords from the title or description for things you aren't interested in.
#	Be careful! You might end up skipping things you don't want to skip.
#	Examples below. Uncomment a line to use it.

#    if ($program_title =~ /I'm Sorry I Haven't A Clue/)   {   return 1;  }
#    if ($program_title =~ /The Navy Lark/)   {   return 1;  }
#    if ($program_description =~ /The latest weather forecast\./)    {   return 1;  }
#    if ($program_description =~ /Eddie Mair presents coverage and analysis/)    {   return 1;  }
#    if ($program_description =~ /Morning news/)    {   return 1;  }
    
    return 0;
}

