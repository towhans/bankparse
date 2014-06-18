################################################################################
#  Module: Format::KB
################################################################################
#
#	Module for parsing emails from KB
#
#-------------------------------------------------------------------------------
package Format::Airbank;

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

        'na vasem uctu s nazvem' => 'Airbank.cz.balance',
#        'u airbank se snizil o'  => 'Airbank.cz.payment_out',
#        'u airbank se zvysil o'  => 'Airbank.cz.payment_in',
    };

    $self->{module} = {
        'Airbank.cz.balance'    => \&Balance_cz,
	};
    return bless $self, $class;
}

################################################################################
#	Group: Format functions
################################################################################
sub Ignore {
	return undef;
}

sub Balance_cz {
    my ($text) = @_;

    my ( $day, $month, $year, $name, $available_balance ) =
      MatchTemplate($text, "dostupny zustatek ke dni (\\d+)\\.(\\d+).(\\d+) v ..:.. na vasem uctu s nazvem (.{1,30}) je (.{1,12}) czk\\.");

    $available_balance = NormalizeAmount($available_balance);
    
    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        balance => { bank_available => $available_balance },
        my_account => {
			country => 'CZ',
			bank => '3030',
			number => $name	
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
