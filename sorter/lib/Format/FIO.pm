################################################################################
#  Module: Format::FIO
################################################################################
#
#	Module for parsing emails from FIO
#
#-------------------------------------------------------------------------------
package Format::FIO;

use 5.008008;
use strict;
use warnings;
use base 'Format';
use Format qw/NormalizeText NormalizeAmount IBAN MatchTemplate/;
use Const;

################################################################################
#	Group: Constructor
################################################################################

#-------------------------------------------------------------------------------
# Constructor: new
#	Creates new Format::FIO object
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
        'zustatek na ucte'    => 'FIO.cz.balance',
        'platba kartou'       => 'FIO.cz.card',
		'vydaj na konte: \d'       => 'FIO.cz.payment.out',
		'prijem na konte: \d'       => 'FIO.cz.payment.in'
    };

    $self->{module} = {
        'FIO.cz.balance'  => \&Balance_cz,
        'FIO.cz.card'     => \&Card_cz,
        'FIO.cz.payment.in'  => \&Payment_cz_in,
        'FIO.cz.payment.out'  => \&Payment_cz_out,
    };
    return bless $self, $class;
}

################################################################################
#	Group: Format functions
################################################################################
sub Balance_cz {
    my ($text) = @_;

    my $template = 
    my ( $account, $balance ) =
      MatchTemplate($text, "zustatek na ucte (.*): (.*)");

    my $dt = DateTime->now();
    my $return = {
        date => {
            day   => $dt->day()   + 0,
            month => $dt->month() + 0,
            year  => $dt->year()  + 0,
        },
        balance => { bank_available => NormalizeAmount($balance) },
        my_account => IBAN('2010', $account),
    };
    return [ $return ];
}

sub Payment_cz_in {
    my ($text) = @_;

    my ( $account, $amount, $vs, $message, $balance, undef, $sender_account, $sender_bank ) =
      MatchTemplate($text, "prijem na konte: (.*) castka: (.*) vs: (.*) zprava prijemci: (.*) aktualni zustatek: (.*) (protiucet: (.*)\\/(.*) ss)*");

    my $dt = DateTime->now();
    my $return = {
        date => {
            day   => $dt->day()   + 0,
            month => $dt->month() + 0,
            year  => $dt->year()  + 0,
        },
		amount => NormalizeAmount($amount), 
        balance => { bank_available => NormalizeAmount($balance) },
        receiver   => IBAN( '2010', $account ),
        sender => IBAN( $sender_bank, $sender_account ),
        my_account => IBAN('2010', $account),
        tags     => {
            how => Const::HOW_BEZHOTOVOSTNI_PLATBA
        },
		vs => $vs,
		description => $message
    };
    return [ $return ];
}

sub Payment_cz_out {
    my ($text) = @_;

    my ( $account, $amount, $vs, $dealer, $balance, undef, $receiver_account, $receiver_bank ) =
      MatchTemplate($text, "vydaj na konte: (.*) castka: (.*) vs: (.*) us: ([^ ]*).* aktualni zustatek: (.*) (protiucet: (.*)\\/(.*) ss)*");

    my $dt = DateTime->now();
    my $return = {
        date => {
            day   => $dt->day()   + 0,
            month => $dt->month() + 0,
            year  => $dt->year()  + 0,
        },
		amount => NormalizeAmount($amount) * -1, 
        balance => { bank_available => NormalizeAmount($balance) },
        sender   => IBAN( '2010', $account ),
        receiver => IBAN( $receiver_bank, $receiver_account ),
        my_account => IBAN('2010', $account),
        tags     => {
            how => Const::HOW_BEZHOTOVOSTNI_PLATBA
        },
		vs => $vs
    };
    return [ $return ];
}

sub Card_cz {
    my ($text) = @_;

    my ( $account, $amount, $vs, $dealer, $balance ) =
      MatchTemplate($text, "vydaj na konte: (.*) castka: (.*) vs: (.*) us: ([^ ]+).* aktualni zustatek: (.*) protiucet: platba kartou");

    my $dt = DateTime->now();
    my $return = {
        date => {
            day   => $dt->day()   + 0,
            month => $dt->month() + 0,
            year  => $dt->year()  + 0,
        },
        oms        => {
            city    => undef,
            country => 'cz',
            dealer  => $dealer
        },
		amount => NormalizeAmount($amount) * -1, 
        balance => { bank_available => NormalizeAmount($balance) },
        my_account => IBAN('2010', $account),
        tags => {
            how  => Const::HOW_PLATBA_KARTOU
        }
    };
    return [ $return ];
}

################################################################################
#	Group: Helper functions
################################################################################
sub _mainText {
    my ($self) = @_;
	return $self->{main_text} if defined $self->{main_text}; 
    my @parts = $self->{email}->parts;

	$self->{main_text} = NormalizeText($parts[0]->decoded);
	return $self->{main_text};
}

1;	
