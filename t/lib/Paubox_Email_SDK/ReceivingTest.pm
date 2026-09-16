package Paubox_Email_SDK::ReceivingTest;
use strict;
use warnings;

use Paubox_Email_SDK;
use Paubox_Email_SDK::ApiHelper;

use JSON;
use Test::More;
use base qw(Test::Class);

sub methodsExist_Offline: Tests(12) {
    print "Executing tests for methodsExist_Offline:\n";

    ok(Paubox_Email_SDK->can('listReceivingDomains'), 'listReceivingDomains exists');
    ok(Paubox_Email_SDK->can('createReceivingDomain'), 'createReceivingDomain exists');
    ok(Paubox_Email_SDK->can('getReceivingDomain'), 'getReceivingDomain exists');
    ok(Paubox_Email_SDK->can('deleteReceivingDomain'), 'deleteReceivingDomain exists');
    ok(Paubox_Email_SDK->can('listMailboxes'), 'listMailboxes exists');
    ok(Paubox_Email_SDK->can('createMailbox'), 'createMailbox exists');
    ok(Paubox_Email_SDK->can('getMailbox'), 'getMailbox exists');
    ok(Paubox_Email_SDK->can('deleteMailbox'), 'deleteMailbox exists');
    ok(Paubox_Email_SDK->can('listReceivedEmails'), 'listReceivedEmails exists');
    ok(Paubox_Email_SDK->can('getReceivedEmail'), 'getReceivedEmail exists');
    ok(Paubox_Email_SDK->can('getReceivedEmailAttachment'), 'getReceivedEmailAttachment exists');
    ok(Paubox_Email_SDK::ApiHelper->can('callToAPIByDelete'), 'ApiHelper callToAPIByDelete exists');
}

sub exportList_Offline: Tests(11) {
    print "Executing tests for exportList_Offline:\n";

    my @expected = qw(
        listReceivingDomains
        createReceivingDomain
        getReceivingDomain
        deleteReceivingDomain
        listMailboxes
        createMailbox
        getMailbox
        deleteMailbox
        listReceivedEmails
        getReceivedEmail
        getReceivedEmailAttachment
    );

    foreach my $method (@expected) {
        ok(
            (grep { $_ eq $method } @Paubox_Email_SDK::EXPORT_OK),
            "$method is in \@EXPORT_OK"
        );
    }
}

sub apiHelperDeleteExport_Offline: Tests(1) {
    print "Executing tests for apiHelperDeleteExport_Offline:\n";

    ok(
        (grep { $_ eq 'callToAPIByDelete' } @Paubox_Email_SDK::ApiHelper::EXPORT_OK),
        'callToAPIByDelete is in ApiHelper \@EXPORT_OK'
    );
}

sub apiHelperDeletePattern_Offline: Tests(1) {
    print "Executing tests for apiHelperDeletePattern_Offline:\n";

    require File::Spec;
    my $module = File::Spec->catfile('lib','Paubox_Email_SDK','ApiHelper.pm');
    open my $fh, '<', $module or die "cannot open $module: $!";
    local $/;
    my $src = <$fh>;
    close $fh;
    like($src, qr/\$client\s*->\s*DELETE\(/,
        'ApiHelper callToAPIByDelete uses REST::Client DELETE');
}

sub listReceivingDomains_Live: Tests(1) {
    print "Executing tests for listReceivingDomains_Live:\n";

    SKIP: {
        skip "config.cfg not present; skipping live receiving tests", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        my $response = eval { $service -> listReceivingDomains() };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        my $apiResponsePERL = from_json($response);
        if ( ref($apiResponsePERL) eq 'ARRAY' || ref($apiResponsePERL) eq 'HASH' ) {
            is('Success', 'Success', 'Test passed');
        } else {
            is('Failure', 'Success', 'Test failed: unexpected response type');
        }
    }
}

sub listReceivedEmails_Live: Tests(1) {
    print "Executing tests for listReceivedEmails_Live:\n";

    SKIP: {
        skip "config.cfg not present; skipping live receiving tests", 1
            unless -e 'config.cfg';

        my $service = Paubox_Email_SDK -> new();
        my $response = eval { $service -> listReceivedEmails({ 'limit' => 1 }) };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        my $apiResponsePERL = from_json($response);
        if ( ref($apiResponsePERL) eq 'ARRAY' || ref($apiResponsePERL) eq 'HASH' ) {
            is('Success', 'Success', 'Test passed');
        } else {
            is('Failure', 'Success', 'Test failed: unexpected response type');
        }
    }
}

1;
