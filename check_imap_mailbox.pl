#!/usr/bin/perl

############################################################################
##
## check_imap_mailbox
##
## Checks the given mailbox for new mails and returns
## CRITICAL if new email has arrived.
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
##
############################################################################

use strict;
use warnings;
use Mail::IMAPClient 3.22;
use Getopt::Long;

## Print Usage if not all parameters are supplied
sub Usage() 
{
  print "\nUsage: check_imap_mailbox [PARAMETERS]

Parameters:
  --host=[HOSTNAME]      : Name or IP address of IMAP server
  --user=[USERNAME]      : Username to connect with
  --pass=[PASSWORD]      : Password to connect with
  --passfile=[FILE]      : Read password from file
  --folder=[IMAP FOLDER] : The IMAP folder to check
  --starttls             : Use STARTTLS
  --ssl                  : Use SSL, changing default port to 993
\n";
}

## Initialize the mandatory options
my $options = {
                'host'   => '',
                'user'   => '',
                'folder' => '',
              };

## Get the options
GetOptions ( $options, "host=s", "user=s", "pass=s", "folder=s", "passfile=s",
                       "ssl", "starttls" );

## Check if all mandatory parameters are supplied. Print usage if not
foreach (keys %{$options})
{
  if ( $options->{$_} eq '' )
  {
    print "\nError: Parameter missing --$_\n";
    Usage();
    exit(3);
  }
}

# Load password if needed, overriding password specified on command line
# if one exists)
if ($options->{passfile})
{
  my $pwf;
  if ( open($pwf, '<', $options->{passfile}) )
  {
    $options->{pass} = <$pwf>;
    chomp $options->{pass};
  }
  else
  {
    print "Unable to read password from ". $options->{passfile} . "\n";
    exit(3);
  }
}

if ( ! $options->{pass} )
{
  print "\nError: No password specified\n";
  Usage();
  exit(3);
}


## Returns an unconnected Mail::IMAPClient object:
my $imap = Mail::IMAPClient->new;       
        
## Connect to server
$imap = Mail::IMAPClient->new (  
                Server  => $options->{host},
                User    => $options->{user},
                Password=> $options->{pass},
                Ssl     => $options->{ssl},
                Starttls=> $options->{starttls},
                Clear   => 5,   # Unnecessary since '5' is the default
                ) or print "Cannot connect to $options->{host}: $@\n" and exit 2;


## Check if folder exists
if ( ! $imap->exists($options->{folder}) )
{
   print "CRIT: folder $options->{folder} doesn't exists";
   exit 2;
}

## Read the unseen messages in folder
my $unseen = $imap->unseen_count($options->{folder}) || "0";

## Now check the results
if ( $unseen == 0 )
{
   print "OK: $unseen unread messages";
   exit 0;
}
else
{
   print "CRIT: $unseen unread messages in $options->{folder}";
   exit 2;
}

