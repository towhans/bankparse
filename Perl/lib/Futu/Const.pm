################################################################################
#  Module: Futu::Const
################################################################################
#  
#	Module holding Futu specific constants
#
#-------------------------------------------------------------------------------

package Futu::Const;

use 5.008008;
use strict;
use warnings;
use utf8;

use constant COUCH_URI         => 'http://localhost:5984';
use constant COUCH_HOST        => 'http://localhost';
use constant COUCH_PORT        => 5984;
use constant PRODUCT_DB_PREFIX => 'product-';
use constant USER_DB_PREFIX    => 'transaction-';
use constant MAIL_DB           => 'mail';
use constant NOTIFICATION_DB   => 'notification';
use constant SUBJECT_DB        => 'subject';
use constant USER_DB           => 'user';

use constant HOW_VKLAD_NA_POBOCCE     => 'vklad na pobočce';
use constant HOW_VYBER_NA_POBOCCE     => 'výběr na pobočce';
use constant HOW_BEZHOTOVOSTNI_PRIJEM => 'bezhotovostní příjem';
use constant HOW_BEZHOTOVOSTNI_PLATBA => 'bezhotovostní platba';
use constant HOW_BEZHOTOVOSTNI_PREVOD => 'bezhotovostní převod';
use constant HOW_PLATBA_KARTOU        => 'platba kartou';
use constant HOW_VYBER_Z_BANKOMATU    => 'výběr z bankomatu';

1;
