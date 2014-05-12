################################################################################
#  Module: Futu::Format::KB
################################################################################
#
#	Module for parsing emails from KB
#
#-------------------------------------------------------------------------------
package Futu::Format::KB;

use 5.008008;
use strict;
use warnings;
use base 'Futu::Format';
use Futu::Format qw/NormalizeText NormalizeAmount IBAN MatchTemplate/;
use Futu::Const;
use JSON;

################################################################################
#	Group: Constructor
################################################################################

#-------------------------------------------------------------------------------
# Constructor: new
#	Creates new Futu::Format::KB object
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
        'vygenerovan vypis'             => 'KB.cz.statement',
        'autorizace zrusena'            => 'KB.cz.card.canceled',
        'autorizaze zrusena'            => 'KB.cz.card.canceled',
        'blokovana castka'              => 'KB.cz.card',
        'provedeni platby z uctu cislo' => 'KB.cz.payment',
        'ucetni zustatek na beznem' 	=> 'KB.cz.balance.current.accounting',
        'pouzitelny zustatek na beznem' => 'KB.cz.balance.current',
        'bezny zustatek na uverovem'    => 'KB.cz.balance.credit',
		'bezny pouzitelny zustatek na kreditni karte cislo' => 'KB.cz.balance.card',
		'oznamujeme vam neprovedeni trvaleho prikazu' => 'KB.cz.payment.canceled'
    };

    $self->{module} = {
        'KB.cz.statement' => \&Ignore,
        'KB.cz.payment.canceled' => \&Ignore,
        'KB.cz.card.canceled' => \&Ignore,
        'KB.cz.card'    => \&Card_cz,
        'KB.cz.payment' => \&Payment_cz,
        'KB.cz.balance.current.accounting' => \&Balance_accounting_cz,
        'KB.cz.balance.current' => \&Balance_current_cz,
        'KB.cz.balance.credit'  => \&Balance_credit_cz,
    	'KB.cz.balance.card'    => \&Balance_card_cz,
	};
    return bless $self, $class;
}

################################################################################
#	Group: Format functions
################################################################################
sub Ignore {
	return undef;
}

sub Balance_accounting_cz {
    my ($text) = @_;

    my ( $account, $day, $month, $year, $available_balance ) =
      MatchTemplate($text, "ucetni zustatek na beznem uctu cislo (.*) ke dni (\\d+)\\.(\\d+).(\\d+) .* je (.{1,12}) czk");
	my ($overdraft) = MatchTemplate($text, "vcetne povoleneho debetu ve vysi (.*) je");

	if ($overdraft) {
    	$overdraft = NormalizeAmount($overdraft);
	} else {
		$overdraft = 0;
	}
    $available_balance = NormalizeAmount($available_balance);
    
    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        overdraft => $overdraft,
        balance => { bank_accounting => $available_balance - $overdraft , bank_available => $available_balance },
        my_account => IBAN('0100', $account) 
    };
    return [ $return ];
}



sub Balance_card_cz {
    my ($text) = @_;

    my ( $card, $day, $month, $year, $balance ) =
      MatchTemplate($text, "bezny pouzitelny zustatek na kreditni karte cislo (.*) ze dne (\\d+)\\.(\\d+).(\\d+) je (.*) czk");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        balance => { bank_available => NormalizeAmount($balance) },
        my_account => IBAN('0100'),
        tags => {
            card => $card,
        }
    };
    return [ $return ];
}

sub Balance_credit_cz {
    my ($text) = @_;

    my ( $account, $day, $month, $year, $accounting_balance ) =
      MatchTemplate($text, "bezny zustatek na uverovem uctu cislo (.*) ze dne (\\d+)\\.(\\d+).(\\d+) je (.*) czk");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        balance => { bank_accounting => NormalizeAmount($accounting_balance) },
        my_account => IBAN('0100', $account),
        product_type => 'credit', 
    };
    return [ $return ];
}

sub Balance_current_cz {
    my ($text) = @_;

    my ( $account, $day, $month, $year, $available_balance ) =
      MatchTemplate($text, "pouzitelny zustatek na beznem uctu cislo (.*) ze dne (\\d+)\\.(\\d+).(\\d+) je (.{1,12}) czk.");
	my ($overdraft) = MatchTemplate($text, "povoleny debet na beznem uctu cini (.*) czk.");

	if ($overdraft) {
    	$overdraft = NormalizeAmount($overdraft);
	} else {
		$overdraft = 0;
	}
    $available_balance = NormalizeAmount($available_balance);
    
    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        overdraft => $overdraft,
        balance => { bank_accounting => $available_balance - $overdraft , bank_available => $available_balance },
        my_account => IBAN('0100', $account) 
    };
    return [ $return ];
}

sub Card_cz {
    my ($text) = @_;
    my ( $card, $day, $month, $year, $amount, $dealer, $city, $country ) =
      MatchTemplate($text, "cislo (.*) byla dne (\\d+)\\.(\\d+).(\\d+) blokovana castka (.*) czk, misto platby (.*); (.*); (.*)\\. castka");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount => NormalizeAmount($amount) * -1,
        oms    => {
            city    => $city,
            country => $country,
            dealer  => $dealer
        },
        my_account => IBAN('0100'),
        tags => {
            how  => Futu::Const::HOW_PLATBA_KARTOU,
            card => $card,
        }
    };
    return [ $return ];
}

sub Payment_cz {
    my ($text) = @_;
    my (
        $sender_account, $sender_bank, $receiver_account,
        $receiver_bank,  $amount,      $day,
        $month,          $year,        $variable_symbol
      )
      = MatchTemplate($text, "z uctu cislo (.*)\\/(.*) na ucet cislo (.*)\\/(.*) castka (.*) czk , datum splatnosti (\\d+)\\.(\\d+).(\\d+), variabilni symbol platby (.*), specificky symbol");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        sender   => IBAN( $sender_bank, $sender_account ),
        receiver => IBAN( $receiver_bank, $receiver_account ),
        vs       => $variable_symbol,
    };

    # we can deduct some information from sender and receiver bank
    # if they differ then the one with 0100 code is my account
    if ( $sender_bank ne $receiver_bank ) {
        if ( $sender_bank eq '0100' ) {
            $return->{my_account} = IBAN( $sender_bank, $sender_account ),
              $return->{amount} *= -1;
            $return->{tags}{how} = Futu::Const::HOW_BEZHOTOVOSTNI_PLATBA
        }
        else {
            $return->{my_account} = IBAN( $receiver_bank, $receiver_account ),;
            $return->{tags}{how} = Futu::Const::HOW_BEZHOTOVOSTNI_PRIJEM
        }
    }
    else {
        if ( $sender_account eq '' ) {
            $return->{tags}{how} = Futu::Const::HOW_VKLAD_NA_POBOCCE;
            $return->{my_account} = IBAN( $receiver_bank, $receiver_account ),;
        }
        elsif ( $receiver_account eq '' ) {
            $return->{tags}{how} = Futu::Const::HOW_VYBER_NA_POBOCCE;
            $return->{my_account} = IBAN( $sender_bank, $sender_account ),;
        }
        else {

            # amount needs to be verified against user's list of bank accounts
            $return->{check}{amount} = JSON::true;
        }
    }

    return [ $return ];
}

################################################################################
#	Group: Helper functions
################################################################################
sub _mainText {
    my ($self) = @_;
	return $self->{main_text} if defined $self->{main_text}; 
    my @parts = $self->{email}->parts;

	$self->{main_text} = NormalizeText($parts[0]->body_str);
	return $self->{main_text};
}

1;	
