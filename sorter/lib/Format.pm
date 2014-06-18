################################################################################
#  Module: Format
################################################################################
#  
#	Module for parsing emails with known format
#
#-------------------------------------------------------------------------------

package Format;

use 5.008008;
use strict;
use warnings;
use Unicode::Normalize;
use Exporter 'import';

our @EXPORT_OK =
  qw(NormalizeCountry Bank NormalizeText NormalizeAmount IBAN PrepareTemplate MatchTemplate);

################################################################################
#	Group: Functions
################################################################################

#-------------------------------------------------------------------------------
# Function: Bank
#	Given an instance of Email::MIME determines the bank that it came from.
#
# Parameters:
#	$email	- Email::MIME instance
#
# Returns:
#	$bank or undef - /KB|CSOB|Raiffeisen|MBank/
#-------------------------------------------------------------------------------
sub Bank {
	my ($email) = @_;
	my $from = lc($email->get('From') || '');
	my $bank;

	# try to determine format by headers
	if ($from =~ m/info\@rb.cz/) {
		$bank = 'Raiffeisen';
	} elsif ($from =~ m/administrator\@tbs.csob.cz/) {
		$bank = 'CSOB';
	} elsif ($from =~ m/info\@kb.cz/) {
		$bank = 'KB';
	} elsif ($from =~ m/kontakt\@mbank.cz/) {
		$bank = 'MBank';
	} elsif ($from =~ m/cic\@csas.cz/) {
		$bank = 'CS';
	} elsif ($from =~ m/info\@airbank.cz/) {
		$bank = 'Airbank';
	} elsif ($from =~ m/onlinebanking\@unicreditgroup.cz/) {
		$bank = 'Unicredit';
	} elsif ($from =~ m/automat\@fio.cz/) {
		$bank = 'FIO';
	} else {
	# try to determine format by content
		my @parts = $email->parts;
		my $text = NormalizeText($parts[0]->decoded);
		if ($text =~ m/dekujeme za vyuziti sluzeb csob/) {
			$bank = 'CSOB';
		} elsif ($text =~ m/pripojene dokumenty mohou byt duverne/) {
			$bank = 'KB';
		} elsif ($text =~ m/e-mail push/) {
			$bank = 'MBank';
		} elsif ($text =~ m/realizovano:|obchodnik/) {
			$bank = 'Raiffeisen';
		} elsif ($text =~ m/jmeno majitele \/ nazev uctu:/) {
			$bank = 'CS';
		}
	}

	return $bank;	
}

sub NormalizeText {
	my ($text) = @_;
	$text = NFD(lc($text));
	$text =~ s/^\s+//g;
	$text =~ s/\s+$//g;
	$text =~ s/[^[:ascii:]]//g;
	$text =~ s/\n+/é/g;
	$text =~ s/\s+/ /g;
	$text =~ s/é/\n/g;
	return $text;
}

sub MatchTemplate {
	my ($text, $template) = @_;
    $template = PrepareTemplate($template);
    my @vars = $text =~ m/$template/;
	foreach (@vars) {
		next unless $_;
		$_ =~ s/(:?^\s+)|(:?\s+$)//g;
	}
	return @vars;
}

sub PrepareTemplate {
    my ($template) = @_;
    $template =~ s/FUTU_CASTKA/\(\.\*\) \(\.\*\) \(\.\*\)/g; 
    $template =~ s/ /\\s*/g;
    return $template;
}

sub IBAN {
    my ( $bank, $account, $country ) = @_;
    $country = 'CZ' unless $country;

    $bank =~ s/ //g if $bank;


    if ($bank and $bank eq '6210' and $account) {
		if (lc($account) eq 'visa classic credit') {
			return {
				country => $country,
				bank    => $bank,
				number  => $account,
			};
		}
        $account = "670100-22".$account;
    }

    if ($account) {
        my ($number, $prefix) = ('', '');
        if ($account =~ /-/) {
            ($prefix, $number) = $account =~ /(.*)-(.*)/;
            $number =~ s/^0+//g; 
            my $length = length($number);
            if ($length < 10) {
                my $zeroes = "0000000000";
                substr($zeroes, 10 - $length, $length, $number);
                $number = $zeroes;
            }
        } else {
            $number = $account;
        }
        $account = $prefix.$number;
        $account =~ s/^0+//g; 
    }


    return {
        country => $country,
        bank    => $bank,
        number  => $account,
    };

}

sub NormalizeAmount {
	my ($amount) = @_;
	return 0 unless $amount;
	$amount =~ s/ //g;
	$amount =~ s/\.//g;
	$amount =~ s/,/\./g;
	return $amount + 0;
}

sub NormalizeCountry {
	my ($country) = @_;
	$country = 'cz' if $country eq 'cze';
	return $country;
}

#-------------------------------------------------------------------------------
# Function: detect
#	determines the format of the message.
#
# Parameters:
#	$email	- Email::MIME instance
#
# Returns:
#	$format or undef - see %format for list of formats in specific bank module
#-------------------------------------------------------------------------------
sub detect {
    my ($self) = @_;

    my $text  = $self->_mainText;
    my $format;
    for my $key ( keys %{$self->{format}} ) {
        my $f = $self->{format}->{$key};
		$key =~ s/ /\\s+/g;
        if ( $text =~ m/$key/ ) {
			$format = $f;
            last;
        }
    }
    return $format;
}

#-------------------------------------------------------------------------------
# Function: apply
#	Parse Email::MIME to transaction notification or
#
# Parameters:
#	$format	- format of the message
#
# Returns:
#	@array	- array of JSON documents - transaction notifications
#-------------------------------------------------------------------------------
sub apply {
    my ($self, $format, $verbose) = @_;
   	my $notifications = $self->{module}->{$format}->($self->_mainText);
	map {$_->{format} = $format unless $_->{format}} @$notifications;
	return $notifications;
}


1;
