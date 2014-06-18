################################################################################
#  Module: Format::CS
################################################################################
#
#	Module for parsing emails from CS
#
#-------------------------------------------------------------------------------
package Format::CS;

use 5.008008;
use strict;
use warnings;
use base 'Format';
use Format qw/NormalizeText NormalizeAmount IBAN MatchTemplate/;

################################################################################
#	Group: Constructor
################################################################################

#-------------------------------------------------------------------------------
# Constructor: new
#	Creates new Format::CS object
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

        'oznameni o zmene zustatku na uctu'               => 'CS.cz.balance',

    };
    $self->{module} = {
        'CS.cz.balance'    => \&Balance_cz,
    };
    return bless $self, $class;
}

################################################################################
#	Group: Format functions
################################################################################

sub Balance_cz {
    my ($text) = @_;

    my ( $my_account, $balance, $available_balance, $day, $month, $year ) =
      MatchTemplate($text, "cislo uctu\\* (.*) kod banky 0800 mena uctu czk -+ vyse zustatku ucetni zustatek (.*) disponibilni zustatek (.*) ke dni (\\d+)\\.(\\d+).(\\d+) e-mailova adresa");

	$my_account =~ s/ *$//g;

    my $acb = NormalizeAmount($balance);
    my $avb = NormalizeAmount($available_balance);
    my $overdraft = $avb - $acb;


    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        balance   => { bank_accounting => $acb, bank_available => $avb},
        overdraft => $overdraft,
        my_account => IBAN( "0800", $my_account ),
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
