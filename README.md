check_imap_mailbox
==================

Checks the given mailbox for new mail and returns WARNING or CRITICAL based the
on presence or absence of new messages and/or the presence or absence of recent
e-mails.

Age-based checks can be an arbitrary number of seconds even with IMAP servers
which do not support RFC 5032.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

redirect_or
===========

Checks whether a web page redirects somewhere. If so, returns OK; otherwise,
runs another check plugin. Intended for use with check_imap_mailbox, but can be
used with other plugins as needed.

Example:

The Museum of BOB allows people to reserve tickets online for special events a
few times a year. When reservations are closed, the reservation site redirects
elsewhere. Their sysadmin wants to trigger an alert if confirmation e-mails
aren't going out when reservations are open but doesn't want alarms warning
that e-mails aren't going out when none are being sent.

  redirect_or --url https://reservations.example.com/reserve/ --plugin check_imap_mailbox -- --host imap.example.com --starttls --user confirmations@example.com --passfile /etc/monitoring/secrets/confirmations --folder "Inbox" --younger 64800 --min-younger-crit 1 --min-younger-warn 3


