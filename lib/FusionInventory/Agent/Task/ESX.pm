package FusionInventory::Agent::Task::ESX;

our $VERSION = "1.1.2";

use Data::Dumper;
use strict;
use warnings;

use FusionInventory::Agent::HTTP::Client::Fusion;
use FusionInventory::Agent::Task::Inventory::Inventory;
use FusionInventory::Agent::Config;
use FusionInventory::VMware::SOAP;
use FusionInventory::Agent::Logger;

sub isEnabled {
    my ( $self, $response ) = @_;

    return $self->{target}->isa('FusionInventory::Agent::Target::Server');
}

sub connect {
    my ( $self, $job ) = @_;

    my $url = 'https://' . $job->{host} . '/sdk/vimService';

    my $vpbs =
      FusionInventory::VMware::SOAP->new( { url => $url, vcenter => 1 } );
    if ( !$vpbs->connect( $job->{user}, $job->{password} ) ) {
        $self->{lastError} = $vpbs->{lastError};
        return;
    }

    $self->{vpbs} = $vpbs;
}

sub createFakeDeviceid {
    my ( $self, $host ) = @_;

    my $hostname = $host->getHostname();
    my $bootTime = $host->getBootTime();
    my ( $year, $month, $day, $hour, $min, $sec );
    if ( $bootTime =~
        /(\d{4})-(\d{1,2})-(\d{1,2})T(\d{1,2}):(\d{1,2}):(\d{1,2})/ )
    {
        $year  = $1;
        $month = $2;
        $day   = $3;
        $hour  = $4;
        $min   = $5;
        $sec   = $6;
    }
    else {
        my $ty;
        my $tm;
        ( $ty, $tm, $day, $hour, $min, $sec ) =
          ( localtime(time) )[ 5, 4, 3, 2, 1, 0 ];
        $year  = $ty + 1900;
        $month = $tm + 1;
    }
    my $deviceid = sprintf "%s-%02d-%02d-%02d-%02d-%02d-%02d",
      $hostname, $year, $month, $day, $hour, $min, $sec;

    return $deviceid;
}

sub createInventory {
    my ( $self, $id ) = @_;

    die unless $self->{vpbs};

    my $vpbs = $self->{vpbs};

    my $host;
    $host = $vpbs->getHostFullInfo($id);

    my $inventory = FusionInventory::Agent::Task::Inventory::Inventory->new(
        logger => $self->{logger},
        config => $self->{config},
    );
    $inventory->{deviceid} = $self->createFakeDeviceid($host);

    $inventory->{isInitialised} = 1;
    $inventory->{h}{CONTENT}{HARDWARE}{ARCHNAME} = ['remote'];

    $inventory->setBios( $host->getBiosInfo() );

    $inventory->setHardware( $host->getHardwareInfo() );

    foreach my $cpu ( @{ $host->getCPUs() } ) {
        $inventory->addEntry( section => 'CPUS', entry => $cpu );
    }

    foreach ( @{ $host->getControllers() } ) {
        $inventory->addEntry( section => 'CONTROLLERS', entry => $_ );

        if ( $_->{PCICLASS} && ( $_->{PCICLASS} eq '300' ) ) {
            $inventory->addEntry(
                section => 'VIDEOS',
                entry   => {
                    NAME    => $_->{NAME},
                    PCISLOT => $_->{PCISLOT},
                }
            );
        }
    }

    my %ipaddr;
    foreach ( @{ $host->getNetworks() } ) {
        $ipaddr{ $_->{IPADDRESS} } = 1 if $_->{IPADDRESS};
        $inventory->addEntry( section => 'NETWORKS', entry => $_ );
    }
    $inventory->setHardware( { IPADDR => join '/', ( keys %ipaddr ) } );

    # TODO
    #    foreach (@{$host->[0]{config}{fileSystemVolume}{mountInfo}}) {
    #
    #    }

    my %volumnMapping;
    foreach ( @{ $host->getStorages() } ) {

        # TODO
        #        $volumnMapping{$entry->{canonicalName}} = $entry->{deviceName};

        $inventory->addEntry( section => 'STORAGES', entry => $_ );
    }

    foreach ( @{ $host->getDrives() } ) {
        $inventory->addEntry( section => 'DRIVES', entry => $_ );
    }

    foreach ( @{ $host->getVirtualMachines() } ) {
        $inventory->addVirtualMachine($_);
    }

    return $inventory;

}

#sub getJobs {
#    my ($self) = @_;
#
#    my $logger = $self->{logger};
#    my $network = $self->{network};
#
#    my $jsonText = $network->get ({
#        source => $self->{backendURL}.'/?a=getJobs&d=TODO',
#        timeout => 60,
#        });
#    if (!defined($jsonText)) {
#        $logger->debug("No answer from server for deployment job.");
#        return;
#    }
#
#
#    return from_json( $jsonText, { utf8  => 1 } );
#}

sub getHostIds {
    my ($self) = @_;

    return $self->{vpbs}->getHostIds();
}

sub run {
    my ( $self, %params ) = @_;

    $self->{logger}->debug("FusionInventory Inventory task $VERSION");

    $self->{client} = FusionInventory::Agent::HTTP::Client::Fusion->new(
        logger       => $self->{logger},
        user         => $params{user},
        password     => $params{password},
        proxy        => $params{proxy},
        ca_cert_file => $params{ca_cert_file},
        ca_cert_dir  => $params{ca_cert_dir},
        no_ssl_check => $params{no_ssl_check},
        debug        => $self->{debug}
    );

    my $globalRemoteConfig = $self->{client}->send(
        "url" => $self->{target}->{url},
        args  => {
            action    => "getConfig",
            machineid => $self->{deviceid},
            task      => { Deploy => $VERSION },
        }
    );

    return unless $globalRemoteConfig->{schedule};
    return unless ref( $globalRemoteConfig->{schedule} ) eq 'ARRAY';

    my $esxRemote;
    foreach my $job ( @{ $globalRemoteConfig->{schedule} } ) {
        next unless $job->{task} eq "ESX";
        $esxRemote = $job->{remote};
    }
    if ( !$esxRemote ) {
        $self->{logger}->info("ESX support disabled server side.");
        return;
    }

    my $jobs = $self->{client}->send(
        "url" => $esxRemote,
        args  => {
            action    => "getJobs",
            machineid => $self->{deviceid}
        }
    );

    return unless $jobs;
    return unless ref( $jobs->{jobs} ) eq 'ARRAY';
    $self->{logger}->info(
        "Got " . int( @{ $jobs->{jobs} } ) . " VMware host(s) to inventory." );

    #    my $esx = FusionInventory::Agent::Task::ESX->new({
    #            config => $config
    #            });

    my $ocsClient = FusionInventory::Agent::HTTP::Client::OCS->new(
        logger       => $self->{logger},
        user         => $params{user},
        password     => $params{password},
        proxy        => $params{proxy},
        ca_cert_file => $params{ca_cert_file},
        ca_cert_dir  => $params{ca_cert_dir},
        no_ssl_check => $params{no_ssl_check},
    );

    foreach my $job ( @{ $jobs->{jobs} } ) {

        if ( !$self->connect($job) ) {
            $self->{client}->send(
                "url" => $esxRemote,
                args  => {
                    machineid => $self->{deviceid},
                    part      => 'login',
                    uuid      => $job->{uuid},
                    msg       => $self->{lastError},
                    code      => 'ko'
                }
            );

            next;
        }

        my $hostIds = $self->getHostIds();
        foreach my $hostId (@$hostIds) {
            my $inventory = $self->createInventory($hostId);

            my $message = FusionInventory::Agent::XML::Query::Inventory->new(
                deviceid => $self->{deviceid},
                content  => $inventory->getContent()
            );

            my $response = $ocsClient->send(
                url     => $self->{target}->getUrl(),
                message => $message
            );
        }
        $self->{client}->send(
            "url" => $esxRemote,
            args  => {
                machineid => $self->{deviceid},
                uuid      => $job->{uuid},
                code      => 'ok'
            }
        );

    }

    return $self;
}

# Only used by the command line tool
sub new {
    my ( undef, $params ) = @_;

    my $logger = FusionInventory::Agent::Logger->new();

    my $self = { config => $params->{config}, logger => $logger };
    bless $self;
}

1;
