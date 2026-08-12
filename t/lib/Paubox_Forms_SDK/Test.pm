package Paubox_Forms_SDK::Test;
use strict;
use warnings;

use Paubox_Forms_SDK;

use JSON;
use Test::More;
use base qw(Test::Class);

# Replace with a real form UUID from your Paubox account to run live tests.
my $VALID_FORM_UUID   = "your-valid-form-uuid-here";
my $INVALID_FORM_UUID = "00000000-0000-0000-0000-000000000000";

# ---------------------------------------------------------------------------
# Placeholders for the authenticated (scoped-API-key) live tests.
# Replace them with real values to run the live tests; while they are left
# as-is the live tests are SKIPped so the suite stays green offline.
# ---------------------------------------------------------------------------
my $FORMS_API_KEY        = "your-forms-api-key-here";        # scoped API key with the "forms" scope
my $FORMS_CUSTOMER_ID    = "your-customer-id-here";          # numeric customer id (needed by formLifecycle_Live)
my $SUBMITTED_FORM_UUID  = "your-submitted-form-uuid-here";  # a form that has at least one submission
my $LIVE_SUBMISSION_ID   = "your-submission-id-here";        # a submission id belonging to that form

sub _validFormUuidSet {
    return $VALID_FORM_UUID ne "your-valid-form-uuid-here" && $VALID_FORM_UUID ne "";
}

sub _formsApiKeySet {
    return $FORMS_API_KEY ne "your-forms-api-key-here" && $FORMS_API_KEY ne "";
}

sub _formsCustomerIdSet {
    return $FORMS_CUSTOMER_ID ne "your-customer-id-here" && $FORMS_CUSTOMER_ID ne "";
}

sub _submittedFormSet {
    return $SUBMITTED_FORM_UUID ne "your-submitted-form-uuid-here" && $SUBMITTED_FORM_UUID ne "";
}

sub _submissionIdSet {
    return $LIVE_SUBMISSION_ID ne "your-submission-id-here" && $LIVE_SUBMISSION_ID ne "";
}

sub _liveFormsService {
    return Paubox_Forms_SDK->new('apiKey' => $FORMS_API_KEY);
}

sub getForm_Success: Tests(1) {
    print "Executing tests for getForm_Success:\n";

    SKIP: {
        skip "Set VALID_FORM_UUID placeholder to run live getForm test", 1
            unless _validFormUuidSet();

        my $forms = Paubox_Forms_SDK->new();
        my $response = eval { $forms->getForm($VALID_FORM_UUID) };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        my $apiResponsePERL = from_json($response);

        if ( defined $apiResponsePERL->{'id'} ) {
            is('Success', 'Success', 'Test passed');
        } else {
            is('Failure', 'Success', 'Test failed: id not present in response');
        }
    }
}

sub getForm_Failure: Tests(1) {
    print "Executing tests for getForm_Failure:\n";

    my $forms = Paubox_Forms_SDK->new();
    my $response = eval { $forms->getForm($INVALID_FORM_UUID) };

    if ($@) {
        # A die on error is also acceptable as failure behaviour
        is('Success', 'Success', 'Test passed: got expected error');
        return;
    }

    my $apiResponsePERL = from_json($response);

    if ( defined $apiResponsePERL->{'errors'} || !defined $apiResponsePERL->{'id'} ) {
        is('Success', 'Success', 'Test passed');
    } else {
        is('Failure', 'Success', 'Test failed: expected error but got success');
    }
}

sub submitForm_Success: Tests(1) {
    print "Executing tests for submitForm_Success:\n";

    SKIP: {
        skip "Set VALID_FORM_UUID placeholder to run live submitForm test", 1
            unless _validFormUuidSet();

        my $forms = Paubox_Forms_SDK->new();
        my $response = eval {
            $forms->submitForm(
                $VALID_FORM_UUID,
                { first_name => "Jane", last_name => "Doe", email => "jane\@example.com" }
            );
        };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        # 201 returns empty body; empty string or no errors both indicate success
        if ( !defined($response) || $response eq "" ) {
            is('Success', 'Success', 'Test passed: 201 empty body');
        } else {
            my $apiResponsePERL = from_json($response);
            if ( !defined $apiResponsePERL->{'errors'} ) {
                is('Success', 'Success', 'Test passed');
            } else {
                is('Failure', 'Success', 'Test failed: ' . $response);
            }
        }
    }
}

sub submitForm_Failure: Tests(1) {
    print "Executing tests for submitForm_Failure:\n";

    my $forms = Paubox_Forms_SDK->new();

    # Missing formId should die
    my $response = eval { $forms->getForm("") };

    if ($@) {
        is('Success', 'Success', 'Test passed: got expected error for empty formId');
    } else {
        is('Failure', 'Success', 'Test failed: expected error for empty formId');
    }
}

# ---------------------------------------------------------------------------
# OFFLINE tests for the authenticated (scoped-API-key) methods.
# These exercise the constructor and every argument-validation path only.
# They must pass with no network access and no credentials.
# ---------------------------------------------------------------------------

sub constructor_Offline: Tests(3) {
    print "Executing tests for constructor_Offline:\n";

    my $forms = Paubox_Forms_SDK->new();
    isa_ok($forms, 'Paubox_Forms_SDK', 'bare constructor result');

    my $service = Paubox_Forms_SDK->new('apiKey' => 'test-api-key');
    isa_ok($service, 'Paubox_Forms_SDK', 'constructor-with-apiKey result');
    is($service->{'apiKey'}, 'test-api-key', 'apiKey is stored on the object');
}

sub apiKeyRequired_Offline: Tests(11) {
    print "Executing tests for apiKeyRequired_Offline:\n";

    # Guarantee no key is set, even when a config.cfg with FORMS_API_KEY exists.
    my $forms = Paubox_Forms_SDK->new();
    delete $forms->{'apiKey'};

    my @calls = (
        [ 'listForms',           [] ],
        [ 'getFormById',         [ 'some-form-id' ] ],
        [ 'createForm',          [ { 'title' => 't', 'form_json' => {}, 'customer_id' => 1 } ] ],
        [ 'updateForm',          [ 'some-form-id', { 'title' => 't' } ] ],
        [ 'archiveForm',         [ 'some-form-id' ] ],
        [ 'unarchiveForm',       [ 'some-form-id' ] ],
        [ 'copyForm',            [ 'some-form-id', 'New Title' ] ],
        [ 'getFormStats',        [] ],
        [ 'listFormSubmissions', [ 'some-form-id' ] ],
        [ 'getSubmissionsCsv',   [ 'some-form-id' ] ],
        [ 'getSubmissionPdf',    [ 'some-form-id', 'some-submission-id' ] ],
    );

    foreach my $call (@calls) {
        my ($method, $args) = @{$call};
        eval { $forms->$method(@{$args}) };
        like($@, qr/apiKey is required/, $method . ' dies without an apiKey');
    }
}

sub argValidation_Offline: Tests(19) {
    print "Executing tests for argValidation_Offline:\n";

    my $service = Paubox_Forms_SDK->new('apiKey' => 'test-api-key');

    eval { $service->getForm() };
    like($@, qr/formId is required/, 'getForm dies without formId');

    eval { $service->submitForm('some-form-id') };
    like($@, qr/formData is required/, 'submitForm dies without formData');

    eval { $service->submitForm('some-form-id', {}) };
    like($@, qr/formData is required/, 'submitForm dies on empty formData hashref');

    eval { $service->getFormById() };
    like($@, qr/formId is required/, 'getFormById dies without formId');

    eval { $service->createForm() };
    like($@, qr/attrs is required/, 'createForm dies without attrs');

    eval { $service->createForm({}) };
    like($@, qr/attrs is required/, 'createForm dies on empty attrs hashref');

    eval { $service->createForm({ 'form_json' => {}, 'customer_id' => 1 }) };
    like($@, qr/title is required/, 'createForm dies without title');

    eval { $service->createForm({ 'title' => 't', 'customer_id' => 1 }) };
    like($@, qr/form_json is required/, 'createForm dies without form_json');

    eval { $service->createForm({ 'title' => 't', 'form_json' => {} }) };
    like($@, qr/customer_id is required/, 'createForm dies without customer_id');

    eval { $service->updateForm(undef, { 'title' => 't' }) };
    like($@, qr/formId is required/, 'updateForm dies without formId');

    eval { $service->updateForm('some-form-id', {}) };
    like($@, qr/updates is required/, 'updateForm dies on empty updates hashref');

    eval { $service->archiveForm('') };
    like($@, qr/formId is required/, 'archiveForm dies without formId');

    eval { $service->unarchiveForm() };
    like($@, qr/formId is required/, 'unarchiveForm dies without formId');

    eval { $service->copyForm(undef, 'New Title') };
    like($@, qr/formId is required/, 'copyForm dies without formId');

    eval { $service->copyForm('some-form-id') };
    like($@, qr/newTitle is required/, 'copyForm dies without newTitle');

    eval { $service->listFormSubmissions() };
    like($@, qr/formId is required/, 'listFormSubmissions dies without formId');

    eval { $service->getSubmissionsCsv('') };
    like($@, qr/formId is required/, 'getSubmissionsCsv dies without formId');

    eval { $service->getSubmissionPdf() };
    like($@, qr/formId is required/, 'getSubmissionPdf dies without formId');

    eval { $service->getSubmissionPdf('some-form-id') };
    like($@, qr/submissionId is required/, 'getSubmissionPdf dies without submissionId');
}

# ---------------------------------------------------------------------------
# LIVE tests for the authenticated (scoped-API-key) methods.
# Each block is SKIPped unless the placeholder constants at the top of this
# file have been replaced with real values, so unset placeholders never emit
# failures (e.g. in CI without credentials).
# ---------------------------------------------------------------------------

sub listForms_Live: Tests(1) {
    print "Executing tests for listForms_Live:\n";

    SKIP: {
        # customer_id is required by the server for scoped-API-key callers,
        # so this test also needs FORMS_CUSTOMER_ID.
        skip "Set FORMS_API_KEY and FORMS_CUSTOMER_ID placeholders to run live listForms test", 1
            unless _formsApiKeySet() && _formsCustomerIdSet();

        my $service = _liveFormsService();
        my $response = eval {
            $service->listForms({
                'customer_id' => 0 + $FORMS_CUSTOMER_ID,
                'items'       => 5,
                'page'        => 1,
            });
        };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        my $apiResponsePERL = from_json($response);
        if ( ref($apiResponsePERL->{'results'}) eq 'ARRAY' ) {
            is('Success', 'Success', 'Test passed');
        } else {
            is('Failure', 'Success', 'Test failed: results not present in response');
        }
    }
}

sub getFormStats_Live: Tests(1) {
    print "Executing tests for getFormStats_Live:\n";

    SKIP: {
        skip "Set FORMS_API_KEY placeholder to run live getFormStats test", 1
            unless _formsApiKeySet();

        my $service = _liveFormsService();
        my $response = eval { $service->getFormStats() };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        my $apiResponsePERL = from_json($response);
        if ( defined $apiResponsePERL->{'active_form_count'} ) {
            is('Success', 'Success', 'Test passed');
        } else {
            is('Failure', 'Success', 'Test failed: active_form_count not present in response');
        }
    }
}

sub formLifecycle_Live: Tests(6) {
    print "Executing tests for formLifecycle_Live:\n";

    SKIP: {
        skip "Set FORMS_API_KEY and FORMS_CUSTOMER_ID placeholders to run live form lifecycle tests", 6
            unless _formsApiKeySet() && _formsCustomerIdSet();

        my $service = _liveFormsService();

        # 1. createForm
        my $created = eval {
            $service->createForm({
                'title'       => 'Perl SDK lifecycle test ' . time(),
                'form_json'   => { 'fields' => [] },
                'customer_id' => 0 + $FORMS_CUSTOMER_ID,
            });
        };
        if ($@) {
            is('Failure', 'Success', 'createForm failed: ' . $@);
            skip "createForm failed; skipping dependent lifecycle tests", 5;
        }
        my $formId = from_json($created)->{'id'};
        ok(defined($formId) && $formId ne "", 'createForm returned a new form id');

        # 2. getFormById
        my $fetched = eval { $service->getFormById($formId) };
        if ($@) {
            is('Failure', 'Success', 'getFormById failed: ' . $@);
        } else {
            ok(defined from_json($fetched)->{'data'}, 'getFormById returned the form record');
        }

        # 3. updateForm
        my $updated = eval {
            $service->updateForm($formId, { 'description' => 'Updated by Perl SDK test suite' });
        };
        if ($@) {
            is('Failure', 'Success', 'updateForm failed: ' . $@);
        } else {
            ok(defined from_json($updated)->{'detail'}, 'updateForm returned a detail message');
        }

        # 4. copyForm
        my $copyId;
        my $copied = eval {
            $service->copyForm($formId, 'Perl SDK lifecycle copy ' . time());
        };
        if ($@) {
            is('Failure', 'Success', 'copyForm failed: ' . $@);
        } else {
            $copyId = from_json($copied)->{'id'};
            ok(defined($copyId) && $copyId ne "", 'copyForm returned the new form id');
        }

        # 5. archiveForm
        my $archived = eval { $service->archiveForm($formId) };
        if ($@) {
            is('Failure', 'Success', 'archiveForm failed: ' . $@);
        } else {
            ok(defined from_json($archived)->{'detail'}, 'archiveForm returned a detail message');
        }

        # 6. unarchiveForm
        my $unarchived = eval { $service->unarchiveForm($formId) };
        if ($@) {
            is('Failure', 'Success', 'unarchiveForm failed: ' . $@);
        } else {
            ok(defined from_json($unarchived)->{'detail'}, 'unarchiveForm returned a detail message');
        }

        # Cleanup: leave the created form and its copy archived.
        eval { $service->archiveForm($formId) };
        eval { $service->archiveForm($copyId) } if defined $copyId;
    }
}

sub listFormSubmissions_Live: Tests(1) {
    print "Executing tests for listFormSubmissions_Live:\n";

    SKIP: {
        skip "Set FORMS_API_KEY and SUBMITTED_FORM_UUID placeholders to run live listFormSubmissions test", 1
            unless _formsApiKeySet() && _submittedFormSet();

        my $service = _liveFormsService();
        my $response = eval { $service->listFormSubmissions($SUBMITTED_FORM_UUID, { 'items' => 5 }) };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        my $apiResponsePERL = from_json($response);
        if ( defined $apiResponsePERL->{'data'} ) {
            is('Success', 'Success', 'Test passed');
        } else {
            is('Failure', 'Success', 'Test failed: data not present in response');
        }
    }
}

sub getSubmissionsCsv_Live: Tests(1) {
    print "Executing tests for getSubmissionsCsv_Live:\n";

    SKIP: {
        skip "Set FORMS_API_KEY and SUBMITTED_FORM_UUID placeholders to run live getSubmissionsCsv test", 1
            unless _formsApiKeySet() && _submittedFormSet();

        my $service = _liveFormsService();
        my $response = eval { $service->getSubmissionsCsv($SUBMITTED_FORM_UUID) };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        ok(defined($response) && $response ne "", 'getSubmissionsCsv returned a non-empty CSV body');
    }
}

sub getSubmissionsCsvSingle_Live: Tests(1) {
    print "Executing tests for getSubmissionsCsvSingle_Live:\n";

    SKIP: {
        skip "Set FORMS_API_KEY, SUBMITTED_FORM_UUID and LIVE_SUBMISSION_ID placeholders to run live single-submission CSV test", 1
            unless _formsApiKeySet() && _submittedFormSet() && _submissionIdSet();

        my $service = _liveFormsService();
        my $response = eval { $service->getSubmissionsCsv($SUBMITTED_FORM_UUID, $LIVE_SUBMISSION_ID) };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        ok(defined($response) && $response ne "", 'getSubmissionsCsv (single submission) returned a non-empty CSV body');
    }
}

sub getSubmissionPdf_Live: Tests(1) {
    print "Executing tests for getSubmissionPdf_Live:\n";

    SKIP: {
        skip "Set FORMS_API_KEY, SUBMITTED_FORM_UUID and LIVE_SUBMISSION_ID placeholders to run live getSubmissionPdf test", 1
            unless _formsApiKeySet() && _submittedFormSet() && _submissionIdSet();

        my $service = _liveFormsService();
        my $response = eval { $service->getSubmissionPdf($SUBMITTED_FORM_UUID, $LIVE_SUBMISSION_ID) };

        if ($@) {
            is('Failure', 'Success', 'Test failed: ' . $@);
            return;
        }

        ok(defined($response) && $response =~ /^%PDF/, 'getSubmissionPdf returned PDF bytes');
    }
}

# ---------------------------------------------------------------------------
# OFFLINE path-safety tests.
#
# Ids are interpolated into the request path, so an id carrying "/", "?", "#"
# or ".." must never be able to retarget the request at a different endpoint
# while still sending the caller's credentials. The dangerous case is silent:
# GET /api/forms/{id} and GET /api/forms/{id}/submissions both key their
# payload on "data", so a formId of "<uuid>/submissions" would satisfy
# _assertSuccessKey and return submission records from a call that asked for a
# form definition.
#
# These run with no network and no credentials: every assertion below must fail
# at the id guard, which is reached before any HTTP call is made.
# ---------------------------------------------------------------------------

my $VALID_UUID       = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
my $VALID_UUID_PLAIN = 'a1b2c3d4e5f67890abcdef1234567890';
# The exact shape that turns getFormById into an unintended submissions read.
my $RETARGET_ID      = $VALID_UUID . '/submissions';

sub pathSegment_Offline: Tests(9) {
    print "Executing tests for pathSegment_Offline:\n";

    is(
        Paubox_Forms_SDK::_pathSegment($VALID_UUID, 'formId'),
        $VALID_UUID,
        'a dashed uuid4 passes through unchanged'
    );
    is(
        Paubox_Forms_SDK::_pathSegment($VALID_UUID_PLAIN, 'formId'),
        $VALID_UUID_PLAIN,
        'an undashed uuid4 passes through unchanged'
    );

    foreach my $bad ( 'a/b', '../x', $VALID_UUID . '/..', 'x?y=1', 'x#frag', 'x%2Fy' ) {
        eval { Paubox_Forms_SDK::_pathSegment($bad, 'formId') };
        like($@, qr/not allowed in a Paubox Forms id/, "_pathSegment rejects '$bad'");
    }

    eval { Paubox_Forms_SDK::_pathSegment(undef, 'formId') };
    like($@, qr/formId is required/, '_pathSegment rejects undef with a required error');
}

sub pathInjectionRejected_Offline: Tests(9) {
    print "Executing tests for pathInjectionRejected_Offline:\n";

    my $service = Paubox_Forms_SDK->new('apiKey' => 'test-api-key');

    # Every method that puts a caller-supplied id in the path. The second
    # element is the remaining args needed to reach the id guard.
    my @calls = (
        [ 'getForm',             [] ],
        [ 'submitForm',          [ { 'field' => 'value' } ] ],
        [ 'getFormById',         [] ],
        [ 'updateForm',          [ { 'title' => 't' } ] ],
        [ 'archiveForm',         [] ],
        [ 'unarchiveForm',       [] ],
        [ 'listFormSubmissions', [] ],
        [ 'getSubmissionsCsv',   [] ],
        [ 'getSubmissionPdf',    [ $VALID_UUID ] ],
    );

    foreach my $call (@calls) {
        my ($method, $rest) = @{$call};
        eval { $service->$method($RETARGET_ID, @{$rest}) };
        like(
            $@,
            qr/not allowed in a Paubox Forms id/,
            $method . ' rejects a formId that would retarget the request'
        );
    }
}

sub submissionIdInjectionRejected_Offline: Tests(2) {
    print "Executing tests for submissionIdInjectionRejected_Offline:\n";

    my $service = Paubox_Forms_SDK->new('apiKey' => 'test-api-key');

    eval { $service->getSubmissionsCsv($VALID_UUID, '../../admin') };
    like($@, qr/submissionId contains characters that are not allowed/,
        'getSubmissionsCsv rejects a traversal submissionId');

    eval { $service->getSubmissionPdf($VALID_UUID, 'x/y') };
    like($@, qr/submissionId contains characters that are not allowed/,
        'getSubmissionPdf rejects a submissionId containing a slash');
}

sub retargetNeverReachesNetwork_Offline: Tests(2) {
    print "Executing tests for retargetNeverReachesNetwork_Offline:\n";

    my $service = Paubox_Forms_SDK->new('apiKey' => 'test-api-key');

    eval { $service->getFormById($RETARGET_ID) };
    my $err = $@;

    # Must fail at the guard...
    like($err, qr/not allowed in a Paubox Forms id/,
        'getFormById("<uuid>/submissions") dies at the id guard');

    # ...and must NOT have gone to the wire. A request that reached the API
    # would surface as a response body or an HTTP status, never as the guard
    # message, so the absence of those is what proves no call was made.
    unlike($err, qr/"data"|Request failed with HTTP status|Unexpected empty response/,
        'no HTTP request is made for a retargeting formId');
}

1;
