#!/usr/bin/perl

use strict;
use lib 't/lib';

use FusionInventory::Test::Hardware;

my %tests = (
    'ddwrt/unknown.1.walk' => [
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'nasbcs',
            SNMPHOSTNAME => 'nasbcs',
            MAC          => '00:14:FD:14:35:2C',
        },
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'nasbcs',
            SNMPHOSTNAME => 'nasbcs',
            MAC          => '00:14:FD:14:35:2C',
        },
        {
            INFO => {
                ID           => undef,
                MANUFACTURER => 'Ddwrt',
                TYPE         => undef
            },
            PORTS => {
                PORT => []
            }
        }
    ],
    'ddwrt/unknown.2.walk' => [
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'Linux nasbcs 2.6.33N7700 #5 SMP Wed Jan 26 12:14:33 CST 2011 i686',
            SNMPHOSTNAME => undef,
            MAC          => undef,
        },
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'Linux nasbcs 2.6.33N7700 #5 SMP Wed Jan 26 12:14:33 CST 2011 i686',
            SNMPHOSTNAME => undef,
            MAC          => undef,
        },
        {
            INFO => {
                ID           => undef,
                MANUFACTURER => 'Ddwrt',
                TYPE         => undef
            },
            PORTS => {
                PORT => []
            }
        }
    ],
    'ddwrt/unknown.3.walk' => [
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'aleph.bu.dauphine.fr',
            SNMPHOSTNAME => 'aleph.bu.dauphine.fr',
            MAC          => '00:26:B9:71:58:1E',
        },
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'aleph.bu.dauphine.fr',
            SNMPHOSTNAME => 'aleph.bu.dauphine.fr',
            MAC          => '00:26:B9:71:58:1E',
        },
        {
            INFO => {
                ID           => undef,
                MANUFACTURER => 'Ddwrt',
                TYPE         => undef
            },
            PORTS => {
                PORT => []
            }
        }
    ],
    'ddwrt/unknown.4.walk' => [
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'primotest.bu.dauphine.fr',
            SNMPHOSTNAME => 'primotest.bu.dauphine.fr',
            MAC          => '00:26:B9:7E:13:08'
        },
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'primotest.bu.dauphine.fr',
            SNMPHOSTNAME => 'primotest.bu.dauphine.fr',
            MAC          => '00:26:B9:7E:13:08'
        },
        {
            INFO => {
                ID           => undef,
                MANUFACTURER => 'Ddwrt',
                TYPE         => undef
            },
            PORTS => {
                PORT => []
            }
        }
    ],
    'ddwrt/unknown.5.walk' => [
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'primo.bu.dauphine.fr',
            SNMPHOSTNAME => 'primo.bu.dauphine.fr',
            MAC          => '00:26:B9:7D:E6:A3'
        },
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'primo.bu.dauphine.fr',
            SNMPHOSTNAME => 'primo.bu.dauphine.fr',
            MAC          => '00:26:B9:7D:E6:A3'
        },
        {
            INFO => {
                ID           => undef,
                MANUFACTURER => 'Ddwrt',
                TYPE         => undef
            },
            PORTS => {
                PORT => []
            }
        }
    ],
    'ddwrt/unknown.6.walk' => [
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'metalib.bu.dauphine.fr',
            SNMPHOSTNAME => 'metalib.bu.dauphine.fr',
            MAC          => '00:26:B9:7E:AD:BB'
        },
        {
            MANUFACTURER => 'Ddwrt',
            TYPE         => undef,
            DESCRIPTION  => 'metalib.bu.dauphine.fr',
            SNMPHOSTNAME => 'metalib.bu.dauphine.fr',
            MAC          => '00:26:B9:7E:AD:BB'
        },
        {
            INFO => {
                ID           => undef,
                MANUFACTURER => 'Ddwrt',
                TYPE         => undef
            },
            PORTS => {
                PORT => []
            }
        }
    ],
);

runInventoryTests(%tests);