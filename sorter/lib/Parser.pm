################################################################################
#  Module: Parser
################################################################################
#  
#   Parse emails
#
#-------------------------------------------------------------------------------
package Parser;

use strict;
use warnings;
use Time::HiRes qw/gettimeofday tv_interval/;
use Const;
use Format qw/Bank/;
use Format::FIO;
use Format::Unicredit;
use Format::KB;
use Format::CSOB;
use Format::Raiffeisen;
use Format::MBank;
use Format::CS;
use Format::Airbank;
use DateTime;
use Data::Dumper;
use File::Slurp;
use Mail::Message;
use Furl;
use JSON::XS;
use DateTime;

################################################################################
#   Group: Functions
################################################################################

my $bank_module = {
    'FIO'        => 'Format::FIO',
    'KB'         => 'Format::KB',
    'Raiffeisen' => 'Format::Raiffeisen',
    'Unicredit'  => 'Format::Unicredit',
    'Airbank'    => 'Format::Airbank',
    'CSOB'       => 'Format::CSOB',
    'MBank'      => 'Format::MBank',
    'CS'         => 'Format::CS',
};

sub Log {
	print(DateTime->now()->datetime()."\t$_[0]\n");
}

#-------------------------------------------------------------------------------
# Function: Parse
#  Parse one email and return structured data
#
# Parameters:
#  $mail - Mail::Message instance
#  $user - user name
#  $filename - file where the mail is stored #TODO set to email itself
#  $url - url where to POST notifications
#
# Returns:
#  $parsed - number of parsed mails
#-------------------------------------------------------------------------------
sub Parse {
    my ( $email, $alias, $filename, $url, $text) = @_;

	Log("Parse: $filename");
    my $msg_header = $email->get('Message-ID');
	my $notifications = [];
	my $futubox;
    if ($alias and $msg_header) {
		my ($message_id) = $msg_header =~ m/<(.*)>/;
		my $timestamp = DateTime->now->iso8601;

		$futubox = $alias;
		my $db_notif;

		# from which bank did email come from
		my $bank = Bank($email);

		if (!$bank) {
			return ('.missingformatfamily', {filename=>$filename});
		}

		# parse the email with right format
		my $parser = $bank_module->{$bank}->new($email);
		my $format = $parser->detect;

		if (!$format) {
			return ('.missingformat', {filename=>$filename});
		}

		$notifications = $parser->apply($format);
		foreach my $notification (@$notifications) {
			$notification->{message_id} = $message_id;
			$notification->{stored}     = { futubox => $futubox };
			$notification->{timestamp}  = { created_at => $timestamp };
		}
        my $ret = {
            formatfamily  => $bank,
            format        => $format,
            filename      => $filename,
            notifications => $notifications,
            url           => $url
        };
		$ret->{text} = $parser->_mainText if $text;
		return ('.parsed', $ret);
    }
    return ('.missingAliasOrMessageId', {filename=>$filename});
}

sub MoveMail {
	my ($fn, $folder) = @_;
	my ($dir, $name) = $fn =~ /(^.*)\/([^\/]*)$/;
	`mkdir -p $dir/../$folder`;

	#Log("MoveMail - $fn -> $dir/../$folder/$name");
	rename($fn, "$dir/../$folder/$name") || Log("Could not rename file $fn to $dir/../$folder/$name ($!)");
}

sub HandleStatus {
	my ($status, $data) = @_;
	if ($status eq '.missingformat') {
		MoveMail($data->{filename}, '.missingformat');
	} elsif ($status eq '.missingformatfamily') {
		MoveMail($data->{filename}, '.missingformatfamily');
	} elsif ($status eq '.parsed') {

		my $all_posted = 1;
		foreach my $notification (@{$data->{notifications}}) {
			if ($data->{url}) {
				# TODO re-use agent
				my $furl = Furl->new( agent   => 'EmailParser/0.001', timeout => 10, );
				my $res = $furl->post(
					$data->{url} ,
					['Content-Type' => 'application/json'], 
					encode_json($notification)
				);
				if (!$res->is_success) {
					$all_posted = undef;
					warn $res->status_line;
				}
			}
		}
		if ($all_posted) {
			MoveMail($data->{filename}, '.parsed');
		} else {
			MoveMail($data->{filename}, '.errorposting');
		}
	} elsif ($status eq '.missingAliasOrMessageId') {
		MoveMail($data->{filename}, '.missingAliasOrMessageId');
	}
}

# parse a folder in Maildir++
sub ParseDir {
	my ($dir, $user, $url) = @_;
	#Log("ParseDir - $dir");
	foreach my $mfn (read_dir($dir)) {
		next unless -f "$dir/$mfn";
		open(my $fh, '<', "$dir/$mfn");
		my $mail = Mail::Message->read($fh);
		my ($status, $data) = Parse($mail, $user, "$dir/$mfn", $url);
		HandleStatus($status, $data);
	}
}

sub ParseMaildirs {
	my ($userdir, $url, $subdir) = @_;
	foreach my $user (read_dir($userdir)) {
		my $dir = "$userdir/$user/$subdir";
		ParseDir($dir, $user, $url) if -d $dir;
	}
}

sub Watch {
	my ($userdir, $url, $interval, $max) = @_;

	$userdir =~ s|/$||;
	Log("ParseMailDirs: .missingformat");
	ParseMaildirs($userdir, $url, '.missingformat');
	Log("ParseMailDirs: .missingformatfamily");
	ParseMaildirs($userdir, $url, '.missingformatfamily');

	my $time = time();
	my $end_time = $time + ($max || 0);
	while (1) {
		last if ($max and ($end_time < time()));
		ParseMaildirs($userdir, $url, 'new');
		if ((time() - $time) % $interval == 0) {
			Log("ParseMailDirs: .errorposting");
			ParseMaildirs($userdir, $url, '.errorposting');
			Log("ParseMailDirs: .errorposting - finished");
		}
		sleep(1);
	}
}


1;
