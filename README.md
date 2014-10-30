The inabber script is a little front end for get-iplayer (found at https://github.com/dinkypumpkin/get_iplayer), that works with Radio 3, Radio 4, and Radio 4 Extra.

Recently the BBC introduced Nitro (https://developer.bbc.co.uk/nitro), which means that get-iplayer's search functions no longer work. I have been using this script as a personal frontend to get-iplayer, and offer it up now as a temporary expedient until someone works out a way to use Nitro.

### What it does

inabber scrapes radio schedules from the BBC's website, then pulls apart the html and presents each program in order and asks if the user wants to download it. Finally it sends the requests to get-iplayer (after making a text file listing the commands its sending, in case something goes wrong).

TV isn't supported, and neither are radio stations other than Radio 3, Radio 4, and Radio 4 Extra.

### Documentation

Copy the script to a file and name it "inabber.pl" (or whatever you want to call it). Run it like this:

> perl inabber.pl 

The script runs get_iplayer your current directory. So if you run it from ~/Documents, the downloaded programs will eventually end up in ~/Documents.

It is possible to tell the script to ignore certain programs. Search the script for "sub SkipIt" and use the examples given below that to guide you.

### Caveats

I wrote this script for my own use, and only added it to Github when get-iplayer's keyword search functions stopped working. The script is quite scrappy.

This is a Perl script. Without Perl it won't work.

The script assumes that get-iplayer is installed to the user's PATH.

### Windows (and OS X?)

The script was written for use under Linux. The script won't work with Windows, but it can be helpful (assuming you have Perl installed). The script will output a list of commands you can feed into get_iplayer to download programs for you. My understanding is that these commands for Windows are slightly different from the Linux versions. You should be able to edit the output file to turn the commands into the proper syntax for your system.

The script may work on OS X; I have no way of knowing. If not, you can probably use it to extract useful commands, as per Windows.
