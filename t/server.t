#!/usr/bin/perl -w

package My::WebServer;
use base qw/Test::HTTP::Server::Simple HTTP::Server::Simple::CGI/;
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Digest::SHA;
use File::Basename;
use FindBin;
use File::Path qw(make_path remove_tree);
use Archive::Tar;
use Compress::Zlib;
use English '-no_match_vars';

my $tmpDirServer = $FindBin::Bin . "/../tmp/deploy-test/server";

remove_tree($tmpDirServer) if -d $tmpDirServer;
make_path($tmpDirServer);

my %files;
my %filePathByFilename;

# Generate a tarball
my $tar = Archive::Tar->new;
$tar->add_files(
    $FindBin::Bin . "/../Makefile.PL",
    $FindBin::Bin . "/../META.yml",
    $FindBin::Bin . "/../lib/FusionInventory/Agent/Task/Deploy.pm"
);
$tar->add_data( 'toto',   'bababa' );
$tar->add_data( 'titit',  'bibibi' );
$tar->add_data( 'tututu', 'bububu' );
open TMP, ">" . $tmpDirServer . "/tmp" or die;
foreach ( 1 .. 1024 ) {
    print TMP "aefsfcoijsfiorjfdrfoijdrfrf";
}
close TMP;
$tar->add_files( $tmpDirServer . "/tmp" );

# Add the tarball in the files list
my $sha = Digest::SHA->new('512');
$tar->write( $tmpDirServer . '/files.tar' );
$sha->addfile( $tmpDirServer . '/files.tar', 'b' );
my $sha512 = $sha->hexdigest();
$files{ $sha512 } = [
    {
        path    => $tmpDirServer . '/files.tar',
        extract => 0,
        sha512  => $sha512
    }
];
$filePathByFilename{'files.tar'} = $tmpDirServer . '/files.tar';

# Generate a multi-part distribution from the tarball
my @parts;
open FILE, "<" . $tmpDirServer . '/files.tar' or die;
binmode(FILE);
my $b;
my $cpt = 0;
while ( read( FILE, $b, 768 ) ) {
    my $file = $tmpDirServer . '/files.tar.part-' . $cpt++ . '.gz';
    my $gz = gzopen( $file, 'wb' );
    $gz->gzwrite($b);
    $gz->gzclose();
    my $sha = Digest::SHA->new('512');
    $sha->addfile( $file, 'b' );
    my $sha512 = $sha->hexdigest;
    push @parts, { path => $file, extract => 1, sha512 => $sha512 };
    $filePathByFilename{ basename($file) } = $file;
}
close FILE;
$sha->reset('512');
$sha->addfile( $tmpDirServer . '/files.tar', 'b' );
$files{ $sha->hexdigest } = \@parts;

my %actions = (
    getConfig => sub {

        my $ret = {
            'requireSSLClientCert' => 0,
            'httpd'                => {
                'ip'    => '0.0.0.0',
                'trust' => ['127.0.0.1'],
                'port'  => 62354
            },
            'configValidityPeriod' => 600,
            'schedule'             => [
                {
                    'periodicity'  => 3600,
                    'delayStartup' => 600,
                    'task'         => 'Inventory',
                    'remote' => 'https://server1/plugins/fusioninventory/b'
                },
                {
                    'periodicity' => 600,
                    'task'        => 'Deploy1',
                    'remote'      => 'http://localhost:8080/deploy1'
                },
                {
                    'periodicity' => 600,
                    'task'        => 'Deploy2',
                    'remote'      => 'http://localhost:8080/deploy2'
                },
                {
                    'periodicity' => 600,
                    'task'        => 'Deploy3',
                    'remote'      => 'http://localhost:8080/deploy3'
                },
                {
                    'periodicity' => 600,
                    'task'        => 'Deploy4',
                    'remote'      => 'http://localhost:8080/deploy4'
                },
                {
                    'periodicity' => 600,
                    'task'        => 'Deploy5',
                    'remote'      => 'http://localhost:8080/deploy5'
                },

                {
                    'periodicity' => 700,
                    'task'        => 'ESX',
                    'remote'      => 'https://server1/plugins/fusioninventory/b'
                },
                {
                    'periodicity' => 5600,
                    'task'        => 'Inventory',
                    'remote'      => 'https://server1/plugins/fusinvinventory/b'
                },
                {
                    'periodicity' => 5600,
                    'task'        => 'FooBarAMQPService',
                    'remote'      => 'amqp://server1/plugins/fusinvinventory/b'
                }
            ]
        };
        return ( encode_json($ret), 200 );

    },
    getJobs => sub {
        my ($cgi, $testname) = @_;

        my $ret = {
            'jobs' => [
                {
                    'checks' => [
                        {
                            type => "fileExists",
                            path => $tmpDirServer . '/files.tar'
                        },

                    ],
                    'actions'         => [],
                    'maxValidityDate' => 12334546,
                    'associatedFiles' => [],
                    'uuid' => '0fae2958-24d5-0651-c49c-d1fec1766af650',
                    'associatedFiles' => []
                }
            ],
            associatedFiles => {}
        };


        if ($testname eq 'deploy1') {
        my $cpt = 0;
        foreach my $sha512 ( keys %files ) {
            push @{ $ret->{jobs}[0]{associatedFiles} }, $sha512;

            my $associatedFile = {
                'uncompress' => 0,
                'mirrors' => ['http://localhost:8080/?action=getFiles&name='],
                'multiparts'             => [],
                'p2p'                    => 0,
                'p2p-retention-duration' => 0,
                'name'                   => 'file-' . $cpt++ . '.test'
            };
            foreach ( @{ $files{$sha512} } ) {
                push @{ $associatedFile->{multiparts} },
                  { basename( $_->{path} ) => $_->{sha512} };
            }
            $ret->{associatedFiles}{$sha512} = $associatedFile;
        }
        } elsif ($testname eq 'deploy2') {
            return ("", 500); # Invalid answer

    }
    elsif ( $testname eq 'deploy3' ) {
          $ret->{jobs}[0]{actions}[0] = {
              cmd => {
                  "retChecks" => [
                      {
                          "type"   => "okCode",
                          "values" => [0]
                      }
                  ],
                  exec => "$EXECUTABLE_NAME -V"
              }
          };
        }
    elsif ( $testname eq 'deploy4' ) {
          $ret->{jobs}[0]{actions}[0] = {
              cmd => {
                  "retChecks" => [
                      {
                          "type"   => "errorCode",
                          "values" => [0]
                      }
                  ],
                  exec => "$EXECUTABLE_NAME -V"
              }
          };
        }
    elsif ( $testname eq 'deploy5' ) {
          $ret->{jobs}[0]{actions}[0] = {
              cmd => {
                  "retChecks" => [
                      {
                          "type"   => "okPattern",
                          "values" => [ "foobar", "perl" ]
                      }
                  ],
                  exec => "$EXECUTABLE_NAME -V"
              }
          };
        }
    elsif ( $testname eq 'deploy6' ) {
          $ret->{jobs}[0]{actions}[0] = {
              cmd => {
                  "retChecks" => [
                      {
                          "type"   => "errorPattern",
                          "values" => [ "foobar", "perl" ]
                      }
                  ],
                  exec => "$EXECUTABLE_NAME -V"
              }
          };
        }
    elsif ( $testname eq 'deploy7' ) {
          $ret->{jobs}[0]{actions}[0] = {
              cmd => {
                  checks => [
                  {
                      path => $FindBin::Bin . "/../lib/FusionInventory/Agent/Task/Deploy.pm",
                      type => "fileExists",
                      return => "ignore" 
                  }
                  ],
                  "retChecks" => [
                      {
                          "type"   => "okPattern",
                          "values" => [ "perl" ]
                      }
                  ],
                  exec => "$EXECUTABLE_NAME -V"
              }
          };
        }
    elsif ( $testname eq 'deploy8' ) {
          $ret->{jobs}[0]{actions}[0] = {
              cmd => {
                  checks => [
                  {
                      path => $FindBin::Bin . "/../lib/FusionInventory/Agent/Task/Deploy.pm-missing",
                      type => "fileExists",
                      return => "ignore" 
                  }
                  ],
                  copy => [
                      $FindBin::Bin . "/../lib/FusionInventory/Agent/Task/Deploy.pm",
                      $FindBin::Bin . "/../lib/FusionInventory/Agent/Task/Deploy.pm-shouldnotbethere"
                      ]
              }
          };
        }
    elsif ( $testname eq 'deploy8' ) {
          $ret->{jobs}[0]{actions}[0] = {
              cmd => {
                  checks => [
                  {
                      path => $FindBin::Bin . "/../lib/FusionInventory/Agent/Task/Deploy.pm-missing",
                      type => "fileExists",
                      return => "ignore" 
                  }
                  ],
                  "retChecks" => [
                      {
                          "type"   => "okPattern",
                          "values" => [ "perl" ]
                      }
                  ],
                  exec => "$EXECUTABLE_NAME -V"
              }
          };
        }


        return ( encode_json($ret), 200 );
    },
    setStatus => sub {
        return ( encode_json( {} ), 200 );
    },
    setLog => sub {
        return ( encode_json( {} ), 200 );
    },
    getFiles => sub {
        my ($cgi) = @_;
        my $name = $cgi->param("name");

        #        print STDERR Dumper(\%filePathByFilename);
        if ( !-f $filePathByFilename{$name} ) {

            #            print STDERR "$sha512 → 404\n";
            return ( encode_json( {} ), 404 );
        }
        else {
            my $content;
            open TMP, "<" . $filePathByFilename{$name} or die;
            binmode(TMP);
            $content .= $_ foreach (<TMP>);
            close TMP;
            return ( $content, 200 );
        }
    },

);

sub handle_request {
    my $self = shift;
    my $cgi  = shift;

    my $testname = $cgi->path_info();
    $testname =~ s#\/##;

    if (   !$actions{ $cgi->param("action") }
        || !defined( $actions{ $cgi->param("action") } ) )
    {
        print "Invalid action\n";
        return;
    }
    my ( $content, $code ) = &{ $actions{ $cgi->param("action") } }($cgi, $testname);
    print "HTTP/1.0 $code OK\r\n";
    print "Content-Type: application/json\r\nContent-Length: ";
    print length($content), "\r\n\r\n", $content;
}

package main;

use strict;
use warnings;

use FusionInventory::Agent::Target::Server;
use FusionInventory::Agent::Task::Deploy;
use FindBin;
use File::Path qw(make_path remove_tree);
use Test::More tests => 16;
use Data::Dumper;

my $tmpDirClient = $FindBin::Bin . "/../tmp/deploy-test/client";
remove_tree($tmpDirClient) if -d $tmpDirClient;
make_path($tmpDirClient);

my $port = 8080;
my $s    = My::WebServer->new();
$s->setup( port => $port );

my $url_root = $s->started_ok("start up my web server");

my $target = FusionInventory::Agent::Target::Server->new(
    url        => "http://localhost:$port/",
    basevardir => $tmpDirClient,
);
ok( $target, "loading Target object" );
my $deploy = FusionInventory::Agent::Task::Deploy->new(
    deviceid => "fakeid",
    target   => $target,
    debug      => 1
);
ok( $deploy, "loading Task object" );

ok( $deploy->processRemote('http://localhost:8080/deploy1'), "processRemote()" );

my $ret=[
          {
            'action' => 'getJobs',
            'machineid' => 'fakeid'
          },
          {
            'currentStep' => 'checking',
            'part' => 'job',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '0fae2958-24d5-0651-c49c-d1fec1766af650'
          },
          {
            'currentStep' => 'downloading',
            'part' => 'job',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '0fae2958-24d5-0651-c49c-d1fec1766af650'
          },
          {
            'currentStep' => 'downloading',
            'part' => 'file',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '72fd779db80c7afbe8d9e776faa684808535c6cf97f6c7c4fc1d421e9da6003f848c0c88996a91d5b235829b3ee7a2df67e445fd45c18570ff85c2a111f5c1a4'
          },
          {
            'status' => 'ok',
            'currentStep' => 'downloading',
            'part' => 'file',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '72fd779db80c7afbe8d9e776faa684808535c6cf97f6c7c4fc1d421e9da6003f848c0c88996a91d5b235829b3ee7a2df67e445fd45c18570ff85c2a111f5c1a4'
          },
          {
            'status' => 'ok',
            'currentStep' => 'downloading',
            'part' => 'job',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '0fae2958-24d5-0651-c49c-d1fec1766af650'
          },
          {
            'currentStep' => 'processing',
            'part' => 'job',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '0fae2958-24d5-0651-c49c-d1fec1766af650'
          },
          {
            'status' => 'ok',
            'currentStep' => 'processing',
            'part' => 'job',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '0fae2958-24d5-0651-c49c-d1fec1766af650'
          },
          {
            'status' => 'ok',
            'part' => 'job',
            'action' => 'setStatus',
            'machineid' => 'DEVICEID',
            'uuid' => '0fae2958-24d5-0651-c49c-d1fec1766af650'
          }
        ];

foreach (0..@$ret) {
# We ignore uuid since we don't know it.
    $ret->[$_]{uuid} = $deploy->{fusionClient}{msgStack}[$_]{uuid} = 'ignore';
    is_deeply($ret->[$_], $deploy->{fusionClient}{msgStack}[$_]);
}

$deploy->{fusionClient}{msgStack} = [];

# Invalid getJobs answer
ok(!$deploy->processRemote('http://localhost:8080/deploy2'), "processRemote()" );
$ret = [
          {
            'action' => 'getJobs',
            'machineid' => 'fakeid'
          }
];
is_deeply($ret, $deploy->{fusionClient}{msgStack});
$deploy->{fusionClient}{msgStack} = [];

my $last;
# Run perl and see 0 as success code and so
# should flag the deployment as OK 
$deploy->processRemote('http://localhost:8080/deploy3');
$last = pop @{$deploy->{fusionClient}{msgStack}};
ok(
        ($last->{status} eq "ok")
        &&
        ($last->{part} eq "job"), "Cmd okCode");
$deploy->{fusionClient}{msgStack} = [];

# Run perl and see 0 as an error code and so
# should flag the deployment as KO
$deploy->processRemote('http://localhost:8080/deploy4');
$last = pop @{$deploy->{fusionClient}{msgStack}};
ok(($last->{status} eq "ko") && ($last->{actionnum} == 0), "Cmd errorCode");
$deploy->{fusionClient}{msgStack} = [];

# Run perl and see 0 as an error code and so
# should flag the deployment as KO
$deploy->processRemote('http://localhost:8080/deploy5');
$last = pop @{$deploy->{fusionClient}{msgStack}};
ok($last->{status} eq "ok", "Cmd okPattern");
$deploy->{fusionClient}{msgStack} = [];

# Run perl and see 0 as an error code and so
# should flag the deployment as KO
$deploy->processRemote('http://localhost:8080/deploy6');
$last = pop @{$deploy->{fusionClient}{msgStack}};
ok(($last->{status} eq "ko") && ($last->{actionnum} == 0), "Cmd errorPatern");
$deploy->{fusionClient}{msgStack} = [];

# Action with check that must return ignore and so get
# the action to be ignored
$deploy->processRemote('http://localhost:8080/deploy7');
$last = pop @{$deploy->{fusionClient}{msgStack}};
ok($last->{status} eq "ok", "false ignore + action");
$deploy->{fusionClient}{msgStack} = [];

# Action with check that must return ignore and so get
# the action to be ignored
$deploy->processRemote('http://localhost:8080/deploy8');
$last = pop @{$deploy->{fusionClient}{msgStack}};
ok($last->{status} eq "ok", "true ignore + action");
$last = pop @{$deploy->{fusionClient}{msgStack}};
ok($last->{status} eq "ignore", "action has been ignored");
ok(!-f $FindBin::Bin . "/../lib/FusionInventory/Agent/Task/Deploy.pm-shouldnotbethere", "action really ignored");
$deploy->{fusionClient}{msgStack} = [];

#ok( $deploy->processRemote('http://localhost:8080/deploy3'), "processRemote()" );
#ok( $deploy->processRemote('http://localhost:8080/deploy4'), "processRemote()" );
#ok( $deploy->processRemote('http://localhost:8080/deploy5'), "processRemote()" );

ok ($deploy->run(), "running the task");