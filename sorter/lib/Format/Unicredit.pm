################################################################################
#  Module: Format::Unicredit
################################################################################
#
#	Module for parsing emails from KB
#
#-------------------------------------------------------------------------------
package Format::Unicredit;

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
#	Creates new Format::KB object
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
        'informuje o autorizaci karetni transakce'             => 'Unicredit.cz.card',
    };

    $self->{module} = {
        'Unicredit.cz.card'    => \&Card_cz,
	};
    return bless $self, $class;
}

################################################################################
#	Group: Format functions
################################################################################
sub Ignore {
	return undef;
}

sub Card_cz {
    my ($text) = @_;
    my ( $card, $day, $month, $year, $amount ) =
      MatchTemplate($text, "cislo karty: (.*) dne: (\\d+)\\.(\\d+).(\\d+) \\d\\d:\\d\\d castka (.*) czk");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount => NormalizeAmount($amount) * -1,
        my_account => IBAN('2700'),
        tags => {
            how  => Const::HOW_PLATBA_KARTOU,
            card => $card,
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
