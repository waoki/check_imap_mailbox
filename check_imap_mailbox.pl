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

Connection parameters:
  --host=[HOSTNAME]      : Name or IP address of IMAP server
  --user=[USERNAME]      : Username to connect with
  --pass=[PASSWORD]      : Password to connect with
  --passfile=[FILE]      : Read password from file
  --folder=[IMAP FOLDER] : The IMAP folder to check
  --starttls             : Use STARTTLS
  --ssl                  : Use SSL, changing default port to 993

Unread message checks:
  --max-unread-crit      : Maximum unread messages before returning CRITICAL
  --max-unread-warn      : Maximum unread messages before returning WARNING
  --min-unread-crit      : Minimum unread messages before returning CRITICAL
  --min-unread-warn      : Minimum unread messages before returning WARNING

\n";
}

## Initialize the mandatory options
my $options = {
                'host'   => '',
                'user'   => '',
                'folder' => '',
              };

## Get the options
GetOptions ( $options, "host=s", "user=s", "pass=s", "folder=s", "passfile=s"
                      ,"ssl", "starttls"
                      ,"max-unread-crit=i", "max-unread-warn=i"
                      ,"min-unread-crit=i", "min-unread-warn=i"
                      );

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

# Validate optional parameters
if ( defined($options->{'max-unread-crit'}) || defined($options->{'max-unread-warn'}) )
{
  unless ( defined($options->{'max-unread-crit'}) &&
           defined($options->{'max-unread-warn'}) )
  {
    print "\nError: --max-unread-crit and --max-unread-warn must be used together\n";
    Usage();
    exit(3);
  }
  else
  {
    unless ( $options->{'max-unread-crit'} >= $options->{'max-unread-warn'} )
    {
      print "\nError: --max-unread-crit must be >= --max-unread-warn\n";
      exit(3);
    }
  }
}
if ( defined($options->{'min-unread-crit'}) || defined($options->{'min-unread-warn'}) )
{
  unless ( defined($options->{'min-unread-crit'}) &&
           defined($options->{'min-unread-warn'}) )
  {
    print "\nError: --min-unread-crit and --min-unread-warn must be used together\n";
    Usage();
    exit(3);
  }
  else
  {
    unless ( $options->{'min-unread-crit'} <= $options->{'min-unread-warn'} )
    {
      print "\nError: --min-unread-crit must be <= --min-unread-warn\n";
      exit(3);
    }
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


my $msg = check_imap_mailbox::msg->new();

## Check if folder exists
if ( ! $imap->exists($options->{folder}) )
{
   $msg->update(2, "folder $options->{folder} doesn't exist");
   # XXX short-circuit
}
else
{

  ## Read the unseen messages in folder
  my $unseen = $imap->unseen_count($options->{folder}) || "0";

  ## Check unseen messages
  if ( defined $options->{'max-unread-crit'} && $unseen > $options->{'max-unread-crit'} )
  {
     $msg->update(2, "$unseen unread messages in $options->{folder}");
  }

  if ( defined $options->{'min-unread-crit'} && $unseen < $options->{'min-unread-crit'} )
  {
     $msg->update(2, "$unseen unread messages in $options->{folder}");
  }

  if ( defined $options->{'max-unread-warn'} && $unseen > $options->{'max-unread-warn'} )
  {
     $msg->update(1, "$unseen unread messages in $options->{folder}");
  }

  if ( defined $options->{'min-unread-warn'} && $unseen < $options->{'min-unread-warn'} )
  {
     $msg->update(1, "$unseen unread messages in $options->{folder}");
  }

  # won't override if an error's been reported, so this is safe:
  $msg->update(0, "$unseen unread messages");

}


print $msg->getmsg();
print "\n";
exit $msg->getstatus();


package check_imap_mailbox::msg;
use Carp;

our $VERSION = '0.1';

sub new
{
  my $self = {};

  bless($self);
  return $self;
}

sub update
{
  my $self = shift;
  my $priority = shift;
  my $msg = shift;
  confess "No priority specified" unless ( defined($priority) );
  confess "No message specified" unless ( defined($msg) );

  if ( ! defined($self->{'priority'}) )
  {
    # Nothing already exists, so update
    $self->{'priority'} = $priority;
    $self->{'msg'} = $msg;
  }
  else
  {
    # Check if we need to update. Can't do straight-across comparison because
    # we prefer to return CRITICAL (2) or WARNING (1) instead of UNKNOWN (3).
    # We assume it's OK unless a check fails.

    if ( $priority == 3 )
    {
      if ( $self->{'priority'} == 0 )
      {
        # UNKNOWN overrides OK here
        $self->{'priority'} = $priority;
        $self->{'msg'} = $msg;
      }
      # UNKNOWN can't override anything else
      return $self;
    }

    if ( $self->{'priority'} == 3 )
    {
      # Let UNKNOWN be overridden by anything but OK or another UNKNOWN
      if ( $priority != 3 && $priority != 0 )
      {
        $self->{'priority'} = $priority;
        $self->{'msg'} = $msg;
      }
      return $self;
    }

    if ( $priority > $self->{'priority'} ) {
      $self->{'priority'} = $priority;
      $self->{'msg'} = $msg;
    }
  }

  return $self;
}

sub getmsg() {
  my $self=shift;
  if ( $self->{'priority'} == 0 )
  {
    return 'OK: ' . $self->{'msg'};
  }
  elsif ( $self->{'priority'} == 1 )
  {
    return 'WARNING: ' . $self->{'msg'};
  }
  elsif ( $self->{'priority'} == 2 )
  {
    return 'CRITICAL: ' . $self->{'msg'};
  }
  else
  {
    return 'UNKNOWN: ' . $self->{'msg'};
  }
}

sub getstatus() {
  my $self=shift;
  return $self->{'priority'};
}
