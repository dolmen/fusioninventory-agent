package FusionInventory::Agent::Tools;

use strict;
use warnings;
use base 'Exporter';

use English qw(-no_match_vars);
use File::Basename;
use File::Spec;
use File::stat;
use Memoize;
use Sys::Hostname;

our @EXPORT = qw(
    getFileHandle
    getCanonicalManufacturer
    getInfosFromDmidecode
    getCpusFromDmidecode
    getVersionFromTaskModuleFile
    getFusionInventoryLibdir
    getFusionInventoryTaskList
    getSanitizedString
);

memoize('getCanonicalManufacturer');
memoize('getInfosFromDmidecode');

sub getFileHandle {
    my %params = @_;

    my $handle;

    SWITCH: {
        if ($params{file}) {
            if (!open $handle, '<', $params{file}) {
                $params{logger}->error(
                    "Can't open file $params{file}: $ERRNO"
                ) if $params{logger};
                return;
            }
            last SWITCH;
        }
        if ($params{command}) {
            if (!open $handle, '-|', $params{command} . " 2>/dev/null") {
                $params{logger}->error(
                    "Can't run command $params{command}: $ERRNO"
                ) if $params{logger};
                return;
            }
            last SWITCH;
        }
	if ($params{string}) {
	    
	    open $handle, "<", \$params{string} or die;
	}
        die "neither command nor file parameter given";
    }

    return $handle;
}

sub getCanonicalManufacturer {
    my ($model) = @_;

    return unless $model;

    my $manufacturer;
    if ($model =~ /(
        maxtor    |
        sony      |
        compaq    |
        ibm       |
        toshiba   |
        fujitsu   |
        lg        |
        samsung   |
        nec       |
        transcend |
        matshita  |
        hitachi   |
        pioneer
    )/xi) {
        $manufacturer = ucfirst(lc($1));
    } elsif ($model =~ /^(hp|HP|hewlett packard)/) {
        $manufacturer = "Hewlett Packard";
    } elsif ($model =~ /^(WDC|[Ww]estern)/) {
        $manufacturer = "Western Digital";
    } elsif ($model =~ /^(ST|[Ss]eagate)/) {
        $manufacturer = "Seagate";
    } elsif ($model =~ /^(HD|IC|HU)/) {
        $manufacturer = "Hitachi";
    }

    return $manufacturer;
}

sub getInfosFromDmidecode {
    my %params = (
        command => 'dmidecode',
        @_
    );

    if ($OSNAME eq 'MSWin32') {
        my @osver;
        eval 'use Win32; @osver = Win32::GetOSVersion();';
        my $isWin2003 = ($osver[4] == 2 && $osver[1] == 5 && $osver[2] == 2);
# We get some strange breakage on Win2003. For the moment
# we don't use dmidecode on this OS.
        return if $isWin2003;
    }

    my $handle = getFileHandle(%params);

    my ($info, $block, $type);

    while (my $line = <$handle>) {
        chomp $line;

        if ($line =~ /DMI type (\d+)/) {
            # start of block

            # push previous block in list
            if ($block) {
                push(@{$info->{$type}}, $block);
                undef $block;
            }

            # switch type
            $type = $1;

            next;
        }

        next unless defined $type;

        next unless $line =~ /^\s+ ([^:]+) : \s (.*\S)/x;

        next if
            $2 eq 'N/A'           ||
            $2 eq 'Not Specified' ||
            $2 eq 'Not Present'   ;

        $block->{$1} = $2;
    }
    close $handle;

    return $info;
}


sub getCpusFromDmidecode {
    my ($logger, $file) = @_;

    my $infos = getInfosFromDmidecode(logger => $logger, file => $file);

    return unless $infos->{4};

    my @cpus;
    foreach (@{$infos->{4}}) {
        next if $_->{Status} && $_->{Status} =~ /Unpopulated/i;

        # VMware
        if (
                ($_->{'Processor Manufacturer'} && ($_->{'Processor Manufacturer'} eq '000000000000'))
                &&
                ($_->{'Processor Version'} && ($_->{'Processor Version'} eq '00000000000000000000000000000000'))
           ) {
            next;
        }

        my $manufacturer = $_->{'Manufacturer'} || $_->{'Processor Manufacturer'};
        my $name = (($manufacturer =~ /Intel/ && $_->{'Family'}) || ($_->{'Version'} || $_->{'Processor Family'})) || $_->{'Processor Version'};

        my $speed;
        if ($_->{Version} && $_->{Version} =~ /([\d\.]+)GHz$/) {
            $speed = $1*1000;
        } elsif ($_->{Version} && $_->{Version} =~ /([\d\.]+)MHz$/) {
            $speed = $1;
        } elsif ($_->{'Max Speed'}) {
            if ($_->{'Max Speed'} =~ /^\s*(\d+)\s*Mhz/i) {
                $speed = $1;
            } elsif ($_->{'Max Speed'} =~ /^\s*(\d+)\s*Ghz/i) {
                $speed = $1*1000;
            }
        }


        my $externalClock;
        if ($_->{'External Clock'}) {
            if ($_->{'External Clock'} =~ /^\s*(\d+)\s*Mhz/i) {
                $externalClock = $1;
            } elsif ($_->{'External Clock'} =~ /^\s*(\d+)\s*Ghz/i) {
                $externalClock = $1*1000;
            }
        }

        push @cpus, {
            SERIAL => $_->{'Serial Number'},
            SPEED => $speed,
            ID => $_->{ID},
            MANUFACTURER => $manufacturer,
            NAME =>  $name,
            CORE => $_->{'Core Count'} || $_->{'Core Enabled'},
            THREAD => $_->{'Thread Count'},
            EXTERNAL_CLOCK => $externalClock
        }

    }

    return \@cpus;
}



sub getVersionFromTaskModuleFile {
    my ($file) = @_;

    my $version;
    open my $fh, "<$file" or return;
    foreach (<$fh>) {
        if (/^# VERSION FROM Agent.pm/) {
            if (!$FusionInventory::Agent::VERSION) {
                eval { use FusionInventory::Agent; 1 };
            }
            $version = $FusionInventory::Agent::VERSION;
            last;
        } elsif (/^our\ *\$VERSION\ *=\ *(\S+);/) {
            $version = $1;
            last;
        } elsif (/^use strict;/) {
            last;
        }
    }
    close $fh;

    if ($version) {
        $version =~ s/^'(.*)'$/$1/;
        $version =~ s/^"(.*)"$/$1/;
    }

    return $version;
}

sub getFusionInventoryLibdir {
    my ($config) = @_;

    die unless $config;

    my @dirToScan;

    my $ret = [];

    if ($config->{devlib}) {
# devlib enable, I only search for backend module in ./lib
        return ['./lib'];
    } else {
        foreach (@INC) {
# perldoc lib
# For each directory in LIST (called $dir here) the lib module also checks to see
# if a directory called $dir/$archname/auto exists. If so the $dir/$archname
# directory is assumed to be a corresponding architecture specific directory and
# is added to @INC in front of $dir. lib.pm also checks if directories called
# $dir/$version and $dir/$version/$archname exist and adds these directories to @INC.
            my $autoDir = $_.'/'.$Config::Config{archname}.'/auto/FusionInventory/Agent/Task/Inventory';

            next if ! -d || (-l && -d readlink) || /^(\.|lib)$/;
            next if ! -d $_.'/FusionInventory/Agent/Task/Inventory';
            push (@$ret, $_) if -d $_.'/FusionInventory/Agent';
            push (@$ret, $autoDir) if -d $autoDir.'/FusionInventory/Agent';
        }
    }

    return $ret;

}

sub getFusionInventoryTaskList {
    my ($config) = @_;

    my $libdir = getFusionInventoryLibdir($config);

    my @tasks;
    foreach (@$libdir) {
        push @tasks, glob($_.'/FusionInventory/Agent/Task/*.pm');
    }

    my @ret;
    foreach (@tasks) {
        next unless basename($_) =~ /(.*)\.pm/;
        my $module = $1;

        next if $module eq 'Base';

        push @ret, {
            path => $_,
            version => getVersionFromTaskModuleFile($_),
            module => $module,
        }
    }

    return \@ret;
}

sub getSanitizedString {
    my ($string) = @_;

    return unless defined $string;

    # clean control caracters
    $string =~ s/[[:cntrl:]]//g;

    # encode to utf-8 if needed
    if ($string !~ m/\A(
          [\x09\x0A\x0D\x20-\x7E]           # ASCII
        | [\xC2-\xDF][\x80-\xBF]            # non-overlong 2-byte
        | \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
        | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2} # straight 3-byte
        | \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
        | \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
        | [\xF1-\xF3][\x80-\xBF]{3}         # planes 4-15
        | \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
        )*\z/x) {
        $string = encode("UTF-8", $string);
    };

    return $string;
}

1;
__END__

=head1 NAME

FusionInventory::Agent::Tools - OS-independant generic functions

=head1 DESCRIPTION

This module provides some OS-independant generic functions.

This module is a backported from the master git branch.

=head1 FUNCTIONS

=head2 getCanonicalManufacturer($manufacturer)

Returns a normalized manufacturer value for given one.

=head2 getInfosFromDmidecode

Returns a structured view of dmidecode output. Each information block is turned
into an hashref, block with same DMI type are grouped into a list, and each
list is indexed by its DMI type into the resulting hashref.

$info = {
    0 => [
        { block }
    ],
    1 => [
        { block },
        { block },
    ],
    ...
}

=head2 getCpusFromDmidecode()

Returns a clean array with the CPU list.

=head2 getVersionFromTaskModuleFile($taskModuleFile)

Parse a task module file to get the $VERSION. The VERSION must be
a line between the begining of the file and the 'use strict;' line.
The line must by either:

 our $VERSION = 'XXXX';

In case the .pm file is from the core distribution, the follow line 
must be present instead:

 # VERSION FROM Agent.pm/

=head2 getFusionInventoryLibdir()

Return a array reference of the location of the FusionInventory/Agent library directory
on the system.

=head2 getSanitizedString($string)

Returns the input stripped from any control character, properly encoded in
UTF-8.
