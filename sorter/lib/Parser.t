#!/usr/bin/env perl
use strict;
use warnings;
use lib qw(sorter/lib);
use lib qw(common/lib);

Parser::Test->runtests;

##############################################################################

package Parser::Test;

use base qw(Test::Class);
use Test::More;
use Data::Dumper;
use Test::Exception;
use Maildir::Split;
use Parser;
use FindBin qw($Bin);
use File::Tempdir;

#----------------------------------------------------------------------

sub __1_Basic : Test(1) {

	my $dir = File::Tempdir->new();
	my $source = $dir->name;

	`cp -r $Bin/TestParser/Maildir $source`;

	my $udir = File::Tempdir->new();
	my $userdir = $udir->name;
	Maildir::Split::Split("$source/Maildir", $userdir, undef);

	Parser::ParseMaildirs($userdir, undef, 'new');
	my $tree = `tree -a $userdir`;
	$tree =~ s|/tmp/.*||;
	is( $tree, '
└── yirie.sedlahczech
    ├── cur
    ├── new
    ├── .parsed
    │   ├── 1284362421.00003.iMac.local
    │   ├── 1284362422.00002.iMac.local
    │   └── 1284462572.00001.iMac.local
    └── tmp

5 directories, 3 files
'
	,'ParseMailDirs');
}

#----------------------------------------------------------------------

sub __1_Url : Test(1) {

	my $dir = File::Tempdir->new();
	my $source = $dir->name;

	`cp -r $Bin/TestParser/Maildir $source`;

	my $udir = File::Tempdir->new();
	my $userdir = $udir->name;
	Maildir::Split::Split("$source/Maildir", $userdir, undef);

	Parser::ParseMaildirs($userdir, 'http://mail.walletapp.net/neco/nekam', 'new');
	my $tree = `tree -a -f -i $userdir | sort`;
	$tree =~ s|/tmp/[^/]*||g;
	is( $tree, '
5 directories, 3 files
/yirie.sedlahczech
/yirie.sedlahczech/cur
/yirie.sedlahczech/.errorposting
/yirie.sedlahczech/.errorposting/1284362421.00003.iMac.local
/yirie.sedlahczech/.errorposting/1284362422.00002.iMac.local
/yirie.sedlahczech/.errorposting/1284462572.00001.iMac.local
/yirie.sedlahczech/new
/yirie.sedlahczech/tmp
'
	,'ParseMailDirs');
}

#----------------------------------------------------------------------

sub __1_Watch : Test(1) {

	my $dir = File::Tempdir->new();
	my $source = $dir->name;

	`cp -r $Bin/TestParser/Maildir $source`;

	my $udir = File::Tempdir->new();
	my $userdir = $udir->name;
	Maildir::Split::Split("$source/Maildir", $userdir, undef);

	Parser::Watch($userdir, undef, 10, 20);
	my $tree = `tree -a $userdir`;
	$tree =~ s|/tmp/.*||;
	is( $tree, '
└── yirie.sedlahczech
    ├── cur
    ├── new
    ├── .parsed
    │   ├── 1284362421.00003.iMac.local
    │   ├── 1284362422.00002.iMac.local
    │   └── 1284462572.00001.iMac.local
    └── tmp

5 directories, 3 files
'
	,'ParseMailDirs');
}

##############################################################################

__END__

