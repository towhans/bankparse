################################################################################
#  Module: Futu::IBAN
################################################################################
#  
#	Czech IBAN generation
#
#-------------------------------------------------------------------------------

package Futu::IBAN;

use 5.008008;
use strict;
use warnings;
use Math::BigInt;

################################################################################
#	Group: Functions
################################################################################

sub IBAN {
    my ( $bank, $account ) = @_;
    return undef unless ( $bank and $account );
    my ( $number, $prefix ) = ( '', '' );
    if ( $account =~ /-/ ) {
        ( $prefix, $number ) = $account =~ /(.*)-(.*)/;
    }
    else {
        $number = $account;
    }
    my ( $cn, $country ) = ( 'CZ', 'CZ' );
    my $bban = $bank . _Prefix($prefix) . _Account($number);

    $cn =~ tr/A-Za-z//cd;
    $cn = uc $cn;
    $cn =~ s/([A-Z])/(ord $1)-55/eg;
    my $no     = sprintf "%s%4s00", $bban, $cn;
    my $bigint = Math::BigInt->new($no);
    my $mod    = 98 - ( $bigint % 97 );
    return $country . $mod . $bban;
}

sub _Prefix {
    my ($prefix) = @_;
    my $length = length($prefix);
    if ($length < 6) {
        my $zeroes = "000000";
        substr($zeroes, 6 - $length, $length, $prefix);
        $prefix = $zeroes;
    }
    return $prefix;
}

sub _Account {
    my ($number) = @_;
    my $length = length($number);
    if ($length < 10) {
        my $zeroes = "0000000000";
        substr($zeroes, 10 - $length, $length, $number);
        $number = $zeroes;
    }
    return $number;
}

1;
