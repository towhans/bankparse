################################################################################
#  Module: Re
################################################################################
#
#	Module with regexp patterns
#
#-------------------------------------------------------------------------------
package Re;

use strict;
use warnings;

our $currency = q/(czk|usd|eur|hrk|gbp)/;
our $amount = q/(.{1,12})/;
