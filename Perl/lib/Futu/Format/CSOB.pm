################################################################################
#  Module: Futu::Format::CSOB
################################################################################
#
#	Module for parsing emails from CSOB
#
#-------------------------------------------------------------------------------
package Futu::Format::CSOB;

use 5.008008;
use strict;
use warnings;
use Futu::Format qw/NormalizeText NormalizeAmount IBAN MatchTemplate/;
use Futu::Const;
use base 'Futu::Format';
use utf8;
use Futu::Mail;

################################################################################
#	Group: Constructor
################################################################################

#-------------------------------------------------------------------------------
# Constructor: new
#	Creates new Futu::Format::CSOB object
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

        'csob'                 => 'CSOB.cz.universal',
    };

    $self->{module} = {

        'CSOB.cz.universal'             => \&Universal_cz,
    };
    return bless $self, $class;
}

sub Universal_cz {
    my ($text) = @_;

	my @notifications = ();
	my @ns = split(/dne/, $text);

	my $modules = {
		'bude na uctu'  					   => 'CSOB.cz.future',
        'vazeny'                 			   => 'CSOB.cz.intro',
        'na transakce platebn'                 => 'CSOB.cz.card',
        'zauctovan hotovostni vklad'           => 'CSOB.cz.deposit',
        'zauctovana transakce zps: castka \\+' => 'CSOB.cz.payment.in.zps',
        'zauctovana transakce zps: castka -'   => 'CSOB.cz.payment.out.zps',
        'zauctovana transakce tps: castka -'   => 'CSOB.cz.payment.out',
        'zauctovana transakce tps: castka \\+' => 'CSOB.cz.payment.in',
        'zasilame vypis z uctu cislo'          => 'CSOB.cz.monthly',
        'zauctovana transakce: castka -'       => 'CSOB.cz.fees',
        'zauctovana transakce: castka +'       => 'CSOB.cz.payment.due',
        'banka prijala platebni prikaz'        => 'CSOB.cz.payment.accepted',
        'disponibilni zustatek'                => 'CSOB.cz.balance',
        'hotovostni vyber'                     => 'CSOB.cz.withdrawal',
        'dorucili jsme vam nove komfortni'     => 'CSOB.cz.comfort',
        'prijeti pozadavku na zaslani vypisu'  => 'CSOB.cz.confirm',
		'vas pozadavek byl prijat' 			   => 'CSOB.cz.confirm',
		'dekujeme za pouziti sluzeb'           => 'CSOB.cz.intro',
	};

    my $sub = {
        'CSOB.cz.card'             => \&Card_cz,
        'CSOB.cz.payment.out'      => \&Payment_out_cz,
        'CSOB.cz.withdrawal'       => \&Cash_withdrawal_cz,
        'CSOB.cz.payment.in'       => \&Payment_in_cz,
        'CSOB.cz.payment.out.zps'  => \&Payment_out_zps_cz,
        'CSOB.cz.payment.in.zps'   => \&Payment_in_zps_cz,
        'CSOB.cz.deposit'          => \&Deposit_cz,
        'CSOB.cz.payment.accepted' => \&Ignore,
        'CSOB.cz.confirm'          => \&Ignore,
        'CSOB.cz.future'           => \&Ignore,
        'CSOB.cz.intro'            => \&Ignore,
        'CSOB.cz.comfort'          => \&Ignore,
        'CSOB.cz.monthly'          => \&Ignore,
        'CSOB.cz.fees'             => \&Fees_cz,
        'CSOB.cz.payment.due'      => \&Due_cz,
        'CSOB.cz.balance'          => \&Balance_cz,
    };
	
	foreach my $part (@ns) {
		my $format = undef;
		for my $key ( keys %$modules ) {
			my $f = $modules->{$key};
			$key =~ s/ /\\s+/g;
			if ( $part =~ m/$key/ ) {
				$format = $f;
				last;
			}
		}
		if ($format) {
			my $notif = $sub->{$format}->($part);
			if ($format eq 'CSOB.cz.payment.due') {
				# try to find a transaction in the same email that sent money
				foreach (@notifications) {
                    if (
                        ( $_->{receiver} and $_->{receiver}{number} and $notif->[0] and $notif->[0]->{receiver} and $notif->[0]->{receiver}{number})
                        and ( $_->{receiver}{number} eq
                              $notif->[0]->{receiver}{number} # new notifications
							)
                      )
                    {
                        $notif->[0]->{sender} = $_->{sender};
                        last;
                    }
				}
			}
			push(@notifications, @$notif) if $notif;
		} else {
			push(@notifications, {format=>'CSOB.error'});
			#Futu::Mail::SendMail(
			#	'sovicka@futu.cz',
			#	'Neznamy format dat',
			#	$part,
			#	'strix@futu.cz'
			#);
		}
	}
	return \@notifications;

}

################################################################################
#	Group: Format functions
################################################################################

sub Balance_cz {
    my ($text) = @_;

    my ( $day, $month, $year, $account, $actual_balance, $available_balance ) =
      MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) \\d\\d:\\d\\d je na vasem uctu cislo (.*) aktualni zustatek (.*) czk disponibilni zustatek (.*) czk");
    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        balance => {
            bank_accounting => NormalizeAmount($actual_balance),
            bank_available  => NormalizeAmount($available_balance)
        },
        my_account => IBAN( '0300', $account )
    };

    return [$return];
}

sub Card_cz {
    my ($text) = @_;

    my ( $day, $month, $year, $account, $amount ) =
      MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) byla na uctu (.*) zauctovana transakce platebni kartou: castka (.*) czk detaily transakce:");

    my ( $card, $dealer, $city ) =
      MatchTemplate($text, "detaily transakce: cislo pk (.*) zprava: .* misto: ([^\\n]*)\\n([^\\n]*) (zustatek|cashback)");

    my ( $vratka ) =
      MatchTemplate($text, "detaily transakce: (vratka)");

	my ($cashback) = MatchTemplate($text, "cashback: (.*) czk");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        sender     => IBAN( '0300',            $account ),
        amount     => NormalizeAmount($amount),
        my_account => IBAN( '0300',            $account ),
        tags => {
            how  => Futu::Const::HOW_PLATBA_KARTOU
        }
    };
	$return->{cashback} = NormalizeAmount($cashback) if $cashback;
	$return->{oms} = {
            city    => $city,
            country => 'cz',
            dealer  => $dealer
        } if $city and $dealer;
	$return->{tags}{card} = $card if $card;
	$return->{tags}{how} = Futu::Const::HOW_BEZHOTOVOSTNI_PRIJEM if $vratka;

    return [ $return ];
}

sub Cash_withdrawal_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $sender_account, $amount, $balance )
      = MatchTemplate($text, "(\\d+)\\.(\\d+)\.(\\d+) byl na uctu (.*) zauctovan hotovostni vyber: castka (.*) czk detaily vyberu: zustatek na uctu po zauctovani transakce: (.*) czk");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        sender   => IBAN( '0300', $sender_account ),
        tags     => {
            how => Futu::Const::HOW_VYBER_NA_POBOCCE
        },
        my_account => IBAN( '0300', $sender_account ),
        balance => {
            bank_accounting => NormalizeAmount($balance),
        },
    };

    return [ $return ];
}

sub Payment_out_zps_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $sender_account, $amount, $receiver_bank,
        $receiver_account )
      = MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) byla na uctu (.*) zauctovana transakce zps: castka (.*) czk na ucet detaily platby: reference banky (.*) reference klienta (.*) zprava");

    my ($vs) = MatchTemplate($text, "vs (.*) vs");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        receiver => IBAN( $receiver_bank, $receiver_account ),
        sender   => IBAN( '0300', $sender_account ),
        tags     => {

            how => $receiver_account eq ''
            ? Futu::Const::HOW_VYBER_NA_POBOCCE
            : Futu::Const::HOW_BEZHOTOVOSTNI_PLATBA
        },
        my_account => IBAN( '0300', $sender_account ),
        vs         => $vs,
    };

    return [ $return ];
}

sub Payment_in_zps_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $receiver_account, $amount, $sender_bank,
        $sender_account )
      = MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) byla na uctu (.*) zauctovana transakce zps: castka (.*) czk z uctu detaily platby: reference banky (.*) reference klienta (.*) zprava");

    my ($vs) = MatchTemplate($text, "vs (.*) vs");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        receiver => IBAN( '0300', $receiver_account ),
        sender   => IBAN( $sender_bank, $sender_account ),
        tags     => {

            how => $sender_account eq ''
            ? Futu::Const::HOW_VKLAD_NA_POBOCCE
            : Futu::Const::HOW_BEZHOTOVOSTNI_PRIJEM
        },
        my_account => IBAN( '0300', $receiver_account ),
        vs         => $vs,
    };

    return [ $return ];
}

sub Payment_out_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $sender_account, $amount, $receiver_account,
        $receiver_bank )
      = MatchTemplate($text, "(\\d+)\\.(\\d+)\.(\\d+) byla na uctu (.*) zauctovana transakce tps: castka (.*) czk na ucet (.*)\\/(.*) detaily");

    my ($vs) = MatchTemplate($text, "vs (.*) vs");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        sender   => IBAN( '0300', $sender_account ),
        receiver => IBAN( $receiver_bank, $receiver_account ),
        tags     => {
            how => Futu::Const::HOW_BEZHOTOVOSTNI_PLATBA
        },
        my_account => IBAN( '0300', $sender_account ),
        vs         => $vs,
    };

    return [ $return ];
}

sub Deposit_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $receiver_account, $amount )
      = MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) byl na uctu (.*) zauctovan hotovostni vklad: castka (.*) czk");

	my ($balance) = MatchTemplate($text, "zustatek na uctu po zauctovani transakce: (.*) czk");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        receiver => IBAN( '0300', $receiver_account ),
        balance => {
            bank_accounting => NormalizeAmount($balance),
        },
        tags     => {

            how => Futu::Const::HOW_VKLAD_NA_POBOCCE
        },
        my_account => IBAN( '0300', $receiver_account ),
    };

    return [ $return ];
}

sub Payment_in_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $receiver_account, $amount, $sender_account,
        $sender_bank )
      = MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) byla na uctu (.*) zauctovana transakce tps: castka (.*) czk z uctu (.*)\\/(.*) detaily");

    my ($vs) = MatchTemplate($text, "vs (.*) vs");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        receiver => IBAN( '0300', $receiver_account ),
        sender   => IBAN( $sender_bank, $sender_account ),
        tags     => {

            how => $sender_account eq ''
            ? Futu::Const::HOW_VKLAD_NA_POBOCCE
            : Futu::Const::HOW_BEZHOTOVOSTNI_PRIJEM
        },
        my_account => IBAN( '0300', $receiver_account ),
        vs         => $vs,
    };

    return [ $return ];
}

sub Due_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $account, $amount ) = MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) byla na uctu (.*) zauctovana transakce: castka (.*) czk detaily");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        receiver => IBAN( '0300',            $account ),
        amount => NormalizeAmount($amount),
        tags   => {
            regularity => 'měsíční',
            what => 'splatka',
            how  => Futu::Const::HOW_BEZHOTOVOSTNI_PREVOD,
        },
        my_account => IBAN( '0300', $account ),
    };
    return [ $return ];
}

sub Fees_cz {
    my ($text) = @_;
    my ( $day, $month, $year, $account, $amount ) = MatchTemplate($text, "(\\d+)\\.(\\d+)\\.(\\d+) byla na uctu (.*) zauctovana transakce: castka (.*) czk detaily");

    my ( $balance ) = MatchTemplate($text, "zustatek na uctu po zauctovani transakce: (.*) czk");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        sender => IBAN( '0300',            $account ),
        amount => NormalizeAmount($amount),
        tags   => {
            regularity => 'měsíční',
            what => 'poplatky',
            whom => 'ČSOB',
            how  => Futu::Const::HOW_BEZHOTOVOSTNI_PLATBA
        },
        balance => {
            bank_accounting => NormalizeAmount($balance),
        },
        my_account => IBAN( '0300', $account ),
        receiver   => IBAN('0300')
    };
    return [ $return ];
}

################################################################################
#	Group: Helper functions
################################################################################
sub Ignore {
	return undef;
}

sub _mainText {
    my ($self) = @_;
	return $self->{main_text} if defined $self->{main_text}; 
    my @parts = $self->{email}->parts;

	$self->{main_text} = NormalizeText($parts[0]->body_str);
	#warn $self->{main_text};
	return $self->{main_text};
}


1;	
