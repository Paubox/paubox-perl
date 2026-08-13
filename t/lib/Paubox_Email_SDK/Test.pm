package Paubox_Email_SDK::Test;
use strict;
use warnings;

use Paubox_Email_SDK;
use Paubox_Email_SDK::Message;

use JSON;
use Test::More;
use base qw(Test::Class);
use Text::CSV qw(csv);

# The Email API tests are live tests: they need config.cfg (API_KEY) and
# network access. Without config.cfg the constructor dies, so the whole
# class is skipped to keep credential-less runs (e.g. CI) green.
sub SKIP_CLASS {
    return 0 if -e 'config.cfg';
    return "config.cfg not present; skipping live Email API tests";
}

sub getEmailDisposition_Success: Tests(2) {
    print "Executing tests for getEmailDisposition_Success:\n";
    my $sourceTrackingIdSuccessArray = ["1aed91d1-f7ce-4c3d-8df2-85ecd225a7fc","ce1e2143-474d-43ba-b829-17a26b8005e5"];
    my $service = Paubox_Email_SDK -> new();
    foreach my $sourceTrackingId(@{
        $sourceTrackingIdSuccessArray
    }) {

        my $response = $service -> getEmailDisposition($sourceTrackingId);

        # Converting JSON api response to perl
        my $apiResponsePERL = from_json($response);       
        if (
            ref($apiResponsePERL -> {'data'}) eq 'HASH' 
            && defined $apiResponsePERL -> {'sourceTrackingId'}
        ) {
            is('Success', 'Success', 'Test passed')
        } else {           
            is('Failure', 'Success', 'Test failed')
        }
    }
}

sub getEmailDisposition_Failure: Tests(2) {
    print "Executing tests for getEmailDisposition_Failure:\n";
    my $sourceTrackingIdFailureArray = ["4a6d68f7-a528-4691-b4d1-82a822ba59be", "4a6d68f7-a528-4691-bsdc1-82a822ba59be"];

    foreach my $sourceTrackingId(@{
        $sourceTrackingIdFailureArray
    }) {

        my $service = Paubox_Email_SDK -> new();
        my $response = $service -> getEmailDisposition($sourceTrackingId);

        # Converting JSON api response to perl
        my $apiResponsePERL = from_json($response);

        if (
            ref($apiResponsePERL -> {'data'}) eq 'HASH' 
            && defined $apiResponsePERL -> {'sourceTrackingId'}
        ) {
            is('Failure', 'Failure', 'Test failed')
        } else {
            is('Success', 'Success', 'Test passed')
        }
    }
}

sub sendMessage_Success: Tests {
    print "Executing tests for sendMessage_Success:\n";
    my $sendMessageSuccessTestData = getSendMessage_TestData(1);
    my $service = Paubox_Email_SDK -> new();
    foreach my $testMsgObj(@{
        $sendMessageSuccessTestData
    }) {

        my $response = $service -> sendMessage($testMsgObj);

        # Converting JSON api response to perl
        my $apiResponsePERL = from_json($response);
        if (
            defined $apiResponsePERL -> {'data'} 
            && defined $apiResponsePERL -> {'sourceTrackingId'}
        ) {
            is('Success', 'Success', 'Test passed')
        } else {            
            is('Failure', 'Success', 'Test failed')
        }
    }
}

sub sendMessage_Failure: Tests {
    print "Executing tests for sendMessage_Failure:\n";
    my $sendMessageSuccessTestData = getSendMessage_TestData(0);
    my $service = Paubox_Email_SDK -> new();
    foreach my $testMsgObj(@{
        $sendMessageSuccessTestData
    }) {

        my $response = $service -> sendMessage($testMsgObj);

        # Converting JSON api response to perl
        my $apiResponsePERL = from_json($response);
        if (
            defined $apiResponsePERL -> {'errors'}
        ) {
            is('Success', 'Success', 'Test passed')
        } else {
            is('Failure', 'Success', 'Test failed')
        }
    }
}

sub getSendMessage_TestData() {

    my($forSuccess) = @_;
    my $csvData = csv( in => "t/SendMessage_TestData.csv", headers => "skip"); # as array of array
    my $arrMessages = [];

    foreach my $testMsgData(@{
        $csvData
    }) {

            my $msgObj;
            if ($forSuccess) {
                if ($testMsgData -> [15] ne "SUCCESS") {
                    next;
                }
            } else {
                if ($testMsgData -> [15] ne "ERROR") {
                    next;
                }
            }

            if ($testMsgData -> [9] > 0) # if testdata file has attachments 
            {
                my $testAttachments = '[{
                "fileName": "'. $testMsgData->[10]
                .
                '", "contentType":"'.$testMsgData -> [11]
                    .
                '", "content":"'.$testMsgData -> [12].
                '"}
                ]
                ';   

                my @decodedJSONTestAttachments = @ {
                    decode_json($testAttachments)
                };

                $msgObj = new Paubox_Email_SDK::Message(
                    'from' => $testMsgData -> [4],
                    'replyTo' => $testMsgData -> [5],
                    'to' => [$testMsgData -> [1]],
                    'cc' => [$testMsgData -> [14]],
                    'bcc' => [$testMsgData -> [2]],
                    'subject' => $testMsgData -> [3],
                    'allowNonTLS' => $testMsgData -> [6] eq "TRUE" ? 1 : 0,
                    'forceSecureNotification' => $testMsgData -> [13],
                    'text_content' => $testMsgData -> [7],
                    'html_content' => $testMsgData -> [8],
                    'attachments' => [@decodedJSONTestAttachments]
                );
            } 
            else # creating msg object without attachments 
            {
                $msgObj = new Paubox_Email_SDK::Message(
                    'from' => $testMsgData -> [4],
                    'replyTo' => $testMsgData -> [5],
                    'to' => [$testMsgData -> [1]],
                    'cc' => [$testMsgData -> [14]],
                    'bcc' => [$testMsgData -> [2]],
                    'subject' => $testMsgData -> [3],
                    'allowNonTLS' => $testMsgData -> [6] eq "TRUE" ? 1 : 0,
                    'forceSecureNotification' => $testMsgData -> [13],
                    'text_content' => $testMsgData -> [7],
                    'html_content' => $testMsgData -> [8]
                );
            }

            push(@{ $arrMessages }, $msgObj);

        }

    return $arrMessages;
}

1;