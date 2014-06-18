package Maildir::Split;

use strict;
use warnings;

use Mail::Box::Maildir;

#-------------------------------------------------------------------------------
# Function: Split
#  Take all the messages from Maildir and split them into other Maildirs
#  based on username from email address
#
# Parameters:
#  $maildir - path to source maildir
#  $userdir - base path for user Maildirs
#  $domain  - domain of addressee
#
# Returns:
#  ($moved, $users, $unknown) - (# of moved emails, # of users, # of missing To)
#-------------------------------------------------------------------------------
sub Split {
	my ($maildir, $userdir, $domain) = @_;
	return 0 unless -d "$maildir";

	my $folder = Mail::Box::Maildir->new(folder => $maildir);

	my $moved  = 0;
	my $users  = {};
	my $unknown = 0;

	foreach my $mail ($folder->messages('ALL')) {
		my $user;
		foreach my $address ($mail->to()) {
			my $u = $address->user();
			my $h = $address->host();
			if ($domain) {
				$user = $u if $h eq $domain;
			} else {
				$user = $u;
			}
		}
		if (!$user) {
			$unknown++;
			$user = 'SYS_mail_without_To_header';
		}

		$user = 'SYS_SPAM' if $user =~ /\W/;

		$users->{$user} = undef;

		if (! -d "$userdir/$user") {
			new Mail::Box::Maildir folder => "$userdir/$user", create => 1;
		}

		my $fn = $mail->filename();
		my @parts = split(/\//, $fn);
		rename($fn, join('/', $userdir, $user, 'new', pop(@parts))) and $moved++;
	}
	return ($moved, scalar keys %$users, $unknown);
}


#-------------------------------------------------------------------------------
# Function: Watch
#  Watch Maildir for changes and apply Split function when it does.
#  Currently a naive approach is used (scan new, check new, scan or
#  wait for 1 sec).
#
# Parameters:
#  $maildir - path to source maildir
#  $userdir - base path for user Maildirs
#  $domain  - domain of addressee
#  $max     - max number of emails to move (undef if unlimited)
#
# Returns:
#  $moves - number of moved emails
#-------------------------------------------------------------------------------
sub Watch {
	my ($maildir, $userdir, $domain, $max) = @_;
	my $total_moved = 0;
	while (1) {
		my ($moved) = Split( $maildir, $userdir, $domain );
		$total_moved += $moved;
		if ( $max and $total_moved >= $max ) { die "Max moved reached" }
		sleep(1) unless $moved; 
	}
}


1;
