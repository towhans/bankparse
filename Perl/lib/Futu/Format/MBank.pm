################################################################################
#  Module: Futu::Format::MBank
################################################################################
#
#	Module for parsing emails from MBank
#
#-------------------------------------------------------------------------------
package Futu::Format::MBank;

use 5.008008;
use strict;
use warnings;
use base 'Futu::Format';
use Futu::Format qw/NormalizeText NormalizeAmount IBAN MatchTemplate/;
use Futu::Const;
use Futu::Mail;
use JSON;
use Futu::Re;

################################################################################
#	Group: Constructor
################################################################################

#-------------------------------------------------------------------------------
# Constructor: new
#	Creates new Futu::Format::MBank object
#
# Parameters:
#	$email	- Email::MIME instance
# Returns:
#	$instance
#-------------------------------------------------------------------------------
sub new {
    my ( $class, $email ) = @_;
    $class = ref $class || $class;
    my $self = { email => $email };

    $self->{format} = {
        'e-mail push'               => 'MBank.cz.push',
		'frekvence: misieni'		=> 'MBank.cz.monthly',
		'pdf'						=> 'MBank.cz.monthly',
    };
    $self->{module} = {
        'MBank.cz.push'    => \&Push_cz,
        'MBank.cz.monthly'    => \&Ignore,
    };
    return bless $self, $class;
}

################################################################################
#	Group: Format functions
################################################################################
sub Ignore {
	return undef;
}

sub Push_cz {
    my ($text) = @_;

    my ( $day, $month, $year ) = MatchTemplate($text, "e-mail push ze dne (\\d+)\\.(\\d+).(\\d+)");
	my $date = {
		day => $day + 0,
		month => $month + 0,
		year => $year + 0
	};	
	my @notifications = ();

	while ($text =~ m/mbank: ([^<]+)/g) {
		my $message = $1;
		my $notif;
		if ($message =~ m/^odchozi platba z/) {
			$notif = Payment_out($message, $date);
		} elsif ($message =~ m/^odchozi platba -/) {
			$notif = Payment_out_inkaso($message, $date);
		} elsif ($message =~ m/^na vas ucet/) {
			$notif = Interest_in($message, $date);
		} elsif ($message =~ m/^prichozi/) {
			$notif = Payment_in($message, $date);

# zrusene transakce
		} elsif ($message =~ m/splatka se nezdarila/) {
			Ignore();
		} elsif ($message =~ m/^zamitnuti prev./) {
			Ignore();
		} elsif ($message =~ m/^zamit. autorizace/) {
			Ignore();
		} elsif ($message =~ m/neprovedeno inkaso/) {
			Ignore();
######
		} elsif ($message =~ m/^autorizace karty/) {
			$notif = Card($message, $date);
		} elsif ($message =~ m/zustatek vypisu visa classic credit/) {
			$notif = Visa($message, $date);


# ne-transakce
		} elsif ($message =~ m/^potv. zmeny adresy/) {
			Ignore();
		} elsif ($message =~ m/^potvrzeni/) {
			Ignore();
		} elsif ($message =~ m/potv. zmeny udaju/) {
			Ignore();
		} elsif ($message =~ m/pripomenuti splatky/) {
			Ignore();
		} elsif ($message =~ m/pristup k sluzbe/) {
			Ignore();
		} elsif ($message =~ m/upozorneni na prekroceni/) {
			Ignore();
		} elsif ($message =~ m/pristupove heslo/) {
			Ignore();
#####


		} elsif ($message =~ m/zustatek na uctu/) {
			$notif = SimpleBalance($message, $date);
		} elsif ($message =~ m/^z vaseho/) {
			$notif = Balance($message, $date);
		} elsif ($message =~ m/^nespravne/) {
			Ignore();
		} else {
		#	Futu::Mail::SendMail(
		#		'sovicka@futu.cz',
		#		'Neznamy format dat',
		#		$message,
		#		'strix@futu.cz'
		#	);
			push( @notifications, {format=>'MBank.error'});
		}
		if ($notif) {
			my ( $balance ) = MatchTemplate($message, "dostup\\.zust:(.*) czk");
			$notif->{balance}{bank_available} = NormalizeAmount($balance) if $balance;
			push( @notifications, $notif);
		}
	}
	return \@notifications;
}

sub SimpleBalance {
    my ($text, $date) = @_;

	my ( $account, $year, $month, $day, $available_balance ) = MatchTemplate($text, "zustatek na uctu: (.*) v (\\d+)-(\\d+)-(\\d+) k dispozici: (.*) czk");
	my $return = {
		date => {
			day => $day + 0,
			month => $month + 0,
			year => $year + 0
		},
		my_account => IBAN('6210', $account),
		balance => {
			bank_available => NormalizeAmount($available_balance)
		},
	};
    return $return;
}

sub Balance {
    my ($text, $date) = @_;

	my $return;
	if ($text =~ m/av: karta/) {
		my ( $account, $amount ) = MatchTemplate($text, "z vaseho uc\\. (.*) odeslo:(.{1,12}) czk");
		my ( $available_balance ) = MatchTemplate($text, "zust:(.{1,12}) czk");
		my $my_account = IBAN('6210', $account);

		$return = {
			date => $date,
			my_account => $my_account,
			sender => $my_account,
			receiver => {
				country => 'CZ',
				bank => 6210,
				number => 'mKreditka'
			},
			amount  => NormalizeAmount($amount),
			balance => {
				bank_available => NormalizeAmount($available_balance)
			},
			tags => {
				how => Futu::Const::HOW_BEZHOTOVOSTNI_PREVOD,
				show_in_reports => JSON::true, # this means hide_in_reports, refactoring needed
			},
		};
	} else {

		my ( $account, $available_balance ) = MatchTemplate($text, "z vaseho uc\\. (.*) odeslo.*zust:(.*) czk");
		$return = {
			date => $date,
			my_account => IBAN('6210', $account),
			balance => {
				bank_available => NormalizeAmount($available_balance)
			},
		};
	}
    return $return;
}


#mBank: Zustatek vypisu VISA CLASSIC CREDIT: 806,00 CZK. Dostup.zust: 69074,00 CZK.
sub Visa {
    my ($text, $date) = @_;

    my ( $amount, $available_balance ) =
      MatchTemplate($text, "credit: (.*) czk\\. dostup\\.zust:(.*) czk");

    my $return = {
        date => $date,
        amount => NormalizeAmount($amount) * -1,
        my_account => IBAN('6210', 'VISA CLASSIC CREDIT'),
        balance => {
            bank_available => NormalizeAmount($available_balance)
        },
        tags => {
            card   => 'VISA CLASSIC CREDIT',
            how => Futu::Const::HOW_PLATBA_KARTOU
        }
    };
    return $return;
}

sub Card {
    my ($text, $date) = @_;

#mBank: Autorizace karty 08852701: MONEYBOOKERS LONDON. Castka: 806,00 CZK. Dostup.limit: 74194,00 CZK.

    my ( $card, $dealer, $amount) =
      MatchTemplate($text, "autorizace karty (\\d+): (.*) castka: $Futu::Re::amount czk");

    my $return = {
        date => $date,
        amount => NormalizeAmount($amount) * -1,
        oms    => {
            city    => "",
            country => "",
            dealer  => $dealer
        },
        my_account => IBAN('6210'),
#        balance => {
#            bank_available => NormalizeAmount($available_balance)
#        },
        tags => {
            card   => $card,
            how => Futu::Const::HOW_PLATBA_KARTOU
        }
    };
    return $return;
}

#mBank: Na Vas ucet 00737698 prislo: 0,04 CZK AV: P?IPS?N? ?ROK?; Dostup.zust: 0,04 CZK
sub Interest_in {
    my ($text, $date) = @_;
    my ( $receiver_account, $amount, $description )
      = MatchTemplate($text, "na vas ucet (.*) prislo: (.*) czk av: (.*);");

    my $return = {
        date => $date,
        amount   => NormalizeAmount($amount),
        sender   => IBAN( '6210' ),
        receiver => IBAN( '6210' , $receiver_account ),
        description       => $description,
		my_account => IBAN('6210', $receiver_account),
        tags => {
            how => Futu::Const::HOW_BEZHOTOVOSTNI_PRIJEM
        }
    };
    return $return;
}

sub Payment_in {
    my ($text, $date) = @_;
    my (
        $sender_account, $sender_bank, $receiver_account,
        $amount,         $description
      )
      = MatchTemplate($text, "(\\d*)\\/?(.*) na uc\\. (.*) castka (.*) czk; av:(.*);");
	$sender_bank = '6210' unless $sender_bank;

    my $return = {
        date => $date,
        amount   => NormalizeAmount($amount),
        sender   => IBAN( $sender_bank, "$sender_account" ),
        receiver => IBAN( '6210' , $receiver_account ),
        description       => $description,
		my_account => IBAN('6210', $receiver_account),
        tags => {
            how => Futu::Const::HOW_BEZHOTOVOSTNI_PRIJEM
        }
    };
    return $return;
}

sub Payment_out_inkaso {
    my ($text, $date) = @_;

    my (
        $sender_account, $receiver_account, $receiver_bank,
        $amount
      )
      = MatchTemplate($text, "odchozi platba - provedeno inkaso\\/sipo z uctu (.*) na ucet \\.\\.\\.(.*)\\/(.*) castka: (.*) czk d");

    my $return = {
        date => $date,
        amount   => NormalizeAmount($amount) * -1,
        sender   => IBAN( '6210', $sender_account ),
        receiver => IBAN( $receiver_bank , "$receiver_account" ),
		my_account => IBAN('6210', $sender_account),
        tags => {
            how => Futu::Const::HOW_BEZHOTOVOSTNI_PLATBA
        }
    };
    return $return;
}

sub Payment_out {
    my ($text, $date) = @_;
    my (
        $sender_account, $receiver_account, $receiver_bank,
        $amount,         $description
      )
      = MatchTemplate($text, "odchozi platba z uc\\. (.*) na uc\\. \\.\\.\\.(.*)\\/(.*) castka (.*) czk; (.*);");

    my $return = {
        date => $date,
        amount   => NormalizeAmount($amount) * -1,
        sender   => IBAN( '6210', $sender_account ),
        receiver => IBAN( $receiver_bank , $receiver_account ),
        description       => $description,
		my_account => IBAN('6210', $sender_account),
        tags => {
            how => Futu::Const::HOW_BEZHOTOVOSTNI_PLATBA
        }
    };
    return $return;
}

################################################################################
#	Group: Helper functions
################################################################################
sub _mainText {
    my ($self) = @_;
	return $self->{main_text} if defined $self->{main_text}; 

    my ($p1, $p2) = $self->{email}->parts;
	my ($p3, $p4) = $p1->parts();

	$self->{main_text} = eval { NormalizeText($p4->body_str) } || 'pdf';
	return $self->{main_text};
}

1;	
