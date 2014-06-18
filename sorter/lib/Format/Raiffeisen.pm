################################################################################
#  Module: Format::Raiffeisen
################################################################################
#
#	Module for parsing emails from Raiffeisen
#
#-------------------------------------------------------------------------------
package Format::Raiffeisen;

use 5.008008;
use strict;
use warnings;
use base 'Format';
use Format qw/NormalizeCountry NormalizeText NormalizeAmount IBAN MatchTemplate/;
use Const;
use Re;
use JSON::XS;

################################################################################
#	Group: Constructor
################################################################################

#-------------------------------------------------------------------------------
# Constructor: new
#	Creates new Format::Raiffeisen object
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

        'info o karetni blokaci' => 'Raiffeisen.cz.card',
        'info o platbe'          => 'Raiffeisen.cz.payment',
        'zmena zustatku'         => 'Raiffeisen.cz.balance'
    };

    $self->{module} = {
        'Raiffeisen.cz.card'    => \&Card_cz,
        'Raiffeisen.cz.payment' => \&Payment_cz,
        'Raiffeisen.cz.balance' => \&Balance_cz,
    };

    return bless $self, $class;
}

################################################################################
#	Group: Format functions
################################################################################

sub Balance_cz {
    my ($text) = @_;

    my ( $balance, $sender, $receiver, $amount, $cur, $day, $month, $year ) =
      MatchTemplate(
        $text,
"zmena zustatku stav uctu: (.*) z: (.*) na: (.*) realizovano: (.*) $Re::currency dne: (\\d+).(\\d+).(\\d+)"
      );

    my ( $sender_account, $sender_bank ) = $sender =~ m/(.*)\/(.*)/;
    $sender_bank =~ s/ //g;

    my ( $return, $receiver_account, $receiver_bank );

    if ( $receiver eq '*' ) {    # platba kartou
        $return = {
            date => {
                day   => $day + 0,
                month => $month + 0,
                year  => $year + 0,
            },
            balance => { bank_available => NormalizeAmount($balance) },
            my_account => IBAN( $sender_bank, $sender_account ),
        };

    }
    else {
        ( $receiver_account, $receiver_bank ) = $receiver =~ m/(.*)\/(.*)/;
        $receiver_bank =~ s/ //g if $receiver_bank;

		my $amount = NormalizeAmount($amount);
		if ($cur eq 'usd') {
			$amount = $amount * 20;
		}
		if ($cur eq 'eur') {
			$amount = $amount * 25;
		}

        $return = {
            date => {
                day   => $day + 0,
                month => $month + 0,
                year  => $year + 0,
            },
            balance => { bank_available => NormalizeAmount($balance) },
            amount  => $amount,
            sender   => IBAN( $sender_bank,   $sender_account ),
            receiver => IBAN( $receiver_bank, $receiver_account ),
        };

        _DeductMyAccount(
            $return,           $sender_account, $sender_bank,
            $receiver_account, $receiver_bank
        );
    }
    return [$return];
}

sub Card_cz {
    my ($text) = @_;
    my (
        $account, $bank, $card,   $amount, $currency, $day,
        $month,   $year 
      ) = MatchTemplate($text, "z: (.*)\\/(.*) cislo karty (.*) castka: (.*) $Re::currency dne: (\\d+).(\\d+).(\\d+)");

	my ($dealer, $city, $country) = MatchTemplate($text, "obchodnik: (.*) mesto: (.*) stat: (.*)");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount => NormalizeAmount($amount),
        tags => {
            card   => $card,
            how    => Const::HOW_PLATBA_KARTOU
        },
        sender     => IBAN( '5500', $account ),
        my_account => IBAN( '5500', $account ),
    };

    if ( $city and $country and $dealer ) {
        $return->{oms} = {
            city    => $city,
            country => NormalizeCountry($country),
            dealer  => $dealer
        };
    }
    return [ $return ];
}

sub Payment_cz {
    my ($text) = @_;

    my ( $sender_account, $sender_bank, $receiver_account, $receiver_bank, $amount, $currency, $day, $month, $year  )
      = MatchTemplate($text, "z: (.*)\\/(.*) na: (.*)\\/(.*) realizovano: (.*) $Re::currency dne: (\\d+).(\\d+).(\\d+)");

    my $return = {
        date => {
            day   => $day + 0,
            month => $month + 0,
            year  => $year + 0,
        },
        amount   => NormalizeAmount($amount),
        type     => 'payment',
        sender   => IBAN( $sender_bank, $sender_account ),
        receiver => IBAN( $receiver_bank, $receiver_account ),
    };

    _DeductDir($return, $sender_account, $sender_bank, $receiver_account, $receiver_bank );
    return [ $return ];
}

sub _DeductMyAccount {
    my ($return, $sender_account, $sender_bank, $receiver_account, $receiver_bank ) = @_;
    # we can deduct some information from sender and receiver bank
    # if they differ then the one with 5500 code is my account
    if ( $sender_bank and $receiver_bank and $sender_bank ne $receiver_bank ) {
        if ( $sender_bank eq '5500' ) {
            $return->{tags}{how} = Const::HOW_BEZHOTOVOSTNI_PLATBA;
            $return->{my_account} = IBAN( $sender_bank, $sender_account ),
            $return->{amount} *= -1;
        }
        else {
            $return->{tags}{how} = Const::HOW_BEZHOTOVOSTNI_PRIJEM;
            $return->{my_account} = IBAN( $receiver_bank, $receiver_account ),;
        }
    }
    else {
        if ( !$sender_account or $sender_account eq '' ) {
            $return->{tags}{how} = Const::HOW_VKLAD_NA_POBOCCE;
            $return->{my_account} = IBAN( $receiver_bank, $receiver_account ),;
        }
        elsif ( !$receiver_account or $receiver_account eq '' ) {
            $return->{tags}{how} = Const::HOW_VYBER_NA_POBOCCE;
            $return->{my_account} = IBAN( $sender_bank, $sender_account ),;
            $return->{amount} *= -1;
        }
        else {

            # amount needs to be verified against user's list of bank accounts
            $return->{check}{amount} = JSON::XS::true;
        }
    }
}

sub _DeductDir {
    my ($return, $sender_account, $sender_bank, $receiver_account, $receiver_bank ) = @_;
    # we can deduct some information from sender and receiver bank
    # if they differ then the one with 5500 code is my account
    if ( $sender_bank ne $receiver_bank ) {
        if ( $sender_bank eq '5500' ) {
            $return->{tags}{how} = Const::HOW_BEZHOTOVOSTNI_PLATBA;
            $return->{my_account} = IBAN( $sender_bank, $sender_account );
            $return->{amount} *= -1;
        }
        else {
            $return->{tags}{how} = Const::HOW_BEZHOTOVOSTNI_PRIJEM;
            $return->{my_account} = IBAN( $receiver_bank, $receiver_account ),;
        }
    }
    else {
        if ( $sender_account eq '' ) {
            $return->{tags}{how} = Const::HOW_VKLAD_NA_POBOCCE;
            $return->{my_account} = IBAN( $receiver_bank, $receiver_account ),;
        }
        elsif ( $receiver_account eq '' ) {
            $return->{tags}{how} = Const::HOW_VYBER_NA_POBOCCE;
            $return->{my_account} = IBAN( $sender_bank, $sender_account ),;
            $return->{amount} *= -1;
        }
        else {

            # amount needs to be verified against user's list of bank accounts
            $return->{check}{amount} = JSON::XS::true;
        }
    }
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

# Seznam zastupek
#
#DN	 	 Číslo účtu - debetní strana
#CN	 	 Číslo účtu - kreditní strana
#DBC	 	 Kód banky - debetní strana
#CBC	 	 Kód banky - kreditní strana
#DVS	 	 Variabilní symbol - debetní strana
#CVS	 	 Variabilní symbol - kreditní strana
#TCS	 	 Konstantní symbol
#TSS	 	 Specifický symbol
#DAN	 	 Název debetního účtu
#CAN	 	 Název kreditního účtu
#DI	 	 Poznámka pro mne
#CI	 	 Poznámka pro příjemce
#RA	 	 Realizovaná částka
#AM	 	 Částka
#CC	 	 Měna
#RD	 	 Datum poslední realizace
#NRL	 	 Důvod nerealizace
#DBB	 	 Disponibilní zůstatek účtu před provedením operace
#DBA	 	 Disponibilní zůstatek účtu po provedení operace
#BB	 	 Účetní zůstatek účtu před provedením operace
#BA	 	 Účetní zůstatek účtu po provedení operace
#DTA	 	 Disponibilní zůstatek běžného účtu + aktuální výše kontokorentu jištěného termínovanými vklady
#DOA	 	 Disponibilní zůstatek běžného účtu + aktuální výše kontokorentu jištěného TV + disponibilní část kontokorentního úvěru (Osobní úvěrová linka, MiniKredit nebo BalanceKredit)
#PCN	 	 Číslo platební karty v chráněném formátu
#MN	 	 Obchodník
#MC	 	 Město
#MS	 	 Stát
#RDLI	 	 Informace o neuhrazené splátce Osobní úvěrové linky - neuhrazeno k
#PT	 	 Informace o neuhrazené splátce Osobní úvěrové linky - splatnost do
#DT	 	 Informace o ukončení platnosti trvalého příkazu - platnost do
#INKACC / INKBNK	 	 Potvrzení povolení inkasa - pro účet číslo / kód banky
#INKSS	 	 Potvrzení povolení inkasa - specifický symbol
#PO	 	 Datum splatnosti od
#PD	 	 Datum splatnosti do
#ST	 	 Status hromadného příkazu k úhradě


1;	
