################################################################################
#  Module: Futu::Parser
################################################################################
#  
#   Module for various Futu specific Email and EmailNotification operations
#
#-------------------------------------------------------------------------------

package Futu::Parser;

use 5.008008;
use strict;
use warnings;
use Exporter 'import';
use CouchDB::Client;
use Time::HiRes qw/gettimeofday tv_interval/;
use Futu::Const;
use Futu::Format qw/Bank/;
use Futu::Format::FIO;
use Futu::Format::Unicredit;
use Futu::Format::KB;
use Futu::Format::CSOB;
use Futu::Format::Raiffeisen;
use Futu::Format::MBank;
use Futu::Format::CS;
use Futu::Format::Airbank;
use Futu::User;
use Futu::Notification;
use Email::MIME;
use DateTime;
use Data::Dumper;

our @EXPORT_OK = qw(Futubox MainParser);

################################################################################
#   Group: Functions
################################################################################

#-------------------------------------------------------------------------------
# Function: Futubox
#   Given an instance of Email::MIME determines futubox (user id)
#
# Parameters:
#   $email  - Email::MIME instance
#
# Returns:
#   $futubox or undef
#-------------------------------------------------------------------------------
sub Futubox {
    my ($email) = @_;
	my $futubox;
    foreach my $a ($email->header('Delivered-To')) {
		$a = lc($a);
		if ($a =~ m/\@futubox\.cz/) {
			$futubox = $a;
			last;
		}
	}
	$futubox = lc($futubox);
    $futubox =~ s/ //g;
    $futubox =~ m/([^<]+)@/;
    return $1;
}

sub SaveEmail {
    my ($email, $db) = @_;
    my $doc = CouchDB::Client::Doc->new(db=>$db);
    $doc->{data} = $email;
    return $doc->create->id;
}

my $bank_module = {
    'FIO' => 'Futu::Format::FIO',
    'KB' => 'Futu::Format::KB',
    'Raiffeisen' => 'Futu::Format::Raiffeisen',
    'Unicredit' => 'Futu::Format::Unicredit',
    'Airbank' => 'Futu::Format::Airbank',
    'CSOB' => 'Futu::Format::CSOB',
    'MBank' => 'Futu::Format::MBank',
    'CS' => 'Futu::Format::CS',
};

sub MainParser {
    my ( $filehandle, $alias, $localy, $uri, $verbose )
      = @_;

    my $couch;
    my $email   = Email::MIME->new($filehandle);
    $alias = Futubox($email) unless $alias;
    my $msg_header = $email->header('Message-ID');
	my $notifications = [];
	my $futubox;
    if ($alias and $msg_header) {
		my ($message_id) = $msg_header =~ m/<(.*)>/;
		my $timestamp = DateTime->now->iso8601;

		$futubox = $alias;
		my $db_notif;
		if ( not $localy ) {
			$couch = CouchDB::Client->new( uri => $uri );

			# check that futubox exists
			my $check = Futu::User::UserExists($alias, $couch);
			die "Unknown user ($alias)" unless $check;
			$futubox = $check->{_id};
			$db_notif = $couch->newDB( Futu::Const::NOTIFICATION_DB );
		}
		# from which bank did email come from
		my $bank = Bank($email);
		die "Unknown bank" unless $bank;

		# parse the email with right format
		my $format = $bank_module->{$bank}->new($email);
		$notifications = $format->parse($verbose);

		foreach my $notification (@$notifications) {
			$notification->{message_id} = $message_id;
			$notification->{stored}     = { futubox => $futubox };
			$notification->{timestamp}  = { created_at => $timestamp };
			Futu::Notification::Create($notification, $db_notif) unless $localy;
		}
    } else {
		warn "Missing alias";

	}
    $Data::Dumper::Terse = 1;
    print Dumper($notifications) if ($verbose and $notifications);
    return ($futubox, $notifications);
}


1;
