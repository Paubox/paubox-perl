# Paubox Perl SDK

Official Perl SDK for the Paubox Email API and Paubox Forms API.

## Repository Structure

```
lib/
  Paubox_Email_SDK.pm          # Email API: sendMessage, getEmailDisposition
  Paubox_Email_SDK/
    ApiHelper.pm               # HTTP layer (REST::Client GET/POST/PUT, responseCode accessor)
    Message.pm                 # Email message object
  Paubox_Forms_SDK.pm          # Forms API: public getForm/submitForm + authenticated form management
t/
  Paubox_Email_SDK.t           # Test runner entry point
  SendMessage_TestData.csv     # CSV-driven test data for email tests
  lib/
    Paubox_Email_SDK/Test.pm   # Email API test cases (Test::Class)
    Paubox_Forms_SDK/Test.pm   # Forms API test cases (Test::Class)
Makefile.PL                    # CPAN build config
cpanfile                       # Perl dependency declarations
CHANGES                        # Changelog
```

## Setup

### Install dependencies

```bash
cpanm --installdeps .
```

Or install from `cpanfile` directly:

```bash
cpanm JSON Config::General REST::Client TryCatch String::Util MIME::Base64
cpanm Test::Class Test::More Text::CSV
```

### Configure credentials

Create `config.cfg` in the project root:

```
API_KEY = YOUR_API_KEY
FORMS_API_KEY = YOUR_SCOPED_API_KEY   # optional; only for authenticated Forms methods
```

`API_KEY` is required by the Email API only. The public Forms
endpoints (`getForm`, `submitForm`) need no credentials; the authenticated
form-management methods need a scoped API key with the `forms` scope, supplied
either as `FORMS_API_KEY` in `config.cfg` or as
`Paubox_Forms_SDK->new('apiKey' => ...)`.

## Running Tests

```bash
perl Makefile.PL
make test
```

## Key Architecture Patterns

- **HTTP layer:** All requests go through `Paubox_Email_SDK::ApiHelper`, which wraps `REST::Client` (`callToAPIByGet`/`callToAPIByPost`/`callToAPIByPut`). Public Forms calls pass an empty auth header which is conditionally omitted. When called on an instance, the helper stores the last HTTP status, readable via `responseCode()` — used by the Forms binary endpoints (CSV/PDF) to detect non-2xx responses.
- **Error handling:** `TryCatch` is used throughout; methods die on unexpected responses. Authenticated Forms methods die if no API key is set.
- **JSON:** All request bodies are `encode_json` encoded; responses are parsed with `from_json` / `decode_json`. Exception: `getSubmissionsCsv`/`getSubmissionPdf` return raw CSV/PDF bytes.
- **Base64:** HTML email content is base64-encoded before transmission (`MIME::Base64`). Form attachment content must also be base64-encoded by the caller.
- **Query strings:** Forms list/stats params are built with `URI::Escape` (`uri_escape`); only caller-provided keys are included.
- **Config:** Email credentials are read from `config.cfg` using `Config::General`. The Forms SDK needs no config for public endpoints; for authenticated methods it takes `'apiKey'` in the constructor or falls back to `FORMS_API_KEY` in `config.cfg` (loaded in an eval so a missing/broken config never breaks the public-only constructor).

## APIs

### Email API (`Paubox_Email_SDK`)
- Base URL: `https://api.paubox.com/v1`
- Auth: `Token token=<apiKey>`
- Methods: `sendMessage`, `getEmailDisposition`

### Forms API (`Paubox_Forms_SDK`)
- Base URL: `https://api.paubox.com/forms`
- Auth: None for public endpoints; `Authorization: Bearer <scoped API key>` (with `forms` scope) for form-management endpoints
- Public methods: `getForm`, `submitForm`
- Authenticated methods: `listForms`, `getFormById`, `createForm`, `updateForm`, `archiveForm`, `unarchiveForm`, `copyForm`, `getFormStats`, `listFormSubmissions`, `getSubmissionsCsv`, `getSubmissionPdf`

See [api.md](api.md) for full API reference.
